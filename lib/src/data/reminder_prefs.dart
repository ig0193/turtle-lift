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
/// at schedule time (`docs/01` §Derived values).
///
/// **Diet only.** The Schedule's training-day reminder and Diet's morning
/// summary are gone (`docs/adr/0015-diet-is-a-log.md`). Their columns on
/// `ReminderPrefs` stay, unwritten and unread, because SQLite cannot drop a
/// column without rebuilding a table that holds user data.
///
/// Diet's per-slot switches keep their own value while [dietOn] is off: the
/// master switch silences them without forgetting what the user chose.
@immutable
class ReminderPreferences {
  const ReminderPreferences({
    required this.dietOn,
    required this.breakfast,
    required this.lunch,
    required this.snack,
    required this.dinner,
  });

  /// Everything off, at the plan's A7 default times. The column defaults on
  /// `ReminderPrefs` hold the same numbers; `test/reminder_prefs_test.dart`
  /// keeps the two in step.
  static const ReminderPreferences defaults = ReminderPreferences(
    dietOn: false,
    breakfast: SlotReminder(on: false, minute: 8 * 60),
    lunch: SlotReminder(on: false, minute: 13 * 60),
    snack: SlotReminder(on: false, minute: 17 * 60),
    dinner: SlotReminder(on: false, minute: 20 * 60 + 30),
  );

  /// The Diet master switch.
  final bool dietOn;

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
        dietOn: dietOn,
        breakfast: slot == MealSlot.breakfast ? value : breakfast,
        lunch: slot == MealSlot.lunch ? value : lunch,
        snack: slot == MealSlot.snack ? value : snack,
        dinner: slot == MealSlot.dinner ? value : dinner,
      );

  ReminderPreferences copyWith({bool? dietOn}) => ReminderPreferences(
        dietOn: dietOn ?? this.dietOn,
        breakfast: breakfast,
        lunch: lunch,
        snack: snack,
        dinner: dinner,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderPreferences &&
      other.dietOn == dietOn &&
      other.breakfast == breakfast &&
      other.lunch == lunch &&
      other.snack == snack &&
      other.dinner == dinner;

  @override
  int get hashCode =>
      Object.hash(dietOn, breakfast, lunch, snack, dinner);

  @override
  String toString() => 'ReminderPreferences(diet: $dietOn, '
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
      dietOn: row.dietOn,
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
            dietOn: Value<bool>(prefs.dietOn),
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
/// Rescheduling after a change is `dietReminderSyncProvider`'s job.
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
