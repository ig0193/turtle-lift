import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_session.dart';
import 'exercise_index.dart';
import 'local_date.dart';
import 'session_store.dart';
import 'set_format.dart';
import 'training_plan.dart' show planTodayProvider, startOfWeek;

/// What the log says about one sub-muscle group, for the Muscles map
/// (`docs/adr/0012-muscles-tab-shows-your-training.md`).
///
/// **Facts, not a model.** Completed sets this calendar week and the last day
/// the muscle was trained directly. No recovery percentage, no readiness: those
/// are modelled values the user cannot check against their own log.
///
/// **Never stored.** Computed on read from saved sessions and the open one, so
/// editing or deleting a workout moves the map with nothing to refresh.
@immutable
class MuscleTraining {
  const MuscleTraining({
    this.primarySets = 0,
    this.secondarySets = 0,
    this.lastTrained,
  });

  /// Completed sets this week of exercises that train the muscle directly.
  final int primarySets;

  /// Completed sets this week of exercises that only work it as a secondary
  /// muscle. A set never counts as both.
  final int secondarySets;

  /// The latest day, up to today, with a completed set of an exercise that
  /// trains this muscle directly. Null when never.
  final LocalDate? lastTrained;

  static const MuscleTraining none = MuscleTraining();

  bool get trainedThisWeek => primarySets > 0;
  bool get workedThisWeek => primarySets > 0 || secondarySets > 0;

  @override
  bool operator ==(Object other) =>
      other is MuscleTraining &&
      other.primarySets == primarySets &&
      other.secondarySets == secondarySets &&
      other.lastTrained == lastTrained;

  @override
  int get hashCode => Object.hash(primarySets, secondarySets, lastTrained);

  @override
  String toString() =>
      'MuscleTraining($primarySets primary, $secondarySets secondary, '
      'last $lastTrained)';
}

/// Per sub-group training for the week starting Monday of [today]'s week —
/// the same Monday-to-Sunday week the Workout tab's week strip shows.
///
/// [sessions] may include the open workout: a set completed a minute ago has
/// trained the muscle (`CLAUDE.md`: a muscle fills on a completed set). A
/// session appearing twice (open and saved) is counted once, by id.
Map<String, MuscleTraining> muscleTrainingFor(
  Iterable<WorkoutSession> sessions,
  ExerciseIndex index, {
  required LocalDate today,
}) {
  final monday = startOfWeek(today);
  final sunday = monday.addDays(6);
  final primary = <String, int>{};
  final secondary = <String, int>{};
  final last = <String, LocalDate>{};
  final seen = <String>{};

  for (final session in sessions) {
    if (!seen.add(session.id)) continue;
    final day = session.performedOn;
    final inWeek = day >= monday && day <= sunday;
    for (final logged in session.exercises) {
      final exercise = index.byId(logged.exerciseId);
      if (exercise == null) continue;
      final sets =
          logged.sets.where((s) => isSetComplete(logged.loadType, s)).length;
      if (sets == 0) continue;
      for (final id in exercise.primary) {
        if (inWeek) primary[id] = (primary[id] ?? 0) + sets;
        if (day <= today) {
          final previous = last[id];
          if (previous == null || day > previous) last[id] = day;
        }
      }
      if (inWeek) {
        for (final id in exercise.secondary) {
          if (exercise.primary.contains(id)) continue;
          secondary[id] = (secondary[id] ?? 0) + sets;
        }
      }
    }
  }

  return <String, MuscleTraining>{
    for (final id in <String>{...primary.keys, ...secondary.keys, ...last.keys})
      id: MuscleTraining(
        primarySets: primary[id] ?? 0,
        secondarySets: secondary[id] ?? 0,
        lastTrained: last[id],
      ),
  };
}

/// [muscleTrainingFor] over the whole log, live. Invalidates itself when a
/// workout is finished, edited or deleted, or a set is completed.
final muscleTrainingProvider = Provider<Map<String, MuscleTraining>>((ref) {
  final open = ref.watch(activeSessionProvider);
  return muscleTrainingFor(
    <WorkoutSession>[
      ?open,
      ...ref.watch(savedSessionsProvider),
    ],
    ref.watch(exerciseIndexProvider),
    today: ref.watch(planTodayProvider),
  );
});

/// The one line said about a muscle's training: on its exercise list, in the
/// shoulder sheet and to a screen reader.
///
/// "6 sets this week · Last trained today", "No sets this week · Last trained
/// 9 days ago", "2 secondary sets this week", or "Not trained yet".
String muscleTrainingLine(MuscleTraining training, LocalDate today) {
  final parts = <String>[];
  if (training.primarySets > 0) {
    parts.add('${_sets(training.primarySets)} this week');
    if (training.secondarySets > 0) {
      parts.add('${training.secondarySets} as secondary');
    }
  } else if (training.secondarySets > 0) {
    parts.add('${training.secondarySets} secondary '
        '${training.secondarySets == 1 ? 'set' : 'sets'} this week');
  } else if (training.lastTrained != null) {
    parts.add('No sets this week');
  }
  final last = training.lastTrained;
  if (last != null) parts.add('Last trained ${relativeDay(last, today)}');
  return parts.isEmpty ? 'Not trained yet' : parts.join(' · ');
}

String _sets(int n) => n == 1 ? '1 set' : '$n sets';

/// "today", "yesterday", "3 days ago". Past dates only; a date after today
/// reads as "today" rather than as a promise.
String relativeDay(LocalDate day, LocalDate today) {
  final days = today.daysAfter(day);
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  return '$days days ago';
}
