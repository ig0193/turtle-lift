import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'diet_plan_store.dart';
import 'local_date.dart';
import 'meal_slot.dart';
import 'meal_ticks.dart';
import 'settings_store.dart';

/// The Diet state the user has entered -- the plan series, the eaten ticks and
/// the daily target -- as notifiers seeded once at boot.
///
/// The same boot-time shape as `TrainingPlanLog`, for the same reason: a Diet
/// pane that flashed its first-time empty state at a user who has a plan would
/// say something false. Every number derived from this state lives in
/// `diet_derived.dart` and is computed on read (`docs/01` §Derived values);
/// nothing here stores a total.
///
/// **Writes go through the stores, then state is re-read or updated.** The
/// stores own the copy-on-write and the "this week only" rules (KTD5, KTD8)
/// and read their own clock at write time (KTD13), so these notifiers never
/// decide which week a write lands in.

/// What the Diet tables held when the app booted.
typedef StoredDiet = ({
  List<DietPlanVersion> versions,
  Set<MealTick> ticks,
  int? proteinTargetG,
});

/// Reads the plan series, every tick and the target. Called once per boot
/// from `main()`; the three reads run concurrently.
Future<StoredDiet> readStoredDiet(AppDatabase database) async {
  final (versions, ticks, target) = await (
    DietPlanStore(database).readVersions(),
    MealTickStore(database).read(),
    SettingsStore(database).readProteinTarget(),
  ).wait;
  return (
    versions: versions,
    ticks: Set<MealTick>.unmodifiable(ticks),
    proteinTargetG: target,
  );
}

// --- Plan -------------------------------------------------------------------

/// The plan series the app started with, oldest first.
final initialDietPlanProvider = Provider<List<DietPlanVersion>>(
  (ref) => const <DietPlanVersion>[],
);

/// Every plan version, oldest first, exactly as stored.
///
/// After each write the series is re-read rather than patched: a write may
/// have copied a whole earlier week forward under new ids, and re-reading is
/// the one way state cannot drift from what the store did. The series is a
/// few hundred rows at most.
class DietPlanLog extends Notifier<List<DietPlanVersion>> {
  @override
  List<DietPlanVersion> build() => ref.read(initialDietPlanProvider);

  DietPlanStore get _store => ref.read(dietPlanStoreProvider);

  Future<void> _reload() async => state = await _store.readVersions();

  /// See [DietPlanStore.addFood].
  Future<void> addFood({
    required Set<int> weekdays,
    required MealSlot slot,
    required String foodId,
    required int halves,
  }) async {
    await _store.addFood(
      weekdays: weekdays,
      slot: slot,
      foodId: foodId,
      halves: halves,
    );
    await _reload();
  }

  /// See [DietPlanStore.setServings].
  Future<void> setServings(DietPlanItem item, int halves) async {
    await _store.setServings(item, halves);
    await _reload();
  }

  /// See [DietPlanStore.removeItem]. Returns the removed row for undo.
  Future<DietPlanItem?> removeItem(DietPlanItem item) async {
    final removed = await _store.removeItem(item);
    await _reload();
    return removed;
  }

  /// See [DietPlanStore.restoreItem].
  Future<void> restoreItem(DietPlanItem item) async {
    await _store.restoreItem(item);
    await _reload();
  }
}

final dietPlanLogProvider =
    NotifierProvider<DietPlanLog, List<DietPlanVersion>>(DietPlanLog.new);

// --- Ticks ------------------------------------------------------------------

/// Every tick the app started with.
final initialMealTicksProvider = Provider<Set<MealTick>>(
  (ref) => const <MealTick>{},
);

/// Every meal ticked as eaten. Presence means eaten.
class MealTicksLog extends Notifier<Set<MealTick>> {
  @override
  Set<MealTick> build() => ref.read(initialMealTicksProvider);

  /// Ticks or unticks [slot] on [date] and returns whether it is ticked now.
  /// The store rejects a date outside this week up to today.
  Future<bool> toggle(LocalDate date, MealSlot slot) async {
    final ticked = await ref.read(mealTickStoreProvider).toggle(date, slot);
    final tick = MealTick(date: date, slot: slot);
    state = Set<MealTick>.unmodifiable(<MealTick>{
      ...state.where((t) => t != tick),
      if (ticked) tick,
    });
    return ticked;
  }
}

final mealTicksProvider =
    NotifierProvider<MealTicksLog, Set<MealTick>>(MealTicksLog.new);

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
