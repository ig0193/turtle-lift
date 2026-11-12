import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/glance_bridge.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/session_progress.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/ui/glance_sync.dart';

/// What the app tells the iOS Live Activity and home-screen widget
/// (`docs/adr/0008-the-week-lives-on-the-workout-landing.md`). Everything sent
/// is derived on the spot; the native side stores nothing it could not be told
/// again, and the clock is a start time the system counts from.
class _FakeBridge implements GlanceBridge {
  final List<String> calls = <String>[];

  @override
  Stream<void> get openWorkoutTaps => const Stream<void>.empty();
  SessionGlance? lastSession;
  WeekGlance? lastWeek;

  @override
  Future<void> showSession(SessionGlance glance) async {
    calls.add('show ${glance.done}/${glance.total}');
    lastSession = glance;
  }

  @override
  Future<void> endSession() async => calls.add('end');

  @override
  Future<void> showWeek(WeekGlance glance) async => lastWeek = glance;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SessionStore store;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = SessionStore(database);
  });
  tearDown(() => database.close());

  Exercise ex(String id, String name) => Exercise(
        id: id,
        name: name,
        equipment: 'Barbell',
        loadType: 'weighted',
        primary: const <String>['chest/mid'],
        secondary: const <String>[],
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
      );
  final index = ExerciseIndex(<Exercise>[ex('bench', 'Bench press'), ex('fly', 'Cable fly')]);

  late _FakeBridge bridge;
  late ProviderContainer container;

  Future<void> pumpSync(
    WidgetTester tester, {
    WorkoutSession? open,
    List<HistorySession>? history,
    List<TrainingPlanEntry> plan = const <TrainingPlanEntry>[],
  }) async {
    bridge = _FakeBridge();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        exerciseIndexProvider.overrideWithValue(index),
        initialActiveSessionProvider.overrideWithValue(open),
        glanceBridgeProvider.overrideWithValue(bridge),
        planTodayProvider.overrideWithValue(LocalDate(2026, 10, 21)),
        initialTrainingPlanProvider.overrideWithValue(plan),
        if (history != null) historySessionsProvider.overrideWithValue(history),
      ],
      child: const GlanceSync(child: SizedBox()),
    ));
    container = ProviderScope.containerOf(tester.element(find.byType(SizedBox)));
    await tester.pump();
  }

  Future<WorkoutSession> openTwo(WidgetTester tester) async {
    late WorkoutSession s;
    await tester.runAsync(() async {
      final created = await store.createSession(templateName: 'Push day');
      for (final id in <String>['bench', 'fly']) {
        await store.addExercise(
            sessionId: created.id, exerciseId: id, loadType: LoadType.weighted);
      }
      s = (await store.readOpenSession())!;
    });
    return s;
  }

  group('the Live Activity', () {
    testWidgets('nothing while the workout is still on its ready view',
        (tester) async {
      final open = await openTwo(tester);
      await pumpSync(tester, open: open);
      expect(bridge.calls, <String>['end'],
          reason: 'no activity until logging starts');
    });

    testWidgets('starts when logging starts, with the title and "0 of 2"',
        (tester) async {
      final open = await openTwo(tester);
      await pumpSync(tester, open: open);

      container.read(loggingStartedProvider.notifier).start(open.id);
      await tester.pump();

      expect(bridge.calls.last, 'show 0/2');
      expect(bridge.lastSession!.title, 'Push day');
      expect(bridge.lastSession!.clockStart, open.loggedAt,
          reason: 'a start time the system counts from, never a duration');
    });

    testWidgets('updates as exercises are done, ends on Finish',
        (tester) async {
      final open = await openTwo(tester);
      await pumpSync(tester, open: open);
      container.read(loggingStartedProvider.notifier).start(open.id);
      await tester.pump();

      await tester.runAsync(() async {
        await container.read(activeSessionProvider.notifier).writeSet(
            sessionExerciseId: open.exercises.first.id,
            position: 0,
            weightKg: 60,
            reps: 8,
            completed: true);
        await container
            .read(activeSessionProvider.notifier)
            .markExerciseDone(open.exercises.first.id, true);
      });
      await tester.pump();
      expect(bridge.calls.last, 'show 1/2');

      await tester.runAsync(
          () => container.read(activeSessionProvider.notifier).finish());
      await tester.pump();
      expect(bridge.calls.last, 'end');
    });

    testWidgets('ends on Discard', (tester) async {
      final open = await openTwo(tester);
      await pumpSync(tester, open: open);
      container.read(loggingStartedProvider.notifier).start(open.id);
      await tester.pump();

      await tester.runAsync(
          () => container.read(activeSessionProvider.notifier).discard());
      await tester.pump();
      expect(bridge.calls.last, 'end');
    });

    test('no clock for a backdated or stale session (the live-clock rule)',
        () {
      final now = DateTime(2026, 10, 21, 18);
      WorkoutSession at(LocalDate day, DateTime loggedAt) => WorkoutSession(
            id: 's',
            title: 'Legs',
            performedOn: day,
            loggedAt: loggedAt,
            templateId: null,
            templateName: null,
            isOpen: true,
            exercises: const <SessionExercise>[],
          );
      expect(
          clockStartFor(at(LocalDate(2026, 10, 21), DateTime(2026, 10, 21, 17)),
              now),
          DateTime(2026, 10, 21, 17));
      expect(
          clockStartFor(at(LocalDate(2026, 10, 20), DateTime(2026, 10, 21, 17)),
              now),
          isNull,
          reason: 'dated another day');
      expect(
          clockStartFor(at(LocalDate(2026, 10, 21), DateTime(2026, 10, 21, 8)),
              now),
          isNull,
          reason: 'over six hours old');
    });
  });

  group('the home-screen widget', () {
    testWidgets('gets this week and the last workout, derived', (tester) async {
      await pumpSync(
        tester,
        plan: <TrainingPlanEntry>[
          TrainingPlanEntry(
              effectiveFrom: LocalDate(2026, 10, 1),
              weekdays: const <int>{0, 2, 4}),
        ],
        history: <HistorySession>[
          HistorySession(
            id: 'a',
            performedOn: DateTime(2026, 10, 19),
            title: 'Push day',
            exercises: const <HistoryExercise>[
              HistoryExercise(
                  name: 'Bench press',
                  primaryGroupIds: <String>['chest'],
                  setScores: <double>[60, 60]),
            ],
          ),
        ],
      );

      final week = bridge.lastWeek!;
      expect(week.headline, '1 of 3 this week');
      expect(week.caption, '2 more to go. Next is Wednesday');
      expect(week.days.map((d) => '${d.label}:${d.state}'),
          <String>['Mon:hit', 'Wed:ahead', 'Fri:ahead']);
      expect(week.lastWorkout, endsWith('Push day · 2 sets'));
    });

    testWidgets('with no plan it says so, never "0 of 0"', (tester) async {
      await pumpSync(tester, history: const <HistorySession>[]);
      expect(bridge.lastWeek!.headline, 'Pick training days');
      expect(bridge.lastWeek!.days, isEmpty);
      expect(bridge.lastWeek!.lastWorkout, isNull);
    });

    test('serialises to plain JSON the widget can read', () {
      const week = WeekGlance(
        headline: '1 of 3 this week',
        caption: '2 more to go. Next is Wednesday',
        days: <GlanceDay>[GlanceDay('Mon', 'hit')],
        lastWorkout: 'Yesterday · Push day · 14 sets',
      );
      expect(week.toJson(), <String, Object?>{
        'headline': '1 of 3 this week',
        'caption': '2 more to go. Next is Wednesday',
        'days': <Map<String, String>>[
          <String, String>{'label': 'Mon', 'state': 'hit'},
        ],
        'lastWorkout': 'Yesterday · Push day · 14 sets',
      });
    });
  });

  group('the method channel bridge', () {
    test('sends the calls the Swift side expects, and survives a '
        'platform without it', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(
        kGlanceChannel,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
          () => messenger.setMockMethodCallHandler(kGlanceChannel, null));

      final real = MethodChannelGlanceBridge(enabled: true);
      await real.showSession(SessionGlance(
        title: 'Push day',
        done: 1,
        total: 5,
        clockStart: DateTime.fromMillisecondsSinceEpoch(1000),
      ));
      await real.endSession();
      expect(calls.map((c) => c.method), <String>['showSession', 'endSession']);

      // The Swift side calls back when a Live Activity or widget is tapped.
      final taps = <void>[];
      final sub = real.openWorkoutTaps.listen(taps.add);
      await messenger.handlePlatformMessage(
        kGlanceChannel.name,
        kGlanceChannel.codec
            .encodeMethodCall(const MethodCall('openWorkout')),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(taps, hasLength(1));
      await sub.cancel();
      expect(calls.first.arguments, <String, Object?>{
        'title': 'Push day',
        'done': 1,
        'total': 5,
        'clockStartMs': 1000,
      });

      messenger.setMockMethodCallHandler(kGlanceChannel, null);
      await real.endSession(); // MissingPluginException is swallowed.
    });
  });
}
