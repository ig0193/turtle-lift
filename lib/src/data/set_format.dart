import 'load_type.dart';
import 'session_store.dart';

/// Renders one logged set, in the format its load type fixes.
///
/// **One formatter, used by every screen that shows a set** — the logging row,
/// the recent-history line, the exercise-list subtitle, the summary log, the
/// history screen and Session Detail. Six screens each writing their own is how
/// the assisted inversion ends up displayed backwards on one of them.
///
/// The formats are `docs/01` §Display formatting, verbatim:
///
/// | type | condition | example |
/// |---|---|---|
/// | `weighted` | always | `22kg × 10` |
/// | `bodyweight` | no added weight | `12 reps` |
/// | `bodyweight` | added weight | `+10kg × 8` |
/// | `assisted` | always | `20kg assist × 8` |
/// | `timed` | no weight | `0:45` |
/// | `timed` | weight | `24kg × 0:45` |
String formatSet(LoadType? type, SetEntry set) {
  switch (type) {
    case LoadType.weighted:
      return '${formatWeight(set.weightKg)}kg × ${set.reps ?? 0}';
    case LoadType.bodyweight:
      final added = set.addedKg;
      if (added == null || added == 0) return '${set.reps ?? 0} reps';
      return '+${formatWeight(added)}kg × ${set.reps ?? 0}';
    case LoadType.assisted:
      return '${formatWeight(set.assistKg)}kg assist × ${set.reps ?? 0}';
    case LoadType.timed:
      final duration = formatDuration(set.durationSec ?? 0);
      final weight = set.weightKg;
      if (weight == null || weight == 0) return duration;
      return '${formatWeight(weight)}kg × $duration';
    case null:
      // A stored load type this build does not recognise: show the numbers that
      // are actually on the row rather than inventing a shape for them.
      return _unknownShape(set);
  }
}

/// Seconds as `m:ss`, which is how a duration reads above a minute and stays
/// readable below one. `docs/01` fixes the display; the input stays whole
/// seconds.
String formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remainder';
}

/// A weight, with the trailing `.0` dropped so 60 reads as `60` and 57.5 as
/// `57.5`. One decimal place, which is what gym plates need.
String formatWeight(double? kg) {
  final value = kg ?? 0;
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

String _unknownShape(SetEntry set) {
  final parts = <String>[
    if (set.weightKg != null) '${formatWeight(set.weightKg)}kg',
    if (set.assistKg != null) '${formatWeight(set.assistKg)}kg assist',
    if (set.addedKg != null) '+${formatWeight(set.addedKg)}kg',
    if (set.durationSec != null) formatDuration(set.durationSec!),
    if (set.reps != null) '${set.reps}',
  ];
  return parts.isEmpty ? '—' : parts.join(' × ');
}

/// Whether a set counts.
///
/// **The one definition the streak, the set count and the calorie tier all
/// read.** A set is complete when the user ticked it *and* its required field is
/// above zero; tapping the tick on an empty required field focuses that field
/// instead. Optional fields never gate completion.
bool isSetComplete(LoadType? type, SetEntry set) {
  if (!set.completed) return false;
  return hasRequiredValue(type, set);
}

/// Whether the required field for [type] is above zero, ignoring the tick.
bool hasRequiredValue(LoadType? type, SetEntry set) {
  switch (type) {
    case LoadType.weighted:
    case LoadType.bodyweight:
    case LoadType.assisted:
      return (set.reps ?? 0) > 0;
    case LoadType.timed:
      return (set.durationSec ?? 0) > 0;
    case null:
      return false;
  }
}

/// Every set of a session's exercise, joined as one line — `60kg × 10 · 60kg ×
/// 8 · 55kg × 10`.
///
/// Showing sets individually rather than a single summary is deliberate: the
/// drop-off across a session is the thing a "last: 60kg × 8" line hides.
String formatSetList(SessionExercise exercise) => exercise.sets
    .where((s) => s.completed)
    .map((s) => formatSet(exercise.loadType, s))
    .join(' · ');
