/// The History tab's own figures: the stats line and a month's total.
///
/// `docs/00` §11: "Stats: streak, total workouts, total sets … These are
/// derived, so they live on the History tab". ADR 0008 keeps **the current
/// week** on the Workout landing, so nothing here counts a week; the calendar
/// totals the month it shows instead (ADR 0013).
///
/// Derived on read from History rows, never stored, so an edit, a re-date or
/// a delete moves every figure with nothing to refresh.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'derived.dart';
import 'history_preview_data.dart';
import 'local_date.dart';
import 'training_plan.dart' show planTodayProvider;

/// The stats line.
class HistoryStats {
  const HistoryStats({
    required this.streak,
    required this.workouts,
    required this.sets,
  });

  final int streak;
  final int workouts;
  final int sets;
}

/// A month's workouts and sets.
class MonthTotal {
  const MonthTotal({required this.workouts, required this.sets});

  final int workouts;
  final int sets;

  /// "6 workouts · 82 sets", or "No workouts".
  String get label => workouts == 0
      ? 'No workouts'
      : '$workouts workout${workouts == 1 ? '' : 's'} · '
          '$sets set${sets == 1 ? '' : 's'}';
}

/// Streak (as of today, decaying), total workouts, total sets.
///
/// "Today" is [planTodayProvider], which `RefreshTodayOnResume` invalidates
/// on resume, so a phone left open across midnight decays the streak the
/// moment it comes back.
final historyStatsProvider = Provider<HistoryStats>((ref) {
  final rows = ref.watch(historySessionsProvider);
  final figures = ref.watch(historyProjectionProvider);
  final today = ref.watch(planTodayProvider);
  var sets = 0;
  for (final row in rows) {
    sets += figures[row.id]?.setCount ?? 0;
  }
  return HistoryStats(
    streak: streakFromDays(
      <LocalDate>[for (final r in rows) LocalDate.fromDateTime(r.performedOn)],
      today,
    ),
    workouts: rows.length,
    sets: sets,
  );
});

/// The workouts and sets in [year]-[month].
MonthTotal monthTotalOf(
  List<HistorySession> rows,
  Map<String, HistoryRowFigures> figures,
  int year,
  int month,
) {
  var workouts = 0;
  var sets = 0;
  for (final row in rows) {
    if (row.performedOn.year != year || row.performedOn.month != month) {
      continue;
    }
    workouts++;
    sets += figures[row.id]?.setCount ?? 0;
  }
  return MonthTotal(workouts: workouts, sets: sets);
}
