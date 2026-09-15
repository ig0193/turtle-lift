import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'load_type.dart';
import 'local_date.dart';
import 'settings_store.dart' show appDatabaseProvider;

/// Reads and writes workouts: the one open session, and every saved one.
///
/// **A store, named like the two this codebase already has.** Widgets and
/// notifiers hold the value types below; they never hold a database row, and
/// swapping the storage underneath them stays a change to this file.
///
/// **This is the session's only writer.** Holding a session graph in a notifier
/// means the screen and the database can disagree, so state is assigned only
/// from what a write read back, and a write that throws leaves the notifier
/// behind disk rather than ahead of it. Writes are serialized through
/// [_queue] because a held stepper fires a burst of mutations whose
/// interleaving would otherwise reorder a value the user is watching.
class SessionStore {
  SessionStore(this._db);

  final AppDatabase _db;

  /// The tail of the write chain. Every mutation appends to it, so two writes
  /// started in the same frame still land in the order they were requested.
  Future<void> _queue = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() write) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await write());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  /// The session in progress, or null when none is open.
  ///
  /// Returns null rather than throwing when the row cannot be interpreted: this
  /// is read before the first frame, and a session a build cannot read is not a
  /// reason to stop the app from launching. See [readOpenSessionOrNull].
  Future<WorkoutSession?> readOpenSession() async {
    final row = await (_db.select(_db.sessions)
          ..where((s) => s.openMarker.equals(kOpenSessionMarker)))
        .getSingleOrNull();
    if (row == null) return null;
    return _hydrate(row);
  }

  /// Every saved session, newest first.
  ///
  /// **Excludes the open one.** Figures derived from training history must not
  /// move while a workout is in progress, so the session being logged does not
  /// reach the streak, the records, or the prefill until it is saved.
  Future<List<WorkoutSession>> readSavedSessions() async {
    final rows = await (_db.select(_db.sessions)
          ..where((s) => s.openMarker.isNull())
          ..orderBy(<OrderClauseGenerator<$SessionsTable>>[
            (s) => OrderingTerm.desc(s.performedOn),
            (s) => OrderingTerm.desc(s.loggedAt),
          ]))
        .get();
    return <WorkoutSession>[
      for (final row in rows) await _hydrate(row),
    ];
  }

  Future<WorkoutSession> _hydrate(SessionRow row) async {
    final exerciseRows = await (_db.select(_db.sessionExercises)
          ..where((e) => e.sessionId.equals(row.id))
          ..orderBy(<OrderClauseGenerator<$SessionExercisesTable>>[
            (e) => OrderingTerm.asc(e.position),
          ]))
        .get();

    final exercises = <SessionExercise>[];
    for (final exerciseRow in exerciseRows) {
      final setRows = await (_db.select(_db.setEntries)
            ..where((s) => s.sessionExerciseId.equals(exerciseRow.id))
            ..orderBy(<OrderClauseGenerator<$SetEntriesTable>>[
              (s) => OrderingTerm.asc(s.position),
            ]))
          .get();
      exercises.add(
        SessionExercise(
          id: exerciseRow.id,
          exerciseId: exerciseRow.exerciseId,
          position: exerciseRow.position,
          // A row whose stored load type this build does not recognise still
          // renders its sets; it just cannot claim a type it does not know.
          loadType: LoadType.fromName(exerciseRow.loadType),
          markedDone: exerciseRow.markedDone,
          sets: <SetEntry>[
            for (final s in setRows)
              SetEntry(
                id: s.id,
                position: s.position,
                completed: s.completed,
                weightKg: s.weightKg,
                reps: s.reps,
                addedKg: s.addedKg,
                assistKg: s.assistKg,
                durationSec: s.durationSec,
              ),
          ],
        ),
      );
    }

    return WorkoutSession(
      id: row.id,
      title: row.title,
      performedOn: row.performedOn,
      loggedAt: row.loggedAt,
      templateId: row.templateId,
      templateName: row.templateName,
      groupIds: decodeGroupIds(row.groupIds),
      isOpen: row.openMarker != null,
      exercises: exercises,
    );
  }

  /// Starts a session and returns it.
  ///
  /// **Clearing any existing open marker is part of the same transaction.** A
  /// stale marker plus the unique index would otherwise reject every future
  /// session, which is how an unreadable row turns into a device that can never
  /// start a workout again. Auto-save uses this same path: the old session is
  /// saved first, and if that has not happened the marker is released here
  /// rather than blocking the user.
  Future<WorkoutSession> createSession({
    String? templateId,
    String? templateName,
    List<String> groupIds = const <String>[],
    LocalDate? performedOn,
  }) =>
      _serialized(() async {
        final id = const Uuid().v4();
        final date = performedOn ?? LocalDate.today();
        await _db.transaction(() async {
          await (_db.update(_db.sessions)
                ..where((s) => s.openMarker.equals(kOpenSessionMarker)))
              .write(const SessionsCompanion(openMarker: Value<int?>(null)));
          await _db.into(_db.sessions).insert(
                SessionsCompanion.insert(
                  id: id,
                  // Prefilled with the template name on the template path and
                  // empty on the ad-hoc path, so the user is never blocked on
                  // naming anything.
                  title: Value<String?>(templateName),
                  performedOn: _clamped(date),
                  loggedAt: DateTime.now(),
                  templateId: Value<String?>(templateId),
                  templateName: Value<String?>(templateName),
                  groupIds: Value<String?>(
                    groupIds.isEmpty ? null : encodeGroupIds(groupIds),
                  ),
                  openMarker: const Value<int?>(kOpenSessionMarker),
                ),
              );
        });
        return (await readOpenSession())!;
      });

  /// Saves the open session, dropping every set row the user never completed.
  ///
  /// **A no-op when nothing is open**, so a double-tapped Finish produces one
  /// saved workout rather than a duplicate or an exception.
  ///
  /// The session keeps its original date: a Monday workout saved on Wednesday
  /// files as Monday, and one finished after midnight files on the day it was
  /// started.
  Future<void> saveOpenSession() => _serialized(() async {
        await _db.transaction(() async {
          final row = await (_db.select(_db.sessions)
                ..where((s) => s.openMarker.equals(kOpenSessionMarker)))
              .getSingleOrNull();
          if (row == null) return;

          final exerciseIds = (await (_db.select(_db.sessionExercises)
                    ..where((e) => e.sessionId.equals(row.id)))
                  .get())
              .map((e) => e.id)
              .toList(growable: false);
          if (exerciseIds.isNotEmpty) {
            await (_db.delete(_db.setEntries)
                  ..where((s) =>
                      s.sessionExerciseId.isIn(exerciseIds) &
                      s.completed.equals(false)))
                .go();
          }

          await (_db.update(_db.sessions)..where((s) => s.id.equals(row.id)))
              .write(const SessionsCompanion(openMarker: Value<int?>(null)));
        });
      });

  /// Drops the open session and everything under it. A no-op when none is open.
  Future<void> discardOpenSession() => _serialized(() async {
        await (_db.delete(_db.sessions)
              ..where((s) => s.openMarker.equals(kOpenSessionMarker)))
            .go();
      });

  /// Permanently removes a saved workout, and its exercises and sets with it.
  Future<void> deleteSession(String sessionId) => _serialized(() async {
        await (_db.delete(_db.sessions)..where((s) => s.id.equals(sessionId)))
            .go();
      });

  /// Adds an exercise to a session and returns the row's id.
  ///
  /// [loadType] is snapshotted here, at the moment of adding, so a regenerated
  /// exercise library can never change what this session's stored numbers mean.
  Future<String> addExercise({
    required String sessionId,
    required String exerciseId,
    required LoadType loadType,
  }) =>
      _serialized(() async {
        final existing = await (_db.select(_db.sessionExercises)
              ..where((e) =>
                  e.sessionId.equals(sessionId) &
                  e.exerciseId.equals(exerciseId)))
            .getSingleOrNull();
        // Adding one that is already here navigates to it rather than splitting
        // its sets across two rows and two prefill chains.
        if (existing != null) return existing.id;

        final id = const Uuid().v4();
        final used = await (_db.select(_db.sessionExercises)
              ..where((e) => e.sessionId.equals(sessionId)))
            .get();
        await _db.into(_db.sessionExercises).insert(
              SessionExercisesCompanion.insert(
                id: id,
                sessionId: sessionId,
                exerciseId: exerciseId,
                position: used.length,
                loadType: loadType.name,
              ),
            );
        return id;
      });

  /// Removes an exercise from a session, taking its sets with it.
  Future<void> removeExercise(String sessionExerciseId) =>
      _serialized(() async {
        await (_db.delete(_db.sessionExercises)
              ..where((e) => e.id.equals(sessionExerciseId)))
            .go();
      });

  /// Records whether the user tapped "Mark exercise done".
  Future<void> setMarkedDone(String sessionExerciseId, bool done) =>
      _serialized(() async {
        await (_db.update(_db.sessionExercises)
              ..where((e) => e.id.equals(sessionExerciseId)))
            .write(SessionExercisesCompanion(markedDone: Value<bool>(done)));
      });

  /// Writes a set row, creating it the first time a field is touched.
  ///
  /// **A row exists only once the user has touched it**, which is what makes
  /// the row's existence the record of "this is entered, not guessed" — a
  /// separate flag held in widget state would be lost on navigating away and on
  /// restart.
  Future<String> writeSet({
    required String sessionExerciseId,
    required int position,
    String? setId,
    bool completed = false,
    double? weightKg,
    int? reps,
    double? addedKg,
    double? assistKg,
    int? durationSec,
  }) =>
      _serialized(() async {
        final id = setId ?? const Uuid().v4();
        await _db.into(_db.setEntries).insertOnConflictUpdate(
              SetEntriesCompanion.insert(
                id: id,
                sessionExerciseId: sessionExerciseId,
                position: position,
                completed: Value<bool>(completed),
                weightKg: Value<double?>(weightKg),
                reps: Value<int?>(reps),
                addedKg: Value<double?>(addedKg),
                assistKg: Value<double?>(assistKg),
                durationSec: Value<int?>(durationSec),
              ),
            );
        return id;
      });

  /// Removes one set row.
  Future<void> deleteSet(String setId) => _serialized(() async {
        await (_db.delete(_db.setEntries)..where((s) => s.id.equals(setId)))
            .go();
      });

  /// Renames a session. An empty title is stored as empty and resolved on read.
  Future<void> setTitle(String sessionId, String? title) =>
      _serialized(() async {
        await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
            .write(SessionsCompanion(title: Value<String?>(title)));
      });

  /// Moves a session to another calendar day.
  ///
  /// **Clamped to today or earlier**, because a future-dated session makes the
  /// streak meaningless. The clamp validates a date the user chose; it never
  /// rewrites one already stored, so crossing a time zone westward cannot move
  /// an existing workout to the previous day through an unrelated edit.
  Future<void> setPerformedOn(String sessionId, LocalDate date) =>
      _serialized(() async {
        await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
            .write(SessionsCompanion(performedOn: Value<LocalDate>(_clamped(date))));
      });

  static LocalDate _clamped(LocalDate date) {
    final today = LocalDate.today();
    return date > today ? today : date;
  }

  /// How many sessions exist at all. Only a test should care.
  @visibleForTesting
  Future<int> sessionCount() async =>
      (await _db.select(_db.sessions).get()).length;
}

/// Parent muscle group ids, comma-joined. Mirrors the custom-template encoding.
String encodeGroupIds(List<String> ids) => ids.join(',');

/// The ids a stored [encodeGroupIds] string names.
List<String> decodeGroupIds(String? stored) {
  if (stored == null || stored.isEmpty) return const <String>[];
  return stored.split(',');
}

/// One logged set.
@immutable
class SetEntry {
  const SetEntry({
    required this.id,
    required this.position,
    required this.completed,
    this.weightKg,
    this.reps,
    this.addedKg,
    this.assistKg,
    this.durationSec,
  });

  final String id;
  final int position;

  /// Whether the user ticked it **and** its required field is above zero.
  final bool completed;

  final double? weightKg;
  final int? reps;
  final double? addedKg;
  final double? assistKg;
  final int? durationSec;
}

/// One exercise within a session.
@immutable
class SessionExercise {
  const SessionExercise({
    required this.id,
    required this.exerciseId,
    required this.position,
    required this.loadType,
    required this.markedDone,
    required this.sets,
  });

  final String id;
  final String exerciseId;
  final int position;

  /// Null only when the stored name is one this build does not recognise.
  final LoadType? loadType;

  /// Whether the user tapped "Mark exercise done". The tri-state the list
  /// renders is derived from this and the sets, never stored.
  final bool markedDone;

  final List<SetEntry> sets;

  /// Sets that count: ticked, with their required field above zero.
  Iterable<SetEntry> get completedSets => sets.where((s) => s.completed);
}

/// One workout.
@immutable
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.title,
    required this.performedOn,
    required this.loggedAt,
    required this.templateId,
    required this.templateName,
    required this.groupIds,
    required this.isOpen,
    required this.exercises,
  });

  final String id;

  /// May be empty in storage; never displayed empty.
  final String? title;

  /// The calendar day the workout happened.
  final LocalDate performedOn;

  /// Internal tiebreaker between two sessions on one day. Never shown.
  final DateTime loggedAt;

  final String? templateId;

  /// The template's name as it was when the session started, so a deleted
  /// custom template still resolves this session's title.
  final String? templateName;

  /// The parent groups this session may train, snapshotted at creation.
  /// **Read only while the session is open.**
  final List<String> groupIds;

  final bool isOpen;
  final List<SessionExercise> exercises;

  /// Whether this session is a template run rather than an ad-hoc one.
  bool get isTemplateSession => templateId != null;

  /// Every completed set in the session.
  Iterable<SetEntry> get completedSets =>
      exercises.expand((e) => e.completedSets);

  /// Whether anything at all has been written, completed or not. A session with
  /// nothing written is dropped silently; one with typed rows asks first.
  bool get hasAnyWrittenSets => exercises.any((e) => e.sets.isNotEmpty);
}

/// The session store.
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SessionStore(ref.watch(appDatabaseProvider)),
);
