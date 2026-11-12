/// One exercise's progress over time: the best set per session, and the best
/// at each rep count. **Derived on read from saved sessions, never stored**,
/// so an edit or a delete moves both with nothing to refresh (ADR 0013).
///
/// **Facts, not a model.** The series plots a set the user actually lifted;
/// there is no estimated one-rep max or decaying "strength score" (audit
/// "later" list). No kg-volume figure either (`docs/00` §3).
library;

import 'load_type.dart';
import 'local_date.dart';
import 'personal_best.dart';
import 'session_store.dart';
import 'set_format.dart';

/// One session's point on the chart.
class ProgressPoint {
  const ProgressPoint({
    required this.sessionId,
    required this.date,
    required this.value,
    required this.label,
    required this.isRecord,
  });

  final String sessionId;
  final LocalDate date;

  /// The plotted number, in [ExerciseProgressSeries.unit].
  final double value;

  /// The set as every screen writes it ("70kg × 5", "1:10").
  final String label;

  /// Whether this session set a personal best for the exercise: the same
  /// projection as the PB mark everywhere else.
  final bool isRecord;
}

/// The points for one exercise, oldest first, and how to read them.
class ExerciseProgressSeries {
  const ExerciseProgressSeries({
    required this.loadType,
    required this.points,
    required this.unit,
    required this.inverted,
  });

  final LoadType? loadType;
  final List<ProgressPoint> points;

  /// "kg", "reps", "kg added", "seconds" or "kg assist".
  final String unit;

  /// True for assisted: **less assistance is better**, so the axis is
  /// flipped and the lightest assist sits highest. The one place in the app
  /// where a smaller number is the record, and the place it would most
  /// easily ship backwards.
  final bool inverted;

  double get _min =>
      points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
  double get _max =>
      points.map((p) => p.value).reduce((a, b) => a > b ? a : b);

  /// How high [value] sits on the chart, 0 at the bottom and 1 at the top,
  /// with "better" always up.
  double heightFraction(double value) {
    if (points.isEmpty) return 0.5;
    final min = _min;
    final max = _max;
    if (max == min) return 0.5;
    final t = (value - min) / (max - min);
    return inverted ? 1 - t : t;
  }

  /// The points from [from] on.
  ExerciseProgressSeries since(LocalDate? from) => from == null
      ? this
      : ExerciseProgressSeries(
          loadType: loadType,
          points: <ProgressPoint>[
            for (final p in points)
              if (!p.date.isBefore(from)) p,
          ],
          unit: unit,
          inverted: inverted,
        );

  /// One sentence a screen reader hears instead of the drawing.
  String summary() {
    if (points.isEmpty) return 'No sessions in this range';
    final first = points.first.value;
    final last = points.last.value;
    final n = points.length;
    final over = 'over $n session${n == 1 ? '' : 's'}';
    String v(double x) => switch (unit) {
          'seconds' => formatDuration(x.round()),
          'reps' => '${x.round()}',
          _ => formatWeight(x),
        };
    final suffix = switch (unit) {
      'seconds' || 'reps' => '',
      'kg assist' => ' kg',
      'kg added' => ' kg added',
      _ => ' kg',
    };
    if (inverted) {
      if (last < first) {
        return 'Assistance dropped from ${v(first)} to ${v(last)}$suffix '
            '$over. Less is better';
      }
      if (last > first) {
        return 'Assistance rose from ${v(first)} to ${v(last)}$suffix '
            '$over. Less is better';
      }
      return 'Assistance held at ${v(last)}$suffix $over. Less is better';
    }
    final subject = switch (unit) {
      'seconds' => 'Longest hold',
      'reps' => 'Most reps',
      _ => 'Best set',
    };
    if (last > first) {
      return '$subject rose from ${v(first)} to ${v(last)}$suffix $over';
    }
    if (last < first) {
      return '$subject fell from ${v(first)} to ${v(last)}$suffix $over';
    }
    return '$subject held at ${v(last)}$suffix $over';
  }
}

/// The best set of [exerciseId] in each saved session that logged it, oldest
/// first.
///
/// Which number is plotted follows the load type (`docs/01` §Personal best per
/// type), using the PB's own [metricFor] to pick the set:
///
/// | type | plotted |
/// |---|---|
/// | weighted | the top weight (its reps break a tie) |
/// | bodyweight | reps, or the added weight once any was added |
/// | assisted | the assistance, **inverted** |
/// | timed | the longest hold |
ExerciseProgressSeries exerciseProgressSeries(
  String exerciseId,
  List<WorkoutSession> savedSessions,
  Map<String, SessionRecords> records,
) {
  final rows = <({WorkoutSession session, SessionExercise exercise})>[];
  for (final session in savedSessions) {
    for (final exercise in session.exercises) {
      if (exercise.exerciseId != exerciseId) continue;
      if (!exercise.sets.any((s) => isSetComplete(exercise.loadType, s))) {
        continue;
      }
      rows.add((session: session, exercise: exercise));
    }
  }
  rows.sort((a, b) {
    final byDay = a.session.performedOn.compareTo(b.session.performedOn);
    return byDay != 0 ? byDay : a.session.loggedAt.compareTo(b.session.loggedAt);
  });

  final type = rows.isEmpty ? null : rows.last.exercise.loadType;
  final anyAdded = type == LoadType.bodyweight &&
      rows.any((r) => r.exercise.sets.any((s) =>
          isSetComplete(r.exercise.loadType, s) && (s.addedKg ?? 0) > 0));

  final points = <ProgressPoint>[];
  for (final row in rows) {
    final exercise = row.exercise;
    final completed = <SetEntry>[
      for (final s in exercise.sets)
        if (isSetComplete(exercise.loadType, s)) s,
    ];
    SetEntry best = completed.first;
    double value;
    switch (type) {
      case LoadType.timed:
        for (final s in completed) {
          if ((s.durationSec ?? 0) > (best.durationSec ?? 0)) best = s;
        }
        value = (best.durationSec ?? 0).toDouble();
      case LoadType.bodyweight when !anyAdded:
        for (final s in completed) {
          if ((s.reps ?? 0) > (best.reps ?? 0)) best = s;
        }
        value = (best.reps ?? 0).toDouble();
      default:
        var bestMetric = metricFor(exercise.loadType, best);
        for (final s in completed) {
          final m = metricFor(exercise.loadType, s);
          if (m.compareTo(bestMetric) > 0) {
            best = s;
            bestMetric = m;
          }
        }
        value = switch (type) {
          LoadType.assisted => best.assistKg ?? 0,
          LoadType.bodyweight => best.addedKg ?? 0,
          _ => best.weightKg ?? 0,
        };
    }
    points.add(ProgressPoint(
      sessionId: row.session.id,
      date: row.session.performedOn,
      value: value,
      label: formatSet(exercise.loadType, best),
      isRecord: records[row.session.id]?.recordSetIds.containsKey(exercise.id) ??
          false,
    ));
  }

  return ExerciseProgressSeries(
    loadType: type,
    points: points,
    unit: switch (type) {
      LoadType.assisted => 'kg assist',
      LoadType.timed => 'seconds',
      LoadType.bodyweight => anyAdded ? 'kg added' : 'reps',
      _ => 'kg',
    },
    inverted: type == LoadType.assisted,
  );
}

/// One row of the "Best at" table: "8 reps" / "62.5kg".
class BestAtRow {
  const BestAtRow(this.label, this.value);

  final String label;
  final String value;
}

/// The quiet records tier: the best at each rep count (audit #8).
///
/// A plateaued lifter still has something to beat, without a badge or an
/// alert. It does not change what "PB" means; it is a reference table.
///
/// | type | rows |
/// |---|---|
/// | weighted | heaviest weight at 1 to 12 reps |
/// | assisted | lightest assist at 1 to 12 reps |
/// | bodyweight | most reps at each added weight ("Bodyweight", "+10kg") |
/// | timed | longest hold at each added weight |
///
/// Twelve reps is the cap Strong uses: past that a "record" is endurance,
/// not strength, and the table would grow without telling anyone anything.
List<BestAtRow> bestAtTable(
  String exerciseId,
  LoadType? type,
  List<WorkoutSession> savedSessions,
) {
  final sets = <SetEntry>[
    for (final session in savedSessions)
      for (final exercise in session.exercises)
        if (exercise.exerciseId == exerciseId)
          for (final s in exercise.sets)
            if (isSetComplete(exercise.loadType, s)) s,
  ];

  switch (type) {
    case LoadType.weighted:
    case LoadType.assisted:
      final byReps = <int, double>{};
      for (final s in sets) {
        final reps = s.reps ?? 0;
        if (reps < 1 || reps > 12) continue;
        final kg = type == LoadType.weighted ? s.weightKg ?? 0 : s.assistKg ?? 0;
        final current = byReps[reps];
        final better = current == null ||
            (type == LoadType.weighted ? kg > current : kg < current);
        if (better) byReps[reps] = kg;
      }
      final reps = byReps.keys.toList()..sort();
      return <BestAtRow>[
        for (final r in reps)
          BestAtRow(
            '$r rep${r == 1 ? '' : 's'}',
            type == LoadType.weighted
                ? '${formatWeight(byReps[r])}kg'
                : '${formatWeight(byReps[r])}kg assist',
          ),
      ];
    case LoadType.bodyweight:
    case LoadType.timed:
      final byLoad = <double, int>{};
      for (final s in sets) {
        final load = type == LoadType.bodyweight
            ? s.addedKg ?? 0
            : s.weightKg ?? 0;
        final amount = type == LoadType.bodyweight
            ? s.reps ?? 0
            : s.durationSec ?? 0;
        final current = byLoad[load];
        if (current == null || amount > current) byLoad[load] = amount;
      }
      final loads = byLoad.keys.toList()..sort();
      return <BestAtRow>[
        for (final load in loads)
          BestAtRow(
            load == 0 ? 'Bodyweight' : '+${formatWeight(load)}kg',
            type == LoadType.bodyweight
                ? '${byLoad[load]} reps'
                : formatDuration(byLoad[load]!),
          ),
      ];
    case null:
      return const <BestAtRow>[];
  }
}
