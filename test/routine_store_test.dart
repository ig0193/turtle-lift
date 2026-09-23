import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/routine_store.dart';

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
      expect(routine.folderId, isNull, reason: 'unfiled until moved');
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

  group('folders', () {
    test('a routine can be filed, and moved back out again', () async {
      final folder = await store.createFolder(name: 'Abc');
      final routine = await store.createRoutine(name: 'Push day');

      await store.moveRoutineToFolder(
          routineId: routine.id, folderId: folder.id);
      expect((await store.readRoutines()).single.folderId, folder.id);

      await store.moveRoutineToFolder(routineId: routine.id, folderId: null);
      expect((await store.readRoutines()).single.folderId, isNull);
    });

    test('deleting a folder keeps its routines, unfiled', () async {
      final folder = await store.createFolder(name: 'Abc');
      final routine = await store.createRoutine(name: 'Push day');
      await store.moveRoutineToFolder(
          routineId: routine.id, folderId: folder.id);

      await store.deleteFolder(folder.id);

      // **The folder is the container, not the owner.** Cascading here would
      // destroy a routine the user spent real time building, to tidy away a
      // label they no longer wanted.
      final read = await store.readRoutines();
      expect(read, hasLength(1));
      expect(read.single.folderId, isNull);
      expect(await store.readFolders(), isEmpty);
    });

    test('folders keep the order they were made in', () async {
      await store.createFolder(name: 'Abc');
      await store.createFolder(name: 'Xyz');

      expect(
        (await store.readFolders()).map((f) => f.name),
        <String>['Abc', 'Xyz'],
      );
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
