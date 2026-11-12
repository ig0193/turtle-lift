import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'exercise_index.dart';
import 'load_type.dart';
import 'local_date.dart';
import 'set_format.dart';
import 'session_store.dart';

/// The session the app was launched with, resolved **before the first frame**.
///
/// **This exists to be overridden, and `main()` is what overrides it** — the
/// same shape, and the same reasoning, as `initialTemplateFilterProvider`. An
/// `AsyncNotifier` reading the table in `build()` resolves a frame or more after
/// the tree first builds, so the Workout tab would render the landing and then
/// swap it for the session in progress on every cold start. That is not a
/// flicker of the same screen: it is the wrong screen, briefly, for a user who
/// is mid-workout.
///
/// The default here — no open session — is what a test, or a missed override,
/// gets, and it is also the honest state of a fresh install.
final initialActiveSessionProvider = Provider<WorkoutSession?>((ref) => null);

/// Reads the open session, degrading to "none" rather than throwing.
///
/// **A failure here must not stop the app from launching.** This is the first
/// thing read before `runApp` whose failure mode is a user's own workout rather
/// than shipped content: `exerciseIndexProvider` throws by design because a
/// broken asset is a broken build, but a session row an older build cannot
/// interpret is not. Killing `main()` over one would leave the user unable to
/// open the app at all, with reinstall the only recovery and their whole
/// history the cost.
///
/// The unreadable row stays on disk, and it does not stay *open*: starting a
/// session clears any existing marker in the same transaction that sets the new
/// one, so a row nobody can read cannot block every future workout.
Future<WorkoutSession?> readOpenSession(SessionStore store) async {
  try {
    return await store.readOpenSession();
  } catch (_) {
    return null;
  }
}

/// Reads saved history, degrading to none rather than throwing.
///
/// **The same rule as [readOpenSession], and for the same reason.** This reads
/// the same three tables, so whatever makes one unreadable makes both
/// unreadable — a schema older than the build expects, a row it cannot
/// interpret. Letting it throw kills `main()` before `runApp`, and the user
/// sees a blank screen with no way back short of reinstalling, which destroys
/// the history the read was for.
Future<List<WorkoutSession>> readSavedSessions(SessionStore store) async {
  try {
    return await store.readSavedSessions();
  } catch (_) {
    return const <WorkoutSession>[];
  }
}

/// The workout in progress, and the only way to change it.
///
/// **A `Notifier`, not an `AsyncNotifier`** — see [initialActiveSessionProvider]
/// for why the read happens before the tree builds rather than inside it. And
/// not a `StateProvider`, which is legacy on Riverpod 3 (see
/// `lib/src/ui/tab_index.dart`).
///
/// **Every mutation writes through the store and then re-reads what landed.**
/// The state is assigned from what the database actually holds rather than from
/// what the caller asked for, so a write that throws leaves this notifier
/// *behind* disk rather than ahead of it. The store serializes those writes, so
/// a held stepper's burst of mutations cannot reorder the value the user is
/// watching.
class ActiveSession extends Notifier<WorkoutSession?> {
  @override
  WorkoutSession? build() => ref.read(initialActiveSessionProvider);

  SessionStore get _store => ref.read(sessionStoreProvider);

  Future<void> _refresh() async {
    state = await _store.readOpenSession();
  }

  /// Re-reads saved history too. Called after anything that moves a workout
  /// between "in progress" and "saved", or changes a saved one.
  Future<void> _refreshSaved() async =>
      ref.read(savedSessionsProvider.notifier).refresh();

  /// Starts a workout from a template, copying its exercises into the session.
  ///
  /// The name is snapshotted onto the session so the title chain keeps working
  /// if a custom template is later deleted. **The exercises are copied, not
  /// referenced**: from here the session's list is its own, and nothing done to
  /// it writes back to the template.
  ///
  /// An id the library does not know, or one with a load type this build cannot
  /// read, is skipped rather than failing the start — a stale id in a user's own
  /// template must not stop them training.
  Future<void> startFromTemplate({
    required String templateId,
    required String templateName,
    required List<String> exerciseIds,
  }) async {
    final index = ref.read(exerciseIndexProvider);
    final exercises = <({String exerciseId, LoadType loadType})>[];
    for (final id in exerciseIds) {
      final loadType = LoadType.fromName(index.byId(id)?.loadType);
      if (loadType == null) continue;
      exercises.add((exerciseId: id, loadType: loadType));
    }
    await _store.createSession(
      templateId: templateId,
      templateName: templateName,
      exercises: exercises,
    );
    await _refresh();
  }

  /// Starts a new workout from a past one's exercise list ("Do again").
  ///
  /// **The exercises, never the numbers.** Only the exercises [source]
  /// actually logged, in its order, each under the load type it has now. No set
  /// is copied: last time's values reach each row as its "last" line and its
  /// prefill, both derived from history, so nothing here can go stale. It keeps
  /// the template it came from, if any, so the title resolves the same way;
  /// the user's own name for that day is not carried over. Dated today.
  Future<void> startAgain(WorkoutSession source) async {
    final index = ref.read(exerciseIndexProvider);
    final exercises = <({String exerciseId, LoadType loadType})>[];
    for (final e in source.exercises) {
      if (!e.sets.any((s) => isSetComplete(e.loadType, s))) continue;
      final loadType =
          LoadType.fromName(index.byId(e.exerciseId)?.loadType) ?? e.loadType;
      if (loadType == null) continue;
      if (exercises.any((x) => x.exerciseId == e.exerciseId)) continue;
      exercises.add((exerciseId: e.exerciseId, loadType: loadType));
    }
    await _store.createSession(
      templateId: source.templateId,
      templateName: source.templateName,
      exercises: exercises,
    );
    await _refresh();
  }

  /// Starts an ad-hoc workout. Its title begins empty and may stay that way.
  ///
  /// Called when the first exercise is added, not when the ad-hoc entry is
  /// tapped: creating it on the tap strands a user who backs out of search with
  /// nothing added in an empty session that has replaced the landing.
  ///
  /// [performedOn] backfills a missed day: History's calendar starts a
  /// workout dated the empty past day the user tapped (ADR 0013). The store
  /// clamps it to today or earlier like every other date.
  Future<void> startAdHoc({LocalDate? performedOn}) async {
    await _store.createSession(performedOn: performedOn);
    await _refresh();
  }

  /// Adds an exercise to a workout that is already saved, and returns its row
  /// id (the existing row's when it is already there).
  ///
  /// **The saved workout stays saved**: nothing reopens it, so the open
  /// session and the Workout tab are untouched. Its sets are then logged
  /// through set logging pointed at the saved session, the same path that
  /// corrects a set months later (ADR 0013).
  Future<String?> addSavedExercise({
    required String sessionId,
    required String exerciseId,
    required LoadType loadType,
  }) async {
    final id = await _store.addExercise(
      sessionId: sessionId,
      exerciseId: exerciseId,
      loadType: loadType,
    );
    await _refreshSaved();
    return id;
  }

  /// Saves the workout in progress, keeping its original date.
  ///
  /// A no-op when nothing is open, so a double-tapped Finish saves one workout.
  Future<void> finish() async {
    await _store.saveOpenSession();
    state = null;
    await _refreshSaved();
  }

  /// Drops the workout in progress and everything under it.
  Future<void> discard() async {
    await _store.discardOpenSession();
    state = null;
    await _refreshSaved();
  }

  /// Renames a saved workout. The title stays optional forever.
  Future<void> renameSaved(String sessionId, String? title) async {
    await _store.setTitle(sessionId, title);
    await _refreshSaved();
  }

  /// Corrects one set of a workout that is already saved.
  ///
  /// Goes through the same store and the same refresh as a live write, so the
  /// streak, the counts and the records all follow the correction without
  /// anything asking them to.
  Future<void> editSavedSet({
    required String sessionExerciseId,
    required int position,
    String? setId,
    bool completed = false,
    double? weightKg,
    int? reps,
    double? addedKg,
    double? assistKg,
    int? durationSec,
  }) async {
    await _store.writeSet(
      sessionExerciseId: sessionExerciseId,
      position: position,
      setId: setId,
      completed: completed,
      weightKg: weightKg,
      reps: reps,
      addedKg: addedKg,
      assistKg: assistKg,
      durationSec: durationSec,
    );
    await _refreshSaved();
  }

  /// Removes one set from a saved workout.
  Future<void> deleteSavedSet(String setId) async {
    await _store.deleteSet(setId);
    await _refreshSaved();
  }

  /// Removes an exercise from a saved workout, taking its sets with it.
  Future<void> removeSavedExercise(String sessionExerciseId) async {
    await _store.removeExercise(sessionExerciseId);
    await _refreshSaved();
  }

  /// Moves a saved workout to another day, clamped to today or earlier.
  Future<void> setSavedPerformedOn(String sessionId, LocalDate date) async {
    await _store.setPerformedOn(sessionId, date);
    await _refreshSaved();
  }

  /// Permanently removes a saved workout, and everything derived from it.
  Future<void> deleteSaved(String sessionId) async {
    await _store.deleteSession(sessionId);
    await _refreshSaved();
  }

  /// Adds an exercise and returns its row id, or the existing row's id when it
  /// is already in this session.
  Future<String?> addExercise({
    required String exerciseId,
    required LoadType loadType,
  }) async {
    final session = state;
    if (session == null) return null;
    final id = await _store.addExercise(
      sessionId: session.id,
      exerciseId: exerciseId,
      loadType: loadType,
    );
    await _refresh();
    return id;
  }

  Future<void> removeExercise(String sessionExerciseId) async {
    await _store.removeExercise(sessionExerciseId);
    await _refresh();
  }

  /// Moves the exercise at [from] to [to] in the open workout's list
  /// (indexes as the list shows them, `to` after removal). The order is the
  /// user's: it is stored as each row's position, and nothing is derived from
  /// it except which row is Up next.
  Future<void> moveExercise(int from, int to) async {
    final session = state;
    if (session == null) return;
    final ids = session.exercises.map((e) => e.id).toList();
    if (from < 0 || from >= ids.length) return;
    final target = to.clamp(0, ids.length - 1);
    if (target == from) return;
    final moved = ids.removeAt(from);
    ids.insert(target, moved);
    await _store.reorderExercises(session.id, ids);
    await _refresh();
  }

  /// Swaps the open workout's exercise [sessionExerciseId] for [exerciseId]
  /// in place. See [SessionStore.swapExercise] for when it is refused.
  Future<SwapResult> swapExercise({
    required String sessionExerciseId,
    required String exerciseId,
    required LoadType loadType,
  }) async {
    final result = await _store.swapExercise(
      sessionExerciseId: sessionExerciseId,
      exerciseId: exerciseId,
      loadType: loadType,
    );
    await _refresh();
    return result;
  }

  /// Writes the note on one of the open workout's exercises.
  Future<void> setNote(String sessionExerciseId, String? note) async {
    await _store.setNote(sessionExerciseId, note);
    await _refresh();
  }

  /// Writes the note on an exercise of a saved workout, from the same set
  /// logging screen that corrects its sets.
  Future<void> setSavedNote(String sessionExerciseId, String? note) async {
    await _store.setNote(sessionExerciseId, note);
    await _refreshSaved();
  }

  Future<void> markExerciseDone(String sessionExerciseId, bool done) async {
    await _store.setMarkedDone(sessionExerciseId, done);
    await _refresh();
  }

  /// Writes a set row, creating it the first time a field is touched.
  Future<void> writeSet({
    required String sessionExerciseId,
    required int position,
    String? setId,
    bool completed = false,
    double? weightKg,
    int? reps,
    double? addedKg,
    double? assistKg,
    int? durationSec,
  }) async {
    await _store.writeSet(
      sessionExerciseId: sessionExerciseId,
      position: position,
      setId: setId,
      completed: completed,
      weightKg: weightKg,
      reps: reps,
      addedKg: addedKg,
      assistKg: assistKg,
      durationSec: durationSec,
    );
    await _refresh();
  }

  Future<void> deleteSet(String setId) async {
    await _store.deleteSet(setId);
    await _refresh();
  }

  /// Renames the workout in progress.
  Future<void> rename(String? title) async {
    final session = state;
    if (session == null) return;
    await _store.setTitle(session.id, title);
    await _refresh();
  }

  /// Moves the workout in progress to another day, clamped to today or earlier.
  Future<void> setPerformedOn(LocalDate date) async {
    final session = state;
    if (session == null) return;
    await _store.setPerformedOn(session.id, date);
    await _refresh();
  }
}

/// The workout in progress, or null when the Workout tab shows its landing.
final activeSessionProvider =
    NotifierProvider<ActiveSession, WorkoutSession?>(ActiveSession.new);

/// The saved sessions the app started with, resolved before the first frame.
///
/// Same shape and same reasoning as [initialActiveSessionProvider]: the streak
/// and the counts are on screen immediately, and resolving them a frame later
/// would show a zero that is not true.
final initialSavedSessionsProvider =
    Provider<List<WorkoutSession>>((ref) => const <WorkoutSession>[]);

/// Every saved workout, and the source for every figure derived from history.
///
/// **A `Notifier` seeded at boot, matching every other store-backed value in
/// this app** — the split filter, the gender, the bodyweight log and the custom
/// templates all take this shape, and the reason is the same: the streak and
/// the counts are on screen on the first frame, and resolving them a frame
/// later would show a zero that is not true.
///
/// **One invalidation funnel, named here.** A drift `watch` would refresh this
/// on its own, but it also puts a live database stream under every widget test,
/// which never settles against the fake clock a widget test installs. So the
/// rule instead is: every mutation that can change saved history goes through
/// [ActiveSession], and [ActiveSession] calls [refresh]. That is the single
/// path, and it is short enough to check — finishing, discarding, deleting a
/// workout, and editing a saved one.
class SavedSessions extends Notifier<List<WorkoutSession>> {
  @override
  List<WorkoutSession> build() => ref.read(initialSavedSessionsProvider);

  /// Re-reads saved history. Called by [ActiveSession] after anything that can
  /// change it.
  Future<void> refresh() async {
    state = await ref.read(sessionStoreProvider).readSavedSessions();
  }
}

/// Every saved workout. The source for every figure derived from history.
final savedSessionsProvider =
    NotifierProvider<SavedSessions, List<WorkoutSession>>(SavedSessions.new);
