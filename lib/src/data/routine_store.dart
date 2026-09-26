import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'session_store.dart';
import 'set_format.dart';

/// The one writer of routines — the user's own ordered exercise lists.
///
/// **Mirrors `SessionStore`'s discipline deliberately.** Every mutation writes
/// through to Drift and the caller re-reads; nothing is held in memory and
/// reconciled later. A routine the user spent ten minutes building must be on
/// disk the moment they add a row to it, because a local-only app has no server
/// to recover it from.
///
/// See `CONTEXT.md` for why a routine is not a template, and `adr/0004` for why
/// the two are stored separately rather than one converting into the other.
class RoutineStore {
  RoutineStore(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------- reading

  /// Every routine, each hydrated with its exercises and their target sets.
  ///
  /// Ordered by `position` ascending, which puts the newest first until the
  /// user drags one — see [createRoutine].
  Future<List<Routine>> readRoutines() async {
    final routineRows = await (_db.select(_db.routines)
          ..orderBy(<OrderClauseGenerator<$RoutinesTable>>[
            (r) => OrderingTerm.asc(r.position),
          ]))
        .get();

    final result = <Routine>[];
    for (final row in routineRows) {
      final exerciseRows = await (_db.select(_db.routineExercises)
            ..where((e) => e.routineId.equals(row.id))
            ..orderBy(<OrderClauseGenerator<$RoutineExercisesTable>>[
              (e) => OrderingTerm.asc(e.position),
            ]))
          .get();

      final exercises = <RoutineExercise>[];
      for (final exerciseRow in exerciseRows) {
        final setRows = await (_db.select(_db.routineSets)
              ..where((s) => s.routineExerciseId.equals(exerciseRow.id))
              ..orderBy(<OrderClauseGenerator<$RoutineSetsTable>>[
                (s) => OrderingTerm.asc(s.position),
              ]))
            .get();
        exercises.add(
          RoutineExercise(
            id: exerciseRow.id,
            exerciseId: exerciseRow.exerciseId,
            position: exerciseRow.position,
            notes: exerciseRow.notes,
            restTimerSec: exerciseRow.restTimerSec,
            sets: <RoutineSet>[
              for (final s in setRows)
                RoutineSet(
                  id: s.id,
                  position: s.position,
                  targetWeightKg: s.targetWeightKg,
                  targetReps: s.targetReps,
                  targetDurationSec: s.targetDurationSec,
                ),
            ],
          ),
        );
      }

      result.add(
        Routine(
          id: row.id,
          name: row.name,
          position: row.position,
          exercises: exercises,
        ),
      );
    }
    return result;
  }

  // ---------------------------------------------------------------- routines

  /// Creates an empty routine and returns it.
  ///
  /// **The newest routine reads first**, which is what the landing shows, and
  /// it gets there by taking a position one below the current minimum rather
  /// than by renumbering every other row. A create is then one insert whatever
  /// the list length, and an explicit drag order (which renumbers from zero)
  /// still wins because both are read ascending.
  Future<Routine> createRoutine({required String name}) async {
    final id = const Uuid().v4();
    final lowest = await _db
        .customSelect('SELECT MIN(position) AS p FROM routines')
        .getSingle();
    final position = (lowest.read<int?>('p') ?? 0) - 1;

    await _db.into(_db.routines).insert(
          RoutinesCompanion.insert(
            id: id,
            name: name,
            position: position,
          ),
        );
    return Routine(
      id: id,
      name: name,
      position: position,
      exercises: const <RoutineExercise>[],
    );
  }

  Future<void> renameRoutine(String routineId, String name) async {
    await (_db.update(_db.routines)..where((r) => r.id.equals(routineId)))
        .write(RoutinesCompanion(name: Value<String>(name)));
  }

  /// Deletes a routine, and its exercises and target sets with it.
  Future<void> deleteRoutine(String routineId) async {
    await (_db.delete(_db.routines)..where((r) => r.id.equals(routineId))).go();
  }

  /// Writes an explicit order, renumbering from zero.
  ///
  /// Ids not in [idsInOrder] keep their existing position, so a partial list
  /// cannot silently reshuffle the rest.
  Future<void> reorderRoutines(List<String> idsInOrder) =>
      _db.transaction(() async {
        for (var i = 0; i < idsInOrder.length; i++) {
          await (_db.update(_db.routines)
                ..where((r) => r.id.equals(idsInOrder[i])))
              .write(RoutinesCompanion(position: Value<int>(i)));
        }
      });

  // --------------------------------------------------------------- exercises

  /// Appends an exercise to a routine and returns its row id.
  Future<String> addExercise({
    required String routineId,
    required String exerciseId,
  }) async {
    final id = const Uuid().v4();
    final highest = await _db
        .customSelect(
          'SELECT MAX(position) AS p FROM routine_exercises WHERE routine_id = ?',
          variables: <Variable<Object>>[Variable<String>(routineId)],
        )
        .getSingle();

    await _db.into(_db.routineExercises).insert(
          RoutineExercisesCompanion.insert(
            id: id,
            routineId: routineId,
            exerciseId: exerciseId,
            position: (highest.read<int?>('p') ?? -1) + 1,
          ),
        );
    return id;
  }

  Future<void> deleteExercise(String routineExerciseId) async {
    await (_db.delete(_db.routineExercises)
          ..where((e) => e.id.equals(routineExerciseId)))
        .go();
  }

  Future<void> reorderExercises(List<String> idsInOrder) =>
      _db.transaction(() async {
        for (var i = 0; i < idsInOrder.length; i++) {
          await (_db.update(_db.routineExercises)
                ..where((e) => e.id.equals(idsInOrder[i])))
              .write(RoutineExercisesCompanion(position: Value<int>(i)));
        }
      });

  Future<void> setExerciseNotes({
    required String routineExerciseId,
    required String? notes,
  }) async {
    final trimmed = notes?.trim();
    await (_db.update(_db.routineExercises)
          ..where((e) => e.id.equals(routineExerciseId)))
        .write(RoutineExercisesCompanion(
      notes: Value<String?>(
        trimmed == null || trimmed.isEmpty ? null : trimmed,
      ),
    ));
  }

  Future<void> setExerciseRestTimer({
    required String routineExerciseId,
    required int? seconds,
  }) async {
    await (_db.update(_db.routineExercises)
          ..where((e) => e.id.equals(routineExerciseId)))
        .write(RoutineExercisesCompanion(
      restTimerSec: Value<int?>(
        seconds == null || seconds <= 0 ? null : seconds,
      ),
    ));
  }

  // -------------------------------------------------------------------- sets

  /// Appends a target set. Every target is optional — a routine may plan three
  /// sets of bench without yet naming a weight.
  Future<String> addSet({
    required String routineExerciseId,
    double? targetWeightKg,
    int? targetReps,
    int? targetDurationSec,
  }) async {
    final id = const Uuid().v4();
    final highest = await _db
        .customSelect(
          'SELECT MAX(position) AS p FROM routine_sets '
          'WHERE routine_exercise_id = ?',
          variables: <Variable<Object>>[Variable<String>(routineExerciseId)],
        )
        .getSingle();

    await _db.into(_db.routineSets).insert(
          RoutineSetsCompanion.insert(
            id: id,
            routineExerciseId: routineExerciseId,
            position: (highest.read<int?>('p') ?? -1) + 1,
            targetWeightKg: Value<double?>(targetWeightKg),
            targetReps: Value<int?>(targetReps),
            targetDurationSec: Value<int?>(targetDurationSec),
          ),
        );
    return id;
  }

  Future<void> updateSet({
    required String setId,
    double? targetWeightKg,
    int? targetReps,
    int? targetDurationSec,
  }) async {
    await (_db.update(_db.routineSets)..where((s) => s.id.equals(setId)))
        .write(RoutineSetsCompanion(
      targetWeightKg: Value<double?>(targetWeightKg),
      targetReps: Value<int?>(targetReps),
      targetDurationSec: Value<int?>(targetDurationSec),
    ));
  }

  Future<void> deleteSet(String setId) async {
    await (_db.delete(_db.routineSets)..where((s) => s.id.equals(setId))).go();
  }
}

/// Whether [session] stopped matching the [routine] it was started from.
///
/// **Only the shape is compared — which exercises, in which order, and how many
/// sets each.** Not the weights: a routine that plans 60kg and a day you managed
/// 62.5 is the routine working, not a routine that needs rewriting, and asking
/// after every good session would train the user to dismiss the question
/// without reading it.
///
/// **Uncompleted sets are invisible here**, because `saveOpenSession` drops them
/// a moment later. A row the user opened and never did must not provoke a
/// question about a change that is about to disappear.
///
/// A session that logged nothing at all never diverges: it is not saved either
/// (`00` §9), so there is nothing to have learned from it.
bool routineDiverges(Routine routine, WorkoutSession session) {
  final done = <(String, int)>[
    for (final exercise in session.exercises)
      if (exercise.sets.where((s) => isSetComplete(exercise.loadType, s)).isNotEmpty)
        (
          exercise.exerciseId,
          exercise.sets
              .where((s) => isSetComplete(exercise.loadType, s))
              .length,
        ),
  ];
  if (done.isEmpty) return false;

  final planned = <(String, int)>[
    for (final exercise in routine.exercises)
      (exercise.exerciseId, exercise.sets.length),
  ];
  if (done.length != planned.length) return true;
  for (var i = 0; i < done.length; i++) {
    if (done[i] != planned[i]) return true;
  }
  return false;
}

/// One of the user's routines: an ordered exercise list with target sets.
@immutable
class Routine {
  const Routine({
    required this.id,
    required this.name,
    required this.position,
    required this.exercises,
  });

  final String id;
  final String name;
  final int position;
  final List<RoutineExercise> exercises;

  /// What the routine card renders under its name: the exercise names, in
  /// order, joined. Resolving ids to names is the caller's job — the store does
  /// not know the library.
  bool get isEmpty => exercises.isEmpty;
}

/// One exercise inside a routine.
@immutable
class RoutineExercise {
  const RoutineExercise({
    required this.id,
    required this.exerciseId,
    required this.position,
    required this.sets,
    this.notes,
    this.restTimerSec,
  });

  final String id;
  final String exerciseId;
  final int position;

  /// Carried onto the session when the routine is started.
  final String? notes;

  /// Rest between sets, in seconds. Null is OFF.
  final int? restTimerSec;
  final List<RoutineSet> sets;
}

/// One planned set. Every target is optional.
@immutable
class RoutineSet {
  const RoutineSet({
    required this.id,
    required this.position,
    this.targetWeightKg,
    this.targetReps,
    this.targetDurationSec,
  });

  final String id;
  final int position;
  final double? targetWeightKg;
  final int? targetReps;
  final int? targetDurationSec;
}
