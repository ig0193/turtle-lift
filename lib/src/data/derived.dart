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

/// How long a session took, or null while it is still running.
///
/// Derived from the two stored timestamps rather than stored itself, so
/// correcting either end corrects this with no second place to update. A
/// session logged before `adr/0004` has neither timestamp and returns null —
/// the UI shows nothing rather than a zero that would read as "took no time".
///
/// **For a running session, use [elapsedOf] instead.** This one deliberately
/// returns null until Finish, so a length that is still growing can never be
/// mistaken for a final one.
Duration? durationOf(WorkoutSession session) {
  final start = session.startedAt;
  final end = session.endedAt;
  if (start == null || end == null) return null;
  final length = end.difference(start);
  return length.isNegative ? Duration.zero : length;
}

/// How long a running session has been going, measured against [now].
///
/// [now] is a parameter rather than a call to `DateTime.now()` inside, because
/// a function that reads the clock cannot be tested and a ticking widget needs
/// to pass the same instant it is painting.
Duration? elapsedOf(WorkoutSession session, DateTime now) {
  final start = session.startedAt;
  if (start == null) return null;
  if (session.endedAt != null) return durationOf(session);
  final length = now.difference(start);
  return length.isNegative ? Duration.zero : length;
}

/// Total external weight moved in a session, in kg — Σ (weight × reps) over
/// completed sets.
///
/// **A partial figure by construction, and it must stay one.** Only two of the
/// four load types move a weight this can count: `weighted` by its own weight,
/// and `bodyweight` by whatever was *added* on top. Assisted work has weight
/// *removed* — counting it, in either direction, would be arithmetic about a
/// number that means the opposite of load. Timed work has no reps to multiply.
/// So a session of dips, planks and assisted pull-ups is honestly 0 kg here.
///
/// That partiality is the whole reason `00` §3 banned this figure in the first
/// place. It came back for the Log Workout summary bar (`adr/0004`) on one
/// condition: it is never the headline stat, and it never appears on the
/// summary card. Set count remains the volume proxy that covers every load
/// type. If you ever find yourself inventing a weight for a bodyweight rep to
/// make this number look complete, that is this rule catching you.
double volumeOf(WorkoutSession session) {
  var total = 0.0;
  for (final exercise in session.exercises) {
    for (final set in exercise.sets) {
      if (!isSetComplete(exercise.loadType, set)) continue;
      final reps = set.reps;
      if (reps == null) continue;
      final load = switch (exercise.loadType) {
        LoadType.weighted => set.weightKg,
        LoadType.bodyweight => set.addedKg,
        LoadType.assisted || LoadType.timed || null => null,
      };
      if (load != null) total += load * reps;
    }
  }
  return total;
}

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

/// The day [templateId] was last performed, or null when it never has been.
///
/// **Recall, not recommendation.** This says what the user did; it never says
/// what to do next. `docs/02` is emphatic that nothing on the Workout tab may
/// state or imply a schedule, and this figure is deliberately incapable of it:
/// it is per-template, it does not rank, it does not reorder the list, and
/// nothing reads it to decide what to show. It is the same kind of value as
/// [timesPerformed] — a fact about history, attached to the thing it is a fact
/// about, so the user recognises a template instead of recalling it.
///
/// **Sessions with no completed set do not count**, matching [timesPerformed]
/// and the streak: an opened-and-abandoned template was not performed. That
/// can only happen to a session saved by the auto-save rule before the
/// zero-set guard, or to one whose sets were later edited away, but the row
/// must not claim a workout the rest of the app does not count.
///
/// **Compared on [WorkoutSession.performedOn], never on `loggedAt`.** A
/// backdated session is a workout done on the day the user says it was, so a
/// Monday session entered on Wednesday reads "Monday" here too.
LocalDate? lastPerformed(String templateId, List<WorkoutSession> savedSessions) {
  LocalDate? latest;
  for (final session in savedSessions) {
    if (session.templateId != templateId) continue;
    if (session.completedSets.isEmpty) continue;
    if (latest == null || session.performedOn.isAfter(latest)) {
      latest = session.performedOn;
    }
  }
  return latest;
}

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
