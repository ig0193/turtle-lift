import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/diet_derived.dart';
import 'package:turtle_lift/src/data/diet_plan.dart';
import 'package:turtle_lift/src/data/diet_plan_store.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/meal_ticks.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';

/// QA: Diet's planned, eaten and to-go figures after edits to a plan that is
/// already ticked, through the notifiers the screens call. Complements the
/// provider group in `diet_derived_test.dart`, which edits an unticked plan.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LocalDate nov(int day) => LocalDate(2026, 11, day); // 4th is a Wednesday

  Map<String, Object?> food(String id, double protein) => <String, Object?>{
    'id': id,
    'name': id,
    'aliases': const <String>[],
    'dietType': 'veg',
    'servingLabel': '1 katori, 100 g',
    'gramsPerServing': 100,
    'proteinPerServingG': protein,
    'proteinPer100g': protein,
    'ifctCode': 'X001',
    'reviewedBy': 'pending-owner-review',
  };
  final foods = FoodIndex.fromJson(<Map<String, Object?>>[
    food('paneer', 14),
    food('dal', 9),
  ]);

  late AppDatabase database;
  late ProviderContainer c;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        foodIndexProvider.overrideWithValue(foods),
        planClockProvider.overrideWithValue(() => nov(4)),
        dietPlanStoreProvider.overrideWithValue(
          DietPlanStore(database, today: () => nov(4)),
        ),
        mealTickStoreProvider.overrideWithValue(
          MealTickStore(database, today: () => nov(4)),
        ),
      ],
    );
  });
  tearDown(() async {
    c.dispose();
    await database.close();
  });

  DietPlanLog log() => c.read(dietPlanLogProvider.notifier);
  DietDay day(int d) => c.read(dietDayProvider(nov(d)));
  DietPlanItem only(int d, MealSlot slot) =>
      day(d).slots[slot.index].items.single.item;

  test(
    'A5: changing servings on a ticked slot changes that day\'s eaten',
    () async {
      await log().addFood(
        weekdays: <int>{0},
        slot: MealSlot.lunch,
        foodId: 'paneer',
        halves: 2,
      );
      await c.read(mealTicksProvider.notifier).toggle(nov(2), MealSlot.lunch);
      await c.read(proteinTargetProvider.notifier).set(40);
      expect(day(2).eatenG, 14);
      expect(day(2).toGoG, 26);

      await log().setServings(only(2, MealSlot.lunch), 3);
      expect(day(2).plannedG, 21);
      expect(day(2).eatenG, 21, reason: 'eaten is plan x ticks, read now');
      expect(day(2).toGoG, 19);
    },
  );

  test(
    'removing the only food of a ticked slot drops eaten, undo restores it',
    () async {
      await log().addFood(
        weekdays: <int>{1},
        slot: MealSlot.dinner,
        foodId: 'dal',
        halves: 2,
      );
      await c.read(mealTicksProvider.notifier).toggle(nov(3), MealSlot.dinner);
      expect(day(3).eatenG, 9);

      final removed = await log().removeItem(only(3, MealSlot.dinner));
      expect(day(3).plannedG, 0);
      expect(day(3).eatenG, 0, reason: 'a tick on an emptied slot counts 0 g');

      await log().restoreItem(removed!);
      expect(day(3).eatenG, 9, reason: 'the tick survived; the food is back');
    },
  );

  test('AE4: adding again with Repeat on Mon-Fri leaves one row per day at the '
      'new servings, and the week totals follow', () async {
    await log().addFood(
      weekdays: <int>{2},
      slot: MealSlot.lunch,
      foodId: 'paneer',
      halves: 2,
    );
    await log().addFood(
      weekdays: <int>{0, 1, 2, 3, 4},
      slot: MealSlot.lunch,
      foodId: 'paneer',
      halves: 4,
    );

    for (var d = 2; d <= 6; d++) {
      expect(day(d).slots[MealSlot.lunch.index].items, hasLength(1));
      expect(day(d).plannedG, 28);
    }
    expect(day(7).plannedG, 0, reason: 'Saturday was not chosen');
    expect(
      c.read(dietWeekProvider).fold<int>(0, (s, d) => s + d.plannedG),
      5 * 28,
    );
  });

  test('an edit never reaches a ticked day of an earlier week', () async {
    await log().addFood(
      weekdays: <int>{0},
      slot: MealSlot.lunch,
      foodId: 'paneer',
      halves: 2,
    );
    final lastWeek = c.read(dietPlanLogProvider);
    expect(lastWeek.single.effectiveFrom, nov(2));

    // Next week's Monday: an edit writes a new version from that Monday.
    final next = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        foodIndexProvider.overrideWithValue(foods),
        planClockProvider.overrideWithValue(() => nov(9)),
        initialDietPlanProvider.overrideWithValue(lastWeek),
        dietPlanStoreProvider.overrideWithValue(
          DietPlanStore(database, today: () => nov(9)),
        ),
      ],
    );
    addTearDown(next.dispose);
    await next
        .read(dietPlanLogProvider.notifier)
        .setServings(
          next
              .read(dietDayProvider(nov(9)))
              .slots[MealSlot.lunch.index]
              .items
              .single
              .item,
          4,
        );

    expect(next.read(dietDayProvider(nov(9))).plannedG, 28);
    expect(
      next.read(dietDayProvider(nov(2))).plannedG,
      14,
      reason: 'last Monday keeps the plan it was lived under',
    );
  });
}
