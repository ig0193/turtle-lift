import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';

/// QA: the calendar-date edges, with every clock injected.
///
/// The single most likely way to get these wrong in the field is an app left
/// open across midnight: the UI's "today" is cached until the next resume
/// (`planTodayProvider`), while the stores read the wall clock at write time.
/// `diet_derived_test` and `diet_log_store_test` prove each side alone; this
/// proves them together across the Sunday-to-Monday edge, where "this week"
/// changes.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LocalDate nov(int day) => LocalDate(2026, 11, day); // 8th is a Sunday

  test('a 23:59:59 log files on its own local day, 00:00 on the next', () {
    expect(LocalDate.fromDateTime(DateTime(2026, 11, 8, 23, 59, 59)), nov(8));
    expect(LocalDate.fromDateTime(DateTime(2026, 11, 9)), nov(9));
    expect(
      LocalDate.fromDateTime(DateTime(2026, 12, 31, 23, 59, 59)),
      LocalDate(2026, 12, 31),
    );
    expect(startOfWeek(nov(8)), nov(2), reason: 'Sunday ends the week');
    expect(startOfWeek(nov(9)), nov(9), reason: 'Monday starts the next');
  });

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
  final foods = FoodIndex.fromJson(<Map<String, Object?>>[food('twelve', 12)]);

  late AppDatabase database;
  late LocalDate wallClock;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    wallClock = nov(8);
  });
  tearDown(() => database.close());

  List<Override> clockedOverrides() => <Override>[
    appDatabaseProvider.overrideWithValue(database),
    foodIndexProvider.overrideWithValue(foods),
    // The UI's today and the stores' today read one wall clock, as in the
    // app; only the UI caches it until a resume.
    planClockProvider.overrideWithValue(() => wallClock),
    dietLogStoreProvider.overrideWithValue(
      DietLogStore(database, today: () => wallClock),
    ),
  ];

  group('Diet left open from Sunday night into Monday', () {
    test('a log written after midnight lands on the day it was logged for, '
        'the pane follows the real today, and Sunday is untouched', () async {
      final c = ProviderContainer(overrides: clockedOverrides());
      addTearDown(c.dispose);
      final log = c.read(dietLogProvider.notifier);

      // Sunday: log lunch.
      await log.addFood(
        date: nov(8),
        slot: MealSlot.lunch,
        foodId: 'twelve',
        halves: 2,
      );
      expect(c.read(dietDayProvider(nov(8))).loggedG, 12);
      expect(c.read(planTodayProvider), nov(8), reason: 'cached by the pane');

      // Past midnight, no resume: the pane still says Sunday is today.
      wallClock = nov(9);
      expect(c.read(planTodayProvider), nov(8));

      await log.addFood(
        date: nov(9),
        slot: MealSlot.lunch,
        foodId: 'twelve',
        halves: 4,
      );

      expect(c.read(dietDayProvider(nov(8))).loggedG, 12,
          reason: 'nothing logged on Monday touches Sunday');
      expect(c.read(dietDayProvider(nov(9))).loggedG, 24);
      expect(c.read(dietDayProvider(nov(15))).loggedG, 0,
          reason: 'a log does not repeat into next week');
      expect(
        c.read(planTodayProvider),
        nov(9),
        reason: 'after a write the pane moves to the real today',
      );
      expect(c.read(dietStripProvider(nov(9))).first.date, nov(9));
    });

    test('logging against the stale Sunday after midnight still works: it is '
        'in the past, not the future', () async {
      final c = ProviderContainer(overrides: clockedOverrides());
      addTearDown(c.dispose);
      wallClock = nov(9);

      await c.read(dietLogProvider.notifier).addFood(
            date: nov(8),
            slot: MealSlot.dinner,
            foodId: 'twelve',
            halves: 2,
          );

      expect(c.read(dietDayProvider(nov(8))).loggedG, 12);
      expect(c.read(dietDayProvider(nov(9))).loggedG, 0);
    });

    test('a day the stale clock thinks is today but the wall clock does not '
        'yet reach is refused: nothing is written', () async {
      final c = ProviderContainer(overrides: clockedOverrides());
      addTearDown(c.dispose);

      // The wall clock is Sunday; Monday is tomorrow.
      await expectLater(
        c.read(dietLogProvider.notifier).addFood(
              date: nov(9),
              slot: MealSlot.lunch,
              foodId: 'twelve',
              halves: 2,
            ),
        throwsArgumentError,
      );
      expect(await DietLogStore(database).readEntries(), isEmpty);
    });

    testWidgets('the week strip lets you pick today and earlier days, never a '
        'later one', (tester) async {
      wallClock = nov(4); // Wednesday
      await tester.pumpWidget(
        ProviderScope(
          overrides: clockedOverrides(),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: ListView(children: const <Widget>[DietPane()]),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(DietPane.nothingLoggedFor(2)), findsOneWidget,
          reason: 'opens on today, Wednesday');

      await tester.tap(find.byKey(DietPane.weekDayKey(4))); // Friday: later
      await tester.pump();
      expect(find.text(DietPane.nothingLoggedFor(4)), findsNothing);
      expect(find.text(DietPane.nothingLoggedFor(2)), findsOneWidget,
          reason: 'a later day cannot be picked');

      await tester.tap(find.byKey(DietPane.weekDayKey(0))); // Monday: earlier
      await tester.pump();
      expect(find.text(DietPane.nothingLoggedFor(0)), findsOneWidget);
    });
  });
}
