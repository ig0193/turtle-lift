import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'history_preview_data.dart';
import 'local_date.dart';
import 'settings_store.dart' show appDatabaseProvider;

/// The weekdays the user aims to train on, as a dated series, and the week
/// summary derived from it.
///
/// Decisions and reasons: `docs/adr/0005-schedule-and-opt-in-notifications.md`.
/// The short version, because each line is a bug someone will otherwise write:
///
/// * **A plan is a weekly pattern and nothing more.** No workout is attached to
///   a day and the app never suggests one.
/// * **Entries are immutable and dated.** A change is a new entry that applies
///   from the day it is saved, so past weeks keep the plan in force *then*.
///   [weekdaysInEffectOn] is the one place that resolution happens.
/// * **Hit / empty is derived on read** from saved sessions, never stored.
///   Sessions are editable and deletable, so any stored tally goes stale.
/// * **Weekdays are 0 = Monday ... 6 = Sunday**, and the week starts on Monday.

/// How many weekdays there are.
const int kWeekdayCount = 7;

/// One saved plan: the training weekdays from [effectiveFrom] onwards, until a
/// later entry replaces it.
@immutable
class TrainingPlanEntry {
  TrainingPlanEntry({required this.effectiveFrom, required Set<int> weekdays})
      : weekdays = Set<int>.unmodifiable(weekdays) {
    assert(
      weekdays.every((d) => d >= 0 && d < kWeekdayCount),
      'weekdays are 0 (Monday) to 6 (Sunday), got $weekdays',
    );
  }

  /// The local calendar date this plan took effect.
  final LocalDate effectiveFrom;

  /// Training weekdays. Empty means "no training days from here".
  final Set<int> weekdays;

  /// The storage form: bit 0 is Monday ... bit 6 is Sunday.
  int get mask => maskOf(weekdays);

  static int maskOf(Set<int> weekdays) =>
      weekdays.fold(0, (mask, day) => mask | (1 << day));

  static Set<int> weekdaysOf(int mask) => <int>{
        for (var d = 0; d < kWeekdayCount; d++)
          if (mask & (1 << d) != 0) d,
      };

  @override
  bool operator ==(Object other) =>
      other is TrainingPlanEntry &&
      other.effectiveFrom == effectiveFrom &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays);

  @override
  int get hashCode => Object.hash(effectiveFrom, Object.hashAllUnordered(weekdays));

  @override
  String toString() => 'TrainingPlanEntry($effectiveFrom, $weekdays)';
}

/// The weekdays in force on [date]: the latest entry on or before it, or none
/// when no plan had been saved yet.
///
/// **Resolved per date, never per week.** A plan saved on a Wednesday governs
/// that Wednesday onwards, so one week can straddle two plans. [entries] may be
/// in any order.
Set<int> weekdaysInEffectOn(List<TrainingPlanEntry> entries, LocalDate date) {
  TrainingPlanEntry? best;
  for (final entry in entries) {
    if (entry.effectiveFrom > date) continue;
    if (best == null || entry.effectiveFrom > best.effectiveFrom) best = entry;
  }
  return best?.weekdays ?? const <int>{};
}

/// Monday of the week containing [date].
LocalDate startOfWeek(LocalDate date) => date.addDays(1 - date.weekday);

/// What happened on one plan day.
enum PlanDayState {
  /// A saved session exists on that date.
  hit,

  /// The day is over and has no session. Rendered quietly, never as a failure.
  empty,

  /// Today with no session yet, or a day still to come.
  ahead,
}

/// One plan day inside a week.
@immutable
class PlanDay {
  const PlanDay(this.date, this.state);

  final LocalDate date;
  final PlanDayState state;

  /// 0 = Monday ... 6 = Sunday.
  int get weekday => date.weekday - 1;
}

/// One week measured against the plan.
@immutable
class WeekSummary {
  const WeekSummary({
    required this.start,
    required this.days,
    required this.extra,
  });

  /// The Monday this week starts on.
  final LocalDate start;

  /// Only the plan days, oldest first.
  final List<PlanDay> days;

  /// Sessions on days that were not plan days, up to and including today.
  final int extra;

  int get planned => days.length;

  int get hit => days.where((d) => d.state == PlanDayState.hit).length;

  /// Plan days still to come, today included until it has a session.
  List<PlanDay> get remaining =>
      days.where((d) => d.state == PlanDayState.ahead).toList(growable: false);
}

/// Measures the week starting [weekStart] against [plan].
///
/// [trained] is the set of dates with a saved session; anything after [today]
/// is ignored, so scrubbing "today" backwards behaves like the real thing.
WeekSummary weekSummaryFor({
  required LocalDate weekStart,
  required LocalDate today,
  required List<TrainingPlanEntry> plan,
  required Set<LocalDate> trained,
}) {
  final days = <PlanDay>[];
  var extra = 0;
  for (var i = 0; i < kWeekdayCount; i++) {
    final date = weekStart.addDays(i);
    final did = date <= today && trained.contains(date);
    if (weekdaysInEffectOn(plan, date).contains(i)) {
      days.add(
        PlanDay(
          date,
          did
              ? PlanDayState.hit
              : date < today
                  ? PlanDayState.empty
                  : PlanDayState.ahead,
        ),
      );
    } else if (did) {
      extra++;
    }
  }
  return WeekSummary(start: weekStart, days: days, extra: extra);
}

// --- Storage ---------------------------------------------------------------

/// Reads and writes the plan series. **No update and no delete**, enforced by
/// there being no method to call, exactly like `PersonalDetailsStore`'s
/// bodyweight series.
class TrainingPlanStore {
  const TrainingPlanStore(this._db);

  final AppDatabase _db;

  /// Every saved plan, oldest first.
  Future<List<TrainingPlanEntryRow>> readEntries() {
    return (_db.select(_db.trainingPlanEntries)
          ..orderBy(<OrderingTerm Function($TrainingPlanEntriesTable)>[
            (entries) => OrderingTerm.asc(entries.effectiveFrom),
          ]))
        .get();
  }

  /// Saves [mask] as the plan from [effectiveFrom] (`YYYY-MM-DD`).
  ///
  /// An upsert on the date: saving twice on one day replaces that day.
  Future<void> appendEntry(String effectiveFrom, int mask) async {
    await _db.into(_db.trainingPlanEntries).insertOnConflictUpdate(
          TrainingPlanEntriesCompanion.insert(
            effectiveFrom: effectiveFrom,
            weekdayMask: mask,
          ),
        );
  }
}

final trainingPlanStoreProvider = Provider<TrainingPlanStore>(
  (ref) => TrainingPlanStore(ref.watch(appDatabaseProvider)),
);

/// The plan series the app started with, resolved before the first frame --
/// the same boot-time shape as `initialBodyweightLogProvider`, for the same
/// reason: a Schedule pane that flashed "pick your training days" at a user who
/// has already picked them would say something false.
final initialTrainingPlanProvider = Provider<List<TrainingPlanEntry>>(
  (ref) => const <TrainingPlanEntry>[],
);

/// Reads the stored plan series, oldest first. Called once from `main()`.
Future<List<TrainingPlanEntry>> readStoredTrainingPlan(
  TrainingPlanStore store,
) async {
  final rows = await store.readEntries();
  return rows
      .map(
        (row) => TrainingPlanEntry(
          effectiveFrom: LocalDate.parse(row.effectiveFrom),
          weekdays: TrainingPlanEntry.weekdaysOf(row.weekdayMask),
        ),
      )
      .toList(growable: false);
}

/// Every saved plan, oldest first.
///
/// **The only mutation is [save], and it takes no date** -- entries cannot be
/// backdated, so the signature does not offer it.
class TrainingPlanLog extends Notifier<List<TrainingPlanEntry>> {
  @override
  List<TrainingPlanEntry> build() => ref.read(initialTrainingPlanProvider);

  /// Saves [weekdays] as the plan from today onwards.
  Future<void> save(Set<int> weekdays) async {
    // The same clock the summaries read, so a saved plan and the week it
    // applies to can never disagree about what day it is.
    final today = ref.read(planTodayProvider);
    final entry = TrainingPlanEntry(effectiveFrom: today, weekdays: weekdays);
    await ref
        .read(trainingPlanStoreProvider)
        .appendEntry(today.encode(), entry.mask);

    // Today is by construction the latest date, so drop any entry already on
    // today and append, keeping the oldest-first order.
    state = <TrainingPlanEntry>[
      ...state.where((e) => e.effectiveFrom != today),
      entry,
    ];
  }
}

final trainingPlanLogProvider =
    NotifierProvider<TrainingPlanLog, List<TrainingPlanEntry>>(
  TrainingPlanLog.new,
);

// --- Derived ---------------------------------------------------------------

/// The clock. A provider so a test can pin "today"; the shipped value reads
/// the device once per read of the providers below.
///
/// **Known limit:** an app left open across midnight keeps yesterday's value
/// until something invalidates it. Acceptable pre-launch; a lifecycle listener
/// that invalidates this provider on resume is the fix.
final planTodayProvider = Provider<LocalDate>((ref) => LocalDate.today());

/// The dates with a saved session. Derived from the history projection, so an
/// edit or delete moves the week summary with no refresh path to forget.
final trainedDatesProvider = Provider<Set<LocalDate>>((ref) {
  return <LocalDate>{
    for (final s in ref.watch(historySessionsProvider))
      LocalDate.fromDateTime(s.performedOn),
  };
});

/// This week against the plan, or null when the user has no training days in
/// force today -- there is nothing to compare, and "0 of 0" would look broken.
final thisWeekSummaryProvider = Provider<WeekSummary?>((ref) {
  final today = ref.watch(planTodayProvider);
  final summary = weekSummaryFor(
    weekStart: startOfWeek(today),
    today: today,
    plan: ref.watch(trainingPlanLogProvider),
    trained: ref.watch(trainedDatesProvider),
  );
  return summary.planned == 0 ? null : summary;
});

/// Last week against the plan that was in force then, or null when it had no
/// plan days.
final lastWeekSummaryProvider = Provider<WeekSummary?>((ref) {
  final today = ref.watch(planTodayProvider);
  final summary = weekSummaryFor(
    weekStart: startOfWeek(today).addDays(-7),
    today: today,
    plan: ref.watch(trainingPlanLogProvider),
    trained: ref.watch(trainedDatesProvider),
  );
  return summary.planned == 0 ? null : summary;
});

/// The weekdays in force today -- what the Schedule chips show.
final todayPlanWeekdaysProvider = Provider<Set<int>>((ref) {
  return weekdaysInEffectOn(
    ref.watch(trainingPlanLogProvider),
    ref.watch(planTodayProvider),
  );
});

/// Exposed for tests that need a mask round trip without a database.
@visibleForTesting
Set<int> debugWeekdaysOf(int mask) => TrainingPlanEntry.weekdaysOf(mask);
