import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart'
    show BodyweightEntry, initialBodyweightLogProvider;
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/destructive_confirmation.dart';
import 'package:turtle_lift/src/ui/session_date_control.dart';
import 'package:turtle_lift/src/ui/session_summary_screen.dart';

/// Slice 1 of the History build (`docs/research/history-tab-audit.md`): what a
/// user types or chooses on a saved workout is never silently lost, and a
/// workout edited down to nothing does not linger as a ghost row.
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

  Exercise ex(String id, String name, List<String> primary) => Exercise(
        id: id,
        name: name,
        equipment: 'barbell',
        loadType: 'weighted',
        primary: primary,
        secondary: const <String>[],
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
      );

  final index = ExerciseIndex(<Exercise>[
    ex('bench', 'Barbell bench press', <String>['chest/mid']),
    ex('row', 'Barbell row', <String>['back/lats']),
  ]);

  Future<String> saveWorkout(
    WidgetTester tester, {
    List<String> exerciseIds = const <String>['bench'],
    LocalDate? on,
    String? title,
  }) async {
    late String id;
    await tester.runAsync(() async {
      final session = await store.createSession(performedOn: on);
      id = session.id;
      if (title != null) await store.setTitle(id, title);
      for (final exerciseId in exerciseIds) {
        final row = await store.addExercise(
          sessionId: id,
          exerciseId: exerciseId,
          loadType: LoadType.weighted,
        );
        await store.writeSet(
          sessionExerciseId: row,
          position: 0,
          weightKg: 60,
          reps: 8,
          completed: true,
        );
      }
      await store.saveOpenSession();
    });
    return id;
  }

  Future<List<WorkoutSession>> savedNow(WidgetTester tester) async =>
      (await tester.runAsync(() => store.readSavedSessions()))!;

  /// Hosts a launcher that pushes the editor, so Back is a real pop.
  Future<void> pump(
    WidgetTester tester,
    String sessionId, {
    WorkoutDatePicker? picker,
  }) async {
    tester.view.physicalSize = const Size(1200, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final saved = await savedNow(tester);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialSavedSessionsProvider.overrideWithValue(saved),
          initialBodyweightLogProvider
              .overrideWithValue(const <BodyweightEntry>[]),
          if (picker != null)
            workoutDatePickerProvider.overrideWithValue(picker),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => pushSessionSummary(context, sessionId),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pumpAndSettle();
  }

  group('B1: the title is saved without pressing Return', () {
    testWidgets('typing then tapping elsewhere saves it', (tester) async {
      final id = await saveWorkout(tester);
      await pump(tester, id);

      await tester.tap(find.byKey(SessionSummaryScreen.titleFieldKey));
      await tester.enterText(
          find.byKey(SessionSummaryScreen.titleFieldKey), 'Heavy bench');
      await tester.pump();
      // Somewhere that is not the field: the "What you did" label.
      await tester.tapAt(const Offset(600, 3300));
      await settle(tester);

      expect((await savedNow(tester)).single.title, 'Heavy bench');
    });

    testWidgets('typing then going back saves it', (tester) async {
      final id = await saveWorkout(tester);
      await pump(tester, id);

      await tester.tap(find.byKey(SessionSummaryScreen.titleFieldKey));
      await tester.enterText(
          find.byKey(SessionSummaryScreen.titleFieldKey), 'Morning push');
      await tester.pump();
      await tester.pageBack();
      await settle(tester);

      expect(find.text('open'), findsOneWidget);
      expect((await savedNow(tester)).single.title, 'Morning push');
    });

    testWidgets('an emptied title clears it and the fallback shows',
        (tester) async {
      final id = await saveWorkout(tester, title: 'Old name');
      await pump(tester, id);

      await tester.tap(find.byKey(SessionSummaryScreen.titleFieldKey));
      await tester.enterText(find.byKey(SessionSummaryScreen.titleFieldKey), '');
      await tester.pump();
      await tester.tapAt(const Offset(600, 3300));
      await settle(tester);

      expect((await savedNow(tester)).single.title, isNull);
      expect(find.text('Barbell bench press'), findsWidgets,
          reason: 'the resolved title is the fallback, never a blank');
    });
  });

  group('B2: a saved workout can change its date', () {
    testWidgets('the editor offers Change date', (tester) async {
      final id = await saveWorkout(tester);
      await pump(tester, id);
      expect(find.byKey(SessionSummaryScreen.changeDateKey), findsOneWidget);
    });

    testWidgets('the real picker cannot reach a future day', (tester) async {
      final id = await saveWorkout(tester);
      await pump(tester, id);

      await tester.tap(find.byKey(SessionSummaryScreen.changeDateKey));
      await tester.pumpAndSettle();

      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(LocalDate.fromDateTime(dialog.lastDate), LocalDate.today());
    });

    testWidgets('a chosen day moves the workout, and History reorders',
        (tester) async {
      final today = LocalDate.today();
      final older = await saveWorkout(tester,
          exerciseIds: <String>['row'], on: today.addDays(-2), title: 'Pull');
      final id = await saveWorkout(tester, title: 'Push');
      expect(older, isNotEmpty);
      await pump(tester, id,
          picker: (context, current) async => today.addDays(-5));

      await tester.tap(find.byKey(SessionSummaryScreen.changeDateKey));
      await settle(tester);

      final saved = await savedNow(tester);
      final moved = saved.firstWhere((s) => s.id == id);
      expect(moved.performedOn, today.addDays(-5));

      final container = ProviderScope.containerOf(
          tester.element(find.byType(SessionSummaryScreen)));
      final order = container
          .read(historySessionsNewestFirstProvider)
          .map((s) => s.id)
          .toList();
      expect(order.first, older, reason: 'Push now sits after Pull');
    });

    testWidgets('backdating an earlier workout moves a later card\'s streak',
        (tester) async {
      final today = LocalDate.today();
      final old = await saveWorkout(tester,
          exerciseIds: <String>['row'], on: today.addDays(-9));
      final latest = await saveWorkout(tester);

      // The older one moves to two days ago, inside the 3-day tolerance.
      await pump(tester, old,
          picker: (context, current) async => today.addDays(-2));
      await tester.tap(find.byKey(SessionSummaryScreen.changeDateKey));
      await settle(tester);

      await pump(tester, latest);
      final streak = find.byKey(SessionSummaryScreen.streakKey);
      expect(
        find.descendant(of: streak, matching: find.text('2')),
        findsOneWidget,
      );
    });
  });

  group('B6: removing the last exercise', () {
    testWidgets('with another exercise left, it only removes that one',
        (tester) async {
      final id = await saveWorkout(tester,
          exerciseIds: <String>['bench', 'row']);
      await pump(tester, id);

      await tester.tap(find.byKey(SessionSummaryScreen.removeKeyFor('bench')));
      await tester.pumpAndSettle();
      expect(find.text('Remove Barbell bench press?'), findsOneWidget);
      await tester.tap(find.byKey(confirmDestructiveKey));
      await settle(tester);

      final saved = await savedNow(tester);
      expect(saved.single.exercises.map((e) => e.exerciseId), <String>['row']);
    });

    testWidgets('as the only exercise, it offers to delete the workout',
        (tester) async {
      final id = await saveWorkout(tester);
      await pump(tester, id);

      await tester.tap(find.byKey(SessionSummaryScreen.removeKeyFor('bench')));
      await tester.pumpAndSettle();
      expect(find.text('Delete this workout?'), findsOneWidget);
      expect(find.textContaining('only exercise'), findsOneWidget);
      await tester.tap(find.byKey(confirmDestructiveKey));
      await settle(tester);

      expect(await savedNow(tester), isEmpty,
          reason: 'no zero-set row left behind');
      expect(find.byType(SessionSummaryScreen), findsNothing);
    });
  });

  test('History leaves out a saved workout with no completed set', () {
    final today = LocalDate.today();
    WorkoutSession session(String id, {required bool completed}) =>
        WorkoutSession(
          id: id,
          title: null,
          performedOn: today,
          loggedAt: today.toDateTime(),
          templateId: null,
          templateName: null,
          isOpen: false,
          exercises: <SessionExercise>[
            SessionExercise(
              id: '$id-e',
              exerciseId: 'bench',
              position: 0,
              loadType: LoadType.weighted,
              markedDone: false,
              sets: <SetEntry>[
                SetEntry(
                  id: '$id-s',
                  position: 0,
                  completed: completed,
                  weightKg: 60,
                  reps: 8,
                ),
              ],
            ),
          ],
        );

    final container = ProviderContainer(overrides: [
      exerciseIndexProvider.overrideWithValue(index),
      initialSavedSessionsProvider.overrideWithValue(<WorkoutSession>[
        session('real', completed: true),
        session('ghost', completed: false),
      ]),
    ]);
    addTearDown(container.dispose);

    expect(
      container.read(historySessionsProvider).map((s) => s.id),
      <String>['real'],
    );
  });
}
