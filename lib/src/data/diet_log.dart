import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'diet_log_store.dart';
import 'local_date.dart';
import 'meal_slot.dart';
import 'settings_store.dart';
import 'today.dart' show planTodayProvider;

/// The Diet state the user has entered -- the log and the daily target -- as
/// notifiers seeded once at boot.
///
/// A Diet pane that opened on an empty day at a user who has been logging
/// would say something false, so the log is read before the first frame, the
/// shape every other piece of user state in `main.dart` has. Every number
/// derived from this state lives in `diet_derived.dart` and is computed on
/// read (`docs/01` §Derived values); nothing here stores a total.
///
/// **Writes go through the store, then state is re-read.** The store owns the
/// "today and earlier" rule and reads its own clock at write time, so these
/// notifiers never decide which dates are allowed.

/// What the Diet tables held when the app booted.
typedef StoredDiet = ({List<DietLogEntry> entries, int? proteinTargetG});

/// Reads the log and the target. Called once per boot from `main()`; the two
/// reads run concurrently.
Future<StoredDiet> readStoredDiet(AppDatabase database) async {
  final (entries, target) = await (
    DietLogStore(database).readEntries(),
    SettingsStore(database).readProteinTarget(),
  ).wait;
  return (entries: entries, proteinTargetG: target);
}

// --- Log --------------------------------------------------------------------

/// The log the app started with, oldest first.
final initialDietLogProvider = Provider<List<DietLogEntry>>(
  (ref) => const <DietLogEntry>[],
);

/// Every logged food, oldest first, exactly as stored.
///
/// After each write the log is re-read rather than patched, so state cannot
/// drift from what the store did. A few thousand rows a year at most.
class DietLog extends Notifier<List<DietLogEntry>> {
  @override
  List<DietLogEntry> build() => ref.read(initialDietLogProvider);

  DietLogStore get _store => ref.read(dietLogStoreProvider);

  /// Re-reads the log, and re-reads "today" with it, so an app left open past
  /// midnight moves to the real day instead of logging against a stale one.
  Future<void> _reload() async {
    state = await _store.readEntries();
    ref.invalidate(planTodayProvider);
  }

  /// See [DietLogStore.addFood].
  Future<void> addFood({
    required LocalDate date,
    required MealSlot slot,
    required String foodId,
    required int halves,
  }) async {
    await _store.addFood(date: date, slot: slot, foodId: foodId, halves: halves);
    await _reload();
  }

  /// See [DietLogStore.setServings].
  Future<void> setServings(DietLogEntry entry, int halves) async {
    await _store.setServings(entry, halves);
    await _reload();
  }

  /// See [DietLogStore.removeEntry]. Returns the removed row for undo.
  Future<DietLogEntry?> removeEntry(DietLogEntry entry) async {
    final removed = await _store.removeEntry(entry);
    await _reload();
    return removed;
  }

  /// See [DietLogStore.restoreEntry].
  Future<void> restoreEntry(DietLogEntry entry) async {
    await _store.restoreEntry(entry);
    await _reload();
  }
}

final dietLogProvider =
    NotifierProvider<DietLog, List<DietLogEntry>>(DietLog.new);

// --- Target -----------------------------------------------------------------

/// The target the app started with; null when never set.
final initialProteinTargetProvider = Provider<int?>((ref) => null);

/// The daily protein target in grams, or null. **A number, never a "follow
/// bodyweight" flag** (R15): accepting the suggestion stores what it said.
class ProteinTarget extends Notifier<int?> {
  @override
  int? build() => ref.read(initialProteinTargetProvider);

  /// Stores [grams]. The store rejects anything outside 1..400.
  Future<void> set(int grams) async {
    await ref.read(settingsStoreProvider).writeProteinTarget(grams);
    state = grams;
  }

  /// Removes the target.
  Future<void> clear() async {
    await ref.read(settingsStoreProvider).writeProteinTarget(null);
    state = null;
  }
}

final proteinTargetProvider =
    NotifierProvider<ProteinTarget, int?>(ProteinTarget.new);
