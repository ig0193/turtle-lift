import 'package:flutter/foundation.dart' show immutable;

import 'load_type.dart';
import 'local_date.dart';
import 'session_store.dart';

/// A set's progression, as a comparable pair.
///
/// Compared lexicographically: the primary component decides, and the secondary
/// only breaks a tie. `docs/01` §Personal best per type fixes the pair for each
/// load type, and [metricFor] is the one place it is written down.
@immutable
class SetMetric implements Comparable<SetMetric> {
  const SetMetric(this.primary, this.secondary);

  final double primary;
  final double secondary;

  @override
  int compareTo(SetMetric other) {
    final byPrimary = primary.compareTo(other.primary);
    if (byPrimary != 0) return byPrimary;
    return secondary.compareTo(other.secondary);
  }

  @override
  bool operator ==(Object other) =>
      other is SetMetric &&
      other.primary == primary &&
      other.secondary == secondary;

  @override
  int get hashCode => Object.hash(primary, secondary);

  @override
  String toString() => 'SetMetric($primary, $secondary)';
}

/// The progression metric for one set of an exercise of [type].
///
/// | type | metric |
/// |---|---|
/// | `weighted` | `(weightKg, reps)` |
/// | `bodyweight` | `(addedKg, reps)` — degenerates to max reps when nobody adds weight |
/// | `assisted` | `(-assistKg, reps)` |
/// | `timed` | `(weightKg, durationSec)` |
///
/// **The assisted pair is negated, and that is the whole point.** Less
/// assistance is better, so it is the one place in the app where a smaller
/// number is the record. Negating here means every comparison everywhere else
/// stays "bigger wins", so no call site has to remember the exception — which
/// is exactly how it would otherwise ship backwards on one screen out of four.
SetMetric metricFor(LoadType? type, SetEntry set) {
  switch (type) {
    case LoadType.weighted:
      return SetMetric(set.weightKg ?? 0, (set.reps ?? 0).toDouble());
    case LoadType.bodyweight:
      return SetMetric(set.addedKg ?? 0, (set.reps ?? 0).toDouble());
    case LoadType.assisted:
      return SetMetric(-(set.assistKg ?? 0), (set.reps ?? 0).toDouble());
    case LoadType.timed:
      return SetMetric(set.weightKg ?? 0, (set.durationSec ?? 0).toDouble());
    case null:
      // A stored load type this build does not recognise. The sets still render
      // through their stored numbers; they just cannot claim a record.
      return const SetMetric(0, 0);
  }
}

/// The best completed set of [exercise], or null when it has none.
SetMetric? bestOf(SessionExercise exercise) {
  SetMetric? best;
  for (final set in exercise.completedSets) {
    final metric = metricFor(exercise.loadType, set);
    if (best == null || metric.compareTo(best) > 0) best = metric;
  }
  return best;
}

/// How many exercises in [session] beat the user's previous best for them.
///
/// A record requires at least one **earlier** session of that exercise and must
/// be **strictly** greater than the best across every session with an earlier
/// `performedOn` (`docs/01` §Progress tracking). Two sessions on the same day
/// therefore share a baseline and can both earn one — the running best advances
/// at a date boundary, not per session, which is what keeps this a faster form
/// of the same rule rather than a second, disagreeing one.
///
/// Counted per exercise, not per set: three progressively heavier sets that all
/// beat the old record are one record, not three.
int pbCountFor(WorkoutSession session, List<WorkoutSession> savedSessions) {
  final earlier = <String, SetMetric>{};
  var sawExerciseBefore = <String>{};

  // One chronological pass, not a full-history scan per session.
  final ordered = <WorkoutSession>[...savedSessions]
    ..sort((a, b) => a.performedOn.compareTo(b.performedOn));

  for (final candidate in ordered) {
    if (!candidate.performedOn.isBefore(session.performedOn)) break;
    for (final exercise in candidate.exercises) {
      final best = bestOf(exercise);
      if (best == null) continue;
      sawExerciseBefore = <String>{...sawExerciseBefore, exercise.exerciseId};
      final current = earlier[exercise.exerciseId];
      if (current == null || best.compareTo(current) > 0) {
        earlier[exercise.exerciseId] = best;
      }
    }
  }

  var records = 0;
  for (final exercise in session.exercises) {
    // No prior session of this exercise means no record: the first time is
    // trivially a maximum, and badging it is the wrong motivational curve.
    if (!sawExerciseBefore.contains(exercise.exerciseId)) continue;
    final best = bestOf(exercise);
    if (best == null) continue;
    final previous = earlier[exercise.exerciseId];
    if (previous != null && best.compareTo(previous) > 0) records++;
  }
  return records;
}

/// Whether [exercise] set a record in [session]. Drives the badge beside an
/// exercise in the log, using the same derivation as the count above so the
/// two can never disagree.
bool isPersonalBest(
  SessionExercise exercise,
  WorkoutSession session,
  List<WorkoutSession> savedSessions,
) {
  final best = bestOf(exercise);
  if (best == null) return false;

  SetMetric? previous;
  var seen = false;
  for (final candidate in savedSessions) {
    if (!candidate.performedOn.isBefore(session.performedOn)) continue;
    for (final other in candidate.exercises) {
      if (other.exerciseId != exercise.exerciseId) continue;
      final otherBest = bestOf(other);
      if (otherBest == null) continue;
      seen = true;
      if (previous == null || otherBest.compareTo(previous) > 0) {
        previous = otherBest;
      }
    }
  }

  if (!seen || previous == null) return false;
  return best.compareTo(previous) > 0;
}

/// Which set of [exercise] is a record right now, as an index into its
/// `sets`, or null.
///
/// **The live form of [isPersonalBest]**, for the PB mark on a set row the
/// moment it is ticked: the same baseline (the best across every saved session
/// with an earlier `performedOn` than [performedOn]), the same "needs a prior
/// session" rule, the same strictly-greater test, and the same per-exercise
/// count -- so only the exercise's single best completed set carries the mark,
/// the first one if two tie. The assisted inversion comes from [metricFor], so
/// lighter assistance is the record here exactly as everywhere else.
///
/// Derived on every build, never stored: untick the set, or edit it below the
/// record, and the mark is simply gone.
int? personalBestSetIndex(
  SessionExercise exercise,
  LocalDate performedOn,
  List<WorkoutSession> savedSessions,
) {
  SetMetric? previous;
  for (final candidate in savedSessions) {
    if (!candidate.performedOn.isBefore(performedOn)) continue;
    for (final other in candidate.exercises) {
      if (other.exerciseId != exercise.exerciseId) continue;
      final otherBest = bestOf(other);
      if (otherBest == null) continue;
      if (previous == null || otherBest.compareTo(previous) > 0) {
        previous = otherBest;
      }
    }
  }
  if (previous == null) return null;

  int? bestIndex;
  SetMetric? best;
  for (var i = 0; i < exercise.sets.length; i++) {
    final set = exercise.sets[i];
    if (!set.completed) continue;
    final metric = metricFor(exercise.loadType, set);
    if (best == null || metric.compareTo(best) > 0) {
      best = metric;
      bestIndex = i;
    }
  }
  if (best == null || best.compareTo(previous) <= 0) return null;
  return bestIndex;
}

