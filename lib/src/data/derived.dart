import 'bodyweight_resolution.dart';
import 'exercise_index.dart';
import 'generated/muscle_taxonomy.dart';
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
/// front delt and triceps, so on a Push day it ticks upper chest and nothing
/// else — the triceps row stays unticked because the user has not done a
/// triceps movement.
///
/// **The map and this list disagree on purpose.** The map answers "what got
/// worked" and fills secondaries too; this answers "what have I trained
/// directly". Both are correct, and `docs/02` is explicit that it must not be
/// "fixed".
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
int streakAsOf(LocalDate date, List<WorkoutSession> savedSessions) {
  final days = <int, LocalDate>{};
  for (final session in savedSessions) {
    if (setCountOf(session) == 0) continue;
    if (session.performedOn.isAfter(date)) continue;
    days[session.performedOn.epochDay] = session.performedOn;
  }
  if (days.isEmpty) return 0;

  final ordered = days.values.toList()
    ..sort((a, b) => b.compareTo(a)); // newest first

  // The chain has to reach the date being asked about, or it has already
  // lapsed and the answer is zero rather than the old number.
  if (date.daysAfter(ordered.first) > 3) return 0;

  var streak = 1;
  for (var i = 1; i < ordered.length; i++) {
    final gap = ordered[i - 1].daysAfter(ordered[i]);
    if (gap > 3) break;
    streak++;
  }
  return streak;
}

/// The name to show for a session, never empty.
///
/// The fallback chain from `docs/00` §6, in order: the user's own title, the
/// template name, the single exercise's name for a quick log, then the primary
/// muscle groups trained. **Never a time-of-day name** — with retrospective
/// logging the log time is not the workout time, so "Evening workout" would be
/// wrong on any backdated session.
String resolvedTitle(WorkoutSession session, ExerciseIndex index) {
  final own = session.title;
  if (own != null && own.trim().isNotEmpty) return own.trim();

  final template = session.templateName;
  if (template != null && template.trim().isNotEmpty) return template.trim();

  final logged = session.exercises.where(countsAsTrained).toList();
  if (logged.length == 1) {
    final library = index.byId(logged.single.exerciseId);
    if (library != null) return library.name;
  }

  final parents = <String>[];
  for (final subGroupId in trainedSubGroups(session, index)) {
    final parent = kSubMuscleGroups[subGroupId]?.group;
    if (parent != null && !parents.contains(parent)) parents.add(parent);
  }
  if (parents.isNotEmpty) {
    // Taxonomy order, so two sessions naming the same groups read the same.
    final ordered = kMuscleTaxonomy.keys.where(parents.contains);
    final labels = ordered
        .map((id) => kMuscleGroupLabels[id] ?? id)
        .toList(growable: false);
    return <String>[
      labels.first,
      ...labels.skip(1).map((l) => l.toLowerCase()),
    ].join(', ');
  }

  return 'Workout';
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
