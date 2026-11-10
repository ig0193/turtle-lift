import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'meal_slot.dart';
import 'settings_store.dart' show appDatabaseProvider;

/// The last minute of the day, 23:59. Every reminder time is 0 to this.
const int kLastMinuteOfDay = 24 * 60 - 1;

/// One meal slot's reminder: whether it is on, and when.
@immutable
class SlotReminder {
  const SlotReminder({required this.on, required this.minute});

  final bool on;

  /// Minutes after local midnight, 0 to [kLastMinuteOfDay].
  final int minute;

  SlotReminder copyWith({bool? on, int? minute}) =>
      SlotReminder(on: on ?? this.on, minute: minute ?? this.minute);

  @override
  bool operator ==(Object other) =>
      other is SlotReminder && other.on == on && other.minute == minute;

  @override
  int get hashCode => Object.hash(on, minute);

  @override
  String toString() => 'SlotReminder(on: $on, minute: $minute)';
}

/// What the user switched on, and when (schema v7, `ReminderPrefs`).
///
/// **Preferences only, never reminder text.** What a reminder says is built
/// from the plan at schedule time, so nothing here goes stale when the plan
/// changes (`docs/01` §Derived values).
///
/// Diet's per-slot switches keep their own value while [dietOn] is off: the
/// master switch silences them without forgetting what the user chose.
@immutable
class ReminderPreferences {
  const ReminderPreferences({
    required this.scheduleOn,
    required this.scheduleMinute,
    required this.dietOn,
    required this.summaryOn,
    required this.summaryMinute,
    required this.breakfast,
    required this.lunch,
    required this.snack,
    required this.dinner,
  });

  /// Everything off, at the plan's A7 default times (and 18:30 for the
  /// Schedule reminder). The column defaults on `ReminderPrefs` hold the same
  /// numbers; `test/reminder_prefs_test.dart` keeps the two in step.
  static const ReminderPreferences defaults = ReminderPreferences(
    scheduleOn: false,
    scheduleMinute: kDefaultScheduleReminderMinute,
    dietOn: false,
    summaryOn: false,
    summaryMinute: 7 * 60 + 30,
    breakfast: SlotReminder(on: false, minute: 8 * 60),
    lunch: SlotReminder(on: false, minute: 13 * 60),
    snack: SlotReminder(on: false, minute: 17 * 60),
    dinner: SlotReminder(on: false, minute: 20 * 60 + 30),
  );

  /// The Schedule tab's training-day reminder (ADR 0005).
  final bool scheduleOn;
  final int scheduleMinute;

  /// The Diet master switch.
  final bool dietOn;

  /// The morning summary of the day's plan.
  final bool summaryOn;
  final int summaryMinute;

  final SlotReminder breakfast;
  final SlotReminder lunch;
  final SlotReminder snack;
  final SlotReminder dinner;

  /// The reminder for [slot].
  SlotReminder slot(MealSlot slot) => switch (slot) {
        MealSlot.breakfast => breakfast,
        MealSlot.lunch => lunch,
        MealSlot.snack => snack,
        MealSlot.dinner => dinner,
      };

  /// A copy with [slot]'s reminder replaced by [value].
  ReminderPreferences withSlot(MealSlot slot, SlotReminder value) =>
      ReminderPreferences(
        scheduleOn: scheduleOn,
        scheduleMinute: scheduleMinute,
        dietOn: dietOn,
        summaryOn: summaryOn,
        summaryMinute: summaryMinute,
        breakfast: slot == MealSlot.breakfast ? value : breakfast,
        lunch: slot == MealSlot.lunch ? value : lunch,
        snack: slot == MealSlot.snack ? value : snack,
        dinner: slot == MealSlot.dinner ? value : dinner,
      );

  ReminderPreferences copyWith({
    bool? scheduleOn,
    int? scheduleMinute,
    bool? dietOn,
    bool? summaryOn,
    int? summaryMinute,
  }) =>
      ReminderPreferences(
        scheduleOn: scheduleOn ?? this.scheduleOn,
        scheduleMinute: scheduleMinute ?? this.scheduleMinute,
        dietOn: dietOn ?? this.dietOn,
        summaryOn: summaryOn ?? this.summaryOn,
        summaryMinute: summaryMinute ?? this.summaryMinute,
        breakfast: breakfast,
        lunch: lunch,
        snack: snack,
        dinner: dinner,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderPreferences &&
      other.scheduleOn == scheduleOn &&
      other.scheduleMinute == scheduleMinute &&
      other.dietOn == dietOn &&
      other.summaryOn == summaryOn &&
      other.summaryMinute == summaryMinute &&
      other.breakfast == breakfast &&
      other.lunch == lunch &&
      other.snack == snack &&
      other.dinner == dinner;

  @override
  int get hashCode => Object.hash(scheduleOn, scheduleMinute, dietOn,
      summaryOn, summaryMinute, breakfast, lunch, snack, dinner);

  @override
  String toString() => 'ReminderPreferences(schedule: $scheduleOn '
      '$scheduleMinute, diet: $dietOn, summary: $summaryOn $summaryMinute, '
      '$breakfast, $lunch, $snack, $dinner)';
}

/// Reads and writes the one reminder-preferences row.
///
/// **A missing row reads as [ReminderPreferences.defaults]** and reading
/// writes nothing, the way an unset settings field reads as null: a fresh
/// install and one upgraded to v7 agree without a seed row.
class ReminderPrefsStore {
  const ReminderPrefsStore(this._db);

  final AppDatabase _db;

  Future<ReminderPreferences> read() async {
    final row = await (_db.select(_db.reminderPrefs)
          ..where((r) => r.id.equals(kReminderPrefsRowId)))
        .getSingleOrNull();
    if (row == null) return ReminderPreferences.defaults;
    return ReminderPreferences(
      scheduleOn: row.scheduleOn,
      scheduleMinute: row.scheduleMinute,
      dietOn: row.dietOn,
      summaryOn: row.summaryOn,
      summaryMinute: row.summaryMinute,
      breakfast: SlotReminder(on: row.breakfastOn, minute: row.breakfastMinute),
      lunch: SlotReminder(on: row.lunchOn, minute: row.lunchMinute),
      snack: SlotReminder(on: row.snackOn, minute: row.snackMinute),
      dinner: SlotReminder(on: row.dinnerOn, minute: row.dinnerMinute),
    );
  }

  /// Stores [prefs] whole, on the one pinned row.
  ///
  /// Throws [ArgumentError] for a minute outside 0..[kLastMinuteOfDay], the
  /// bounds the table's CHECKs hold, before anything is written.
  Future<void> write(ReminderPreferences prefs) async {
    final minutes = <String, int>{
      'scheduleMinute': prefs.scheduleMinute,
      'summaryMinute': prefs.summaryMinute,
      for (final slot in MealSlot.values)
        '${slot.name}Minute': prefs.slot(slot).minute,
    };
    for (final MapEntry(key: name, value: minute) in minutes.entries) {
      if (minute < 0 || minute > kLastMinuteOfDay) {
        throw ArgumentError.value(
            minute, name, 'must be 0 to $kLastMinuteOfDay');
      }
    }
    await _db.into(_db.reminderPrefs).insertOnConflictUpdate(
          ReminderPrefsCompanion(
            id: const Value<int>(kReminderPrefsRowId),
            scheduleOn: Value<bool>(prefs.scheduleOn),
            scheduleMinute: Value<int>(prefs.scheduleMinute),
            dietOn: Value<bool>(prefs.dietOn),
            summaryOn: Value<bool>(prefs.summaryOn),
            summaryMinute: Value<int>(prefs.summaryMinute),
            breakfastOn: Value<bool>(prefs.breakfast.on),
            breakfastMinute: Value<int>(prefs.breakfast.minute),
            lunchOn: Value<bool>(prefs.lunch.on),
            lunchMinute: Value<int>(prefs.lunch.minute),
            snackOn: Value<bool>(prefs.snack.on),
            snackMinute: Value<int>(prefs.snack.minute),
            dinnerOn: Value<bool>(prefs.dinner.on),
            dinnerMinute: Value<int>(prefs.dinner.minute),
          ),
        );
  }
}

final reminderPrefsStoreProvider = Provider<ReminderPrefsStore>(
  (ref) => ReminderPrefsStore(ref.watch(appDatabaseProvider)),
);

/// The preferences as read at boot. `main.dart` overrides this from the
/// database, the shape `initialProteinTargetProvider` uses; the default is
/// the A7 defaults, so a test that never thinks about reminders sees them off.
final initialReminderPrefsProvider =
    Provider<ReminderPreferences>((ref) => ReminderPreferences.defaults);

/// The reminder preferences, in memory, seeded at boot.
///
/// Rescheduling after a change is the caller's job (U16, U17), because what
/// to schedule depends on the plan as well as on these switches.
class ReminderPrefsLog extends Notifier<ReminderPreferences> {
  @override
  ReminderPreferences build() => ref.read(initialReminderPrefsProvider);

  /// Shows [next], then writes it (profile audit B5: a second quick tap
  /// reads this state, so it must not wait for the database). A refused
  /// write puts back what was there.
  Future<void> save(ReminderPreferences next) async {
    final previous = state;
    state = next;
    try {
      await ref.read(reminderPrefsStoreProvider).write(next);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final reminderPrefsProvider =
    NotifierProvider<ReminderPrefsLog, ReminderPreferences>(
        ReminderPrefsLog.new);
