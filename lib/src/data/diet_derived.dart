import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bodyweight_resolution.dart';
import 'diet_plan.dart';
import 'diet_plan_store.dart';
import 'food.dart';
import 'food_index.dart';
import 'local_date.dart';
import 'meal_ticks.dart';
import 'settings_store.dart' show kMaxProteinTargetG, kMinProteinTargetG;
import 'training_plan.dart' show kWeekdayCount, planTodayProvider, startOfWeek;

/// Every number Diet shows, computed on read (R24, KTD13).
///
/// The rules, because each line is a bug someone will otherwise write:
///
/// * **Nothing here is stored.** Planned, eaten, to go, the meter and the
///   suggestion are functions of what the user entered plus the food list, so
///   an edited plan or a corrected food value moves every figure at once.
/// * **Round once, on the total, half up.** Three rows of 2.4 g are 7 g, not
///   the 6 g that summing rounded rows gives. Protein is summed exactly, as an
///   integer count of [kProteinUnitsPerGram]ths of a gram (one decimal of
///   protein per serving times a count of halves), so no float drift can move
///   a total across a rounding edge.
/// * **The plan in effect is resolved per week**: the latest version whose
///   Monday is on or before the date's Monday ([versionInEffectOn]).
/// * **Eaten is the planned protein of the ticked slots** under the plan in
///   effect that week. A tick on a slot that has since been emptied counts
///   nothing and shows nothing.

/// What an unknown food id renders as (R26). It counts 0 g and can still be
/// removed.
const String kUnknownFoodName = 'Unknown food';

/// Protein is summed in twentieths of a gram: tenths (the food list's one
/// decimal) times halves (the serving step).
const int kProteinUnitsPerGram = 20;

/// The protein of [halves] half-servings of [food], in protein units. An
/// unknown food is 0.
int proteinUnitsFor(Food? food, int halves) =>
    food == null ? 0 : (food.proteinPerServingG * 10).round() * halves;

/// The exact protein of [items], in protein units, unrounded.
int proteinUnitsOf(Iterable<DietPlanItem> items, FoodIndex foods) =>
    items.fold(
        0, (sum, i) => sum + proteinUnitsFor(foods.byId(i.foodId), i.servingsHalves));

/// Whole grams from protein units, half up. The one rounding step.
int gramsOf(int units) =>
    (units + kProteinUnitsPerGram ~/ 2) ~/ kProteinUnitsPerGram;

/// Grams still to plan to reach [target]; never below 0.
int toGoGrams({required int target, required int planned}) =>
    math.max(0, target - planned);

/// How full the planned-against-target bar is, 0 to 1.
double meterFraction({required int target, required int planned}) =>
    (planned / target).clamp(0.0, 1.0);

/// The version whose Monday is the latest on or before [date]'s Monday, or
/// null before the first version. [versions] may be in any order.
DietPlanVersion? versionInEffectOn(
    List<DietPlanVersion> versions, LocalDate date) {
  final monday = startOfWeek(date);
  DietPlanVersion? best;
  for (final v in versions) {
    if (v.effectiveFrom > monday) continue;
    if (best == null || v.effectiveFrom > best.effectiveFrom) best = v;
  }
  return best;
}

/// The plan items in force on [date]'s weekday; empty before any version.
List<DietPlanItem> itemsInEffectOn(
    List<DietPlanVersion> versions, LocalDate date) {
  final weekday = date.weekday - 1;
  return <DietPlanItem>[
    for (final item
        in versionInEffectOn(versions, date)?.items ?? const <DietPlanItem>[])
      if (item.weekday == weekday) item,
  ];
}

/// Whether a meal on [date] can be ticked: this week, up to and including
/// [today]. The same bounds `MealTickStore.toggle` enforces.
bool isTickable(LocalDate date, {required LocalDate today}) =>
    date >= startOfWeek(today) && date <= today;

/// The suggested daily target for a bodyweight of [kg]: 1.6 g per kg to the
/// nearest 5 g, halves rounding up (KTD12). Null without a bodyweight.
///
/// Computed as `kg × 16 / 50` fifths so 68.75 kg lands on exactly 110; the
/// tiny epsilon keeps a product that should be a whole number of fifths from
/// falling just under it. Kept inside the target's own bounds so accepting it
/// can always be stored.
int? suggestedTargetFor(double? kg) {
  if (kg == null) return null;
  // `round` is half away from zero, which is half up for a positive weight.
  final fifths = (kg * 16 / 50 + 1e-9).round();
  return (fifths * 5).clamp(kMinProteinTargetG, kMaxProteinTargetG);
}

// --- The day ----------------------------------------------------------------

/// One food row as Diet shows it.
@immutable
class DietDayItem {
  const DietDayItem({required this.item, required this.food});

  /// The stored row, which edits are made against.
  final DietPlanItem item;

  /// The food it names, or null when the id is not in the list.
  final Food? food;

  bool get isUnknown => food == null;

  String get name => food?.name ?? kUnknownFoodName;

  /// Servings as a number: 0.5 to 4.
  double get servings => item.servingsHalves / 2;

  /// This row's protein, exact. For display only; never summed.
  double get proteinG =>
      proteinUnitsFor(food, item.servingsHalves) / kProteinUnitsPerGram;
}

/// One meal slot on one day.
@immutable
class DietSlotDay {
  const DietSlotDay({
    required this.slot,
    required this.items,
    required this.proteinG,
    required this.ticked,
    required this.canTick,
  });

  final MealSlot slot;

  /// In the user's order.
  final List<DietDayItem> items;

  /// The slot total, rounded once.
  final int proteinG;

  /// Ticked as eaten. Never true on an empty slot.
  final bool ticked;

  /// Shows a tick control: a non-empty slot on a tickable day (R18).
  final bool canTick;

  bool get isEmpty => items.isEmpty;
}

/// One day of the plan with every figure Diet shows for it.
@immutable
class DietDay {
  const DietDay({
    required this.date,
    required this.slots,
    required this.plannedG,
    required this.eatenG,
    required this.targetG,
    required this.tickable,
  });

  final LocalDate date;

  /// The four slots, in [MealSlot] order.
  final List<DietSlotDay> slots;

  /// The day's planned protein, rounded once on the day total.
  final int plannedG;

  /// Planned protein of the ticked slots, rounded once.
  final int eatenG;

  /// The daily target, or null when none is set.
  final int? targetG;

  /// This week, up to today.
  final bool tickable;

  /// Grams still to plan, or null without a target. 0 once planned reaches
  /// the target, and the UI shows no "to go" line then (AE1).
  int? get toGoG =>
      targetG == null ? null : toGoGrams(target: targetG!, planned: plannedG);

  /// The planned-against-target bar, 0 to 1, or null without a target.
  double? get meter => targetG == null
      ? null
      : meterFraction(target: targetG!, planned: plannedG);

  bool get isEmpty => slots.every((s) => s.isEmpty);
}

/// Builds [date]'s [DietDay]. Pure; [dietDayProvider] binds it to state.
DietDay dietDayFor({
  required LocalDate date,
  required LocalDate today,
  required List<DietPlanVersion> versions,
  required Set<MealTick> ticks,
  required int? target,
  required FoodIndex foods,
}) {
  final items = itemsInEffectOn(versions, date);
  final tickable = isTickable(date, today: today);
  var plannedUnits = 0;
  var eatenUnits = 0;
  final slots = <DietSlotDay>[];
  for (final slot in MealSlot.values) {
    final inSlot = <DietPlanItem>[
      for (final i in items)
        if (i.slot == slot) i,
    ];
    final units = proteinUnitsOf(inSlot, foods);
    final ticked =
        inSlot.isNotEmpty && ticks.contains(MealTick(date: date, slot: slot));
    plannedUnits += units;
    if (ticked) eatenUnits += units;
    slots.add(DietSlotDay(
      slot: slot,
      items: List<DietDayItem>.unmodifiable(<DietDayItem>[
        for (final i in inSlot)
          DietDayItem(item: i, food: foods.byId(i.foodId)),
      ]),
      proteinG: gramsOf(units),
      ticked: ticked,
      canTick: tickable && inSlot.isNotEmpty,
    ));
  }
  return DietDay(
    date: date,
    slots: List<DietSlotDay>.unmodifiable(slots),
    plannedG: gramsOf(plannedUnits),
    eatenG: gramsOf(eatenUnits),
    targetG: target,
    tickable: tickable,
  );
}

// --- Providers --------------------------------------------------------------

/// One day of Diet, recomputed whenever the plan, the ticks, the target, the
/// food list or the date changes -- there is no refresh path to forget.
final dietDayProvider = Provider.family<DietDay, LocalDate>((ref, date) {
  return dietDayFor(
    date: date,
    today: ref.watch(planTodayProvider),
    versions: ref.watch(dietPlanLogProvider),
    ticks: ref.watch(mealTicksProvider),
    target: ref.watch(proteinTargetProvider),
    foods: ref.watch(foodIndexProvider),
  );
});

/// This week, Monday to Sunday, for the week strip.
final dietWeekProvider = Provider<List<DietDay>>((ref) {
  final monday = startOfWeek(ref.watch(planTodayProvider));
  return List<DietDay>.unmodifiable(<DietDay>[
    for (var i = 0; i < kWeekdayCount; i++)
      ref.watch(dietDayProvider(monday.addDays(i))),
  ]);
});

/// The suggested target from the bodyweight in effect today, or null when
/// there is none (R16). Never stored.
final suggestedTargetProvider = Provider<int?>((ref) {
  final today = ref.watch(planTodayProvider);
  final weight = ref.watch(weightInEffectProvider)(today.toDateTime());
  return suggestedTargetFor(weight?.weightKg);
});
