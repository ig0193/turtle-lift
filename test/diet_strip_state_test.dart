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
import 'package:turtle_lift/src/ui/diet_pane.dart';

/// The state behind the Diet strip and the date picker's markers
/// (`docs/adr/0017-diet-date-picker.md`): where the seven-day window starts,
/// how it moves, and which days have anything logged.
///
/// "Today" is Wednesday 4 November 2026, so the strip opens on Monday the 2nd.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LocalDate nov(int day) => LocalDate(2026, 11, day);
  LocalDate oct(int day) => LocalDate(2026, 10, day);

  late AppDatabase database;
  late LocalDate clock;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    clock = nov(4);
  });
  tearDown(() => database.close());

  final foods = FoodIndex.fromJson(<Map<String, Object?>>[
    <String, Object?>{
      'id': 'paneer',
      'name': 'Paneer',
      'aliases': const <String>[],
      'dietType': 'veg',
      'servingLabel': '1 katori, 100 g',
      'gramsPerServing': 100,
      'proteinPerServingG': 9.4,
      'proteinPer100g': 9.4,
      'ifctCode': 'X001',
      'reviewedBy': 'pending-owner-review',
    },
  ]);

  /// A container whose "today" is [clock], moved by the test.
  ProviderContainer container({List<DietLogEntry> log = const []}) {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(database),
      dietLogStoreProvider
          .overrideWithValue(DietLogStore(database, today: () => clock)),
      planClockProvider.overrideWithValue(() => clock),
      foodIndexProvider.overrideWithValue(foods),
      initialDietLogProvider.overrideWithValue(log),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('DietStripStart', () {
    test('opens on the Monday of this week', () {
      final c = container();
      expect(c.read(dietStripStartProvider), nov(2));
    });

    test('on a Monday it is that same day, on a Sunday the Monday before', () {
      clock = nov(2);
      expect(container().read(dietStripStartProvider), nov(2));

      clock = nov(8); // a Sunday
      expect(container().read(dietStripStartProvider), nov(2));

      clock = nov(9); // the next Monday
      expect(container().read(dietStripStartProvider), nov(9));
    });

    test('shift moves it one day at a time, either way', () {
      final c = container();
      final start = c.read(dietStripStartProvider.notifier);

      start.shift(-1);
      expect(c.read(dietStripStartProvider), nov(1));
      start.shift(-1);
      expect(c.read(dietStripStartProvider), oct(31));
      start.shift(1);
      expect(c.read(dietStripStartProvider), nov(1));
    });

    test('shift can move by several days at once', () {
      final c = container();
      c.read(dietStripStartProvider.notifier).shift(-9);
      expect(c.read(dietStripStartProvider), oct(24));
      c.read(dietStripStartProvider.notifier).shift(3);
      expect(c.read(dietStripStartProvider), oct(27));
    });

    test('it never slides past this week\'s Monday', () {
      final c = container();
      final start = c.read(dietStripStartProvider.notifier);

      start.shift(1);
      expect(c.read(dietStripStartProvider), nov(2),
          reason: 'already on this week\'s Monday');

      start.shift(-3);
      start.shift(10);
      expect(c.read(dietStripStartProvider), nov(2),
          reason: 'a big step forward stops at this week\'s Monday');
    });

    test('it clamps at the lookback, however far it is asked to go', () {
      final c = container();
      final start = c.read(dietStripStartProvider.notifier);
      final earliest = nov(4).addDays(-kDietStripLookbackDays);

      start.shift(-100000);
      expect(c.read(dietStripStartProvider), earliest);

      start.shift(-1);
      expect(c.read(dietStripStartProvider), earliest,
          reason: 'there is nothing before it');

      start.shift(1);
      expect(c.read(dietStripStartProvider), earliest.addDays(1),
          reason: 'and it moves forward from there');
      expect(kDietStripLookbackDays, 3650);
    });

    test('showWeekOf jumps to the Monday of that date\'s week', () {
      final c = container();
      final start = c.read(dietStripStartProvider.notifier);

      start.showWeekOf(oct(28)); // a Wednesday
      expect(c.read(dietStripStartProvider), oct(26));

      start.showWeekOf(nov(1)); // a Sunday: still the week of the 26th
      expect(c.read(dietStripStartProvider), oct(26));

      start.showWeekOf(oct(26)); // a Monday: itself
      expect(c.read(dietStripStartProvider), oct(26));

      start.showWeekOf(LocalDate(2025, 12, 30)); // a Tuesday, last year
      expect(c.read(dietStripStartProvider), LocalDate(2025, 12, 29));
    });

    test('showWeekOf resets whatever shift had done', () {
      final c = container();
      final start = c.read(dietStripStartProvider.notifier);
      start.shift(-5);

      start.showWeekOf(nov(3));

      expect(c.read(dietStripStartProvider), nov(2));
    });

    test('a new today puts it back on this week, a resume on the same one '
        'does not', () {
      final c = container();
      final start = c.read(dietStripStartProvider.notifier);
      start.shift(-3);
      expect(c.read(dietStripStartProvider), oct(30));

      // A resume that finds the same date changes nothing downstream.
      c.invalidate(planTodayProvider);
      expect(c.read(dietStripStartProvider), oct(30),
          reason: 'LocalDate compares by value, so the strip is not rebuilt');

      // A resume across midnight into next week snaps it back.
      clock = nov(11);
      c.invalidate(planTodayProvider);
      expect(c.read(dietStripStartProvider), nov(9),
          reason: 'the Monday of the week that is now this week');
    });

    test('a new today also moves the bound it slides to', () {
      final c = container();
      clock = nov(11);
      c.invalidate(planTodayProvider);
      final start = c.read(dietStripStartProvider.notifier);

      start.shift(-2);
      start.shift(10);

      expect(c.read(dietStripStartProvider), nov(9),
          reason: 'forward stops at the new this-week Monday');
    });
  });

  group('dietStripProvider', () {
    test('is seven days from the start it is given, in order', () {
      final c = container();

      expect(c.read(dietStripProvider(oct(30))).map((d) => d.date),
          <LocalDate>[
        oct(30),
        oct(31),
        nov(1),
        nov(2),
        nov(3),
        nov(4),
        nov(5),
      ]);
    });

    test('carries each day\'s logged protein, so the meters follow the window',
        () async {
      final c = container();
      await c.read(dietLogProvider.notifier).addFood(
            date: nov(2),
            slot: MealSlot.lunch,
            foodId: 'paneer',
            halves: 2,
          );

      final strip = c.read(dietStripProvider(nov(1)));
      expect(strip.map((d) => d.loggedG), <int>[0, 9, 0, 0, 0, 0, 0],
          reason: 'one serving of paneer is 9 g, on the 2nd only');

      final slid = c.read(dietStripProvider(oct(31)));
      expect(slid.map((d) => d.loggedG), <int>[0, 0, 9, 0, 0, 0, 0],
          reason: 'the same day, one position later after sliding back');
    });
  });

  group('dietLoggedDatesProvider', () {
    DietLogEntry entry(LocalDate date, String foodId, MealSlot slot) =>
        DietLogEntry(
          id: '$foodId-${date.encode()}-${slot.name}',
          date: date,
          slot: slot,
          foodId: foodId,
          servingsHalves: 2,
          position: 0,
        );

    test('is empty with nothing logged', () {
      expect(container().read(dietLoggedDatesProvider), isEmpty);
    });

    test('holds each day once, however many foods it has', () {
      final c = container(log: <DietLogEntry>[
        entry(nov(2), 'a', MealSlot.breakfast),
        entry(nov(2), 'b', MealSlot.lunch),
        entry(nov(2), 'c', MealSlot.dinner),
        entry(oct(28), 'a', MealSlot.snack),
      ]);

      expect(c.read(dietLoggedDatesProvider), <LocalDate>{nov(2), oct(28)});
    });

    test('gains a day when a food is logged on it', () async {
      final c = container();
      expect(c.read(dietLoggedDatesProvider), isEmpty);

      await c.read(dietLogProvider.notifier).addFood(
            date: oct(28),
            slot: MealSlot.snack,
            foodId: 'soya',
            halves: 2,
          );

      expect(c.read(dietLoggedDatesProvider), <LocalDate>{oct(28)});
    });

    test('loses a day when its last food is removed, and not before',
        () async {
      final c = container();
      final log = c.read(dietLogProvider.notifier);
      await log.addFood(
          date: nov(3), slot: MealSlot.lunch, foodId: 'a', halves: 2);
      await log.addFood(
          date: nov(3), slot: MealSlot.dinner, foodId: 'b', halves: 2);
      expect(c.read(dietLoggedDatesProvider), <LocalDate>{nov(3)});

      final first = c.read(dietLogProvider).first;
      await log.removeEntry(first);
      expect(c.read(dietLoggedDatesProvider), <LocalDate>{nov(3)},
          reason: 'one food is still logged that day');

      await log.removeEntry(c.read(dietLogProvider).single);
      expect(c.read(dietLoggedDatesProvider), isEmpty);
    });

    test('a removed food comes back with Undo', () async {
      final c = container();
      final log = c.read(dietLogProvider.notifier);
      await log.addFood(
          date: nov(3), slot: MealSlot.lunch, foodId: 'a', halves: 2);
      final removed = await log.removeEntry(c.read(dietLogProvider).single);
      expect(c.read(dietLoggedDatesProvider), isEmpty);

      await log.restoreEntry(removed!);

      expect(c.read(dietLoggedDatesProvider), <LocalDate>{nov(3)});
    });

    test('a past day can be logged on, and shows up beside today\'s',
        () async {
      final c = container();
      final log = c.read(dietLogProvider.notifier);

      await log.addFood(
          date: oct(20), slot: MealSlot.lunch, foodId: 'a', halves: 2);
      await log.addFood(
          date: nov(4), slot: MealSlot.lunch, foodId: 'a', halves: 2);

      expect(c.read(dietLoggedDatesProvider), <LocalDate>{oct(20), nov(4)});
    });

    test('a day that has not happened cannot be logged, so it never shows',
        () async {
      final c = container();

      await expectLater(
        c.read(dietLogProvider.notifier).addFood(
            date: nov(5), slot: MealSlot.lunch, foodId: 'a', halves: 2),
        throwsArgumentError,
      );

      expect(c.read(dietLoggedDatesProvider), isEmpty);
    });
  });
}
