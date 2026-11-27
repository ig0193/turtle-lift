import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/diet_derived.dart';
import 'package:turtle_lift/src/data/diet_log.dart';
import 'package:turtle_lift/src/data/diet_log_store.dart';
import 'package:turtle_lift/src/data/food.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/today.dart';

/// Every number Diet shows is computed here, on read, from the log. These tests run on
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
  DietLogEntry entry(
    String foodId, {
    LocalDate? date,
    MealSlot slot = MealSlot.lunch,
    int halves = 2,
    int position = 0,
  }) =>
      DietLogEntry(
        id: 'e${nextId++}',
        date: date ?? nov(4),
        slot: slot,
        foodId: foodId,
        servingsHalves: halves,
        position: position,
      );

  group('rounding', () {
    test('three rows of 2.4 g total 7 g: rounded once on the total, not 6',
        () {
      final entries = <DietLogEntry>[entry('a'), entry('b'), entry('c')];
      expect(gramsOf(proteinUnitsOf(entries, foods)), 7);
      expect(
        entries
            .map((e) => gramsOf(proteinUnitsOf(<DietLogEntry>[e], foods)))
            .fold<int>(0, (a, b) => a + b),
        6,
        reason: 'summing rounded rows is the bug this guards against',
      );
    });

    test('half servings: 1.5 x 12.0 g is 18 g', () {
      expect(
          gramsOf(proteinUnitsOf(
              <DietLogEntry>[entry('twelve', halves: 3)], foods)),
          18);
    });

    test('a total of exactly half a gram rounds up', () {
      // 0.5 x 1.0 g = 0.5 g.
      final half = FoodIndex.fromJson(<Map<String, Object?>>[food('one', 1.0)]);
      expect(
          gramsOf(proteinUnitsOf(<DietLogEntry>[entry('one', halves: 1)], half)),
          1);
    });

    test('an unknown food counts 0 g', () {
      expect(proteinUnitsOf(<DietLogEntry>[entry('gone')], foods), 0);
    });
  });

  group('target arithmetic', () {
    test('AE1: 86 against 120 is 34 to go; 120 against 120 is 0', () {
      expect(toGoGrams(target: 120, logged: 86), 34);
      expect(toGoGrams(target: 120, logged: 120), 0);
    });

    test('to go clamps at 0 when logged exceeds the target', () {
      expect(toGoGrams(target: 100, logged: 130), 0);
    });

    test('the meter is logged over target, clamped to 0..1', () {
      expect(meterFraction(target: 120, logged: 60), 0.5);
      expect(meterFraction(target: 120, logged: 0), 0);
      expect(meterFraction(target: 100, logged: 130), 1);
    });
  });

  group('entriesOn', () {
    test('returns only the entries dated that day', () {
      final all = <DietLogEntry>[
        entry('a', date: nov(3)),
        entry('b', date: nov(4)),
        entry('c', date: nov(4), slot: MealSlot.dinner),
        entry('a', date: nov(5)),
      ];
      expect(entriesOn(all, nov(4)).map((e) => e.foodId), <String>['b', 'c']);
      expect(entriesOn(all, nov(6)), isEmpty);
    });

    test('a food logged on one weekday never shows on the next week\'s same '
        'weekday: there is no repeat', () {
      final all = <DietLogEntry>[entry('a', date: nov(4))];
      expect(entriesOn(all, nov(11)), isEmpty);
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
    // Wednesday the 4th has 86 g; Monday the 2nd has 12 + 28 = 40 g.
    final log = <DietLogEntry>[
      entry('forty-three', date: nov(4), slot: MealSlot.breakfast),
      entry('forty-three', date: nov(4), slot: MealSlot.lunch),
      entry('gone', date: nov(4), slot: MealSlot.snack, halves: 3),
      entry('twelve', date: nov(2), slot: MealSlot.lunch),
      entry('twenty-eight', date: nov(2), slot: MealSlot.dinner),
    ];

    DietDay day(LocalDate date, {int? target, List<DietLogEntry>? entries}) =>
        dietDayFor(
          date: date,
          entries: entries ?? log,
          target: target,
          foods: foods,
        );

    test('AE1: 86 of 120 logged with 34 to go and a meter', () {
      final d = day(nov(4), target: 120);
      expect(d.loggedG, 86);
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

    test('a day counts only its own entries', () {
      expect(day(nov(2)).loggedG, 40);
      expect(day(nov(3)).loggedG, 0);
      expect(day(nov(11)).loggedG, 0, reason: 'nothing repeats next week');
    });

    test('rows within a slot follow position, not insertion order', () {
      final d = day(nov(4), entries: <DietLogEntry>[
        entry('b', slot: MealSlot.snack, position: 1),
        entry('a', slot: MealSlot.snack, position: 0),
      ]);
      expect(d.slots[MealSlot.snack.index].items.map((i) => i.entry.foodId),
          <String>['a', 'b']);
    });

    test('a day with nothing logged is empty with the full target to go', () {
      final d = day(nov(3), target: 100);
      expect(d.loggedG, 0);
      expect(d.toGoG, 100);
      expect(d.isEmpty, isTrue);
      expect(d.slots.every((s) => s.isEmpty), isTrue);
    });

    test('logged at or past the target has 0 to go and a full meter', () {
      final d = day(nov(4), target: 50);
      expect(d.toGoG, 0);
      expect(d.meter, 1);
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
        dietLogStoreProvider
            .overrideWithValue(DietLogStore(database, today: () => nov(4))),
        ...extra,
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('editing the log moves dietDayProvider with no manual invalidation',
        () async {
      final c = container();
      final sub = c.listen(dietDayProvider(nov(4)), (_, _) {});
      addTearDown(sub.close);
      expect(sub.read().loggedG, 0);

      final log = c.read(dietLogProvider.notifier);
      await log.addFood(
          date: nov(4), slot: MealSlot.lunch, foodId: 'twelve', halves: 3);
      expect(c.read(dietDayProvider(nov(4))).loggedG, 18);

      final row = c
          .read(dietDayProvider(nov(4)))
          .slots[MealSlot.lunch.index]
          .items
          .single
          .entry;
      await log.setServings(row, 2);
      expect(c.read(dietDayProvider(nov(4))).loggedG, 12);

      final removed = await log.removeEntry(row);
      expect(c.read(dietDayProvider(nov(4))).loggedG, 0);
      await log.restoreEntry(removed!);
      expect(c.read(dietDayProvider(nov(4))).loggedG, 12);

      expect(await DietLogStore(database).readEntries(),
          c.read(dietLogProvider),
          reason: 'state is what was stored');
    });

    test('a write on one day leaves another day untouched', () async {
      final c = container();
      await c.read(dietLogProvider.notifier).addFood(
          date: nov(3), slot: MealSlot.lunch, foodId: 'twelve', halves: 2);
      await c.read(dietLogProvider.notifier).addFood(
          date: nov(4), slot: MealSlot.lunch, foodId: 'a', halves: 2);
      expect(c.read(dietDayProvider(nov(3))).loggedG, 12);
      expect(c.read(dietDayProvider(nov(4))).loggedG, 2);
    });

    test('the target feeds the day and persists', () async {
      final c = container(extra: [
        initialDietLogProvider.overrideWithValue(<DietLogEntry>[
          entry('twelve'),
        ]),
      ]);
      expect(c.read(dietDayProvider(nov(4))).loggedG, 12);

      await c.read(proteinTargetProvider.notifier).set(20);
      expect(c.read(dietDayProvider(nov(4))).toGoG, 8);
      expect(await SettingsStore(database).readProteinTarget(), 20);

      await c.read(proteinTargetProvider.notifier).clear();
      expect(c.read(dietDayProvider(nov(4))).targetG, isNull);
      expect(await SettingsStore(database).readProteinTarget(), isNull);
    });

    test('boot seeds read back what is stored', () async {
      final store = DietLogStore(database, today: () => nov(4));
      await store.addFood(
          date: nov(2), slot: MealSlot.dinner, foodId: 'a', halves: 2);
      await SettingsStore(database).writeProteinTarget(140);

      final stored = await readStoredDiet(database);
      expect(stored.entries, await store.readEntries());
      expect(stored.entries.single.date, nov(2));
      expect(stored.proteinTargetG, 140);
    });

    test('the strip is the seven days from its first day', () {
      final c = container();
      expect(c.read(dietStripProvider(nov(2))).map((d) => d.date),
          <LocalDate>[for (var d = 2; d <= 8; d++) nov(d)]);
    });

    test('the strip can start on any day, not only a Monday', () {
      final c = container();
      expect(c.read(dietStripProvider(nov(5))).map((d) => d.date),
          <LocalDate>[for (var d = 5; d <= 11; d++) nov(d)]);
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
