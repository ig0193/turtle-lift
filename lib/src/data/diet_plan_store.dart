import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'local_date.dart';
import 'meal_slot.dart';
import 'settings_store.dart' show appDatabaseProvider;
import 'training_plan.dart' show kWeekdayCount, startOfWeek;

/// The Diet plan: a dated series of whole-week versions keyed by Monday,
/// written copy-on-write (`docs/adr/0007-diet-in-profile.md`).
///
/// The rules, because each line is a bug someone will otherwise write:
///
/// * **Every write lands in the version at this week's Monday.** If that
///   version does not exist yet, the write first copies the latest earlier
///   version's items into it (new ids), or starts it empty, in the same
///   transaction as the edit. **No path writes an older version**, so a past
///   week keeps reading the plan that was in force then -- the guarantee
///   `TrainingPlanStore` gives the training plan.
/// * **"This week" comes from the store's own clock, read at write time,**
///   never from a cached provider. `planTodayProvider` can still say Sunday in
///   an app left open into Monday; a Monday edit written into Sunday's week
///   would rewrite a week the user has already lived.
/// * **Rows are found by `(weekday, slot, foodId)`, not by id.** The UI shows
///   the version in effect, which may be an older week's; once the edit has
///   copied it forward, the row to change is the copy, which has a new id.
/// * **Weekdays are 0 = Monday ... 6 = Sunday**, matching `TrainingPlanEntry`.
/// * **Servings are halves, 1 to 8.** The schema CHECKs the same bounds; this
///   store checks them first so a bad value never opens a transaction.

/// The fewest halves a plan item can hold: half a serving.
const int kMinServingsHalves = 1;

/// The most halves a plan item can hold: four servings.
const int kMaxServingsHalves = 8;

/// One food in one meal slot of one weekday.
@immutable
class DietPlanItem {
  const DietPlanItem({
    required this.id,
    required this.weekday,
    required this.slot,
    required this.foodId,
    required this.servingsHalves,
    required this.position,
  });

  final String id;

  /// 0 = Monday ... 6 = Sunday.
  final int weekday;

  final MealSlot slot;

  /// The bundled food's id.
  final String foodId;

  /// Servings as a count of halves, 1 to 8.
  final int servingsHalves;

  /// Order within the slot, as the user added the foods.
  final int position;

  factory DietPlanItem._fromRow(DietPlanItemRow row) => DietPlanItem(
        id: row.id,
        weekday: row.weekday,
        slot: MealSlot.values.byName(row.slot),
        foodId: row.foodId,
        servingsHalves: row.servingsHalves,
        position: row.position,
      );

  @override
  bool operator ==(Object other) =>
      other is DietPlanItem &&
      other.id == id &&
      other.weekday == weekday &&
      other.slot == slot &&
      other.foodId == foodId &&
      other.servingsHalves == servingsHalves &&
      other.position == position;

  @override
  int get hashCode =>
      Object.hash(id, weekday, slot, foodId, servingsHalves, position);

  @override
  String toString() => 'DietPlanItem($weekday ${slot.name} $foodId '
      '${servingsHalves}h #$position)';
}

/// One whole-week version: the plan from [effectiveFrom] (a Monday) until a
/// later version replaces it. Empty [items] is a real answer, "nothing
/// planned from here".
@immutable
class DietPlanVersion {
  DietPlanVersion({
    required this.effectiveFrom,
    required List<DietPlanItem> items,
  }) : items = List<DietPlanItem>.unmodifiable(items);

  /// The Monday this version takes effect from.
  final LocalDate effectiveFrom;

  /// Ordered by weekday, then slot in day order, then position.
  final List<DietPlanItem> items;

  @override
  bool operator ==(Object other) =>
      other is DietPlanVersion &&
      other.effectiveFrom == effectiveFrom &&
      listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(effectiveFrom, Object.hashAll(items));

  @override
  String toString() => 'DietPlanVersion($effectiveFrom, $items)';
}

/// Reads and writes the Diet plan series.
class DietPlanStore {
  DietPlanStore(this._db, {LocalDate Function()? today})
      : _today = today ?? LocalDate.today;

  final AppDatabase _db;
  final LocalDate Function() _today;

  static const Uuid _uuid = Uuid();

  /// Every version with its items, oldest first.
  Future<List<DietPlanVersion>> readVersions() async {
    final versionRows = await (_db.select(_db.dietPlanVersions)
          ..orderBy(<OrderingTerm Function($DietPlanVersionsTable)>[
            (v) => OrderingTerm.asc(v.effectiveFrom),
          ]))
        .get();
    final itemRows = await _db.select(_db.dietPlanItems).get();

    final byVersion = <LocalDate, List<DietPlanItem>>{};
    for (final row in itemRows) {
      byVersion
          .putIfAbsent(row.effectiveFrom, () => <DietPlanItem>[])
          .add(DietPlanItem._fromRow(row));
    }
    return <DietPlanVersion>[
      for (final v in versionRows)
        DietPlanVersion(
          effectiveFrom: v.effectiveFrom,
          items: (byVersion[v.effectiveFrom] ?? <DietPlanItem>[])
            ..sort(_byDayOrder),
        ),
    ];
  }

  /// Puts [foodId] in [slot] on every one of [weekdays], [halves] servings
  /// each, in this week's version.
  ///
  /// **One transaction across every weekday**, so a failure part-way leaves
  /// no row and no new version. A food already in that slot on that day keeps
  /// its row and position and takes the new servings: one row per food per
  /// slot per day, never a second that double counts.
  Future<void> addFood({
    required Set<int> weekdays,
    required MealSlot slot,
    required String foodId,
    required int halves,
  }) async {
    if (weekdays.isEmpty) {
      throw ArgumentError.value(weekdays, 'weekdays', 'pick at least one day');
    }
    for (final day in weekdays) {
      _checkWeekday(day);
    }
    if (foodId.isEmpty) {
      throw ArgumentError.value(foodId, 'foodId', 'must not be empty');
    }
    _checkHalves(halves);

    return _db.transaction(() async {
      final monday = await _ensureCurrentVersion();
      for (final day in weekdays.toList()..sort()) {
        await _put(monday, day, slot, foodId, halves);
      }
    });
  }

  /// Sets the servings of [item] -- as found in this week's version by its
  /// weekday, slot and food -- to [halves].
  ///
  /// Throws [StateError] when that food is no longer in that slot this week;
  /// the copy-on-write that preceded the check is rolled back with it.
  Future<void> setServings(DietPlanItem item, int halves) async {
    _checkHalves(halves);
    return _db.transaction(() async {
      final monday = await _ensureCurrentVersion();
      final row = await _find(monday, item.weekday, item.slot, item.foodId);
      if (row == null) {
        throw StateError('$item is not in the plan for the week of $monday');
      }
      await (_db.update(_db.dietPlanItems)..where((i) => i.id.equals(row.id)))
          .write(DietPlanItemsCompanion(servingsHalves: Value<int>(halves)));
    });
  }

  /// Removes [item] -- as found in this week's version by its weekday, slot
  /// and food -- and returns what was removed, for [restoreItem] to undo.
  ///
  /// The returned item is this week's row, which after a copy-on-write has a
  /// different id from [item]. Null when there was nothing to remove.
  Future<DietPlanItem?> removeItem(DietPlanItem item) async {
    return _db.transaction(() async {
      final monday = await _ensureCurrentVersion();
      final row = await _find(monday, item.weekday, item.slot, item.foodId);
      if (row == null) return null;
      await (_db.delete(_db.dietPlanItems)..where((i) => i.id.equals(row.id)))
          .go();
      return DietPlanItem._fromRow(row);
    });
  }

  /// Puts a removed [item] back into **this week's** version, with its
  /// servings and position, and its id when that id is still free.
  ///
  /// If the same food has been added to that slot since, the restored
  /// servings win and there is still one row: undo returns the plan to how it
  /// was before the remove.
  Future<void> restoreItem(DietPlanItem item) async {
    _checkWeekday(item.weekday);
    _checkHalves(item.servingsHalves);
    return _db.transaction(() async {
      final monday = await _ensureCurrentVersion();
      final existing =
          await _find(monday, item.weekday, item.slot, item.foodId);
      if (existing != null) {
        await (_db.update(_db.dietPlanItems)
              ..where((i) => i.id.equals(existing.id)))
            .write(DietPlanItemsCompanion(
          servingsHalves: Value<int>(item.servingsHalves),
          position: Value<int>(item.position),
        ));
        return;
      }
      final idTaken = await (_db.select(_db.dietPlanItems)
                ..where((i) => i.id.equals(item.id)))
              .getSingleOrNull() !=
          null;
      await _db.into(_db.dietPlanItems).insert(
            DietPlanItemsCompanion.insert(
              id: idTaken ? _uuid.v4() : item.id,
              effectiveFrom: monday,
              weekday: item.weekday,
              slot: item.slot.name,
              foodId: item.foodId,
              servingsHalves: item.servingsHalves,
              position: item.position,
            ),
          );
    });
  }

  // --- Internals (always called inside a transaction) -----------------------

  /// The Monday of this week by the store clock, with a version there:
  /// copied from the latest earlier version, or empty when there is none.
  Future<LocalDate> _ensureCurrentVersion() async {
    final monday = startOfWeek(_today());
    final existing = await (_db.select(_db.dietPlanVersions)
          ..where((v) => v.effectiveFrom.equalsValue(monday)))
        .getSingleOrNull();
    if (existing != null) return monday;

    final previous = await (_db.select(_db.dietPlanVersions)
          ..where((v) => v.effectiveFrom.isSmallerThanValue(monday.encode()))
          ..orderBy(<OrderingTerm Function($DietPlanVersionsTable)>[
            (v) => OrderingTerm.desc(v.effectiveFrom),
          ])
          ..limit(1))
        .getSingleOrNull();

    await _db
        .into(_db.dietPlanVersions)
        .insert(DietPlanVersionsCompanion.insert(effectiveFrom: monday));

    if (previous != null) {
      final items = await (_db.select(_db.dietPlanItems)
            ..where((i) => i.effectiveFrom.equalsValue(previous.effectiveFrom)))
          .get();
      for (final row in items) {
        await _db.into(_db.dietPlanItems).insert(
              DietPlanItemsCompanion.insert(
                id: _uuid.v4(),
                effectiveFrom: monday,
                weekday: row.weekday,
                slot: row.slot,
                foodId: row.foodId,
                servingsHalves: row.servingsHalves,
                position: row.position,
              ),
            );
      }
    }
    return monday;
  }

  Future<DietPlanItemRow?> _find(
    LocalDate monday,
    int weekday,
    MealSlot slot,
    String foodId,
  ) {
    return (_db.select(_db.dietPlanItems)
          ..where((i) =>
              i.effectiveFrom.equalsValue(monday) &
              i.weekday.equals(weekday) &
              i.slot.equals(slot.name) &
              i.foodId.equals(foodId)))
        .getSingleOrNull();
  }

  /// Inserts the food at the end of the slot, or sets its servings if it is
  /// already there.
  Future<void> _put(
    LocalDate monday,
    int weekday,
    MealSlot slot,
    String foodId,
    int halves,
  ) async {
    final existing = await _find(monday, weekday, slot, foodId);
    if (existing != null) {
      await (_db.update(_db.dietPlanItems)
            ..where((i) => i.id.equals(existing.id)))
          .write(DietPlanItemsCompanion(servingsHalves: Value<int>(halves)));
      return;
    }
    final inSlot = await (_db.select(_db.dietPlanItems)
          ..where((i) =>
              i.effectiveFrom.equalsValue(monday) &
              i.weekday.equals(weekday) &
              i.slot.equals(slot.name)))
        .get();
    final position = inSlot.fold<int>(
            -1, (max, row) => row.position > max ? row.position : max) +
        1;
    await _db.into(_db.dietPlanItems).insert(
          DietPlanItemsCompanion.insert(
            id: _uuid.v4(),
            effectiveFrom: monday,
            weekday: weekday,
            slot: slot.name,
            foodId: foodId,
            servingsHalves: halves,
            position: position,
          ),
        );
  }

  static void _checkWeekday(int day) {
    if (day < 0 || day >= kWeekdayCount) {
      throw ArgumentError.value(
          day, 'weekday', 'must be 0 (Monday) to 6 (Sunday)');
    }
  }

  static void _checkHalves(int halves) {
    if (halves < kMinServingsHalves || halves > kMaxServingsHalves) {
      throw ArgumentError.value(halves, 'halves',
          'must be $kMinServingsHalves to $kMaxServingsHalves');
    }
  }

  static int _byDayOrder(DietPlanItem a, DietPlanItem b) {
    final byDay = a.weekday.compareTo(b.weekday);
    if (byDay != 0) return byDay;
    final bySlot = a.slot.index.compareTo(b.slot.index);
    if (bySlot != 0) return bySlot;
    final byPosition = a.position.compareTo(b.position);
    if (byPosition != 0) return byPosition;
    return a.foodId.compareTo(b.foodId);
  }
}

/// The Diet plan store, on the device clock.
final dietPlanStoreProvider = Provider<DietPlanStore>(
  (ref) => DietPlanStore(ref.watch(appDatabaseProvider)),
);
