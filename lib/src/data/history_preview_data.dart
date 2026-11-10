/// The shape the History tab renders, and the projection behind it.
///
/// **The session tables have landed, and this reads them.**
/// [historySessionsProvider] is now a view over the saved workouts in
/// `session_store.dart`; the preview fixture it used to yield is gone, because
/// the moment a user finished a real workout it would have appeared beside a
/// training split they never did.
///
/// **The personal-best count comes from `personal_best.dart`, not from the
/// projection's own running best.** Two derivations of the same figure drift,
/// and this is the figure where drift is worst: the projection collapsed a set
/// to one comparable number and had no way to express the assisted inversion,
/// where *less* assistance is the record. The projection still does the
/// single-pass work the spec requires for everything else.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_session.dart';
import 'derived.dart';
import 'exercise_index.dart';
import 'generated/muscle_taxonomy.dart';
import 'personal_best.dart';
import 'session_store.dart';

/// One logged workout, reduced to what a history row needs.
///
/// **[performedOn] is a local calendar date, never a timestamp.** `CLAUDE.md`
/// is explicit: an 11pm session must not land on the wrong day. The real table
/// will carry `loggedAt` separately as an internal ordering tiebreaker; a row
/// never shows it.
class HistorySession {
  const HistorySession({
    required this.id,
    required this.performedOn,
    required this.exercises,
    this.title,
    this.templateName,
    this.isQuickLog = false,
  });

  final String id;

  /// The day the workout happened, at local midnight.
  final DateTime performedOn;

  final List<HistoryExercise> exercises;

  /// What the user named it, when they named it. Null falls through the
  /// resolution chain in [resolvedTitle].
  final String? title;

  /// The template it was started from, which is the second link of the title
  /// chain (`docs/00` §6). Ignoring it named a cleared template workout
  /// "Chest, shoulders, triceps" here and "Push day" on its card (B7).
  final String? templateName;

  /// A single-exercise session logged on its own. It counts for the streak on
  /// exactly the same terms as a full session.
  final bool isQuickLog;
}

/// One exercise inside a session, with the sets actually performed.
class HistoryExercise {
  const HistoryExercise({
    required this.name,
    required this.primaryGroupIds,
    required this.setScores,
    this.note,
  });

  final String name;

  /// Parent muscle group ids this exercise trains. **Primary only** — `docs/01`
  /// defines the `trained` tick that way, and a glyph filled by secondary
  /// muscles would claim a session worked something it brushed.
  final List<String> primaryGroupIds;

  /// Each set reduced to the one number a personal best is decided on — weight
  /// for a weighted lift, reps for bodyweight, seconds for a timed hold.
  ///
  /// Collapsing the four load types to one comparable number here is what lets
  /// the projection stay load-type agnostic. The real implementation will need
  /// the inversion for assisted lifts, where **less assistance is better**;
  /// this fixture contains no assisted exercise, and that is a gap the real
  /// version must close rather than inherit.
  final List<double> setScores;

  /// The user's note for this exercise in this workout, which All workouts
  /// searches along with the title and the exercise names.
  final String? note;
}

/// The derived figures one session carries, computed rather than stored.
class HistoryRowFigures {
  const HistoryRowFigures({
    required this.setCount,
    required this.exerciseCount,
    required this.pbCount,
    required this.trainedGroupIds,
  });

  final int setCount;
  final int exerciseCount;

  /// How many exercises in this session beat the user's previous best for that
  /// exercise. Rendered only when at least one — never "0 personal bests".
  final int pbCount;

  /// Parent groups this session trained, in taxonomy order.
  final List<String> trainedGroupIds;
}

/// Every session's figures, from **one chronological pass**.
///
/// **This is the shape the spec requires, not an optimisation.**
/// `docs/00-build-spec.md` says to compute personal bests "in one chronological
/// pass with a running per-exercise best. Not O(n^2)." A row that asked "is
/// this a PB?" for itself would re-walk all earlier sessions per exercise, and
/// with a PB pill on every row that is the quadratic the spec forbids — which
/// is why this variant of the History tab is impossible without a projection
/// and why the projection comes first.
///
/// Nothing here is stored. Editing or deleting a session and rebuilding gives a
/// different, correct answer for free.
Map<String, HistoryRowFigures> buildHistoryProjection(
  List<HistorySession> sessions,
) {
  final ascending = <HistorySession>[...sessions]
    ..sort((a, b) => a.performedOn.compareTo(b.performedOn));

  final runningBest = <String, double>{};
  final figures = <String, HistoryRowFigures>{};

  for (final session in ascending) {
    var pbCount = 0;
    var setCount = 0;
    final trained = <String>{};

    for (final exercise in session.exercises) {
      setCount += exercise.setScores.length;
      trained.addAll(exercise.primaryGroupIds);

      final best = exercise.setScores.fold<double>(0, (a, b) => a > b ? a : b);
      final previous = runningBest[exercise.name];

      // A personal best needs a prior session of that exercise: the first time
      // you ever do something is trivially your maximum, and badging it would
      // make every beginner's first weeks a wall of trophies (`docs/01`).
      if (previous != null && best > previous) pbCount++;
      if (previous == null || best > previous) runningBest[exercise.name] = best;
    }

    figures[session.id] = HistoryRowFigures(
      setCount: setCount,
      exerciseCount: session.exercises.length,
      pbCount: pbCount,
      trainedGroupIds: <String>[
        for (final id in kMuscleTaxonomy.keys)
          if (trained.contains(id)) id,
      ],
    );
  }

  return figures;
}

/// The session's name, or the first thing down the chain that is not empty.
///
/// `docs/00-build-spec.md`'s fallback chain: the title the user gave it, else
/// the single exercise's name for a quick log, else the muscle groups trained.
/// **A row is never blank.**
String resolvedTitle(HistorySession session, HistoryRowFigures figures) =>
    titleFromParts(
      title: session.title,
      templateName: session.templateName,
      singleExerciseName:
          session.exercises.length == 1 ? session.exercises.single.name : null,
      trainedGroupIds: figures.trainedGroupIds,
    );

/// The sessions the History tab renders: the user's real saved workouts.
///
/// **Overridable, and that is the whole point of it being a provider.** A test
/// hands it a list rather than seeding a database.
final historySessionsProvider = Provider<List<HistorySession>>((ref) {
  final saved = ref.watch(savedSessionsProvider);
  final index = ref.watch(exerciseIndexProvider);
  // A saved workout with no completed set is not a trained day: the streak
  // already ignores it, so History must not list it or dot the calendar for
  // it either (audit B6). Editing now offers to delete such a workout; this
  // is the defensive half for one that exists anyway.
  return <HistorySession>[
    for (final session in saved)
      if (setCountOf(session) > 0) historySessionFrom(session, index),
  ];
});

/// One saved workout, reduced to what a history row needs.
HistorySession historySessionFrom(WorkoutSession session, ExerciseIndex index) {
  final exercises = <HistoryExercise>[];
  for (final exercise in session.exercises) {
    final library = index.byId(exercise.exerciseId);
    final completed = exercise.completedSets.toList();
    if (completed.isEmpty) continue;
    exercises.add(
      HistoryExercise(
        name: library?.name ?? 'Unknown exercise',
        // Parent groups only: the tick is defined on primary muscles, and a
        // glyph filled by secondaries would claim a session worked something
        // it brushed.
        primaryGroupIds: <String>[
          for (final subGroupId in library?.primary ?? const <String>[])
            if (kSubMuscleGroups[subGroupId] != null)
              kSubMuscleGroups[subGroupId]!.group,
        ],
        setScores: <double>[
          for (final set in completed)
            metricFor(exercise.loadType, set).primary,
        ],
        note: exercise.note,
      ),
    );
  }

  return HistorySession(
    id: session.id,
    performedOn: session.performedOn.toDateTime(),
    exercises: exercises,
    title: session.title,
    templateName: session.templateName,
    // A quick log is one exercise logged on its own. One finished exercise
    // of a template is a short template workout, not a quick log (B7).
    isQuickLog: exercises.length == 1 &&
        (session.templateName ?? '').trim().isEmpty,
  );
}

/// Every saved workout's records, projected once and cached (audit B5).
///
/// The History rows, the detail log, the editor, the share card and exercise
/// history all read this, so the PB count and the marked set can never
/// disagree, and editing a past workout reprojects once rather than once per
/// row.
final sessionRecordsProvider = Provider<Map<String, SessionRecords>>(
  (ref) => personalBestProjection(ref.watch(savedSessionsProvider)),
);

/// The records of one saved workout, or none.
SessionRecords recordsOf(Ref ref, String sessionId) =>
    ref.watch(sessionRecordsProvider)[sessionId] ?? SessionRecords.none;

/// The projection over the saved workouts, with the personal-best count taken
/// from the one derivation the summary card also uses.
final historyProjectionProvider = Provider<Map<String, HistoryRowFigures>>(
  (ref) {
    final rows = buildHistoryProjection(ref.watch(historySessionsProvider));
    final saved = ref.watch(savedSessionsProvider);
    if (saved.isEmpty) return rows;
    final records = ref.watch(sessionRecordsProvider);

    return <String, HistoryRowFigures>{
      for (final session in saved)
        if (rows[session.id] case final row?)
          session.id: HistoryRowFigures(
            setCount: setCountOf(session),
            exerciseCount: exerciseCountOf(session),
            pbCount: records[session.id]?.count ?? 0,
            trainedGroupIds: row.trainedGroupIds,
          ),
    };
  },
);

/// Sessions newest first, which is the order the tab lists them in.
///
/// Ordered by [HistorySession.performedOn] — the day it happened, not the day
/// it was typed in — so a backdated session slots into its real place rather
/// than jumping to the top.
final historySessionsNewestFirstProvider = Provider<List<HistorySession>>(
  (ref) {
    // Sorted with the incoming position as the tiebreak, because Dart's
    // `List.sort` is only stable up to 32 elements. Saved sessions arrive
    // newest first by performedOn and then loggedAt (docs/00 §11); without
    // the tiebreak, two workouts on one day swapped order once the history
    // grew past 32 rows.
    final sessions = ref.watch(historySessionsProvider);
    final order = <int>[for (var i = 0; i < sessions.length; i++) i]
      ..sort((a, b) {
        final byDate =
            sessions[b].performedOn.compareTo(sessions[a].performedOn);
        return byDate != 0 ? byDate : a.compareTo(b);
      });
    return <HistorySession>[for (final i in order) sessions[i]];
  },
);

/// "September 2026" for the date a session happened on.
///
/// The History tab's month-grouped list and the calendar card both need this,
/// so it lives here rather than being a private array in either widget -- two
/// copies of the month-name table is exactly the drift `exerciseCountLabel`
/// (`divider_row.dart`) was written to avoid for pluralisation.
String monthYearLabel(DateTime date) {
  const months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

/// Every session, keyed by the local calendar day it happened on.
///
/// **The calendar card's only read of session data.** A day can hold more than
/// one entry -- a full workout and a later quick log both filed under
/// [HistorySession.performedOn] with no time component -- so the value is a
/// list, never a single session. The key always carries a zero time, matching
/// [HistorySession.performedOn] itself, so a lookup only ever has to build the
/// same kind of key back with `DateTime(year, month, day)`.
Map<DateTime, List<HistorySession>> groupSessionsByDay(
  List<HistorySession> sessions,
) {
  final byDay = <DateTime, List<HistorySession>>{};
  for (final session in sessions) {
    final day = DateTime(
      session.performedOn.year,
      session.performedOn.month,
      session.performedOn.day,
    );
    (byDay[day] ??= <HistorySession>[]).add(session);
  }
  return byDay;
}

DateTime _day(int daysAgo) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo);
}

/// A hand-written history, kept **only as a test fixture**.
///
/// **Nothing in the app serves this any more.** [historySessionsProvider] reads
/// the user's real saved workouts; this list exists so the History tab's own
/// tests can render a known shape without seeding a database. Serving it was
/// the state this file shipped in before the session tables landed, and leaving
/// it wired would have shown a user a training split they never did the moment
/// they finished their first real workout.
@visibleForTesting
final List<HistorySession> kPreviewSessions = <HistorySession>[
  HistorySession(
    id: 's1',
    performedOn: _day(0),
    title: 'Push day',
    exercises: <HistoryExercise>[
      const HistoryExercise(
        name: 'Barbell bench press',
        primaryGroupIds: <String>['chest'],
        setScores: <double>[80, 82.5, 82.5, 80],
      ),
      const HistoryExercise(
        name: 'Overhead press',
        primaryGroupIds: <String>['shoulders'],
        setScores: <double>[47.5, 47.5, 45],
      ),
      const HistoryExercise(
        name: 'Triceps pushdown',
        primaryGroupIds: <String>['triceps'],
        setScores: <double>[32.5, 32.5, 30],
      ),
    ],
  ),
  HistorySession(
    id: 's2',
    performedOn: _day(1),
    isQuickLog: true,
    exercises: <HistoryExercise>[
      const HistoryExercise(
        name: 'Barbell curl',
        primaryGroupIds: <String>['biceps'],
        setScores: <double>[30, 30, 27.5],
      ),
    ],
  ),
  HistorySession(
    id: 's3',
    performedOn: _day(3),
    title: 'Leg day',
    exercises: <HistoryExercise>[
      const HistoryExercise(
        name: 'Back squat',
        primaryGroupIds: <String>['quads', 'glutes'],
        setScores: <double>[110, 112.5, 110, 105],
      ),
      const HistoryExercise(
        name: 'Romanian deadlift',
        primaryGroupIds: <String>['hamstrings', 'glutes'],
        setScores: <double>[90, 90, 87.5],
      ),
      const HistoryExercise(
        name: 'Standing calf raise',
        primaryGroupIds: <String>['calves'],
        setScores: <double>[60, 60, 60, 55],
      ),
    ],
  ),
  HistorySession(
    id: 's4',
    performedOn: _day(5),
    title: 'Pull day',
    exercises: <HistoryExercise>[
      const HistoryExercise(
        name: 'Barbell row',
        primaryGroupIds: <String>['back'],
        setScores: <double>[75, 75, 72.5],
      ),
      const HistoryExercise(
        name: 'Lat pulldown',
        primaryGroupIds: <String>['back'],
        setScores: <double>[65, 65, 62.5],
      ),
      const HistoryExercise(
        name: 'Barbell curl',
        primaryGroupIds: <String>['biceps'],
        setScores: <double>[27.5, 27.5, 25],
      ),
    ],
  ),
  HistorySession(
    id: 's5',
    performedOn: _day(7),
    title: 'Push day',
    exercises: <HistoryExercise>[
      const HistoryExercise(
        name: 'Barbell bench press',
        primaryGroupIds: <String>['chest'],
        setScores: <double>[80, 80, 77.5],
      ),
      const HistoryExercise(
        name: 'Overhead press',
        primaryGroupIds: <String>['shoulders'],
        setScores: <double>[45, 45, 45],
      ),
    ],
  ),
  HistorySession(
    id: 's6',
    performedOn: _day(9),
    title: 'Leg day',
    exercises: <HistoryExercise>[
      const HistoryExercise(
        name: 'Back squat',
        primaryGroupIds: <String>['quads', 'glutes'],
        setScores: <double>[105, 107.5, 105],
      ),
      const HistoryExercise(
        name: 'Romanian deadlift',
        primaryGroupIds: <String>['hamstrings', 'glutes'],
        setScores: <double>[87.5, 87.5, 85],
      ),
    ],
  ),
  HistorySession(
    id: 's7',
    performedOn: _day(11),
    isQuickLog: true,
    exercises: <HistoryExercise>[
      const HistoryExercise(
        name: 'Plank',
        primaryGroupIds: <String>['abs'],
        setScores: <double>[75, 70, 60],
      ),
    ],
  ),
  HistorySession(
    id: 's8',
    performedOn: _day(13),
    title: 'Pull day',
    exercises: <HistoryExercise>[
      const HistoryExercise(
        name: 'Barbell row',
        primaryGroupIds: <String>['back'],
        setScores: <double>[72.5, 72.5, 70],
      ),
      const HistoryExercise(
        name: 'Face pull',
        primaryGroupIds: <String>['shoulders'],
        setScores: <double>[25, 25, 22.5],
      ),
    ],
  ),
  // The long gap: a fortnight off, which is what the back catalogue should
  // look like rather than an unbroken cadence.
  HistorySession(
    id: 's9',
    performedOn: _day(29),
    title: 'Full body day',
    exercises: <HistoryExercise>[
      const HistoryExercise(
        name: 'Back squat',
        primaryGroupIds: <String>['quads', 'glutes'],
        setScores: <double>[100, 100, 97.5],
      ),
      const HistoryExercise(
        name: 'Barbell bench press',
        primaryGroupIds: <String>['chest'],
        setScores: <double>[77.5, 77.5, 75],
      ),
      const HistoryExercise(
        name: 'Barbell row',
        primaryGroupIds: <String>['back'],
        setScores: <double>[70, 70, 67.5],
      ),
    ],
  ),
  HistorySession(
    id: 's10',
    performedOn: _day(32),
    exercises: <HistoryExercise>[
      const HistoryExercise(
        name: 'Lat pulldown',
        primaryGroupIds: <String>['back'],
        setScores: <double>[62.5, 62.5, 60],
      ),
      const HistoryExercise(
        name: 'Barbell curl',
        primaryGroupIds: <String>['biceps'],
        setScores: <double>[25, 25, 25],
      ),
    ],
  ),
];
