import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'load_type.dart';
import 'local_date.dart';

/// Writes a handful of plausible workouts into an empty database, purely so
/// the History tab has something to render while its calendar and Recent
/// list are being built and reviewed on a real device.
///
/// **Debug-only, and temporary.** `main.dart` calls this behind `kDebugMode`
/// and only when the sessions table is empty, so it never runs in a release
/// build and never touches a real workout. This file is a development
/// convenience, not a feature -- delete it (and the call site in
/// `main.dart`) once the History redesign has real data to look at.
///
/// **One `batch`, not ~150 serialized round trips.** The first version of this
/// file drove every row through `SessionStore`'s own one-write-at-a-time,
/// queued-and-transacted API -- the same path a live set entry takes. That is
/// correct for one set typed by a hand, and it is exactly wrong for a hundred
/// rows written at once: on a real device it held `main()`'s boot awaits open
/// for minutes, which is the one thing `CLAUDE.md` says a splash must never
/// do ("never gate entry on it"). Building every row up front and writing them
/// in a single `AppDatabase.batch` finishes in well under a second regardless
/// of how much sample data this seeds, because it is one transaction instead
/// of hundreds.
///
/// Exercise ids are real entries from `assets/exercises/exercises.json`, so
/// every seeded set renders through the same load-type formatter a logged set
/// would. Weights step up release over release so the most recent session of
/// each kind lands a personal best, matching what a real lifter's history
/// tends to look like.
Future<void> seedSampleHistoryIfEmpty(AppDatabase db) async {
  final existing =
      await (db.select(db.sessions)..limit(1)).getSingleOrNull();
  if (existing != null) return;

  const uuid = Uuid();
  final sessionRows = <SessionsCompanion>[];
  final exerciseRows = <SessionExercisesCompanion>[];
  final setRows = <SetEntriesCompanion>[];

  LocalDate dateDaysAgo(int daysAgo) =>
      LocalDate.fromDateTime(DateTime.now().subtract(Duration(days: daysAgo)));

  void addExerciseRows(String sessionId, List<_SeedExercise> exercises) {
    for (var ei = 0; ei < exercises.length; ei++) {
      final exercise = exercises[ei];
      final exerciseRowId = uuid.v4();
      exerciseRows.add(SessionExercisesCompanion.insert(
        id: exerciseRowId,
        sessionId: sessionId,
        exerciseId: exercise.id,
        position: ei,
        loadType: exercise.loadType.name,
      ));
      for (var si = 0; si < exercise.sets.length; si++) {
        final set = exercise.sets[si];
        setRows.add(SetEntriesCompanion.insert(
          id: uuid.v4(),
          sessionExerciseId: exerciseRowId,
          position: si,
          completed: const Value<bool>(true),
          weightKg: Value<double?>(set.weightKg),
          reps: Value<int?>(set.reps),
        ));
      }
    }
  }

  void workout({
    required int daysAgo,
    required String title,
    required List<_SeedExercise> exercises,
  }) {
    final sessionId = uuid.v4();
    sessionRows.add(SessionsCompanion.insert(
      id: sessionId,
      title: Value<String?>(title),
      performedOn: dateDaysAgo(daysAgo),
      loggedAt: DateTime.now(),
      templateName: Value<String?>(title),
    ));
    addExerciseRows(sessionId, exercises);
  }

  void quickLog({required int daysAgo, required _SeedExercise exercise}) {
    final sessionId = uuid.v4();
    sessionRows.add(SessionsCompanion.insert(
      id: sessionId,
      performedOn: dateDaysAgo(daysAgo),
      loggedAt: DateTime.now(),
    ));
    addExerciseRows(sessionId, <_SeedExercise>[exercise]);
  }

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
  workout(
    daysAgo: 23,
    title: 'Push day',
    exercises: <_SeedExercise>[bench(70), ohp(42.5), tricepsPushdown(20)],
  );
  workout(
    daysAgo: 20,
    title: 'Pull day',
    exercises: <_SeedExercise>[row(65), latPulldown(58), curl(27.5)],
  );
  workout(
    daysAgo: 17,
    title: 'Leg day',
    exercises: <_SeedExercise>[squat(90), rdl(80), calfRaise(60)],
  );
  quickLog(daysAgo: 15, exercise: pullUp);
  workout(
    daysAgo: 13,
    title: 'Push day',
    exercises: <_SeedExercise>[bench(72.5), ohp(45), tricepsPushdown(22.5)],
  );
  workout(
    daysAgo: 10,
    title: 'Pull day',
    exercises: <_SeedExercise>[row(67.5), latPulldown(60), curl(30)],
  );
  workout(
    daysAgo: 8,
    title: 'Leg day',
    exercises: <_SeedExercise>[squat(95), rdl(82.5), calfRaise(65)],
  );
  workout(
    daysAgo: 5,
    title: 'Push day',
    exercises: <_SeedExercise>[bench(75), ohp(47.5), tricepsPushdown(22.5)],
  );
  workout(
    daysAgo: 3,
    title: 'Pull day',
    exercises: <_SeedExercise>[row(70), latPulldown(62.5), curl(30)],
  );
  workout(
    daysAgo: 1,
    title: 'Leg day',
    exercises: <_SeedExercise>[squat(100), rdl(85), calfRaise(65)],
  );
  // Today carries two sessions, so the calendar's two-dot day and the
  // History tab's "quick log" tag both have something to show immediately.
  workout(
    daysAgo: 0,
    title: 'Push day',
    exercises: <_SeedExercise>[bench(77.5), ohp(47.5), tricepsPushdown(25)],
  );
  quickLog(daysAgo: 0, exercise: curl(32.5));

  await db.batch((batch) {
    batch.insertAll(db.sessions, sessionRows);
    batch.insertAll(db.sessionExercises, exerciseRows);
    batch.insertAll(db.setEntries, setRows);
  });
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
