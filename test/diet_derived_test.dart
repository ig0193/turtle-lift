import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/diet_derived.dart';
import 'package:turtle_lift/src/data/diet_plan.dart';
import 'package:turtle_lift/src/data/diet_plan_store.dart';
import 'package:turtle_lift/src/data/food.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_ticks.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';

/// Every number Diet shows is computed here, on read. These tests run on
/// fixture foods, never the shipped list: its values are still under owner
/// review (U19) and a test pinned to them would break on every pass.
///
/// November 2026: Monday is the 2nd, 9th, 16th; Sunday the 8th, 15th.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LocalDate nov(int day) => LocalDate(2026, 11, day);

  Map<String, Object?> food(String id, double protein) => <String, Object?>{
        'id': id,
        'name': 'Food $id',
        'aliases': const <String>[],
        'dietType': 'veg',
        'servingLabel': '1 bowl, 100 g',
        'gramsPerServing': 100,
        'proteinPerServingG': protein,
        'proteinPer100g': protein,
        'ifctCode': 'X001',
        'reviewedBy': 'pending-owner-review',
      };

  final foods = FoodIndex.fromJson(<Map<String, Object?>>[
    food('a', 2.4),
    food('b', 2.4),
    food('c', 2.4),
    food('twelve', 12.0),
    food('forty-three', 43.0),
    food('twenty-eight', 28.0),
  ]);

  var nextId = 0;
  DietPlanItem item(
    String foodId, {
    int weekday = 2,
    MealSlot slot = MealSlot.lunch,
    int halves = 2,
    int position = 0,
  }) =>
      DietPlanItem(
        id: 'i${nextId++}',
        weekday: weekday,
        slot: slot,
        foodId: foodId,
        servingsHalves: halves,
        position: position,
      );

  DietPlanVersion version(int mondayDay, List<DietPlanItem> items) =>
      DietPlanVersion(effectiveFrom: nov(mondayDay), items: items);

  group('rounding', () {
    test('three rows of 2.4 g total 7 g: rounded once on the total, not 6',
        () {
      final items = <DietPlanItem>[item('a'), item('b'), item('c')];
      expect(gramsOf(proteinUnitsOf(items, foods)), 7);
      expect(
        items.map((i) => gramsOf(proteinUnitsOf(<DietPlanItem>[i], foods)))
            .fold<int>(0, (a, b) => a + b),
        6,
        reason: 'summing rounded rows is the bug this guards against',
      );
    });

    test('half servings: 1.5 x 12.0 g is 18 g', () {
      expect(gramsOf(proteinUnitsOf(<DietPlanItem>[item('twelve', halves: 3)],
          foods)), 18);
    });

    test('a total of exactly half a gram rounds up', () {
      // 0.5 x 1.0 g = 0.5 g.
      final half = FoodIndex.fromJson(<Map<String, Object?>>[food('one', 1.0)]);
      expect(gramsOf(proteinUnitsOf(
          <DietPlanItem>[item('one', halves: 1)], half)), 1);
    });

    test('an unknown food counts 0 g', () {
      expect(proteinUnitsOf(<DietPlanItem>[item('gone')], foods), 0);
    });
  });

  group('target arithmetic', () {
    test('AE1: 86 against 120 is 34 to go; 120 against 120 is 0', () {
      expect(toGoGrams(target: 120, planned: 86), 34);
      expect(toGoGrams(target: 120, planned: 120), 0);
    });

    test('to go clamps at 0 when planned exceeds the target', () {
      expect(toGoGrams(target: 100, planned: 130), 0);
    });

    test('the meter is planned over target, clamped to 0..1', () {
      expect(meterFraction(target: 120, planned: 60), 0.5);
      expect(meterFraction(target: 120, planned: 0), 0);
      expect(meterFraction(target: 100, planned: 130), 1);
    });
  });

  group('version in effect', () {
    final versions = <DietPlanVersion>[
      version(2, <DietPlanItem>[item('twelve')]),
      version(16, <DietPlanItem>[item('a')]),
    ];

    test('a week with its own version uses it', () {
      expect(versionInEffectOn(versions, nov(18))!.effectiveFrom, nov(16));
      expect(versionInEffectOn(versions, nov(16))!.effectiveFrom, nov(16));
    });

    test('a week with no version resolves to the latest earlier one', () {
      expect(versionInEffectOn(versions, nov(12))!.effectiveFrom, nov(2));
      expect(versionInEffectOn(versions, nov(15))!.effectiveFrom, nov(2),
          reason: 'Sunday the 15th is still the week of the 9th');
    });

    test('a date before any version resolves to an empty plan', () {
      expect(versionInEffectOn(versions, nov(1)), isNull);
      expect(itemsInEffectOn(versions, nov(1)), isEmpty);
    });

    test('any list order resolves the same way', () {
      expect(versionInEffectOn(versions.reversed.toList(), nov(12))!
          .effectiveFrom, nov(2));
    });
  });

  group('tickable', () {
    test('Sunday of this week is tickable on Sunday', () {
      expect(isTickable(nov(8), today: nov(8)), isTrue);
      expect(isTickable(nov(2), today: nov(8)), isTrue);
    });

    test('on the following Monday, last Sunday is not', () {
      expect(isTickable(nov(8), today: nov(9)), isFalse);
      expect(isTickable(nov(9), today: nov(9)), isTrue);
    });

    test('a future day is not tickable', () {
      expect(isTickable(nov(5), today: nov(4)), isFalse);
    });
  });

  group('suggestion', () {
    test('1.6 g per kg to the nearest 5 g, halves up', () {
      expect(suggestedTargetFor(72), 115, reason: '115.2');
      expect(suggestedTargetFor(71.9), 115, reason: '115.04');
      expect(suggestedTargetFor(73.5), 120, reason: '117.6');
      expect(suggestedTargetFor(68.75), 110, reason: 'exactly 110');
      expect(suggestedTargetFor(73.4375), 120, reason: '117.5 rounds up');
    });

    test('no bodyweight gives no suggestion', () {
      expect(suggestedTargetFor(null), isNull);
    });
  });

  group('a day', () {
    // Wednesday the 4th; today is Wednesday unless a test says otherwise.
    final plan = <DietPlanVersion>[
      version(2, <DietPlanItem>[
        item('forty-three', weekday: 2, slot: MealSlot.breakfast),
        item('forty-three', weekday: 2, slot: MealSlot.lunch),
        item('twelve', weekday: 0, slot: MealSlot.lunch),
        item('twenty-eight', weekday: 0, slot: MealSlot.dinner),
        item('gone', weekday: 2, slot: MealSlot.snack, halves: 3),
      ]),
    ];

    DietDay day(
      LocalDate date, {
      LocalDate? today,
      int? target,
      Set<MealTick> ticks = const <MealTick>{},
      List<DietPlanVersion>? versions,
    }) =>
        dietDayFor(
          date: date,
          today: today ?? nov(4),
          versions: versions ?? plan,
          ticks: ticks,
          target: target,
          foods: foods,
        );

    test('AE1: 86 of 120 planned with 34 to go and a meter', () {
      final d = day(nov(4), target: 120);
      expect(d.plannedG, 86);
      expect(d.toGoG, 34);
      expect(d.meter, closeTo(86 / 120, 1e-9));
      expect(d.slots.map((s) => s.slot), MealSlot.values);
      expect(d.slots.first.proteinG, 43);
    });

    test('no target means no to go and no meter', () {
      final d = day(nov(4));
      expect(d.targetG, isNull);
      expect(d.toGoG, isNull);
      expect(d.meter, isNull);
    });

    test('an unknown food is named, counts 0 g and is still listed', () {
      final snack = day(nov(4)).slots[MealSlot.snack.index];
      expect(snack.items.single.isUnknown, isTrue);
      expect(snack.items.single.name, kUnknownFoodName);
      expect(snack.items.single.servings, 1.5);
      expect(snack.proteinG, 0);
      expect(snack.isEmpty, isFalse, reason: 'it can still be removed');
    });

    test('AE3: a ticked Monday lunch reads 12 g eaten; Friday has no tick',
        () {
      final ticks = <MealTick>{MealTick(date: nov(2), slot: MealSlot.lunch)};
      final monday = day(nov(2), ticks: ticks);
      expect(monday.eatenG, 12);
      expect(monday.slots[MealSlot.lunch.index].ticked, isTrue);
      expect(monday.slots[MealSlot.lunch.index].canTick, isTrue);
      final friday = day(nov(6), ticks: ticks);
      expect(friday.tickable, isFalse);
      expect(friday.slots.every((s) => !s.canTick), isTrue);
    });

    test('an empty slot cannot be ticked', () {
      final monday = day(nov(2));
      expect(monday.slots[MealSlot.breakfast.index].isEmpty, isTrue);
      expect(monday.slots[MealSlot.breakfast.index].canTick, isFalse);
    });

    test('eaten ignores a tick on a slot that has since become empty', () {
      final ticks = <MealTick>{
        MealTick(date: nov(2), slot: MealSlot.breakfast), // empty slot
        MealTick(date: nov(2), slot: MealSlot.dinner),
      };
      final monday = day(nov(2), ticks: ticks);
      expect(monday.eatenG, 28);
      expect(monday.slots[MealSlot.breakfast.index].ticked, isFalse,
          reason: 'no tick is ever shown on an empty slot');
    });

    test('eaten uses the plan in effect that week', () {
      final versions = <DietPlanVersion>[
        ...plan,
        version(9, <DietPlanItem>[
          item('a', weekday: 0, slot: MealSlot.lunch),
        ]),
      ];
      final ticks = <MealTick>{
        MealTick(date: nov(2), slot: MealSlot.lunch),
        MealTick(date: nov(9), slot: MealSlot.lunch),
      };
      expect(day(nov(2), today: nov(10), versions: versions, ticks: ticks)
          .eatenG, 12);
      expect(day(nov(9), today: nov(10), versions: versions, ticks: ticks)
          .eatenG, 2);
    });

    test('a date before any version is an empty day', () {
      final d = day(LocalDate(2026, 10, 30), target: 100);
      expect(d.plannedG, 0);
      expect(d.toGoG, 100);
      expect(d.slots.every((s) => s.isEmpty), isTrue);
    });
  });

  group('providers', () {
    late AppDatabase database;
    setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => database.close());

    ProviderContainer container({
      List<Override> extra = const <Override>[],
    }) {
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(database),
        foodIndexProvider.overrideWithValue(foods),
        planTodayProvider.overrideWithValue(nov(4)),
        dietPlanStoreProvider
            .overrideWithValue(DietPlanStore(database, today: () => nov(4))),
        mealTickStoreProvider
            .overrideWithValue(MealTickStore(database, today: () => nov(4))),
        ...extra,
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('editing the plan moves dietDayProvider with no manual invalidation',
        () async {
      final c = container();
      final sub = c.listen(dietDayProvider(nov(4)), (_, _) {});
      addTearDown(sub.close);
      expect(sub.read().plannedG, 0);

      final log = c.read(dietPlanLogProvider.notifier);
      await log.addFood(
          weekdays: <int>{2}, slot: MealSlot.lunch, foodId: 'twelve', halves: 3);
      expect(c.read(dietDayProvider(nov(4))).plannedG, 18);

      final row = c.read(dietDayProvider(nov(4)))
          .slots[MealSlot.lunch.index].items.single.item;
      await log.setServings(row, 2);
      expect(c.read(dietDayProvider(nov(4))).plannedG, 12);

      final removed = await log.removeItem(row);
      expect(c.read(dietDayProvider(nov(4))).plannedG, 0);
      await log.restoreItem(removed!);
      expect(c.read(dietDayProvider(nov(4))).plannedG, 12);

      expect(await DietPlanStore(database).readVersions(),
          c.read(dietPlanLogProvider),
          reason: 'state is what was stored');
    });

    test('ticks and the target feed the day and persist', () async {
      final c = container(extra: [
        initialDietPlanProvider.overrideWithValue(<DietPlanVersion>[
          version(2, <DietPlanItem>[item('twelve', weekday: 2)]),
        ]),
      ]);
      expect(await c.read(mealTicksProvider.notifier)
          .toggle(nov(4), MealSlot.lunch), isTrue);
      expect(c.read(dietDayProvider(nov(4))).eatenG, 12);

      await c.read(proteinTargetProvider.notifier).set(20);
      expect(c.read(dietDayProvider(nov(4))).toGoG, 8);
      expect(await SettingsStore(database).readProteinTarget(), 20);

      await c.read(proteinTargetProvider.notifier).clear();
      expect(c.read(dietDayProvider(nov(4))).targetG, isNull);
      expect(await SettingsStore(database).readProteinTarget(), isNull);

      expect(await c.read(mealTicksProvider.notifier)
          .toggle(nov(4), MealSlot.lunch), isFalse);
      expect(c.read(dietDayProvider(nov(4))).eatenG, 0);
      expect(await MealTickStore(database).read(), isEmpty);
    });

    test('boot seeds read back what is stored', () async {
      final plans = DietPlanStore(database, today: () => nov(4));
      await plans.addFood(
          weekdays: <int>{0}, slot: MealSlot.dinner, foodId: 'a', halves: 2);
      await MealTickStore(database, today: () => nov(4))
          .toggle(nov(2), MealSlot.dinner);
      await SettingsStore(database).writeProteinTarget(140);

      final stored = await readStoredDiet(database);
      expect(stored.versions, await plans.readVersions());
      expect(stored.ticks,
          <MealTick>{MealTick(date: nov(2), slot: MealSlot.dinner)});
      expect(stored.proteinTargetG, 140);
    });

    test('the week is Monday to Sunday of today', () {
      final c = container();
      expect(c.read(dietWeekProvider).map((d) => d.date),
          <LocalDate>[for (var d = 2; d <= 8; d++) nov(d)]);
    });

    test('the suggestion reads the bodyweight in effect today', () {
      final none = container();
      expect(none.read(suggestedTargetProvider), isNull);

      final c = container(extra: [
        initialBodyweightLogProvider.overrideWithValue(<BodyweightEntry>[
          BodyweightEntry(date: DateTime(2026, 10, 1), weightKg: 72),
          BodyweightEntry(date: DateTime(2026, 11, 20), weightKg: 90),
        ]),
      ]);
      expect(c.read(suggestedTargetProvider), 115,
          reason: 'the later weigh-in is not in effect on the 4th');
    });
  });
}
