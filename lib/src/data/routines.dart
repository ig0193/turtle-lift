import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'load_type.dart';
import 'routine_store.dart';
import 'session_store.dart';
import 'set_format.dart';
import 'settings_store.dart' show appDatabaseProvider;

/// The store, wired to the one database.
final routineStoreProvider = Provider<RoutineStore>(
  (ref) => RoutineStore(ref.watch(appDatabaseProvider)),
);

/// Seeds resolved before the first frame in `main()`, exactly as the active
/// session and the split filter are.
///
/// **Not resolved inside `build()`, deliberately.** A landing that started
/// empty and filled a frame later would flash "no routines yet" at a user who
/// has ten, every cold start.
final initialRoutinesProvider = Provider<List<Routine>>(
  (ref) => const <Routine>[],
);

final initialRoutineFoldersProvider = Provider<List<RoutineFolder>>(
  (ref) => const <RoutineFolder>[],
);

/// The user's routines, newest first until they drag one.
///
/// **Write through, then re-read** — the same discipline as `ActiveSession`.
/// Every mutation here ends in `_refresh()`, so this state always trails disk
/// and never leads it. A routine that appears in the list but is not yet on
/// disk is a routine that vanishes on the next cold start.
class RoutineList extends Notifier<List<Routine>> {
  @override
  List<Routine> build() => ref.watch(initialRoutinesProvider);

  RoutineStore get _store => ref.read(routineStoreProvider);

  Future<void> _refresh() async {
    state = await _store.readRoutines();
    ref.read(routineFolderListProvider.notifier).refresh();
  }

  Future<Routine> create({required String name, String? folderId}) async {
    final routine = await _store.createRoutine(name: name, folderId: folderId);
    await _refresh();
    return routine;
  }

  Future<void> rename(String routineId, String name) async {
    await _store.renameRoutine(routineId, name);
    await _refresh();
  }

  Future<void> delete(String routineId) async {
    await _store.deleteRoutine(routineId);
    await _refresh();
  }

  /// Copies a routine, its exercises and its target sets.
  ///
  /// Named `"<name> (copy)"` rather than silently identically: two rows reading
  /// `Push day` with no way to tell them apart is how a user edits the wrong
  /// one.
  Future<void> duplicate(Routine source) async {
    final copy = await _store.createRoutine(
      name: '${source.name} (copy)',
      folderId: source.folderId,
    );
    for (final exercise in source.exercises) {
      final rowId = await _store.addExercise(
        routineId: copy.id,
        exerciseId: exercise.exerciseId,
      );
      if (exercise.notes != null) {
        await _store.setExerciseNotes(
            routineExerciseId: rowId, notes: exercise.notes);
      }
      if (exercise.restTimerSec != null) {
        await _store.setExerciseRestTimer(
            routineExerciseId: rowId, seconds: exercise.restTimerSec);
      }
      for (final set in exercise.sets) {
        await _store.addSet(
          routineExerciseId: rowId,
          targetWeightKg: set.targetWeightKg,
          targetReps: set.targetReps,
          targetDurationSec: set.targetDurationSec,
        );
      }
    }
    await _refresh();
  }

  /// Rewrites a routine to match the workout that was actually done.
  ///
  /// **A replace, not a merge.** The session already carries the routine's
  /// notes and rest timers — they were copied onto it at the start, and edited
  /// there if the user changed them — so rebuilding from the session keeps
  /// everything the user touched and drops only what they dropped. Merging
  /// would have to guess which of two orderings won.
  ///
  /// The new targets are what was lifted, not what was planned: that is the
  /// whole point of the question this answers.
  Future<void> updateFromSession(
    String routineId,
    WorkoutSession session,
  ) async {
    final existing = state.where((r) => r.id == routineId).firstOrNull;
    if (existing == null) return;

    for (final exercise in existing.exercises) {
      await _store.deleteExercise(exercise.id);
    }

    for (final exercise in session.exercises) {
      final done = exercise.sets
          .where((s) => isSetComplete(exercise.loadType, s))
          .toList(growable: false);
      if (done.isEmpty) continue;

      final rowId = await _store.addExercise(
        routineId: routineId,
        exerciseId: exercise.exerciseId,
      );
      if (exercise.notes != null) {
        await _store.setExerciseNotes(
            routineExerciseId: rowId, notes: exercise.notes);
      }
      if (exercise.restTimerSec != null) {
        await _store.setExerciseRestTimer(
            routineExerciseId: rowId, seconds: exercise.restTimerSec);
      }
      for (final set in done) {
        await _store.addSet(
          routineExerciseId: rowId,
          // Which field held the load depends on the type, and the routine
          // builder reads column 0 for all of weight, assistance and time.
          targetWeightKg: switch (exercise.loadType) {
            LoadType.weighted => set.weightKg,
            LoadType.bodyweight => set.addedKg,
            LoadType.assisted => set.assistKg,
            LoadType.timed || null => null,
          },
          targetReps: exercise.loadType == LoadType.timed ? null : set.reps,
          targetDurationSec: set.durationSec,
        );
      }
    }
    await _refresh();
  }

  Future<void> reorder(List<String> idsInOrder) async {
    await _store.reorderRoutines(idsInOrder);
    await _refresh();
  }

  Future<void> moveToFolder({
    required String routineId,
    required String? folderId,
  }) async {
    await _store.moveRoutineToFolder(routineId: routineId, folderId: folderId);
    await _refresh();
  }

  Future<String> addExercise({
    required String routineId,
    required String exerciseId,
  }) async {
    final id =
        await _store.addExercise(routineId: routineId, exerciseId: exerciseId);
    await _refresh();
    return id;
  }

  Future<void> removeExercise(String routineExerciseId) async {
    await _store.deleteExercise(routineExerciseId);
    await _refresh();
  }

  Future<void> setExerciseNotes({
    required String routineExerciseId,
    required String? notes,
  }) async {
    await _store.setExerciseNotes(
        routineExerciseId: routineExerciseId, notes: notes);
    await _refresh();
  }

  Future<void> setExerciseRestTimer({
    required String routineExerciseId,
    required int? seconds,
  }) async {
    await _store.setExerciseRestTimer(
        routineExerciseId: routineExerciseId, seconds: seconds);
    await _refresh();
  }

  Future<void> addSet({
    required String routineExerciseId,
    double? targetWeightKg,
    int? targetReps,
    int? targetDurationSec,
  }) async {
    await _store.addSet(
      routineExerciseId: routineExerciseId,
      targetWeightKg: targetWeightKg,
      targetReps: targetReps,
      targetDurationSec: targetDurationSec,
    );
    await _refresh();
  }

  Future<void> updateSet({
    required String setId,
    double? targetWeightKg,
    int? targetReps,
    int? targetDurationSec,
  }) async {
    await _store.updateSet(
      setId: setId,
      targetWeightKg: targetWeightKg,
      targetReps: targetReps,
      targetDurationSec: targetDurationSec,
    );
    await _refresh();
  }

  Future<void> deleteSet(String setId) async {
    await _store.deleteSet(setId);
    await _refresh();
  }

  Future<void> refresh() => _refresh();
}

final routineListProvider =
    NotifierProvider<RoutineList, List<Routine>>(RoutineList.new);

/// Split out so tests can `overrideWithValue` cheaply — Riverpod 3 does not
/// offer that on a `NotifierProvider`. Same reason `customTemplatesProvider`
/// exists beside its notifier.
final routinesProvider =
    Provider<List<Routine>>((ref) => ref.watch(routineListProvider));

class RoutineFolderList extends Notifier<List<RoutineFolder>> {
  @override
  List<RoutineFolder> build() => ref.watch(initialRoutineFoldersProvider);

  RoutineStore get _store => ref.read(routineStoreProvider);

  Future<void> refresh() async {
    state = await _store.readFolders();
  }

  Future<RoutineFolder> create(String name) async {
    final folder = await _store.createFolder(name: name);
    await refresh();
    return folder;
  }

  Future<void> rename(String folderId, String name) async {
    await _store.renameFolder(folderId, name);
    await refresh();
  }

  /// Deletes a folder. Its routines survive, unfiled — see [RoutineStore].
  Future<void> delete(String folderId) async {
    await _store.deleteFolder(folderId);
    await refresh();
    await ref.read(routineListProvider.notifier).refresh();
  }
}

final routineFolderListProvider =
    NotifierProvider<RoutineFolderList, List<RoutineFolder>>(
        RoutineFolderList.new);

final routineFoldersProvider =
    Provider<List<RoutineFolder>>((ref) => ref.watch(routineFolderListProvider));
