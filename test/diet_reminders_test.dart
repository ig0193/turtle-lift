import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/main.dart' show RefreshTodayOnResume;
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/diet_plan.dart';
import 'package:turtle_lift/src/data/diet_plan_store.dart';
import 'package:turtle_lift/src/data/diet_reminders.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/meal_ticks.dart';
import 'package:turtle_lift/src/data/reminder_prefs.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/data/training_reminders.dart';

import 'support/fake_reminder_scheduler.dart';

/// Diet's reminders (U17, R20, R22, KTD15): built from the plan in effect
/// this week and the switches, never from ticks, and kept in step with the
/// OS by a derived provider. "Today" is Wednesday 4 November 2026; Monday is
/// the 2nd.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LocalDate nov(int day) => LocalDate(2026, 11, day);
  final today = nov(4);

  Map<String, Object?> food(String id, String name, double protein,
          {String serving = '1 katori, 150 g'}) =>
      <String, Object?>{
        'id': id,
        'name': name,
        'aliases': const <String>[],
        'dietType': 'veg',
        'servingLabel': serving,
        'gramsPerServing': 150,
        'proteinPerServingG': protein,
        'proteinPer100g': protein,
        'ifctCode': 'X001',
        'reviewedBy': 'pending-owner-review',
      };

  final foods = FoodIndex.fromJson(<Map<String, Object?>>[
    food('bhurji', 'Paneer bhurji', 18.0),
    food('milk', 'Milk', 8.0, serving: '1 glass, 250 ml'),
    food('rajma', 'Rajma', 9.0),
    food('curd', 'Curd', 11.0),
    food('chana', 'Roasted chana', 2.4, serving: '1 tbsp, 10 g'),
    food('chicken', 'Chicken curry', 25.3),
  ]);

  var nextId = 0;
  DietPlanItem item(int weekday, MealSlot slot, String foodId,
          {int halves = 2, int position = 0}) =>
      DietPlanItem(
        id: 'i${nextId++}',
        weekday: weekday,
        slot: slot,
        foodId: foodId,
        servingsHalves: halves,
        position: position,
      );

  const allOn = ReminderPreferences(
    scheduleOn: false,
    scheduleMinute: 18 * 60 + 30,
    dietOn: true,
    summaryOn: true,
    summaryMinute: 7 * 60 + 30,
    breakfast: SlotReminder(on: true, minute: 8 * 60),
    lunch: SlotReminder(on: true, minute: 13 * 60),
    snack: SlotReminder(on: true, minute: 17 * 60),
    dinner: SlotReminder(on: true, minute: 20 * 60 + 30),
  );

  /// Thursday (weekday 3): breakfast and lunch, no snack, no dinner.
  final thursday = <DietPlanItem>[
    item(3, MealSlot.breakfast, 'bhurji'),
    item(3, MealSlot.breakfast, 'milk', position: 1),
    item(3, MealSlot.lunch, 'rajma'),
    item(3, MealSlot.lunch, 'curd', position: 1),
  ];

  List<DietPlanVersion> planOf(List<DietPlanItem> items) =>
      <DietPlanVersion>[DietPlanVersion(effectiveFrom: nov(2), items: items)];

  List<WeeklyReminder> build(List<DietPlanVersion> versions,
          {ReminderPreferences prefs = allOn}) =>
      dietRemindersFor(
          versions: versions, foods: foods, prefs: prefs, today: today);

  group('dietRemindersFor', () {
    test('Thursday with no snack has no snack reminder; lunch still has one '
        '(AE7)', () {
      final reminders = build(planOf(thursday));
      final ids = reminders.map((r) => r.id).toSet();

      expect(ids, contains(dietMealReminderId(3, MealSlot.lunch)));
      expect(ids, contains(dietMealReminderId(3, MealSlot.breakfast)));
      expect(ids, isNot(contains(dietMealReminderId(3, MealSlot.snack))));
      expect(ids, isNot(contains(dietMealReminderId(3, MealSlot.dinner))));
      expect(ids, <int>{
        dietSummaryReminderId(3),
        dietMealReminderId(3, MealSlot.breakfast),
        dietMealReminderId(3, MealSlot.lunch),
      });
    });

    test('a day with nothing planned has no summary', () {
      final ids = build(planOf(thursday)).map((r) => r.id).toSet();
      for (final wd in <int>[0, 1, 2, 4, 5, 6]) {
        expect(ids, isNot(contains(dietSummaryReminderId(wd))));
      }
      expect(build(const <DietPlanVersion>[]), isEmpty,
          reason: 'no plan at all, nothing to remind');
    });

    test('bodies and titles follow the template, with grams per food', () {
      final byId = {for (final r in build(planOf(thursday))) r.id: r};

      final summary = byId[dietSummaryReminderId(3)]!;
      expect(summary.title, 'Today, 46 g protein planned');
      expect(summary.body,
          'Breakfast: Paneer bhurji, Milk. Lunch: Rajma, Curd.');
      expect(summary.weekday, 3);
      expect(summary.minute, 7 * 60 + 30);
      expect(summary.target, ReminderTarget.dietToday);

      final lunch = byId[dietMealReminderId(3, MealSlot.lunch)]!;
      expect(lunch.title, 'Lunch, 20 g protein');
      expect(lunch.body, 'Rajma, 1 katori (9 g). Curd, 1 katori (11 g).');
      expect(lunch.weekday, 3);
      expect(lunch.minute, 13 * 60);
      expect(lunch.target, ReminderTarget.dietToday);

      final breakfast = byId[dietMealReminderId(3, MealSlot.breakfast)]!;
      expect(breakfast.title, 'Breakfast, 26 g protein');
      expect(breakfast.body,
          'Paneer bhurji, 1 katori (18 g). Milk, 1 glass (8 g).');
      expect(breakfast.minute, 8 * 60);
    });

    test('totals are rounded once, like the day view; rows keep a decimal',
        () {
      final byId = {
        for (final r in build(planOf(<DietPlanItem>[
          item(0, MealSlot.snack, 'chana', halves: 3),
          item(0, MealSlot.snack, 'chana', halves: 3, position: 1),
          item(0, MealSlot.snack, 'chicken', halves: 1, position: 2),
        ])))
          r.id: r,
      };
      // 3.6 + 3.6 + 12.65 = 19.85, rounded once to 20 (not 4 + 4 + 13 = 21).
      final snack = byId[dietMealReminderId(0, MealSlot.snack)]!;
      expect(snack.title, 'Snack, 20 g protein');
      expect(snack.body,
          'Roasted chana, 1.5 tbsp (3.6 g). Roasted chana, 1.5 tbsp (3.6 g). '
          'Chicken curry, 0.5 katori (12.7 g).');
      expect(byId[dietSummaryReminderId(0)]!.title,
          'Today, 20 g protein planned');
    });

    test('ticks cannot reach it: the builder takes no ticks, and the provider '
        'gives an identical schedule whatever is ticked', () {
      List<WeeklyReminder> withTicks(Set<MealTick> ticks) {
        final c = ProviderContainer(overrides: [
          planTodayProvider.overrideWithValue(today),
          foodIndexProvider.overrideWithValue(foods),
          initialDietPlanProvider.overrideWithValue(planOf(thursday)),
          initialReminderPrefsProvider.overrideWithValue(allOn),
          initialMealTicksProvider.overrideWithValue(ticks),
        ]);
        addTearDown(c.dispose);
        return c.read(dietRemindersProvider);
      }

      final none = withTicks(const <MealTick>{});
      expect(none, isNotEmpty);
      expect(withTicks(<MealTick>{
        MealTick(date: nov(5), slot: MealSlot.lunch),
      }), none, reason: 'Thursday lunch ticked still keeps its reminder');
      expect(withTicks(<MealTick>{
        for (var d = 2; d <= 4; d++)
          for (final s in MealSlot.values) MealTick(date: nov(d), slot: s),
      }), none);
    });

    test('a full plan with every reminder on is 35 entries in range', () {
      final full = planOf(<DietPlanItem>[
        for (var wd = 0; wd < 7; wd++)
          for (final s in MealSlot.values) item(wd, s, 'rajma'),
      ]);
      final reminders = build(full);

      expect(reminders, hasLength(35));
      expect(reminders.where((r) => kDietSummaryReminderIds.contains(r.id)),
          hasLength(7));
      expect(reminders.where((r) => kDietMealReminderIds.contains(r.id)),
          hasLength(28));
      expect(reminders.map((r) => r.id).toSet(), hasLength(35));
    });

    test('the master switch off silences everything', () {
      expect(build(planOf(thursday), prefs: allOn.copyWith(dietOn: false)),
          isEmpty);
    });

    test('summary off keeps meal reminders; a slot off drops only that slot',
        () {
      final ids = build(planOf(thursday),
              prefs: allOn
                  .copyWith(summaryOn: false)
                  .withSlot(MealSlot.breakfast,
                      const SlotReminder(on: false, minute: 8 * 60)))
          .map((r) => r.id)
          .toSet();
      expect(ids, <int>{dietMealReminderId(3, MealSlot.lunch)});
    });

    test('uses the plan in effect this week, not a later one', () {
      final versions = <DietPlanVersion>[
        DietPlanVersion(effectiveFrom: nov(2), items: thursday),
        DietPlanVersion(effectiveFrom: nov(9), items: <DietPlanItem>[
          item(0, MealSlot.dinner, 'chicken'),
        ]),
      ];
      final ids = build(versions).map((r) => r.id).toSet();
      expect(ids, contains(dietSummaryReminderId(3)));
      expect(ids, isNot(contains(dietSummaryReminderId(0))));
    });

    test('copy never carries a dash, nor a word about eating, across the '
        'shipped food list', () {
      final shipped = FoodIndex.fromJson(
        (jsonDecode(File('assets/foods/foods.json').readAsStringSync())
                as List<Object?>)
            .cast<Map<String, Object?>>(),
      );
      final all = shipped.all;
      final items = <DietPlanItem>[
        for (var i = 0; i < all.length; i++)
          item(i % 7, MealSlot.values[i % 4], all[i].id,
              halves: 1 + i % 8, position: i),
      ];
      final reminders = dietRemindersFor(
          versions: planOf(items),
          foods: shipped,
          prefs: allOn,
          today: today);
      expect(reminders, hasLength(35));
      for (final r in reminders) {
        for (final copy in <String>[r.title, r.body]) {
          expect(copy, isNot(contains('—')));
          expect(copy, isNot(contains('–')));
          expect(copy.toLowerCase(), isNot(contains('eaten')));
          expect(copy.toLowerCase(), isNot(contains('miss')));
        }
      }
    });
  });

  group('keeping the OS in step', () {
    late AppDatabase database;
    late FakeReminderScheduler fake;
    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      fake = FakeReminderScheduler(permitted: true);
    });
    tearDown(() => database.close());

    final mondays = TrainingPlanEntry(
      effectiveFrom: LocalDate(2026, 10, 1),
      weekdays: const <int>{0, 1, 2, 3, 4, 5, 6},
    );

    ProviderContainer container({
      ReminderPreferences prefs = allOn,
      List<DietPlanVersion>? plan,
    }) {
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(database),
        dietPlanStoreProvider
            .overrideWithValue(DietPlanStore(database, today: () => today)),
        mealTickStoreProvider
            .overrideWithValue(MealTickStore(database, today: () => today)),
        reminderSchedulerProvider.overrideWithValue(fake),
        planTodayProvider.overrideWithValue(today),
        foodIndexProvider.overrideWithValue(foods),
        initialDietPlanProvider.overrideWithValue(plan ?? planOf(thursday)),
        initialTrainingPlanProvider
            .overrideWithValue(<TrainingPlanEntry>[mondays]),
        initialReminderPrefsProvider.overrideWithValue(prefs),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('starting the sync schedules from the stored state (boot)', () async {
      final c = container();
      c.listen(dietReminderSyncProvider, (_, _) {});
      await settle();

      expect(fake.pending.keys.toSet(), <int>{203, 330, 331});
      expect(fake.pending[331]!.body,
          'Rajma, 1 katori (9 g). Curd, 1 katori (11 g).');
    });

    test('a plan edit reschedules, with no target set (target-independent)',
        () async {
      final c = container(plan: const <DietPlanVersion>[]);
      c.listen(dietReminderSyncProvider, (_, _) {});
      await settle();
      expect(fake.pending, isEmpty);
      expect(c.read(proteinTargetProvider), isNull);

      await c.read(dietPlanLogProvider.notifier).addFood(
          weekdays: const <int>{3},
          slot: MealSlot.snack,
          foodId: 'chana',
          halves: 2);
      await settle();

      expect(fake.pending.keys.toSet(), <int>{203, 332});
      expect(fake.pending[332]!.title, 'Snack, 2 g protein');
      expect(fake.pending[203]!.title, 'Today, 2 g protein planned');
    });

    test('a preference change reschedules at the new time', () async {
      final c = container();
      c.listen(dietReminderSyncProvider, (_, _) {});
      await settle();

      await c.read(reminderPrefsProvider.notifier).save(allOn.withSlot(
          MealSlot.lunch, const SlotReminder(on: true, minute: 12 * 60)));
      await settle();

      expect(fake.pending[331]!.minute, 12 * 60);
    });

    test('ticking a meal does not touch the OS (R20)', () async {
      final c = container();
      c.listen(dietReminderSyncProvider, (_, _) {});
      await settle();
      fake.calls.clear();

      await c.read(mealTicksProvider.notifier).toggle(nov(4), MealSlot.lunch);
      await settle();

      expect(fake.calls, isEmpty);
    });

    test('the full schedule is 35 diet entries, 42 with 7 training reminders',
        () async {
      final c = container(
        prefs: allOn.copyWith(scheduleOn: true),
        plan: planOf(<DietPlanItem>[
          for (var wd = 0; wd < 7; wd++)
            for (final s in MealSlot.values) item(wd, s, 'rajma'),
        ]),
      );
      c.listen(dietReminderSyncProvider, (_, _) {});
      await settle();
      expect(fake.pending, hasLength(35));

      c.listen(trainingReminderSyncProvider, (_, _) {});
      await settle();
      expect(fake.pending, hasLength(42));
      expect(fake.pending.keys.where(kTrainingReminderIds.contains),
          hasLength(7));
    });

    test('master off cancels 200-206 and 300-363 and nothing else', () async {
      final c = container(prefs: allOn.copyWith(scheduleOn: true));
      c.listen(dietReminderSyncProvider, (_, _) {});
      c.listen(trainingReminderSyncProvider, (_, _) {});
      await settle();
      expect(fake.pending.keys.toSet(),
          <int>{100, 101, 102, 103, 104, 105, 106, 203, 330, 331});

      await c
          .read(reminderPrefsProvider.notifier)
          .save(allOn.copyWith(scheduleOn: true, dietOn: false));
      await settle();

      expect(fake.pending.keys.toSet(),
          <int>{100, 101, 102, 103, 104, 105, 106});
      expect(fake.calls, isNot(contains('cancelAll')));
    });

    test('with the master off the food list is never read', () {
      final c = ProviderContainer(overrides: [
        planTodayProvider.overrideWithValue(today),
        initialReminderPrefsProvider
            .overrideWithValue(ReminderPreferences.defaults),
      ]);
      addTearDown(c.dispose);
      // foodIndexProvider throws without an override.
      expect(c.read(dietRemindersProvider), isEmpty);
    });
  });

  testWidgets('the app root reschedules diet reminders at boot and on resume',
      (tester) async {
    final fake = FakeReminderScheduler(permitted: true);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        reminderSchedulerProvider.overrideWithValue(fake),
        planTodayProvider.overrideWithValue(today),
        foodIndexProvider.overrideWithValue(foods),
        initialDietPlanProvider.overrideWithValue(planOf(thursday)),
        initialReminderPrefsProvider.overrideWithValue(allOn),
      ],
      child: const RefreshTodayOnResume(child: SizedBox()),
    ));
    await tester.pump();
    expect(fake.pending.keys.toSet(), <int>{203, 330, 331}, reason: 'boot');

    fake.pending.clear();
    for (final state in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();

    expect(fake.pending.keys.toSet(), <int>{203, 330, 331}, reason: 'resume');
  });
}
