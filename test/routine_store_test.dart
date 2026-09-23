import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/routine_store.dart';
import 'package:turtle_lift/src/data/session_store.dart';

/// Proves the store behind the Workout landing's routines (`adr/0004`).
///
/// **A routine is not a template, and this file is where that stops being a
/// naming argument.** A template names parent muscle groups and ships with the
/// app; a routine names *exercises in an order*, with target sets, and belongs
/// to the user. The two are stored separately and neither converts into the
/// other — see `CONTEXT.md`.
///
/// The cases that matter most are the ones that could lose a user's work with
/// no undo and no backup: deleting a folder, and deleting a routine.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late RoutineStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = RoutineStore(database);
  });

  tearDown(() => database.close());

  Future<Routine> pushDay() async {
    final routine = await store.createRoutine(name: 'Push day');
    final bench = await store.addExercise(
      routineId: routine.id,
      exerciseId: 'barbell-bench-press',
    );
    await store.addSet(routineExerciseId: bench, targetWeightKg: 60, targetReps: 8);
    await store.addSet(routineExerciseId: bench, targetWeightKg: 60, targetReps: 8);
    return (await store.readRoutines()).single;
  }

  group('building a routine', () {
    test('a new one is empty, and says so rather than inventing exercises',
        () async {
      final routine = await store.createRoutine(name: 'Push day');

      expect(routine.name, 'Push day');
      expect(routine.exercises, isEmpty);
    });

    test('exercises keep the order they were added in', () async {
      final routine = await store.createRoutine(name: 'Push day');
      for (final id in <String>['bench', 'ohp', 'dips']) {
        await store.addExercise(routineId: routine.id, exerciseId: id);
      }

      final read = (await store.readRoutines()).single;
      expect(
        read.exercises.map((e) => e.exerciseId),
        <String>['bench', 'ohp', 'dips'],
      );
      expect(read.exercises.map((e) => e.position), <int>[0, 1, 2]);
    });

    test('target sets round-trip under their exercise', () async {
      final routine = await pushDay();

      final bench = routine.exercises.single;
      expect(bench.sets, hasLength(2));
      expect(bench.sets.first.targetWeightKg, 60);
      expect(bench.sets.first.targetReps, 8);
    });

    test('a target set may be left blank — a plan need not name numbers',
        () async {
      final routine = await store.createRoutine(name: 'Push day');
      final bench =
          await store.addExercise(routineId: routine.id, exerciseId: 'bench');
      await store.addSet(routineExerciseId: bench);

      final set = (await store.readRoutines()).single.exercises.single.sets.single;
      expect(set.targetWeightKg, isNull);
      expect(set.targetReps, isNull);
      expect(set.targetDurationSec, isNull);
    });

    test('notes and a rest timer live on the routine exercise too', () async {
      final routine = await store.createRoutine(name: 'Push day');
      final bench =
          await store.addExercise(routineId: routine.id, exerciseId: 'bench');

      await store.setExerciseNotes(routineExerciseId: bench, notes: 'Pause 1s');
      await store.setExerciseRestTimer(routineExerciseId: bench, seconds: 120);

      final read = (await store.readRoutines()).single.exercises.single;
      expect(read.notes, 'Pause 1s');
      expect(read.restTimerSec, 120);
    });
  });

  group('editing and deleting', () {
    test('renaming touches exactly one routine', () async {
      final keep = await store.createRoutine(name: 'Pull day');
      final rename = await store.createRoutine(name: 'Push day');

      await store.renameRoutine(rename.id, 'Chest and triceps');

      final names = (await store.readRoutines()).map((r) => r.name).toSet();
      expect(names, <String>{'Pull day', 'Chest and triceps'});
      expect(
        (await store.readRoutines()).firstWhere((r) => r.id == keep.id).name,
        'Pull day',
      );
    });

    test('deleting a routine takes its exercises and sets with it', () async {
      final routine = await pushDay();

      await store.deleteRoutine(routine.id);

      expect(await store.readRoutines(), isEmpty);
      // Nothing may outlive its parent: an orphaned set row is invisible,
      // unreachable and permanent in an app with no server to reconcile it.
      expect(await database.select(database.routineExercises).get(), isEmpty);
      expect(await database.select(database.routineSets).get(), isEmpty);
    });

    test('removing one exercise leaves the rest of the routine alone',
        () async {
      final routine = await store.createRoutine(name: 'Push day');
      final bench =
          await store.addExercise(routineId: routine.id, exerciseId: 'bench');
      await store.addExercise(routineId: routine.id, exerciseId: 'ohp');

      await store.deleteExercise(bench);

      final read = (await store.readRoutines()).single;
      expect(read.exercises.map((e) => e.exerciseId), <String>['ohp']);
    });
  });

  group('divergence from what was actually done', () {
    // Hevy asks "update routine?" when the workout you ran stopped matching the
    // routine you started. The question is only worth asking when something
    // really changed, so this is where "changed" is defined.
    WorkoutSession sessionOf(List<(String, int)> shape) => WorkoutSession(
          id: 's',
          title: null,
          performedOn: LocalDate.today(),
          loggedAt: DateTime.now(),
          templateId: null,
          templateName: null,
          groupIds: const <String>[],
          isOpen: false,
          exercises: <SessionExercise>[
            for (final (position, (exerciseId, sets)) in shape.indexed)
              SessionExercise(
                id: 'se-$position',
                exerciseId: exerciseId,
                position: position,
                loadType: LoadType.weighted,
                markedDone: false,
                sets: <SetEntry>[
                  for (var i = 0; i < sets; i++)
                    SetEntry(
                      id: 'set-$position-$i',
                      position: i,
                      completed: true,
                      weightKg: 60,
                      reps: 8,
                    ),
                ],
              ),
          ],
        );

    test('running a routine exactly as planned is no change', () async {
      final routine = await pushDay();

      expect(routineDiverges(routine, sessionOf(<(String, int)>[
        ('barbell-bench-press', 2),
      ])), isFalse);
    });

    test('an added exercise is a change', () async {
      final routine = await pushDay();

      expect(routineDiverges(routine, sessionOf(<(String, int)>[
        ('barbell-bench-press', 2),
        ('overhead-press', 3),
      ])), isTrue);
    });

    test('a different number of sets is a change', () async {
      final routine = await pushDay();

      expect(routineDiverges(routine, sessionOf(<(String, int)>[
        ('barbell-bench-press', 4),
      ])), isTrue);
    });

    test('reordering the same exercises is a change', () async {
      final routine = await store.createRoutine(name: 'Push day');
      for (final id in <String>['bench', 'ohp']) {
        final rowId =
            await store.addExercise(routineId: routine.id, exerciseId: id);
        await store.addSet(routineExerciseId: rowId);
      }
      final read = (await store.readRoutines()).single;

      expect(routineDiverges(read, sessionOf(<(String, int)>[
        ('ohp', 1),
        ('bench', 1),
      ])), isTrue);
    });

    test('sets left unticked do not count as a change', () async {
      final routine = await pushDay();
      final session = WorkoutSession(
        id: 's',
        title: null,
        performedOn: LocalDate.today(),
        loggedAt: DateTime.now(),
        templateId: null,
        templateName: null,
        groupIds: const <String>[],
        isOpen: true,
        exercises: <SessionExercise>[
          SessionExercise(
            id: 'se-0',
            exerciseId: 'barbell-bench-press',
            position: 0,
            loadType: LoadType.weighted,
            markedDone: false,
            sets: <SetEntry>[
              SetEntry(
                  id: 'a', position: 0, completed: true, weightKg: 60, reps: 8),
              SetEntry(
                  id: 'b', position: 1, completed: true, weightKg: 60, reps: 8),
              // A third row the user opened and never did. `saveOpenSession`
              // drops it, so it must not provoke the question either.
              SetEntry(id: 'c', position: 2, completed: false),
            ],
          ),
        ],
      );

      expect(routineDiverges(routine, session), isFalse);
    });

    test('a session that logged nothing never provokes the question',
        () async {
      final routine = await pushDay();

      expect(routineDiverges(routine, sessionOf(const <(String, int)>[])),
          isFalse);
    });
  });

  group('ordering', () {
    test('routines come back newest first until the user reorders them',
        () async {
      await store.createRoutine(name: 'First');
      await store.createRoutine(name: 'Second');

      expect(
        (await store.readRoutines()).map((r) => r.name),
        <String>['Second', 'First'],
      );
    });

    test('an explicit order survives a reopen', () async {
      final first = await store.createRoutine(name: 'First');
      final second = await store.createRoutine(name: 'Second');

      await store.reorderRoutines(<String>[first.id, second.id]);

      expect(
        (await store.readRoutines()).map((r) => r.name),
        <String>['First', 'Second'],
      );
    });
  });
}
