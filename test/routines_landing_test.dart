import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/routine_store.dart';
import 'package:turtle_lift/src/data/routines.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/log_workout_screen.dart';
import 'package:turtle_lift/src/ui/routine_card.dart';
import 'package:turtle_lift/src/ui/workout_root.dart';

/// The Workout landing, rebuilt around routines (`adr/0004`).
///
/// **The rule this file guards is that a routine is not a template.** A
/// template names muscle groups and ships with the app; a routine names
/// exercises the user chose, in an order, and starting one fills the workout
/// with them. A regression that quietly started an *empty* session from a
/// routine would render identically on the landing and lose the whole feature.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late RoutineStore routines;
  late SessionStore sessions;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    routines = RoutineStore(database);
    sessions = SessionStore(database);
  });
  tearDown(() => database.close());

  final index = ExerciseIndex(<Exercise>[
    Exercise(
      id: 'bench',
      name: 'Barbell bench press',
      equipment: 'Barbell',
      loadType: 'weighted',
      primary: const <String>['chest/mid'],
      secondary: const <String>[],
      setup: '',
      posture: '',
      execution: '',
      commonMistakes: '',
    ),
    Exercise(
      id: 'ohp',
      name: 'Overhead press',
      equipment: 'Barbell',
      loadType: 'weighted',
      primary: const <String>['shoulders/front-delt'],
      secondary: const <String>[],
      setup: '',
      posture: '',
      execution: '',
      commonMistakes: '',
    ),
  ]);

  Future<void> pumpLanding(WidgetTester tester) async {
    late List<Routine> seededRoutines;
    late WorkoutSession? open;
    await tester.runAsync(() async {
      seededRoutines = await routines.readRoutines();
      open = await sessions.readOpenSession();
    });

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialRoutinesProvider.overrideWithValue(seededRoutines),
          initialActiveSessionProvider.overrideWithValue(open),
          initialSavedSessionsProvider.overrideWithValue(<WorkoutSession>[]),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: WorkoutRoot()),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
  }

  /// A routine of two lifts, two planned sets on the first.
  Future<Routine> pushDay() async {
    final routine = await routines.createRoutine(name: 'Push day');
    final bench =
        await routines.addExercise(routineId: routine.id, exerciseId: 'bench');
    await routines.addSet(
        routineExerciseId: bench, targetWeightKg: 60, targetReps: 8);
    await routines.addSet(
        routineExerciseId: bench, targetWeightKg: 60, targetReps: 8);
    await routines.addExercise(routineId: routine.id, exerciseId: 'ohp');
    return (await routines.readRoutines()).single;
  }

  group('what the landing lists', () {
    testWidgets('leads with Start empty workout, then the routine controls',
        (tester) async {
      await pumpLanding(tester);

      expect(find.text('Start empty workout'), findsOneWidget);
      expect(find.text('ROUTINES'), findsOneWidget);
      expect(find.byKey(WorkoutLandingBody.newRoutineKey), findsOneWidget);
      expect(find.byKey(WorkoutLandingBody.templatesKey), findsOneWidget);
    });

    testWidgets('a routine card names its exercises', (tester) async {
      await tester.runAsync(pushDay);
      await pumpLanding(tester);

      expect(find.text('Push day'), findsOneWidget);
      expect(
        find.text('2 exercises · 2 sets · Barbell bench press, Overhead press'),
        findsOneWidget,
        reason: 'the count is what a user scanning six routines wants; the '
            'names are the reminder of which one this is',
      );
    });

    testWidgets('an empty routine cannot be started', (tester) async {
      await tester.runAsync(
          () => routines.createRoutine(name: 'Nothing in here'));
      await pumpLanding(tester);

      final routineId = (await tester.runAsync(routines.readRoutines))!.single.id;
      final start = tester.widget<InkWell>(
        find.byKey(RoutineCard.startKey(routineId)),
      );
      // Starting it would open a workout with nothing in it, which is what
      // Start empty workout is already for.
      expect(start.onTap, isNull);
      expect(find.text('No exercises yet'), findsOneWidget);
    });

    testWidgets('with no routines it points at Start empty workout',
        (tester) async {
      await pumpLanding(tester);

      expect(find.byType(RoutineCard), findsNothing);
      expect(find.textContaining('Routines you build appear here'),
          findsOneWidget);
    });
  });

  group('starting a routine', () {
    testWidgets('copies its exercises and planned sets into the session',
        (tester) async {
      await tester.runAsync(pushDay);
      await pumpLanding(tester);

      await act(tester, () async {
        await tester.tap(find.text('Start'));
      });

      final open = await tester.runAsync(() => sessions.readOpenSession());
      expect(open, isNotNull);
      expect(
        open!.exercises.map((e) => e.exerciseId),
        <String>['bench', 'ohp'],
        reason: 'in the routine\'s order',
      );
      // The targets arrive as uncompleted rows: the numbers are already there
      // and the user ticks them off. `saveOpenSession` drops whatever is still
      // unticked at Finish.
      final bench = open.exercises.first;
      expect(bench.sets, hasLength(2));
      expect(bench.sets.first.weightKg, 60);
      expect(bench.sets.first.reps, 8);
      expect(bench.sets.every((s) => !s.completed), isTrue);
    });

    testWidgets('the landing is replaced by the log screen', (tester) async {
      await tester.runAsync(pushDay);
      await pumpLanding(tester);

      await act(tester, () async {
        await tester.tap(find.text('Start'));
      });

      expect(find.byType(LogWorkoutBody), findsOneWidget);
      expect(find.byType(RoutineCard), findsNothing,
          reason: 'an open workout replaces the landing, never covers it');
    });

    testWidgets('the session takes the routine\'s name', (tester) async {
      await tester.runAsync(pushDay);
      await pumpLanding(tester);

      await act(tester, () async {
        await tester.tap(find.text('Start'));
      });

      final open = await tester.runAsync(() => sessions.readOpenSession());
      expect(open!.title, 'Push day');
    });
  });

  group('reordering', () {
    testWidgets('a long-press drag writes a new order that survives a re-read',
        (tester) async {
      await tester.runAsync(() async {
        await routines.createRoutine(name: 'First');
        await routines.createRoutine(name: 'Second');
      });
      await pumpLanding(tester);

      // Newest first until the user drags one.
      expect(
        tester
            .widgetList<RoutineCard>(find.byType(RoutineCard))
            .map((c) => c.routine.name),
        <String>['Second', 'First'],
      );

      final cards = find.byType(RoutineCard);
      final cardHeight = tester.getSize(cards.first).height;
      final gesture = await tester.startGesture(tester.getCenter(cards.first));
      // The delayed listener wants a real long press before it will drag.
      await tester.pump(const Duration(milliseconds: 700));
      // Then move in steps: one jump past the target does not register as a
      // drag across the row it has to swap with.
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(Offset(0, cardHeight / 4));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await act(tester, () async {
        await gesture.up();
      });
      await tester.pumpAndSettle();

      final stored = await tester.runAsync(routines.readRoutines);
      expect(
        stored!.map((r) => r.name),
        <String>['First', 'Second'],
        reason: 'the order is on disk, not only in the widget tree',
      );
    });
  });

  group('updating a routine from what was done', () {
    /// A routine of one exercise, two planned sets.
    ///
    /// Deliberately not [pushDay], whose second exercise has no planned sets:
    /// skipping a planned exercise *is* a divergence, so that fixture could
    /// never produce the "ran it as planned" case.
    Future<void> benchOnly() async {
      final routine = await routines.createRoutine(name: 'Bench day');
      final bench = await routines.addExercise(
          routineId: routine.id, exerciseId: 'bench');
      await routines.addSet(
          routineExerciseId: bench, targetWeightKg: 60, targetReps: 8);
      await routines.addSet(
          routineExerciseId: bench, targetWeightKg: 60, targetReps: 8);
    }

    /// Runs the routine, optionally adds a set beyond the plan, and finishes.
    Future<void> runAndFinish(WidgetTester tester, {required bool diverge}) async {
      await tester.runAsync(benchOnly);
      await pumpLanding(tester);
      await act(tester, () async {
        await tester.tap(find.text('Start'));
      });

      final open = (await tester.runAsync(() => sessions.readOpenSession()))!;
      final bench = open.exercises.first;
      await act(tester, () async {
        for (final set in bench.sets) {
          await sessions.writeSet(
            sessionExerciseId: bench.id,
            setId: set.id,
            position: set.position,
            completed: true,
            weightKg: 60,
            reps: 8,
          );
        }
        if (diverge) {
          await sessions.writeSet(
            sessionExerciseId: bench.id,
            position: 2,
            completed: true,
            weightKg: 62.5,
            reps: 6,
          );
        }
        await sessions.saveOpenSession();
      });
    }

    testWidgets('the session remembers which routine it came from',
        (tester) async {
      await tester.runAsync(benchOnly);
      await pumpLanding(tester);
      await act(tester, () async {
        await tester.tap(find.text('Start'));
      });

      final open = await tester.runAsync(() => sessions.readOpenSession());
      final stored = await tester.runAsync(routines.readRoutines);
      expect(open!.routineId, stored!.single.id);
      // Not folded into templateId: that column branches the template path.
      expect(open.templateId, isNull);
    });

    testWidgets('a third set makes the routine diverge', (tester) async {
      await runAndFinish(tester, diverge: true);

      final saved =
          (await tester.runAsync(() => sessions.readSavedSessions()))!.single;
      final routine = (await tester.runAsync(routines.readRoutines))!.single;
      expect(routineDiverges(routine, saved), isTrue);
    });

    testWidgets('running it as planned does not', (tester) async {
      await runAndFinish(tester, diverge: false);

      final saved =
          (await tester.runAsync(() => sessions.readSavedSessions()))!.single;
      final routine = (await tester.runAsync(routines.readRoutines))!.single;
      expect(routineDiverges(routine, saved), isFalse);
    });

    testWidgets('updating rewrites the plan to what was lifted',
        (tester) async {
      await runAndFinish(tester, diverge: true);
      final saved =
          (await tester.runAsync(() => sessions.readSavedSessions()))!.single;
      final routineId = (await tester.runAsync(routines.readRoutines))!.single.id;

      final container = ProviderScope.containerOf(
        tester.element(find.byType(WorkoutRoot)),
      );
      await tester.runAsync(() => container
          .read(routineListProvider.notifier)
          .updateFromSession(routineId, saved));

      final routine = (await tester.runAsync(routines.readRoutines))!.single;
      expect(routine.exercises.single.sets, hasLength(3));
      // The new targets are what was lifted, not what was planned.
      expect(routine.exercises.single.sets.last.targetWeightKg, 62.5);
      expect(routine.exercises.single.sets.last.targetReps, 6);
    });
  });

}
