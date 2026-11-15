import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/diet_derived.dart';
import 'package:turtle_lift/src/data/diet_log.dart';
import 'package:turtle_lift/src/data/diet_log_store.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/today.dart';

/// QA: Diet's logged and to-go figures after edits to a day that already has
/// food in it, through the notifiers the screens call. Complements the
/// provider group in `diet_derived_test.dart`, which starts from an empty log.
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
        dietLogStoreProvider.overrideWithValue(
          DietLogStore(database, today: () => nov(4)),
        ),
      ],
    );
  });
  tearDown(() async {
    c.dispose();
    await database.close();
  });

  DietLog log() => c.read(dietLogProvider.notifier);
  DietDay day(int d) => c.read(dietDayProvider(nov(d)));
  DietLogEntry only(int d, MealSlot slot) =>
      day(d).slots[slot.index].items.single.entry;

  test('A5: changing servings on a logged slot changes that day\'s total',
      () async {
    await log().addFood(
      date: nov(2),
      slot: MealSlot.lunch,
      foodId: 'paneer',
      halves: 2,
    );
    await c.read(proteinTargetProvider.notifier).set(40);
    expect(day(2).loggedG, 14);
    expect(day(2).toGoG, 26);

    await log().setServings(only(2, MealSlot.lunch), 3);
    expect(day(2).loggedG, 21, reason: 'derived on read, nothing stored');
    expect(day(2).toGoG, 19);
  });

  test('removing the only food of a slot empties it, undo restores it',
      () async {
    await log().addFood(
      date: nov(3),
      slot: MealSlot.dinner,
      foodId: 'dal',
      halves: 2,
    );
    expect(day(3).loggedG, 9);

    final removed = await log().removeEntry(only(3, MealSlot.dinner));
    expect(day(3).loggedG, 0);
    expect(day(3).slots[MealSlot.dinner.index].isEmpty, isTrue);

    await log().restoreEntry(removed!);
    expect(day(3).loggedG, 9);
    expect(only(3, MealSlot.dinner).servingsHalves, 2);
  });

  test('AE4: adding the same food again leaves one row at the new servings',
      () async {
    await log().addFood(
      date: nov(4),
      slot: MealSlot.lunch,
      foodId: 'paneer',
      halves: 2,
    );
    await log().addFood(
      date: nov(4),
      slot: MealSlot.lunch,
      foodId: 'paneer',
      halves: 4,
    );

    expect(day(4).slots[MealSlot.lunch.index].items, hasLength(1));
    expect(day(4).loggedG, 28);
  });

  test('an edit on one day never reaches another day or another week',
      () async {
    await log().addFood(
      date: nov(2),
      slot: MealSlot.lunch,
      foodId: 'paneer',
      halves: 2,
    );
    await log().addFood(
      date: nov(4),
      slot: MealSlot.lunch,
      foodId: 'paneer',
      halves: 2,
    );

    await log().setServings(only(4, MealSlot.lunch), 4);
    expect(day(4).loggedG, 28);
    expect(day(2).loggedG, 14, reason: 'Monday keeps what was logged on it');
    expect(day(9).loggedG, 0, reason: 'nothing repeats next week');
    expect(
      c.read(dietStripProvider(nov(2))).fold<int>(0, (s, d) => s + d.loggedG),
      14 + 28,
    );
  });
}
