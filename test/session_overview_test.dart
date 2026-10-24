import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/session_progress.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/body_diagram.dart';
import 'package:turtle_lift/src/ui/exercise_detail_screen.dart';
import 'package:turtle_lift/src/ui/exercise_picker_sheet.dart';
import 'package:turtle_lift/src/ui/session_actions.dart';
import 'package:turtle_lift/src/ui/session_body_map.dart';
import 'package:turtle_lift/src/ui/session_overview_body.dart';
import 'package:turtle_lift/src/ui/set_logging_screen.dart';

/// The workout in progress: its ready view, its list, its live strip and clock,
/// and what the map shows of a plan.
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

  Exercise ex(
    String id,
    String name, {
    String primary = 'chest/mid',
    List<String> secondary = const <String>['triceps/triceps'],
  }) =>
      Exercise(
        id: id,
        name: name,
        equipment: 'barbell',
        loadType: 'weighted',
        primary: <String>[primary],
        secondary: secondary,
        setup: 'Set up.',
        posture: 'Braced.',
        execution: 'Press, breathing out.',
        commonMistakes: 'No bouncing.',
      );

  final index = ExerciseIndex(<Exercise>[
    ex('bench', 'Bench press'),
    ex('fly', 'Cable fly', primary: 'chest/upper', secondary: const <String>[]),
    ex('curl', 'Barbell curl', primary: 'biceps/biceps',
        secondary: const <String>[]),
  ]);

  /// A session with [ids] on its list; [worked] names the ones to give a
  /// completed set, and [typed] the ones to give a set that is written but not
  /// ticked.
  Future<WorkoutSession> makeSession(
    WidgetTester tester,
    List<String> ids, {
    Set<String> worked = const <String>{},
    Set<String> typed = const <String>{},
    DateTime? now,
  }) async {
    late WorkoutSession session;
    await tester.runAsync(() async {
      session = await store.createSession(templateName: 'Push day');
      for (final id in ids) {
        final row = await store.addExercise(
          sessionId: session.id,
          exerciseId: id,
          loadType: LoadType.weighted,
        );
        if (worked.contains(id)) {
          await store.writeSet(
              sessionExerciseId: row,
              position: 0,
              weightKg: 60,
              reps: 8,
              completed: true);
        } else if (typed.contains(id)) {
          await store.writeSet(
              sessionExerciseId: row, position: 0, weightKg: 60, reps: 8);
        }
      }
      session = (await store.readOpenSession())!;
    });
    return session;
  }

  Future<void> pumpOverview(
    WidgetTester tester,
    WorkoutSession session, {
    DateTime? now,
    Set<String> started = const <String>{},
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialActiveSessionProvider.overrideWithValue(session),
          if (now != null) clockNowProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                // Seeded after the first read, the way a tap would record it.
                for (final id in started) {
                  ref.read(loggingStartedProvider.notifier).start(id);
                }
                return SessionOverviewBody(onFinished: (_) {});
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  List<BodyDiagram> diagrams(WidgetTester tester) =>
      tester.widgetList<BodyDiagram>(find.byType(BodyDiagram)).toList();

  group('the ready view', () {
    testWidgets('says how many exercises are planned', (tester) async {
      final session = await makeSession(tester, <String>['bench', 'fly']);

      await pumpOverview(tester, session);

      expect(find.text('2 exercises planned'), findsOneWidget);
      expect(find.byKey(SessionOverviewBody.startLoggingKey), findsOneWidget);
    });

    testWidgets('says so for an empty workout', (tester) async {
      final session = await makeSession(tester, <String>[]);

      await pumpOverview(tester, session);

      expect(find.text('Nothing logged yet'), findsOneWidget);
    });

    testWidgets('says exercise, not exercises, for one', (tester) async {
      final session = await makeSession(tester, <String>['bench']);

      await pumpOverview(tester, session);

      expect(find.text('1 exercise planned'), findsOneWidget);
    });

    testWidgets('has no live strip, no list and no Finish yet', (tester) async {
      final session = await makeSession(tester, <String>['bench', 'fly']);

      await pumpOverview(tester, session);

      expect(find.byKey(LiveStrip.stripKey), findsNothing,
          reason: 'the workout is being set up, not in progress');
      expect(find.text(SessionOverviewBody.keepLoggingLabel), findsNothing);
      expect(find.byKey(SessionActions.finishKey), findsNothing,
          reason: 'there is nothing to finish before logging has started');
      expect(find.byKey(SessionActions.discardKey), findsOneWidget,
          reason: 'but the way out has to be there');
    });

    testWidgets('shows the map at its largest', (tester) async {
      final session = await makeSession(tester, <String>['bench']);

      await pumpOverview(tester, session);

      expect(
        tester.getSize(find.byType(BodyDiagram).first).height,
        kReadyDiagramHeight,
      );
    });

    testWidgets('Start logging records it and opens the picker', (tester) async {
      final session = await makeSession(tester, <String>['bench', 'fly']);
      await pumpOverview(tester, session);

      await tester.tap(find.byKey(SessionOverviewBody.startLoggingKey));
      await tester.pumpAndSettle();

      expect(find.text('What are you starting with?'), findsOneWidget);
      expect(find.byType(ExercisePickerSheet), findsOneWidget);
      final container = ProviderScope.containerOf(
          tester.element(find.byType(SessionOverviewBody)));
      expect(container.read(loggingStartedProvider), contains(session.id));
    });

    testWidgets('dismissing the picker leaves the list, not the button again',
        (tester) async {
      final session = await makeSession(tester, <String>['bench', 'fly']);
      await pumpOverview(tester, session);
      await tester.tap(find.byKey(SessionOverviewBody.startLoggingKey));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10)); // the scrim
      await tester.pumpAndSettle();

      expect(find.text(SessionOverviewBody.keepLoggingLabel), findsOneWidget);
      expect(find.byKey(SessionOverviewBody.startLoggingKey), findsNothing,
          reason: 'the user has already pressed it');
    });

    testWidgets('discarding asks first', (tester) async {
      final session = await makeSession(tester, <String>['bench']);
      await pumpOverview(tester, session);

      await tester.tap(find.byKey(SessionActions.discardKey));
      await tester.pumpAndSettle();

      expect(find.text('Discard workout?'), findsOneWidget);
    });
  });

  group('the list', () {
    testWidgets('appears once anything has been written, with no tap needed',
        (tester) async {
      final session =
          await makeSession(tester, <String>['bench', 'fly'], typed: {'bench'});

      await pumpOverview(tester, session);

      expect(find.text(SessionOverviewBody.keepLoggingLabel), findsOneWidget,
          reason: 'after a restart the in-memory tap is gone, but a set on '
              'disk says logging began');
      expect(find.byKey(SessionOverviewBody.startLoggingKey), findsNothing);
    });

    testWidgets('lists the exercises in order, with Finish available',
        (tester) async {
      final session = await makeSession(
          tester, <String>['bench', 'fly'],
          typed: {'bench'});

      await pumpOverview(tester, session);

      final bench = tester.getTopLeft(find.text('Bench press')).dy;
      final fly = tester.getTopLeft(find.text('Cable fly')).dy;
      expect(bench, lessThan(fly));
      expect(find.byKey(SessionActions.finishKey), findsOneWidget);
    });

    testWidgets('marks the first exercise that is not done as up next',
        (tester) async {
      final session = await makeSession(tester, <String>['bench', 'fly'],
          worked: {'bench'});
      // Marking bench done makes fly the next one.
      await tester.runAsync(() async {
        await store.setMarkedDone(session.exercises.first.id, true);
      });
      final updated = (await tester.runAsync(() => store.readOpenSession()))!;

      await pumpOverview(tester, updated);

      expect(find.text('UP NEXT'), findsOneWidget);
      final upNext = tester.getTopLeft(find.text('UP NEXT')).dy;
      final fly = tester.getTopLeft(find.text('Cable fly')).dy;
      final bench = tester.getTopLeft(find.text('Bench press')).dy;
      expect(upNext, greaterThan(bench));
      expect(upNext, lessThan(fly), reason: 'the tag sits on the fly row');
    });

    testWidgets('counts how many are done', (tester) async {
      final session = await makeSession(tester, <String>['bench', 'fly'],
          worked: {'bench'});
      await tester.runAsync(() async {
        await store.setMarkedDone(session.exercises.first.id, true);
      });
      final updated = (await tester.runAsync(() => store.readOpenSession()))!;

      await pumpOverview(tester, updated);

      expect(find.text('1 of 2 done'), findsOneWidget);
    });

    testWidgets('shrinks the map as the list grows', (tester) async {
      expect(sessionDiagramHeightFor(0), 176);
      expect(sessionDiagramHeightFor(3), 176);
      expect(sessionDiagramHeightFor(4), 152);
      expect(sessionDiagramHeightFor(6), 128);
      expect(sessionDiagramHeightFor(8), 108);
      expect(
        sessionDiagramHeightFor(8),
        lessThan(kReadyDiagramHeight),
        reason: 'the ready view is where the map is biggest',
      );
    });

    testWidgets('a row with written sets opens the logging screen',
        (tester) async {
      final session = await makeSession(tester, <String>['bench'],
          typed: {'bench'});
      await pumpOverview(tester, session);

      await tester.tap(find.text('Bench press'));
      await tester.pumpAndSettle();

      expect(find.byType(SetLoggingScreen), findsOneWidget);
    });

    testWidgets('a row for an exercise never done opens its page first',
        (tester) async {
      final session = await makeSession(tester, <String>['bench', 'fly'],
          typed: {'bench'});
      await pumpOverview(tester, session);

      await tester.tap(find.text('Cable fly'));
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseDetailScreen), findsOneWidget);
    });

    testWidgets('Add exercise opens the picker, titled for adding',
        (tester) async {
      final session = await makeSession(tester, <String>['bench'],
          typed: {'bench'});
      await pumpOverview(tester, session);

      await tester.tap(find.byKey(SessionOverviewBody.addExerciseKey));
      await tester.pumpAndSettle();

      expect(find.text('Add an exercise'), findsOneWidget);
    });
  });

  group('the live strip and clock', () {
    testWidgets('appear together once logging has started', (tester) async {
      final session = await makeSession(tester, <String>['bench'],
          typed: {'bench'});

      await pumpOverview(
        tester,
        session,
        now: session.loggedAt.add(const Duration(minutes: 12, seconds: 34)),
      );

      expect(find.text('WORKOUT IN PROGRESS'), findsOneWidget);
      expect(find.byKey(SessionClock.clockKey), findsOneWidget);
      expect(find.text('12:34'), findsOneWidget);
    });

    testWidgets('are both absent on the ready view', (tester) async {
      final session = await makeSession(tester, <String>['bench']);

      await pumpOverview(
        tester,
        session,
        now: session.loggedAt.add(const Duration(minutes: 3)),
      );

      expect(find.text('WORKOUT IN PROGRESS'), findsNothing);
      expect(find.byKey(SessionClock.clockKey), findsNothing);
    });

    testWidgets('the clock hides for a workout dated another day',
        (tester) async {
      late WorkoutSession backdated;
      await tester.runAsync(() async {
        backdated = await store.createSession(
          templateName: 'Old',
          performedOn: LocalDate.today().addDays(-2),
        );
        final row = await store.addExercise(
          sessionId: backdated.id,
          exerciseId: 'bench',
          loadType: LoadType.weighted,
        );
        await store.writeSet(
            sessionExerciseId: row, position: 0, weightKg: 60, reps: 8);
        backdated = (await store.readOpenSession())!;
      });

      await pumpOverview(
        tester,
        backdated,
        now: backdated.loggedAt.add(const Duration(minutes: 3)),
      );

      expect(find.text('WORKOUT IN PROGRESS'), findsOneWidget,
          reason: 'it is still a workout in progress');
      expect(find.byKey(SessionClock.clockKey), findsNothing,
          reason: 'but it was logged afterwards, so there is no elapsed time '
              'to show');
    });

    testWidgets('the clock ticks on its own', (tester) async {
      final session = await makeSession(tester, <String>['bench'],
          typed: {'bench'});
      var now = session.loggedAt.add(const Duration(seconds: 5));

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            exerciseIndexProvider.overrideWithValue(index),
            initialActiveSessionProvider.overrideWithValue(session),
            clockNowProvider.overrideWithValue(() => now),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: SessionOverviewBody(onFinished: (_) {}),
            ),
          ),
        ),
      );
      expect(find.text('0:05'), findsOneWidget);

      now = session.loggedAt.add(const Duration(seconds: 9));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('0:09'), findsOneWidget,
          reason: 'it rebuilds on its own timer, not on a session change');
    });
  });

  group('the map', () {
    testWidgets('outlines what the workout plans, and fills nothing yet',
        (tester) async {
      final session = await makeSession(tester, <String>['bench', 'fly']);

      await pumpOverview(tester, session);

      for (final diagram in diagrams(tester)) {
        expect(diagram.planned, <String>{'chest/mid', 'chest/upper'},
            reason: 'primary muscles of every exercise on the list');
        expect(diagram.fill(<String>{'chest/mid'}), AppPalette.mutedSurface,
            reason: 'planning is not having done it');
      }
    });

    testWidgets('stops outlining a muscle once it has been worked',
        (tester) async {
      final session = await makeSession(tester, <String>['bench', 'fly'],
          worked: {'bench'});

      await pumpOverview(tester, session);

      for (final diagram in diagrams(tester)) {
        expect(diagram.planned, <String>{'chest/upper'},
            reason: 'chest/mid is filled now, and an outline never sits on a '
                'coloured muscle');
        expect(diagram.fill(<String>{'chest/mid'}), AppPalette.accentStrong);
        expect(diagram.fill(<String>{'triceps/triceps'}),
            AppPalette.accentLight,
            reason: 'the map fills secondaries as well');
      }
    });

    testWidgets('does not outline a secondary muscle', (tester) async {
      final session = await makeSession(tester, <String>['bench']);

      await pumpOverview(tester, session);

      for (final diagram in diagrams(tester)) {
        expect(diagram.planned.contains('triceps/triceps'), isFalse,
            reason: 'a by-product is not what the workout is for');
      }
    });
  });
}
