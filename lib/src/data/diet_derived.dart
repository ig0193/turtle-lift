import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bodyweight_resolution.dart';
import 'diet_log.dart';
import 'diet_log_store.dart';
import 'food.dart';
import 'food_index.dart';
import 'local_date.dart';
import 'settings_store.dart' show kMaxProteinTargetG, kMinProteinTargetG;
import 'today.dart' show kWeekdayCount, planTodayProvider;

/// Every number Diet shows, computed on read (R24, KTD13).
///
/// The rules, because each line is a bug someone will otherwise write:
///
/// * **Nothing here is stored.** Logged, to go, the meter and the suggestion
///   are functions of what the user entered plus the food list, so an edited
///   entry or a corrected food value moves every figure at once.
/// * **Round once, on the total, half up.** Three rows of 2.4 g are 7 g, not
///   the 6 g that summing rounded rows gives. Protein is summed exactly, as an
///   integer count of [kProteinUnitsPerGram]ths of a gram (one decimal of
///   protein per serving times a count of halves), so no float drift can move
///   a total across a rounding edge.
/// * **A day is the entries dated that day.** There is no plan to resolve and
///   no tick: a food in the log has been eaten and counts.

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

/// The exact protein of [entries], in protein units, unrounded.
int proteinUnitsOf(Iterable<DietLogEntry> entries, FoodIndex foods) =>
    entries.fold(
        0,
        (sum, e) =>
            sum + proteinUnitsFor(foods.byId(e.foodId), e.servingsHalves));

/// Whole grams from protein units, half up. The one rounding step.
int gramsOf(int units) =>
    (units + kProteinUnitsPerGram ~/ 2) ~/ kProteinUnitsPerGram;

/// Grams still to eat to reach [target]; never below 0.
int toGoGrams({required int target, required int logged}) =>
    math.max(0, target - logged);

/// How full the logged-against-target bar is, 0 to 1.
double meterFraction({required int target, required int logged}) =>
    (logged / target).clamp(0.0, 1.0);

/// The entries logged on [date].
List<DietLogEntry> entriesOn(List<DietLogEntry> entries, LocalDate date) =>
    <DietLogEntry>[
      for (final e in entries)
        if (e.date == date) e,
    ];

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
  const DietDayItem({required this.entry, required this.food});

  /// The stored row, which edits are made against.
  final DietLogEntry entry;

  /// The food it names, or null when the id is not in the list.
  final Food? food;

  bool get isUnknown => food == null;

  String get name => food?.name ?? kUnknownFoodName;

  /// Servings as a number: 0.5 to 4.
  double get servings => entry.servingsHalves / 2;

  /// This row's protein, exact. For display only; never summed.
  double get proteinG =>
      proteinUnitsFor(food, entry.servingsHalves) / kProteinUnitsPerGram;
}

/// One meal slot on one day.
@immutable
class DietSlotDay {
  const DietSlotDay({
    required this.slot,
    required this.items,
    required this.proteinG,
  });

  final MealSlot slot;

  /// In the user's order.
  final List<DietDayItem> items;

  /// The slot total, rounded once.
  final int proteinG;

  bool get isEmpty => items.isEmpty;
}

/// One day of the log with every figure Diet shows for it.
@immutable
class DietDay {
  const DietDay({
    required this.date,
    required this.slots,
    required this.loggedG,
    required this.targetG,
  });

  final LocalDate date;

  /// The four slots, in [MealSlot] order.
  final List<DietSlotDay> slots;

  /// The day's logged protein, rounded once on the day total.
  final int loggedG;

  /// The daily target, or null when none is set.
  final int? targetG;

  /// Grams still to eat, or null without a target. 0 once logged reaches the
  /// target, and the UI shows no "to go" line then (AE1).
  int? get toGoG =>
      targetG == null ? null : toGoGrams(target: targetG!, logged: loggedG);

  /// The logged-against-target bar, 0 to 1, or null without a target.
  double? get meter => targetG == null
      ? null
      : meterFraction(target: targetG!, logged: loggedG);

  bool get isEmpty => slots.every((s) => s.isEmpty);
}

/// Builds [date]'s [DietDay]. Pure; [dietDayProvider] binds it to state.
DietDay dietDayFor({
  required LocalDate date,
  required List<DietLogEntry> entries,
  required int? target,
  required FoodIndex foods,
}) {
  final day = entriesOn(entries, date)
    ..sort((a, b) => a.position.compareTo(b.position));
  var loggedUnits = 0;
  final slots = <DietSlotDay>[];
  for (final slot in MealSlot.values) {
    final inSlot = <DietLogEntry>[
      for (final e in day)
        if (e.slot == slot) e,
    ];
    final units = proteinUnitsOf(inSlot, foods);
    loggedUnits += units;
    slots.add(DietSlotDay(
      slot: slot,
      items: List<DietDayItem>.unmodifiable(<DietDayItem>[
        for (final e in inSlot) DietDayItem(entry: e, food: foods.byId(e.foodId)),
      ]),
      proteinG: gramsOf(units),
    ));
  }
  return DietDay(
    date: date,
    slots: List<DietSlotDay>.unmodifiable(slots),
    loggedG: gramsOf(loggedUnits),
    targetG: target,
  );
}

// --- Providers --------------------------------------------------------------

/// One day of Diet, recomputed whenever the log, the target, the food list or
/// the date changes -- there is no refresh path to forget.
final dietDayProvider = Provider.family<DietDay, LocalDate>((ref, date) {
  return dietDayFor(
    date: date,
    entries: ref.watch(dietLogProvider),
    target: ref.watch(proteinTargetProvider),
    foods: ref.watch(foodIndexProvider),
  );
});

/// The seven days from [start], for the week strip's meters.
///
/// Keyed by the strip's first day, not by "this week": the strip is a window
/// that slides one day at a time and can sit on any run of seven days
/// (`docs/adr/0017-diet-date-picker.md`).
final dietStripProvider =
    Provider.family<List<DietDay>, LocalDate>((ref, start) {
  return List<DietDay>.unmodifiable(<DietDay>[
    for (var i = 0; i < kWeekdayCount; i++)
      ref.watch(dietDayProvider(start.addDays(i))),
  ]);
});

/// The days with anything logged, for the date picker's markers. Derived from
/// the log, so an add, an edit or a remove moves a marker with no refresh.
final dietLoggedDatesProvider = Provider<Set<LocalDate>>((ref) {
  return <LocalDate>{for (final e in ref.watch(dietLogProvider)) e.date};
});

/// The suggested target from the bodyweight in effect today, or null when
/// there is none (R16). Never stored.
final suggestedTargetProvider = Provider<int?>((ref) {
  final today = ref.watch(planTodayProvider);
  final weight = ref.watch(weightInEffectProvider)(today.toDateTime());
  return suggestedTargetFor(weight?.weightKg);
});
