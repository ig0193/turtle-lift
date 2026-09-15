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
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/equipment_exercise_list_screen.dart';
import 'package:turtle_lift/src/ui/exercise_detail_screen.dart';
import 'package:turtle_lift/src/ui/muscle_exercise_list_screen.dart';
import 'package:turtle_lift/src/ui/set_logging_screen.dart';

/// Proves the sub-group list's second job: the swap screen inside a workout.
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
        equipment: 'barbell',
        loadType: 'weighted',
        primary: const <String>['chest/mid'],
        secondary: const <String>[],
        setup: 'Set up.',
        posture: 'Braced.',
        execution: 'Press.',
        commonMistakes: 'No bouncing.',
      );

  final index = ExerciseIndex(<Exercise>[
    ex('flat-press', 'Flat barbell press'),
    ex('machine-press', 'Machine chest press'),
    ex('dumbbell-press', 'Dumbbell bench press'),
  ]);

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    WorkoutSession? session,
    List<WorkoutSession> saved = const <WorkoutSession>[],
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialActiveSessionProvider.overrideWithValue(session),
          initialSavedSessionsProvider.overrideWithValue(saved),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: screen),
      ),
    );
    await tester.pump();
  }

  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
  }

  group('browsing from the Muscles tab', () {
    testWidgets('renders exactly as it always has', (tester) async {
      await pump(tester,
          const MuscleExerciseListScreen(subGroupId: 'chest/mid'));

      expect(find.text('Flat barbell press'), findsOneWidget);
      expect(find.textContaining('no sets yet'), findsNothing);
    });

    testWidgets('a row opens the exercise page, not the logging screen',
        (tester) async {
      await pump(tester,
          const MuscleExerciseListScreen(subGroupId: 'chest/mid'));

      await tester.tap(find.text('Flat barbell press'));
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseDetailScreen), findsOneWidget);
    });
  });

  group('the equipment list', () {
    testWidgets('is unaffected while a workout is open', (tester) async {
      final session = await tester.runAsync(() => store.createSession());

      await pump(tester,
          const EquipmentExerciseListScreen(equipment: 'barbell'),
          session: session);

      await tester.tap(find.text('Flat barbell press'));
      await tester.pumpAndSettle();

      expect(
        find.byType(ExerciseDetailScreen),
        findsOneWidget,
        reason: 'the session mode is opt-in precisely so the equipment list, '
            'which shares this row and scaffold, does not change underneath',
      );
    });
  });

  group('opened from inside a workout', () {
    testWidgets('a logged exercise sorts to the top with its sets',
        (tester) async {
      late WorkoutSession session;
      await tester.runAsync(() async {
        session = await store.createSession();
        final row = await store.addExercise(
          sessionId: session.id,
          exerciseId: 'machine-press',
          loadType: LoadType.weighted,
        );
        await store.writeSet(
            sessionExerciseId: row,
            position: 0,
            weightKg: 60,
            reps: 8,
            completed: true);
        session = (await store.readOpenSession())!;
      });

      await pump(
        tester,
        const MuscleExerciseListScreen(
            subGroupId: 'chest/mid', inSession: true),
        session: session,
      );

      expect(find.text('60kg × 8'), findsOneWidget);
      final machineY =
          tester.getTopLeft(find.text('Machine chest press')).dy;
      final flatY = tester.getTopLeft(find.text('Flat barbell press')).dy;
      expect(
        machineY,
        lessThan(flatY),
        reason: 'the user is looking for the lift they just did, not choosing '
            'a new one',
      );
    });

    testWidgets('an exercise opened but not yet logged says so',
        (tester) async {
      late WorkoutSession session;
      await tester.runAsync(() async {
        session = await store.createSession();
        await store.addExercise(
          sessionId: session.id,
          exerciseId: 'machine-press',
          loadType: LoadType.weighted,
        );
        session = (await store.readOpenSession())!;
      });

      await pump(
        tester,
        const MuscleExerciseListScreen(
            subGroupId: 'chest/mid', inSession: true),
        session: session,
      );

      expect(find.text('no sets yet'), findsOneWidget);
    });

    testWidgets('a familiar exercise goes straight to logging', (tester) async {
      late WorkoutSession session;
      late List<WorkoutSession> saved;
      await tester.runAsync(() async {
        final past = await store.createSession(
            performedOn: LocalDate.today().addDays(-3));
        final row = await store.addExercise(
            sessionId: past.id,
            exerciseId: 'flat-press',
            loadType: LoadType.weighted);
        await store.writeSet(
            sessionExerciseId: row,
            position: 0,
            weightKg: 60,
            reps: 8,
            completed: true);
        await store.saveOpenSession();
        session = await store.createSession();
        saved = await store.readSavedSessions();
      });

      await pump(
        tester,
        const MuscleExerciseListScreen(
            subGroupId: 'chest/mid', inSession: true),
        session: session,
        saved: saved,
      );
      await act(tester, () => tester.tap(find.text('Flat barbell press')));

      expect(find.byType(SetLoggingScreen), findsOneWidget);
    });

    testWidgets('an exercise never done detours through its page first',
        (tester) async {
      final session = await tester.runAsync(() => store.createSession());

      await pump(
        tester,
        const MuscleExerciseListScreen(
            subGroupId: 'chest/mid', inSession: true),
        session: session,
      );
      await act(tester, () => tester.tap(find.text('Flat barbell press')));

      expect(find.byType(ExerciseDetailScreen), findsOneWidget);
      expect(find.byKey(ExerciseDetailScreen.startLoggingKey), findsOneWidget);
    });

    testWidgets('an already-logged exercise reopens without a detour',
        (tester) async {
      late WorkoutSession session;
      await tester.runAsync(() async {
        session = await store.createSession();
        final row = await store.addExercise(
          sessionId: session.id,
          exerciseId: 'flat-press',
          loadType: LoadType.weighted,
        );
        await store.writeSet(
            sessionExerciseId: row,
            position: 0,
            weightKg: 60,
            reps: 8,
            completed: true);
        session = (await store.readOpenSession())!;
      });

      await pump(
        tester,
        const MuscleExerciseListScreen(
            subGroupId: 'chest/mid', inSession: true),
        session: session,
      );
      await act(tester, () => tester.tap(find.text('Flat barbell press')));

      expect(
        find.byType(SetLoggingScreen),
        findsOneWidget,
        reason: 'this is the only route back in to add a fourth set or fix a '
            'mistyped weight',
      );
    });
  });
}
