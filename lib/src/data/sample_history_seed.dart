import 'load_type.dart';
import 'local_date.dart';
import 'session_store.dart';

/// Writes a handful of plausible workouts into an empty session store, purely
/// so the History tab has something to render while its calendar and Recent
/// list are being built and reviewed on a real device.
///
/// **Debug-only, and temporary.** [main.dart] calls this behind `kDebugMode`
/// and only when [SessionStore.readSavedSessions] comes back empty, so it
/// never runs in a release build and never overwrites a real workout. This
/// file is a development convenience, not a feature -- delete it (and the
/// call site in `main.dart`) once the History redesign has real data to look
/// at, or whenever a fresh-install demo stops being useful.
///
/// Exercise ids are real entries from `assets/exercises/exercises.json`, so
/// every seeded set renders through the same load-type formatter a logged set
/// would. Weights step up release over release so the most recent session of
/// each kind lands a personal best, matching what a real lifter's history
/// tends to look like.
Future<void> seedSampleHistoryIfEmpty(SessionStore store) async {
  if ((await store.readSavedSessions()).isNotEmpty) return;

  Future<void> workout({
    required int daysAgo,
    required String title,
    required List<String> groupIds,
    required List<_SeedExercise> exercises,
  }) async {
    final session = await store.createSession(
      templateName: title,
      groupIds: groupIds,
      performedOn: LocalDate.fromDateTime(
        DateTime.now().subtract(Duration(days: daysAgo)),
      ),
    );
    for (final exercise in exercises) {
      final exerciseId = await store.addExercise(
        sessionId: session.id,
        exerciseId: exercise.id,
        loadType: exercise.loadType,
      );
      for (var i = 0; i < exercise.sets.length; i++) {
        final set = exercise.sets[i];
        await store.writeSet(
          sessionExerciseId: exerciseId,
          position: i,
          completed: true,
          weightKg: set.weightKg,
          reps: set.reps,
        );
      }
    }
    await store.saveOpenSession();
  }

  Future<void> quickLog({
    required int daysAgo,
    required _SeedExercise exercise,
  }) async {
    final session = await store.createSession(
      performedOn: LocalDate.fromDateTime(
        DateTime.now().subtract(Duration(days: daysAgo)),
      ),
    );
    final exerciseId = await store.addExercise(
      sessionId: session.id,
      exerciseId: exercise.id,
      loadType: exercise.loadType,
    );
    for (var i = 0; i < exercise.sets.length; i++) {
      final set = exercise.sets[i];
      await store.writeSet(
        sessionExerciseId: exerciseId,
        position: i,
        completed: true,
        weightKg: set.weightKg,
        reps: set.reps,
      );
    }
    await store.saveOpenSession();
  }

  const push = <String>['chest', 'shoulders', 'triceps'];
  const pull = <String>['back', 'biceps'];
  const legs = <String>['quads', 'hamstrings', 'calves'];

  _SeedExercise bench(double kg) => _SeedExercise.weighted(
        'barbell-bench-press',
        <(double, int)>[(kg, 8), (kg, 8), (kg - 2.5, 9)],
      );
  _SeedExercise ohp(double kg) => _SeedExercise.weighted(
        'barbell-overhead-press',
        <(double, int)>[(kg, 8), (kg, 7), (kg, 7)],
      );
  _SeedExercise tricepsPushdown(double kg) => _SeedExercise.weighted(
        'band-triceps-pushdown',
        <(double, int)>[(kg, 12), (kg, 12), (kg, 10)],
      );
  _SeedExercise row(double kg) => _SeedExercise.weighted(
        'barbell-bent-over-row',
        <(double, int)>[(kg, 8), (kg, 8), (kg, 8)],
      );
  _SeedExercise latPulldown(double kg) => _SeedExercise.weighted(
        'lat-pulldown',
        <(double, int)>[(kg, 10), (kg, 10), (kg, 9)],
      );
  _SeedExercise curl(double kg) => _SeedExercise.weighted(
        'barbell-curl',
        <(double, int)>[(kg, 10), (kg, 9), (kg, 8)],
      );
  _SeedExercise squat(double kg) => _SeedExercise.weighted(
        'barbell-back-squat',
        <(double, int)>[(kg, 8), (kg, 8), (kg - 5, 8), (kg - 5, 7)],
      );
  _SeedExercise rdl(double kg) => _SeedExercise.weighted(
        'barbell-romanian-deadlift',
        <(double, int)>[(kg, 8), (kg, 8), (kg, 8)],
      );
  _SeedExercise calfRaise(double kg) => _SeedExercise.weighted(
        'barbell-standing-calf-raise',
        <(double, int)>[(kg, 15), (kg, 15), (kg, 12), (kg, 12)],
      );
  final pullUp = _SeedExercise.bodyweight('pull-up', <int>[9, 7, 6]);

  // Oldest first, so later (heavier) sessions set the personal bests the
  // History rows show -- matching `buildHistoryProjection`'s own chronological
  // pass rather than fighting it.
  await workout(
    daysAgo: 23,
    title: 'Push day',
    groupIds: push,
    exercises: <_SeedExercise>[bench(70), ohp(42.5), tricepsPushdown(20)],
  );
  await workout(
    daysAgo: 20,
    title: 'Pull day',
    groupIds: pull,
    exercises: <_SeedExercise>[row(65), latPulldown(58), curl(27.5)],
  );
  await workout(
    daysAgo: 17,
    title: 'Leg day',
    groupIds: legs,
    exercises: <_SeedExercise>[squat(90), rdl(80), calfRaise(60)],
  );
  await quickLog(daysAgo: 15, exercise: pullUp);
  await workout(
    daysAgo: 13,
    title: 'Push day',
    groupIds: push,
    exercises: <_SeedExercise>[bench(72.5), ohp(45), tricepsPushdown(22.5)],
  );
  await workout(
    daysAgo: 10,
    title: 'Pull day',
    groupIds: pull,
    exercises: <_SeedExercise>[row(67.5), latPulldown(60), curl(30)],
  );
  await workout(
    daysAgo: 8,
    title: 'Leg day',
    groupIds: legs,
    exercises: <_SeedExercise>[squat(95), rdl(82.5), calfRaise(65)],
  );
  await workout(
    daysAgo: 5,
    title: 'Push day',
    groupIds: push,
    exercises: <_SeedExercise>[bench(75), ohp(47.5), tricepsPushdown(22.5)],
  );
  await workout(
    daysAgo: 3,
    title: 'Pull day',
    groupIds: pull,
    exercises: <_SeedExercise>[row(70), latPulldown(62.5), curl(30)],
  );
  await workout(
    daysAgo: 1,
    title: 'Leg day',
    groupIds: legs,
    exercises: <_SeedExercise>[squat(100), rdl(85), calfRaise(65)],
  );
  // Today carries two sessions, so the calendar's two-dot day and the
  // History tab's "quick log" tag both have something to show immediately.
  await workout(
    daysAgo: 0,
    title: 'Push day',
    groupIds: push,
    exercises: <_SeedExercise>[bench(77.5), ohp(47.5), tricepsPushdown(25)],
  );
  await quickLog(daysAgo: 0, exercise: curl(32.5));
}

/// One exercise's worth of seed sets, load-type aware so [seedSampleHistoryIfEmpty]
/// can treat a weighted lift and a bodyweight one the same way.
class _SeedExercise {
  const _SeedExercise._(this.id, this.loadType, this.sets);

  factory _SeedExercise.weighted(String id, List<(double, int)> sets) =>
      _SeedExercise._(
        id,
        LoadType.weighted,
        <_SeedSet>[for (final (kg, reps) in sets) _SeedSet(weightKg: kg, reps: reps)],
      );

  factory _SeedExercise.bodyweight(String id, List<int> repsPerSet) =>
      _SeedExercise._(
        id,
        LoadType.bodyweight,
        <_SeedSet>[for (final reps in repsPerSet) _SeedSet(reps: reps)],
      );

  final String id;
  final LoadType loadType;
  final List<_SeedSet> sets;
}

class _SeedSet {
  const _SeedSet({this.weightKg, this.reps});

  final double? weightKg;
  final int? reps;
}
