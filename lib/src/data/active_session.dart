import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'load_type.dart';
import 'local_date.dart';
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

  /// Starts a workout from a template, carrying its name and muscle groups.
  ///
  /// The name and groups are snapshotted onto the session so the title chain
  /// and the template lock keep working if that template is later deleted.
  Future<void> startFromTemplate({
    required String templateId,
    required String templateName,
    required List<String> groupIds,
  }) async {
    await _store.createSession(
      templateId: templateId,
      templateName: templateName,
      groupIds: groupIds,
    );
    await _refresh();
  }

  /// Starts an ad-hoc workout. Its title begins empty and may stay that way.
  ///
  /// Called when the first exercise is added, not when the ad-hoc entry is
  /// tapped: creating it on the tap strands a user who backs out of search with
  /// nothing added in an empty session that has replaced the landing.
  Future<void> startAdHoc() async {
    await _store.createSession();
    await _refresh();
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
