import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'local_date.dart';
import 'meal_slot.dart';
import 'settings_store.dart' show appDatabaseProvider;
import 'training_plan.dart' show startOfWeek;

/// The optional "eaten" tick on a meal slot (`docs/adr/0007-diet-in-profile.md`).
///
/// * **Presence means eaten; an untick is a hard delete.** There is no stored
///   "false".
/// * **Only this week, up to today, can be changed.** A CHECK cannot see
///   "today", so this store holds the rule, reading its own clock at write
///   time for the reason `DietPlanStore` does. Older ticks stay readable.

/// One meal ticked as eaten on one calendar day.
@immutable
class MealTick {
  const MealTick({required this.date, required this.slot});

  final LocalDate date;
  final MealSlot slot;

  @override
  bool operator ==(Object other) =>
      other is MealTick && other.date == date && other.slot == slot;

  @override
  int get hashCode => Object.hash(date, slot);

  @override
  String toString() => 'MealTick($date ${slot.name})';
}

/// Reads and toggles meal ticks.
class MealTickStore {
  MealTickStore(this._db, {LocalDate Function()? today})
      : _today = today ?? LocalDate.today;

  final AppDatabase _db;
  final LocalDate Function() _today;

  /// Ticks oldest first, then in slot order; narrowed to [from]..[to]
  /// inclusive when given.
  Future<List<MealTick>> read({LocalDate? from, LocalDate? to}) async {
    final query = _db.select(_db.mealTicks);
    if (from != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(from.encode()));
    }
    if (to != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(to.encode()));
    }
    final ticks = (await query.get())
        .map((row) => MealTick(
            date: row.date, slot: MealSlot.values.byName(row.slot)))
        .toList();
    ticks.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.slot.index.compareTo(b.slot.index);
    });
    return ticks;
  }

  /// Ticks [slot] on [date] if it was not ticked, unticks it if it was, and
  /// returns whether it is ticked now.
  ///
  /// Throws [ArgumentError] for a date after today or before this week's
  /// Monday, by the store clock at the moment of the call.
  Future<bool> toggle(LocalDate date, MealSlot slot) async {
    final today = _today();
    final monday = startOfWeek(today);
    if (date > today || date < monday) {
      throw ArgumentError.value(
          date, 'date', 'only $monday to $today can be ticked');
    }
    return _db.transaction(() async {
      final removed = await (_db.delete(_db.mealTicks)
            ..where((t) => t.date.equalsValue(date) & t.slot.equals(slot.name)))
          .go();
      if (removed > 0) return false;
      await _db
          .into(_db.mealTicks)
          .insert(MealTicksCompanion.insert(date: date, slot: slot.name));
      return true;
    });
  }
}

/// The meal tick store, on the device clock.
final mealTickStoreProvider = Provider<MealTickStore>(
  (ref) => MealTickStore(ref.watch(appDatabaseProvider)),
);
