import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/diet_slot_card.dart';

/// QA: the calendar-date edges, with every clock injected.
///
/// The single most likely way to get these wrong in the field is an app left
/// open across midnight: the UI's "today" is cached until the next resume
/// (`planTodayProvider`), while the stores read the wall clock at write time.
/// `diet_derived_test`, `meal_ticks_test` and `training_plan_test` prove each
/// side alone; this proves them together across the Sunday-to-Monday edge,
/// where "this week" changes.
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
    dietPlanStoreProvider.overrideWithValue(
      DietPlanStore(database, today: () => wallClock),
    ),
    mealTickStoreProvider.overrideWithValue(
      MealTickStore(database, today: () => wallClock),
    ),
  ];

  group('Diet left open from Sunday night into Monday', () {
    test('an edit after midnight lands in the new week, the pane follows it, '
        'and last week keeps what was eaten', () async {
      final c = ProviderContainer(overrides: clockedOverrides());
      addTearDown(c.dispose);
      final log = c.read(dietPlanLogProvider.notifier);

      // Sunday: plan lunch and tick it.
      await log.addFood(
        weekdays: <int>{6},
        slot: MealSlot.lunch,
        foodId: 'twelve',
        halves: 2,
      );
      expect(
        await c.read(mealTicksProvider.notifier).toggle(nov(8), MealSlot.lunch),
        isTrue,
      );
      expect(c.read(dietDayProvider(nov(8))).eatenG, 12);

      // Past midnight, no resume: the user doubles Sunday lunch.
      wallClock = nov(9);
      await log.addFood(
        weekdays: <int>{6},
        slot: MealSlot.lunch,
        foodId: 'twelve',
        halves: 4,
      );

      expect(
        c.read(dietDayProvider(nov(8))).plannedG,
        12,
        reason: 'copy-on-write: last week keeps the plan it was lived under',
      );
      expect(c.read(dietDayProvider(nov(8))).eatenG, 12);
      expect(
        c.read(dietDayProvider(nov(15))).plannedG,
        24,
        reason: 'the edit takes effect from this Monday',
      );
      expect(
        c.read(planTodayProvider),
        nov(9),
        reason:
            'after a write the pane shows the week the write landed in; '
            'left on last week the edit would vanish from the screen',
      );
      expect(c.read(dietWeekProvider).first.date, nov(9));
    });

    testWidgets('tapping a tick still showing for Sunday does not throw', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await DietPlanStore(database, today: () => wallClock).addFood(
          weekdays: <int>{6},
          slot: MealSlot.lunch,
          foodId: 'twelve',
          halves: 2,
        );
      });
      final plan = await tester.runAsync(
        () => DietPlanStore(database).readVersions(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...clockedOverrides(),
            initialDietPlanProvider.overrideWithValue(plan!),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: ListView(children: const <Widget>[DietPane()]),
            ),
          ),
        ),
      );
      await tester.pump();
      final tick = find.byKey(DietSlotCard.tickKey(MealSlot.lunch));
      expect(tick, findsOneWidget, reason: 'Sunday is today on screen');

      // Midnight passes with the app in the foreground.
      wallClock = nov(9);
      await tester.ensureVisible(tick);
      await tester.tap(tick);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason:
            'the store refuses last week; the tap must not surface that '
            'as an uncaught error',
      );
      expect(
        await tester.runAsync(() => MealTickStore(database).read()),
        isEmpty,
        reason: 'Sunday is last week now, so nothing is written',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DietPane)),
      );
      expect(
        container.read(planTodayProvider),
        nov(9),
        reason: 'the refusal moves the pane to the real today',
      );
    });
  });
}
