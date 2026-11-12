import 'bodyweight_resolution.dart';
import 'exercise_index.dart';
import 'generated/muscle_taxonomy.dart';
import 'load_type.dart';
import 'local_date.dart';
import 'personal_details_store.dart' show BodyweightEntry;
import 'session_store.dart';
import 'set_format.dart';

/// Every figure the app displays, computed on read from the logged sets.
///
/// **Nothing here is stored, and that is the cardinal rule of the app.**
/// Sessions are editable and deletable, so any denormalised aggregate goes stale
/// the moment a weight is corrected, a set removed, a date changed or a workout
/// deleted. Deriving on read makes all of those correct by construction.
///
/// **Two families, split by what they aggregate.** History aggregates — the
/// streak, records, the calorie estimate, prefill and times-performed — read
/// *saved* sessions only, so a workout in progress never moves a figure that
/// describes the past. Within-session rules — set completion, the trained tick,
/// per-exercise display state and a session's own counts — are pure functions
/// over one session's rows and run identically against an open session and a
/// saved one. The live map and ticks depend on that second family.

/// How many completed sets a session holds. The headline stat, and the input to
/// the calorie tier.
int setCountOf(WorkoutSession session) => session.exercises
    .expand((e) => e.sets.where((s) => isSetComplete(e.loadType, s)))
    .length;

/// How many exercises a session actually logged work for.
int exerciseCountOf(WorkoutSession session) => session.exercises
    .where((e) => e.sets.any((s) => isSetComplete(e.loadType, s)))
    .length;

/// What a session exercise looks like to the ad-hoc list.
enum ExerciseProgress {
  notStarted,
  inProgress,
  done;

  /// The label `docs/02` uses on the ad-hoc overview.
  String get label => switch (this) {
        ExerciseProgress.notStarted => 'To do',
        ExerciseProgress.inProgress => 'In progress',
        ExerciseProgress.done => 'Done',
      };
}

/// The tri-state an exercise renders, derived rather than stored.
///
/// Storing it would go stale the moment the user deletes every set from an
/// in-progress exercise, which is the drift `docs/01` §Derived values exists to
/// prevent.
ExerciseProgress progressOf(SessionExercise exercise) {
  if (exercise.markedDone) return ExerciseProgress.done;
  final hasCompleted =
      exercise.sets.any((s) => isSetComplete(exercise.loadType, s));
  if (hasCompleted) return ExerciseProgress.inProgress;
  return ExerciseProgress.notStarted;
}

/// Whether an exercise counts as trained for the tick and the map.
///
/// **A completed set is enough, and so is Mark exercise done.** A user who logs
/// three sets and walks to the next machine has trained that muscle; making the
/// tick wait for a button they never tapped would leave the summary disagreeing
/// with the work they just did.
bool countsAsTrained(SessionExercise exercise) =>
    exercise.markedDone ||
    exercise.sets.any((s) => isSetComplete(exercise.loadType, s));

/// The sub-muscle groups this session has trained **directly**.
///
/// Primary muscles only. An incline press is primary upper chest and secondary
/// front delt and triceps, so it counts upper chest and nothing else — the user
/// has not done a triceps movement.
///
/// No screen lists these any more (the nested muscle list went with
/// `docs/adr/0006-workout-tab-is-exercise-first.md`); it survives because the
/// resolved-title chain and the history figures still ask which muscles a
/// session trained directly.
Set<String> trainedSubGroups(WorkoutSession session, ExerciseIndex index) {
  final trained = <String>{};
  for (final exercise in session.exercises) {
    if (!countsAsTrained(exercise)) continue;
    final library = index.byId(exercise.exerciseId);
    if (library == null) continue;
    trained.addAll(library.primary);
  }
  return trained;
}

/// The sub-muscle groups the session's exercises train directly, whether or not
/// any of them has been worked yet.
///
/// What the body map outlines. **Primary only**, like [trainedSubGroups]: an
/// outline says "this is what the workout is for", and a secondary muscle is a
/// by-product rather than a goal. Every exercise on the list counts, so a
/// template shows its whole plan from the first frame and an ad-hoc workout
/// grows one as it is built.
Set<String> plannedSubGroups(WorkoutSession session, ExerciseIndex index) {
  final planned = <String>{};
  for (final exercise in session.exercises) {
    final library = index.byId(exercise.exerciseId);
    if (library == null) continue;
    planned.addAll(library.primary);
  }
  return planned;
}

/// Every sub-muscle group the session touched, split by how hard.
///
/// Drives the body map: primaries fill in the strong accent, secondaries in the
/// light one, and everything else stays muted.
({Set<String> primary, Set<String> secondary}) workedSubGroups(
  WorkoutSession session,
  ExerciseIndex index,
) {
  final primary = <String>{};
  final secondary = <String>{};
  for (final exercise in session.exercises) {
    if (!countsAsTrained(exercise)) continue;
    final library = index.byId(exercise.exerciseId);
    if (library == null) continue;
    primary.addAll(library.primary);
    secondary.addAll(library.secondary);
  }
  // A muscle worked directly is never downgraded by also appearing as a
  // secondary somewhere else in the session.
  secondary.removeAll(primary);
  return (primary: primary, secondary: secondary);
}

/// The workout streak as of [date].
///
/// Walks back through the distinct days that carry at least one completed set,
/// chaining while each gap is **three days or fewer**. Three is deliberate:
/// Friday to Monday is exactly three, so a tighter rule would break the streak
/// of anyone training weekdays only, or on the Push/Pull/Legs split the app's
/// own headline templates encourage.
///
/// **It decays against the date it is asked about, not against stored data.**
/// If the last workout was five days ago, `streakAsOf(today)` is 0 even though
/// nothing in storage changed — which is the difference between a live streak
/// and the "app said 12, opened it a week later, still says 12" bug.
int streakAsOf(LocalDate date, List<WorkoutSession> savedSessions) =>
    streakFromDays(<LocalDate>[
      for (final session in savedSessions)
        if (setCountOf(session) > 0) session.performedOn,
    ], date);

/// The streak tolerance: at most this many days between workout days.
const int kStreakGapDays = 3;

/// Whether two workout days chain: the later is at most [kStreakGapDays]
/// after the earlier. **The one statement of the rule**, read by the streak
/// figure and by the calendar's streak runs, so the two cannot disagree.
bool streakChains(LocalDate earlier, LocalDate later) =>
    later.daysAfter(earlier) <= kStreakGapDays;

/// The streak as of [date] over a set of workout days.
///
/// The core of [streakAsOf], over plain dates, so History's stats line (which
/// reads History rows) and the summary card (which reads saved sessions)
/// count with the same code.
int streakFromDays(Iterable<LocalDate> trainedDays, LocalDate date) {
  final days = <int, LocalDate>{};
  for (final day in trainedDays) {
    if (day.isAfter(date)) continue;
    days[day.epochDay] = day;
  }
  if (days.isEmpty) return 0;

  final ordered = days.values.toList()
    ..sort((a, b) => b.compareTo(a)); // newest first

  // The chain has to reach the date being asked about, or it has already
  // lapsed and the answer is zero rather than the old number.
  if (!streakChains(ordered.first, date)) return 0;

  var streak = 1;
  for (var i = 1; i < ordered.length; i++) {
    if (!streakChains(ordered[i], ordered[i - 1])) break;
    streak++;
  }
  return streak;
}

/// Every day that is linked to the next day by a streak chain.
///
/// Between two consecutive workout days that chain ([streakChains]), every
/// day from the earlier up to the day before the later is linked to its next
/// day. The calendar draws a connector across exactly those, so the run you
/// see is the rule the streak counts by (ADR 0013).
Set<LocalDate> streakLinkedDays(Iterable<LocalDate> trainedDays) {
  final ordered = <int, LocalDate>{
    for (final d in trainedDays) d.epochDay: d,
  }.values.toList()
    ..sort();
  final linked = <LocalDate>{};
  for (var i = 1; i < ordered.length; i++) {
    final earlier = ordered[i - 1];
    final later = ordered[i];
    if (!streakChains(earlier, later)) continue;
    for (var d = earlier; d.isBefore(later); d = d.addDays(1)) {
      linked.add(d);
    }
  }
  return linked;
}

/// The name to show for a session, never empty.
///
/// The fallback chain from `docs/00` §6, in order: the user's own title, the
/// template name, the single exercise's name for a quick log, then the primary
/// muscle groups trained. **Never a time-of-day name** — with retrospective
/// logging the log time is not the workout time, so "Evening workout" would be
/// wrong on any backdated session.
String resolvedTitle(WorkoutSession session, ExerciseIndex index) {
  final logged = session.exercises.where(countsAsTrained).toList();
  final parents = <String>{};
  for (final subGroupId in trainedSubGroups(session, index)) {
    final parent = kSubMuscleGroups[subGroupId]?.group;
    if (parent != null) parents.add(parent);
  }
  return titleFromParts(
    title: session.title,
    templateName: session.templateName,
    singleExerciseName: logged.length == 1
        ? index.byId(logged.single.exerciseId)?.name
        : null,
    trainedGroupIds: parents,
  );
}

/// **The** title chain, the one place it is written (audit B7).
///
/// History rows, the detail, the editor and the share card all reach it, so a
/// cleared title can no longer read as the template name in one place and as
/// "Chest, shoulders, triceps" in another. In order: the user's own title,
/// the template name, the single logged exercise, the parent muscle groups in
/// taxonomy order, then "Workout".
String titleFromParts({
  required String? title,
  required String? templateName,
  required String? singleExerciseName,
  required Iterable<String> trainedGroupIds,
}) {
  if (title != null && title.trim().isNotEmpty) return title.trim();
  if (templateName != null && templateName.trim().isNotEmpty) {
    return templateName.trim();
  }
  if (singleExerciseName != null) return singleExerciseName;

  final trained = trainedGroupIds.toSet();
  // Taxonomy order, so two sessions naming the same groups read the same.
  final labels = <String>[
    for (final id in kMuscleTaxonomy.keys)
      if (trained.contains(id)) kMuscleGroupLabels[id] ?? id,
  ];
  if (labels.isEmpty) return 'Workout';
  return <String>[
    labels.first,
    ...labels.skip(1).map((l) => l.toLowerCase()),
  ].join(', ');
}

/// How many saved sessions the user has completed at least one set of
/// [exerciseId] in.
///
/// Drives the first-time detour: an exercise nobody has ever completed opens
/// its reference page before its logging screen, because the user cannot know a
/// lift they have never done.
int timesPerformed(String exerciseId, List<WorkoutSession> savedSessions) =>
    savedSessions
        .where((session) => session.exercises.any((e) =>
            e.exerciseId == exerciseId &&
            e.sets.any((s) => isSetComplete(e.loadType, s))))
        .length;

/// The most recent saved session that logged [exerciseId], or null.
///
/// **Ordered by the day it happened, then by when it was written.** Prefill
/// reads the most recent saved session regardless of the open session's own
/// date, so a user backdating today's entry still prefills from what they
/// actually last lifted.
WorkoutSession? lastSessionOf(
  String exerciseId,
  List<WorkoutSession> savedSessions,
) {
  WorkoutSession? latest;
  for (final session in savedSessions) {
    final hasIt = session.exercises.any((e) =>
        e.exerciseId == exerciseId &&
        e.sets.any((s) => isSetComplete(e.loadType, s)));
    if (!hasIt) continue;
    if (latest == null ||
        session.performedOn.isAfter(latest.performedOn) ||
        (session.performedOn == latest.performedOn &&
            session.loggedAt.isAfter(latest.loggedAt))) {
      latest = session;
    }
  }
  return latest;
}

/// The set to prefill row [index] of [exerciseId] from, or null.
///
/// The first set of an exercise prefills from the same set index of the user's
/// last session of it; each set added afterwards prefills from the previous set
/// in the current session, which is the caller's job rather than this one's.
SetEntry? prefillFor(
  String exerciseId,
  int index,
  List<WorkoutSession> savedSessions,
) {
  final last = lastSessionOf(exerciseId, savedSessions);
  if (last == null) return null;
  final exercise =
      last.exercises.firstWhere((e) => e.exerciseId == exerciseId);
  final completed = exercise.sets
      .where((s) => isSetComplete(exercise.loadType, s))
      .toList(growable: false);
  if (completed.isEmpty) return null;
  if (index < completed.length) return completed[index];
  return completed.last;
}

/// One set from the last time an exercise was logged, for the line inside a
/// set row: "Last 62.5kg × 6".
class LastTimeSet {
  const LastTimeSet(this.loadType, this.set);

  /// The load type it was logged under, which is how it must be read back:
  /// an assisted set stays assistance.
  final LoadType? loadType;
  final SetEntry set;

  /// The line, through the one formatter every screen uses ([formatSet]).
  String get label => 'Last ${formatSet(loadType, set)}';
}

/// Set [index] of the most recent saved session of [exerciseId], or null.
///
/// **The same index, and nothing past it.** Prefill repeats the last set for
/// extra rows because a guess has to be something; a comparison does not, and
/// "last 60kg × 8" under a fourth set nobody did last time would be invented.
///
/// [before], when given, keeps only sessions on an earlier day: correcting a
/// saved session compares it with what came before it, never with itself.
/// Derived on read like everything else here, so editing that older session
/// moves the line.
LastTimeSet? lastTimeSetAt(
  String exerciseId,
  int index,
  List<WorkoutSession> savedSessions, {
  LocalDate? before,
}) {
  final pool = before == null
      ? savedSessions
      : savedSessions.where((s) => s.performedOn.isBefore(before)).toList();
  final last = lastSessionOf(exerciseId, pool);
  if (last == null) return null;
  final exercise =
      last.exercises.firstWhere((e) => e.exerciseId == exerciseId);
  final completed = exercise.sets
      .where((s) => isSetComplete(exercise.loadType, s))
      .toList(growable: false);
  if (index >= completed.length) return null;
  return LastTimeSet(exercise.loadType, completed[index]);
}

/// "Last 62.5kg × 6": the last completed set of the last saved session that
/// logged [exerciseId], in its load type's own format, or null when never.
///
/// Used by the picker rows, the Muscles exercise lists and exercise detail,
/// so all three say the same thing about the same lift.
String? lastSetLine(String exerciseId, List<WorkoutSession> savedSessions) {
  final last = lastSessionOf(exerciseId, savedSessions);
  if (last == null) return null;
  final logged = last.exercises.firstWhere((e) => e.exerciseId == exerciseId);
  final completed = logged.sets
      .where((s) => isSetComplete(logged.loadType, s))
      .toList(growable: false);
  if (completed.isEmpty) return null;
  return 'Last ${formatSet(logged.loadType, completed.last)}';
}

/// How many saved sessions logged at least one completed set of [exerciseId].
int timesLogged(String exerciseId, List<WorkoutSession> savedSessions) =>
    savedSessions
        .where((session) => session.exercises.any((e) =>
            e.exerciseId == exerciseId &&
            e.sets.any((s) => isSetComplete(e.loadType, s))))
        .length;

/// The exercises logged most recently, newest first, each once, at most
/// [limit]: the picker's Recent group.
///
/// Retrieval beats search for a lifter who does the same ten lifts. Derived
/// from saved sessions on read, so deleting a workout drops its exercises from
/// the group with nothing to clean up.
List<String> recentExerciseIds(
  List<WorkoutSession> savedSessions, {
  int limit = 6,
}) {
  final ordered = <WorkoutSession>[...savedSessions]..sort((a, b) {
      final byDay = b.performedOn.compareTo(a.performedOn);
      return byDay != 0 ? byDay : b.loggedAt.compareTo(a.loggedAt);
    });
  final ids = <String>[];
  for (final session in ordered) {
    for (final exercise in session.exercises) {
      if (ids.length >= limit) return ids;
      if (ids.contains(exercise.exerciseId)) continue;
      if (!exercise.sets.any((s) => isSetComplete(exercise.loadType, s))) {
        continue;
      }
      ids.add(exercise.exerciseId);
    }
  }
  return ids;
}

/// How many set rows an exercise opens with: as many as its last saved session
/// held, and at least one.
int openingRowCount(String exerciseId, List<WorkoutSession> savedSessions) {
  final last = lastSessionOf(exerciseId, savedSessions);
  if (last == null) return 1;
  final exercise =
      last.exercises.firstWhere((e) => e.exerciseId == exerciseId);
  final completed =
      exercise.sets.where((s) => isSetComplete(exercise.loadType, s)).length;
  return completed == 0 ? 1 : completed;
}

/// The effort tier a session's set count puts it in.
enum EffortTier {
  light(3.5),
  moderate(5.0),
  vigorous(6.0);

  const EffortTier(this.met);

  /// The metabolic equivalent `docs/00` §8 assigns the tier.
  final double met;
}

/// The tier for [sets]: 1–9 light, 10–20 moderate, 21+ vigorous.
EffortTier effortTierFor(int sets) {
  if (sets <= 9) return EffortTier.light;
  if (sets <= 20) return EffortTier.moderate;
  return EffortTier.vigorous;
}

/// The session's estimated calories, or **null** when no bodyweight was in
/// effect on its day.
///
/// `kcal = (MET × 3.5 × bodyweightKg / 200) × minutes`, where
/// `minutes = sets × 42.5 / 60`.
///
/// **Null is a real answer and must stay one.** A session logged before the user
/// ever weighed in shows the add-weight prompt rather than a number, and adding
/// a weight later does not back-fill it — `docs/01` chose a prompt over a wrong
/// number. Resolution goes through [weightInEffectOn], which already refuses to
/// soften a null into the earliest entry.
double? caloriesFor(WorkoutSession session, List<BodyweightEntry> series) {
  final weight = weightInEffectOn(series, session.performedOn.toDateTime());
  if (weight == null) return null;

  final sets = setCountOf(session);
  if (sets == 0) return null;

  final minutes = sets * 42.5 / 60;
  final met = effortTierFor(sets).met;
  return (met * 3.5 * weight.weightKg / 200) * minutes;
}
