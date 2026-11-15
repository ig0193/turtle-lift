import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'local_date.dart';
import 'meal_slot.dart';
import 'settings_store.dart' show appDatabaseProvider;

/// The Diet log: what the user ate, one row per food per meal slot per day
/// (`docs/adr/0015-diet-is-a-log.md`).
///
/// The rules, because each line is a bug someone will otherwise write:
///
/// * **A row belongs to one date and repeats nowhere.** There is no weekly
///   pattern to copy forward and no version series: an edit changes that day
///   and no other.
/// * **Today and earlier only.** Logging a meal that has not been eaten is
///   planning, which this feature no longer does. "Today" comes from the
///   store's own clock, read at write time, never from a cached provider:
///   `planTodayProvider` can still say yesterday in an app left open past
///   midnight.
/// * **Rows are found by id.** Nothing is copied on write, so an id stays the
///   id the UI was shown.
/// * **Servings are halves, 1 to 8.** The schema CHECKs the same bounds; this
///   store checks them first so a bad value never opens a transaction.

/// The fewest halves a logged food can hold: half a serving.
const int kMinServingsHalves = 1;

/// The most halves a logged food can hold: four servings.
const int kMaxServingsHalves = 8;

/// One food eaten in one meal slot on one day.
@immutable
class DietLogEntry {
  const DietLogEntry({
    required this.id,
    required this.date,
    required this.slot,
    required this.foodId,
    required this.servingsHalves,
    required this.position,
  });

  final String id;

  /// The local calendar day it was eaten.
  final LocalDate date;

  final MealSlot slot;

  /// The bundled food's id.
  final String foodId;

  /// Servings as a count of halves, 1 to 8.
  final int servingsHalves;

  /// Order within the slot, as the user added the foods.
  final int position;

  factory DietLogEntry._fromRow(DietLogEntryRow row) => DietLogEntry(
        id: row.id,
        date: row.date,
        slot: MealSlot.values.byName(row.slot),
        foodId: row.foodId,
        servingsHalves: row.servingsHalves,
        position: row.position,
      );

  @override
  bool operator ==(Object other) =>
      other is DietLogEntry &&
      other.id == id &&
      other.date == date &&
      other.slot == slot &&
      other.foodId == foodId &&
      other.servingsHalves == servingsHalves &&
      other.position == position;

  @override
  int get hashCode =>
      Object.hash(id, date, slot, foodId, servingsHalves, position);

  @override
  String toString() =>
      'DietLogEntry($date ${slot.name} $foodId ${servingsHalves}h #$position)';
}

/// Reads and writes the Diet log.
class DietLogStore {
  DietLogStore(this._db, {LocalDate Function()? today})
      : _today = today ?? LocalDate.today;

  final AppDatabase _db;
  final LocalDate Function() _today;

  static const Uuid _uuid = Uuid();

  /// Every entry, oldest day first, then slot in day order, then position.
  Future<List<DietLogEntry>> readEntries() async {
    final rows = await _db.select(_db.dietLogEntries).get();
    return rows.map(DietLogEntry._fromRow).toList()..sort(_byDayOrder);
  }

  /// Logs [foodId] in [slot] on [date], [halves] servings.
  ///
  /// A food already in that slot on that day keeps its row and position and
  /// takes the new servings: one row per food per slot per day, never a
  /// second that double counts.
  ///
  /// Throws [ArgumentError] for a date after today, a bad serving count or an
  /// empty food id.
  Future<void> addFood({
    required LocalDate date,
    required MealSlot slot,
    required String foodId,
    required int halves,
  }) async {
    _checkDate(date);
    if (foodId.isEmpty) {
      throw ArgumentError.value(foodId, 'foodId', 'must not be empty');
    }
    _checkHalves(halves);

    return _db.transaction(() async {
      final existing = await _find(date, slot, foodId);
      if (existing != null) {
        await _setHalves(existing.id, halves);
        return;
      }
      final inSlot = await (_db.select(_db.dietLogEntries)
            ..where((e) => e.date.equalsValue(date) & e.slot.equals(slot.name)))
          .get();
      final position = inSlot.fold<int>(
              -1, (max, row) => row.position > max ? row.position : max) +
          1;
      await _db.into(_db.dietLogEntries).insert(
            DietLogEntriesCompanion.insert(
              id: _uuid.v4(),
              date: date,
              slot: slot.name,
              foodId: foodId,
              servingsHalves: halves,
              position: position,
            ),
          );
    });
  }

  /// Sets the servings of [entry] to [halves].
  ///
  /// Throws [StateError] when the entry is no longer in the log.
  Future<void> setServings(DietLogEntry entry, int halves) async {
    _checkHalves(halves);
    final changed = await _setHalves(entry.id, halves);
    if (changed == 0) throw StateError('$entry is not in the log');
  }

  /// Removes [entry] and returns what was removed, for [restoreEntry] to
  /// undo. Null when there was nothing to remove.
  Future<DietLogEntry?> removeEntry(DietLogEntry entry) async {
    return _db.transaction(() async {
      final row = await (_db.select(_db.dietLogEntries)
            ..where((e) => e.id.equals(entry.id)))
          .getSingleOrNull();
      if (row == null) return null;
      await (_db.delete(_db.dietLogEntries)..where((e) => e.id.equals(entry.id)))
          .go();
      return DietLogEntry._fromRow(row);
    });
  }

  /// Puts a removed [entry] back with its servings and position, and its id
  /// when that id is still free.
  ///
  /// If the same food has been logged to that slot since, the restored
  /// servings win and there is still one row: undo returns the log to how it
  /// was before the remove.
  Future<void> restoreEntry(DietLogEntry entry) async {
    _checkDate(entry.date);
    _checkHalves(entry.servingsHalves);
    return _db.transaction(() async {
      final existing = await _find(entry.date, entry.slot, entry.foodId);
      if (existing != null) {
        await (_db.update(_db.dietLogEntries)
              ..where((e) => e.id.equals(existing.id)))
            .write(DietLogEntriesCompanion(
          servingsHalves: Value<int>(entry.servingsHalves),
          position: Value<int>(entry.position),
        ));
        return;
      }
      final idTaken = await (_db.select(_db.dietLogEntries)
                ..where((e) => e.id.equals(entry.id)))
              .getSingleOrNull() !=
          null;
      await _db.into(_db.dietLogEntries).insert(
            DietLogEntriesCompanion.insert(
              id: idTaken ? _uuid.v4() : entry.id,
              date: entry.date,
              slot: entry.slot.name,
              foodId: entry.foodId,
              servingsHalves: entry.servingsHalves,
              position: entry.position,
            ),
          );
    });
  }

  // --- Internals -------------------------------------------------------------

  Future<DietLogEntryRow?> _find(LocalDate date, MealSlot slot, String foodId) {
    return (_db.select(_db.dietLogEntries)
          ..where((e) =>
              e.date.equalsValue(date) &
              e.slot.equals(slot.name) &
              e.foodId.equals(foodId)))
        .getSingleOrNull();
  }

  Future<int> _setHalves(String id, int halves) {
    return (_db.update(_db.dietLogEntries)..where((e) => e.id.equals(id)))
        .write(DietLogEntriesCompanion(servingsHalves: Value<int>(halves)));
  }

  void _checkDate(LocalDate date) {
    final today = _today();
    if (date > today) {
      throw ArgumentError.value(
          date, 'date', 'a meal can be logged up to $today, not after it');
    }
  }

  static void _checkHalves(int halves) {
    if (halves < kMinServingsHalves || halves > kMaxServingsHalves) {
      throw ArgumentError.value(halves, 'halves',
          'must be $kMinServingsHalves to $kMaxServingsHalves');
    }
  }

  static int _byDayOrder(DietLogEntry a, DietLogEntry b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    final bySlot = a.slot.index.compareTo(b.slot.index);
    if (bySlot != 0) return bySlot;
    final byPosition = a.position.compareTo(b.position);
    if (byPosition != 0) return byPosition;
    return a.foodId.compareTo(b.foodId);
  }
}

/// The Diet log store, on the device clock.
final dietLogStoreProvider = Provider<DietLogStore>(
  (ref) => DietLogStore(ref.watch(appDatabaseProvider)),
);
