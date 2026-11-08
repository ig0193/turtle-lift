import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/diet_plan.dart';
import 'package:turtle_lift/src/data/diet_plan_store.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/meal_ticks.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/diet_day_card.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/diet_slot_card.dart';
import 'package:turtle_lift/src/ui/empty_state.dart';
import 'package:turtle_lift/src/ui/food_picker_screen.dart';
import 'package:turtle_lift/src/ui/food_serving_sheet.dart';
import 'package:turtle_lift/src/ui/ghost_button.dart';
import 'package:turtle_lift/src/ui/glass_tab_bar.dart';
import 'package:turtle_lift/src/ui/protein_target_screen.dart';
import 'package:turtle_lift/src/ui/week_day_chip.dart';

import 'protein_target_screen_test.dart' show expectNoBannedCopy;

/// The Diet segment's states, on fixture foods (the shipped list is still
/// under owner review). "Today" is Wednesday 4 November 2026; Monday is the
/// 2nd.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LocalDate nov(int day) => LocalDate(2026, 11, day);

  late AppDatabase database;
  late DietPlanStore store;
  late MealTickStore tickStore;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = DietPlanStore(database, today: () => nov(4));
    tickStore = MealTickStore(database, today: () => nov(4));
  });
  tearDown(() => database.close());

  Map<String, Object?> food(String id, String name, double protein) =>
      <String, Object?>{
        'id': id,
        'name': name,
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
    food('paneer', 'Paneer', 9.4),
    food('dal', 'Chana dal', 6.5),
    food('soya', 'Soya chunks', 21.5),
    food('chicken', 'Chicken breast', 30.0),
    food('egg', 'Boiled egg', 6.3),
  ]);

  DietPlanItem item(String foodId,
          {int weekday = 2, MealSlot slot = MealSlot.lunch, int halves = 2}) =>
      DietPlanItem(
        id: '$foodId-$weekday-${slot.name}',
        weekday: weekday,
        slot: slot,
        foodId: foodId,
        servingsHalves: halves,
        position: 0,
      );

  /// The shell's shape: a root [AppScreen] over the floating tab bar, the
  /// pane in a list padded by [screenScrollPadding], as [ProfileRoot] does.
  Widget host({
    FoodIndex? index,
    List<DietPlanVersion> plan = const <DietPlanVersion>[],
    int? target,
    Set<MealTick> ticks = const <MealTick>{},
    LocalDate Function()? clock,
  }) =>
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          dietPlanStoreProvider.overrideWithValue(store),
          mealTickStoreProvider.overrideWithValue(tickStore),
          foodIndexProvider.overrideWithValue(index ?? foods),
          if (clock == null)
            planTodayProvider.overrideWithValue(nov(4))
          else
            planClockProvider.overrideWithValue(clock),
          initialDietPlanProvider.overrideWithValue(plan),
          initialProteinTargetProvider.overrideWithValue(target),
          initialMealTicksProvider.overrideWithValue(ticks),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: AppScreen.root(
            title: 'Profile',
            extendBody: true,
            bottomBar: GlassTabBar(selectedIndex: 3, onSelected: (_) {}),
            body: Builder(
              builder: (context) => ListView(
                padding: screenScrollPadding(context),
                children: const <Widget>[DietPane()],
              ),
            ),
          ),
        ),
      );

  group('food list unavailable', () {
    testWidgets('shows the plain copy and no button (R26)', (tester) async {
      await tester.pumpWidget(host(index: FoodIndex.unavailable()));
      await tester.pumpAndSettle();

      expect(find.text(DietPane.unavailableCopy), findsOneWidget);
      expect(DietPane.unavailableCopy,
          'Food list unavailable. Reinstall the app to restore it.');
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(GhostButton), findsNothing);
      expect(find.text(DietPane.emptyHeading), findsNothing);
    });

    testWidgets('wins over a stored plan: nothing can be shown without foods',
        (tester) async {
      await tester.pumpWidget(host(
        index: FoodIndex.unavailable(),
        plan: <DietPlanVersion>[
          DietPlanVersion(effectiveFrom: nov(2), items: [item('paneer')]),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text(DietPane.unavailableCopy), findsOneWidget);
      expect(find.text('Paneer'), findsNothing);
    });
  });

  group('first-time empty state', () {
    testWidgets('bowl glyph, heading, one line and one filled Plan Monday',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text(DietPane.emptyHeading), findsOneWidget);
      expect(DietPane.emptyHeading, "Plan your week's protein");
      expect(find.text(DietPane.emptyBody), findsOneWidget);
      final glyph =
          tester.widget<EmptyStateGlyphIcon>(find.byType(EmptyStateGlyphIcon));
      expect(glyph.glyph, EmptyStateGlyph.bowl);

      expect(find.byType(FilledButton), findsOneWidget,
          reason: 'one primary action per view');
      expect(
        find.descendant(
            of: find.byType(FilledButton), matching: find.text('Plan Monday')),
        findsOneWidget,
      );
    });

    testWidgets('a ghost "Set a daily target" under Plan Monday opens the '
        'target screen (U13)', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final ghost = find.byKey(DietPane.setTargetKey);
      expect(ghost, findsOneWidget);
      expect(find.ancestor(of: ghost, matching: find.byType(GhostButton)),
          findsOneWidget);
      expect(find.descendant(of: ghost, matching: find.text('Set a daily target')),
          findsOneWidget);
      expect(tester.getTopLeft(ghost).dy,
          greaterThan(tester.getTopLeft(find.byKey(DietPane.planMondayKey)).dy));

      await tester.tap(ghost);
      await tester.pumpAndSettle();
      expect(find.byType(ProteinTargetScreen), findsOneWidget);
    });

    testWidgets('Plan Monday opens the picker for Monday, Breakfast',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DietPane.planMondayKey));
      await tester.pumpAndSettle();

      final picker =
          tester.widget<FoodPickerScreen>(find.byType(FoodPickerScreen));
      expect(picker.weekday, 0);
      expect(picker.slot, MealSlot.breakfast);
      expect(find.text('Add to Breakfast, Mon'), findsOneWidget);
    });

    testWidgets('a plan whose versions are all empty is still first-time',
        (tester) async {
      await tester.pumpWidget(host(plan: <DietPlanVersion>[
        DietPlanVersion(effectiveFrom: nov(2), items: const <DietPlanItem>[]),
      ]));
      await tester.pumpAndSettle();

      expect(find.text(DietPane.emptyHeading), findsOneWidget);
    });
  });

  Future<void> pump(WidgetTester tester, Widget app,
      {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  List<DietPlanVersion> planOf(List<DietPlanItem> items) =>
      <DietPlanVersion>[DietPlanVersion(effectiveFrom: nov(2), items: items)];

  Finder slotCard(MealSlot slot) => find.byKey(DietSlotCard.cardKey(slot));

  Finder inSlot(MealSlot slot, String text) =>
      find.descendant(of: slotCard(slot), matching: find.text(text));

  Future<void> selectDay(WidgetTester tester, int weekday) async {
    await tester.tap(find.byKey(DietPane.weekDayKey(weekday)));
    await tester.pumpAndSettle();
  }

  group('the week strip', () {
    testWidgets('shows Monday to Sunday of this week with today selected',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, host(plan: planOf([item('paneer')])));

      for (var d = 0; d < 7; d++) {
        final chip = find.byKey(DietPane.weekDayKey(d));
        expect(chip, findsOneWidget);
        expect(find.descendant(of: chip, matching: find.text('${2 + d}')),
            findsOneWidget,
            reason: 'the date of weekday $d');
        expect(tester.getSemantics(chip),
            isSemantics(isButton: true, isSelected: d == 2, hasTapAction: true),
            reason: 'weekday $d');
      }
      expect(
        tester.getSemantics(find.byKey(DietPane.weekDayKey(2))).label,
        contains('today'),
      );
      handle.dispose();
    });

    testWidgets('the selected day is outlined on the 16pt card radius '
        '(taste pass: one radius scale)', (tester) async {
      await pump(tester, host(plan: planOf([item('paneer')])));
      final box = tester.widget<Container>(find.descendant(
        of: find.byKey(DietPane.weekDayKey(2)),
        matching: find.byType(Container),
      ).first);
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(16));
    });

    testWidgets("tapping Friday shows Friday's slots", (tester) async {
      await pump(
        tester,
        host(plan: planOf([
          item('paneer'),
          item('egg', weekday: 4, slot: MealSlot.breakfast),
        ])),
      );
      expect(inSlot(MealSlot.lunch, 'Paneer'), findsOneWidget);
      expect(find.text('Boiled egg'), findsNothing);

      await selectDay(tester, 4);
      expect(inSlot(MealSlot.breakfast, 'Boiled egg'), findsOneWidget);
      expect(find.text('Paneer'), findsNothing);
    });

    testWidgets('the selected day is in memory and survives a rebuild',
        (tester) async {
      await pump(tester, host(plan: planOf([item('paneer')])));
      await selectDay(tester, 5);

      final container =
          ProviderScope.containerOf(tester.element(find.byType(DietPane)));
      expect(container.read(dietSelectedDayProvider), nov(7));
    });

    testWidgets(
        'a resume across midnight resets the selection to the new today; a '
        'same-day resume keeps it', (tester) async {
      var today = nov(4);
      await pump(
          tester, host(plan: planOf([item('paneer')]), clock: () => today));
      final container =
          ProviderScope.containerOf(tester.element(find.byType(DietPane)));

      await selectDay(tester, 6);
      container.invalidate(planTodayProvider); // resume, same day
      await tester.pumpAndSettle();
      expect(container.read(dietSelectedDayProvider), nov(8));

      today = nov(5); // past midnight
      container.invalidate(planTodayProvider);
      await tester.pumpAndSettle();
      expect(container.read(dietSelectedDayProvider), nov(5));
    });
  });

  group('the day card', () {
    testWidgets('AE2: with no target it reads "86 g planned" and no bar',
        (tester) async {
      await pump(tester, host(plan: planOf([item('soya', halves: 8)])));

      final card = find.byKey(DietDayCard.cardKey);
      expect(card, findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('86 g planned')),
          findsOneWidget);
      expect(find.textContaining('to go'), findsNothing);
      expect(find.byKey(DietDayCard.barKey), findsNothing);
      expect(find.text('Planned'), findsNothing);
      final link = find.byKey(DietDayCard.setTargetKey);
      expect(find.descendant(of: card, matching: link), findsOneWidget);
      expect(find.descendant(of: link, matching: find.text('Set a daily target')),
          findsOneWidget);

      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byType(ProteinTargetScreen), findsOneWidget);
    });

    testWidgets('AE1: with a target it reads "86 of 120 g planned", 34 g to go',
        (tester) async {
      await pump(tester,
          host(target: 120, plan: planOf([item('soya', halves: 8)])));

      expect(find.text('86 of 120 g planned'), findsOneWidget);
      expect(find.text('34 g to go'), findsOneWidget);
    });

    testWidgets('AE1: at the target there is no "to go" line', (tester) async {
      await pump(tester,
          host(target: 120, plan: planOf([item('chicken', halves: 8)])));

      expect(find.text('120 of 120 g planned'), findsOneWidget);
      expect(find.textContaining('to go'), findsNothing);
    });

    testWidgets('a target and no plan skips the first-time state',
        (tester) async {
      await pump(tester, host(target: 120));

      expect(find.text(DietPane.emptyHeading), findsNothing);
      expect(find.text('0 of 120 g planned'), findsOneWidget);
      expect(find.text('Nothing planned for Wednesday'), findsOneWidget);
    });
  });

  group('the slot cards', () {
    testWidgets('four slots in order, rows read name, serving and grams',
        (tester) async {
      await pump(tester, host(plan: planOf([item('paneer')])));

      final ys = <double>[
        for (final slot in MealSlot.values) tester.getTopLeft(slotCard(slot)).dy,
      ];
      for (var i = 1; i < ys.length; i++) {
        expect(ys[i], greaterThan(ys[i - 1]));
      }
      for (final slot in MealSlot.values) {
        expect(inSlot(slot, slot.label), findsOneWidget);
        expect(find.byKey(DietSlotCard.addFoodKey(slot)), findsOneWidget);
      }

      final row = find.byKey(DietSlotCard.rowKey(MealSlot.lunch, 'paneer'));
      expect(find.descendant(of: row, matching: find.text('Paneer')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('1 katori')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('9.4 g')),
          findsOneWidget);
      final handle = tester.ensureSemantics();
      expect(tester.getSemantics(row).label, 'Paneer, 1 katori, 9.4 g');
      handle.dispose();
    });

    testWidgets('slot totals and the day total match the rows',
        (tester) async {
      await pump(
        tester,
        host(plan: planOf([
          item('paneer'), // 9.4
          item('dal'), // 6.5
          item('dal', slot: MealSlot.dinner, halves: 3), // 9.75
        ])),
      );

      // Lunch 15.9 -> 16; dinner 9.75 -> 10; day 25.65 -> 26, rounded once.
      expect(
        find.descendant(
            of: find.byKey(DietSlotCard.totalKey(MealSlot.lunch)),
            matching: find.text('16 g'),
            matchRoot: true),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: find.byKey(DietSlotCard.totalKey(MealSlot.dinner)),
            matching: find.text('10 g'),
            matchRoot: true),
        findsOneWidget,
      );
      expect(find.byKey(DietSlotCard.totalKey(MealSlot.breakfast)),
          findsNothing,
          reason: 'an empty slot shows no total');
      expect(find.text('26 g planned'), findsOneWidget);
      expect(inSlot(MealSlot.dinner, '1.5 katori'), findsOneWidget);
    });

    testWidgets('a day with nothing planned says so above four empty slots',
        (tester) async {
      await pump(tester, host(plan: planOf([item('paneer')])));
      await selectDay(tester, 3);

      expect(find.text('Nothing planned for Thursday'), findsOneWidget);
      for (final slot in MealSlot.values) {
        expect(slotCard(slot), findsOneWidget);
        expect(find.byKey(DietSlotCard.totalKey(slot)), findsNothing);
      }
      final line = tester.getTopLeft(find.text('Nothing planned for Thursday'));
      expect(line.dy,
          lessThan(tester.getTopLeft(slotCard(MealSlot.breakfast)).dy));
    });

    testWidgets('+ Add food opens the picker for that weekday and slot',
        (tester) async {
      await pump(tester, host(plan: planOf([item('paneer')])));
      await selectDay(tester, 4);

      await tester.ensureVisible(find.byKey(DietSlotCard.addFoodKey(MealSlot.snack)));
      await tester.tap(find.byKey(DietSlotCard.addFoodKey(MealSlot.snack)));
      await tester.pumpAndSettle();

      final picker =
          tester.widget<FoodPickerScreen>(find.byType(FoodPickerScreen));
      expect(picker.weekday, 4);
      expect(picker.slot, MealSlot.snack);
      expect(find.text('Add to Snack, Fri'), findsOneWidget);
    });

    testWidgets('an unknown food renders "Unknown food", 0 g, and can be '
        'removed (R26)', (tester) async {
      await store.addFood(
          weekdays: <int>{2}, slot: MealSlot.lunch, foodId: 'gone', halves: 2);
      await pump(tester, host(plan: await store.readVersions()));

      final row = find.byKey(DietSlotCard.rowKey(MealSlot.lunch, 'gone'));
      expect(find.descendant(of: row, matching: find.text('Unknown food')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('0 g')),
          findsOneWidget);
      expect(find.text('0 g planned'), findsOneWidget);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(FoodServingSheet), findsOneWidget);
      expect(find.byKey(FoodServingSheet.commitKey), findsNothing,
          reason: 'nothing to scale on a food the list no longer has');

      await tester.tap(find.byKey(FoodServingSheet.removeKey));
      await tester.pumpAndSettle();
      expect(row, findsNothing);
      final stored = await store.readVersions();
      expect(stored.expand((v) => v.items), isEmpty);
    });

    testWidgets('the last slot card scrolls clear of the floating tab bar',
        (tester) async {
      await pump(
        tester,
        host(plan: planOf([
          for (final slot in MealSlot.values) ...[
            item('paneer', slot: slot),
            item('dal', slot: slot),
          ],
        ])),
        size: const Size(375, 667),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();

      final add = tester.getRect(find.byKey(DietSlotCard.addFoodKey(MealSlot.dinner)));
      final bar = tester.getRect(find.byType(GlassTabBar));
      expect(add.bottom, lessThanOrEqualTo(bar.top));
    });

    testWidgets('no primary button on the day view, and no verdict copy',
        (tester) async {
      await pump(tester,
          host(target: 40, plan: planOf([item('soya', halves: 8)])));

      expect(find.byType(FilledButton), findsNothing,
          reason: 'the day view has no single primary action');
      final copy = tester
          .widgetList<Text>(find.descendant(
              of: find.byType(DietPane), matching: find.byType(Text)))
          .map((t) => (t.data ?? t.textSpan!.toPlainText()).toLowerCase());
      for (final text in copy) {
        for (final banned in <String>[
          'behind',
          'missed',
          'failed',
          'over',
          'great job',
          '–',
          '—',
        ]) {
          expect(text.contains(banned), isFalse, reason: '"$text"');
        }
      }
      expect(find.textContaining('to go'), findsNothing,
          reason: '86 of 40 g: planned past the target, so no "to go"');
    });
  });

  group('planning a week', () {
    testWidgets('the seeded 4 x 7 plan is built in 12 or fewer sheet commits',
        (tester) async {
      await pump(tester, host(), size: const Size(390, 1400));
      var commits = 0;

      /// From the Diet pane: + Add food (or Plan Monday), pick, set Repeat on
      /// to exactly [days], commit.
      Future<void> plan(MealSlot slot, String foodId, Set<int> days,
          {int fromWeekday = 0}) async {
        final planMonday = find.byKey(DietPane.planMondayKey);
        if (planMonday.evaluate().isNotEmpty) {
          await tester.tap(planMonday);
        } else {
          await selectDay(tester, fromWeekday);
          final add = find.byKey(DietSlotCard.addFoodKey(slot));
          await tester.ensureVisible(add);
          await tester.tap(add);
        }
        await tester.pumpAndSettle();
        final row = find.byKey(FoodPickerScreen.rowKey(foodId));
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        for (var d = 0; d < 7; d++) {
          final chip = find.byKey(FoodServingSheet.repeatChipKey(d));
          final selected = tester.widget<WeekDayChip>(chip).selected;
          if (selected != days.contains(d)) await tester.tap(chip);
        }
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(FoodServingSheet.commitKey));
        await tester.pumpAndSettle();
        commits++;
        expect(find.byType(FoodPickerScreen), findsNothing);
      }

      const week = <int>{0, 1, 2, 3, 4, 5, 6};
      const weekdays = <int>{0, 1, 2, 3, 4};
      const weekend = <int>{5, 6};
      await plan(MealSlot.breakfast, 'egg', weekdays);
      await plan(MealSlot.breakfast, 'paneer', weekend, fromWeekday: 5);
      await plan(MealSlot.lunch, 'dal', week);
      await plan(MealSlot.lunch, 'paneer', weekdays);
      await plan(MealSlot.snack, 'soya', week);
      await plan(MealSlot.dinner, 'chicken', weekdays);
      await plan(MealSlot.dinner, 'dal', weekend, fromWeekday: 6);

      expect(commits, lessThanOrEqualTo(12));
      final items = (await store.readVersions())
          .singleWhere((v) => v.effectiveFrom == nov(2))
          .items;
      for (var d = 0; d < 7; d++) {
        for (final slot in MealSlot.values) {
          expect(items.where((i) => i.weekday == d && i.slot == slot),
              isNotEmpty,
              reason: '${slot.label} on weekday $d');
        }
      }
      // And the pane shows it: Saturday has every slot filled.
      await selectDay(tester, 5);
      for (final slot in MealSlot.values) {
        expect(find.byKey(DietSlotCard.totalKey(slot)), findsOneWidget);
      }
    });
  });

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  double widthOf(WidgetTester tester, Key key) =>
      tester.getSize(find.byKey(key)).width;

  /// To the bottom of the pane, where the plan settings sit, scrolled clear
  /// of the floating tab bar as a user would.
  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
  }

  group('the target (U13)', () {
    testWidgets('an in-pane Target row reads "Not set" and opens the screen',
        (tester) async {
      await pump(tester, host(plan: planOf([item('paneer')])));

      final row = find.byKey(DietPane.targetRowKey);
      await scrollToEnd(tester);
      expect(find.descendant(of: row, matching: find.text('Target')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Not set')),
          findsOneWidget);
      expect(tester.getTopLeft(row).dy,
          greaterThan(tester.getTopLeft(slotCard(MealSlot.dinner)).dy),
          reason: 'plan settings sit below the slots');

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(ProteinTargetScreen), findsOneWidget);
    });

    testWidgets('with a target the row reads "120 g a day"', (tester) async {
      await pump(tester, host(target: 120, plan: planOf([item('paneer')])));

      final row = find.byKey(DietPane.targetRowKey);
      expect(find.descendant(of: row, matching: find.text('120 g a day')),
          findsOneWidget);
    });

    testWidgets('saving a target on the screen moves the day card',
        (tester) async {
      await pump(tester, host(plan: planOf([item('soya', halves: 8)])));
      expect(find.text('86 g planned'), findsOneWidget);

      await tester.tap(find.byKey(DietDayCard.setTargetKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(ProteinTargetScreen.fieldKey), '120');
      await tester.pump();
      await tester.tap(find.byKey(ProteinTargetScreen.saveKey));
      await tester.pumpAndSettle();

      expect(find.text('86 of 120 g planned'), findsOneWidget);
      expect(find.text('34 g to go'), findsOneWidget);
      expect(find.byKey(DietDayCard.setTargetKey), findsNothing);
      expect(await SettingsStore(database).readProteinTarget(), 120);
    });

    testWidgets('Clear target returns the day card to the no-target copy',
        (tester) async {
      await pump(tester,
          host(target: 120, plan: planOf([item('soya', halves: 8)])));
      expect(find.text('86 of 120 g planned'), findsOneWidget);

      final row = find.byKey(DietPane.targetRowKey);
      await scrollToEnd(tester);
      await tester.tap(row);
      await tester.pumpAndSettle();
      final clear = find.byKey(ProteinTargetScreen.clearKey);
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(find.text('86 g planned'), findsOneWidget);
      expect(find.textContaining('to go'), findsNothing);
      expect(find.byKey(DietDayCard.barKey), findsNothing);
      expect(find.byKey(DietDayCard.setTargetKey), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(DietPane.targetRowKey),
              matching: find.text('Not set')),
          findsOneWidget);
    });

    testWidgets(
        'with a target the card shows the planned bar and a "Planned" legend',
        (tester) async {
      // Friday: a future day, so planned only.
      await pump(
          tester,
          host(
              target: 120,
              plan: planOf([item('soya', weekday: 4, halves: 4)]))); // 43 g
      await selectDay(tester, 4);

      expect(find.byKey(DietDayCard.barKey), findsOneWidget);
      expect(find.byKey(DietDayCard.setTargetKey), findsNothing);
      expect(
          widthOf(tester, DietDayCard.plannedLayerKey) /
              widthOf(tester, DietDayCard.barKey),
          closeTo(43 / 120, 0.01));
      final legend = find.byKey(DietDayCard.legendKey);
      expect(find.descendant(of: legend, matching: find.text('Planned')),
          findsOneWidget,
          reason: 'a word, never colour alone');
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('the planned bar stops at full past the target',
        (tester) async {
      await pump(tester,
          host(target: 40, plan: planOf([item('soya', halves: 8)])));

      expect(widthOf(tester, DietDayCard.plannedLayerKey),
          closeTo(widthOf(tester, DietDayCard.barKey), 0.01));
    });

    testWidgets('strip chips carry a meter of planned against target',
        (tester) async {
      await pump(
        tester,
        host(target: 100, plan: planOf([
          item('chicken', weekday: 0, halves: 4), // 60 g Monday
          item('chicken', weekday: 1, halves: 8), // 120 g Tuesday
        ])),
      );

      Finder meter(int d) => find.descendant(
          of: find.byKey(DietPane.weekDayKey(d)),
          matching: find.byType(WeekDayMeter));
      for (var d = 0; d < 7; d++) {
        expect(meter(d), findsOneWidget, reason: 'weekday $d');
      }
      double fill(int d) => tester.widget<WeekDayMeter>(meter(d)).fraction;
      expect(fill(0), closeTo(0.6, 1e-9));
      expect(fill(1), 1.0);
      expect(fill(3), 0.0);
      final monday = find.descendant(
          of: meter(0), matching: find.byKey(WeekDayMeter.fillKey));
      expect(tester.getSize(monday).width,
          closeTo(0.6 * tester.getSize(meter(0)).width, 0.01));
    });

    testWidgets('no target, no meters', (tester) async {
      await pump(tester, host(plan: planOf([item('paneer')])));
      expect(find.byType(WeekDayMeter), findsNothing);
    });
  });

  group('eaten ticks (U14)', () {
    // Monday lunch: soya 21.5 + egg 6.3 = 27.8 -> 28 g.
    List<DietPlanItem> week() => [
          item('soya', weekday: 0),
          item('egg', weekday: 0),
          item('paneer', weekday: 0, slot: MealSlot.dinner),
          item('paneer'), // Wednesday lunch
          item('chicken', weekday: 4), // Friday lunch
        ];

    Finder tick(MealSlot slot) => find.byKey(DietSlotCard.tickKey(slot));

    testWidgets(
        'AE3: ticking Monday lunch on Wednesday shows "28 g eaten" on Monday; '
        'Friday has no tick controls', (tester) async {
      await pump(tester, host(plan: planOf(week())));
      await selectDay(tester, 0);

      expect(find.textContaining('eaten'), findsNothing);
      await tester.tap(tick(MealSlot.lunch));
      await tester.pumpAndSettle();

      expect(
          find.descendant(
              of: find.byKey(DietDayCard.cardKey),
              matching: find.text('28 g eaten')),
          findsOneWidget);
      expect(await tickStore.read(),
          [MealTick(date: nov(2), slot: MealSlot.lunch)]);
      expect(containerOf(tester).read(mealTicksProvider),
          {MealTick(date: nov(2), slot: MealSlot.lunch)});

      await selectDay(tester, 4);
      for (final slot in MealSlot.values) {
        expect(tick(slot), findsNothing, reason: '${slot.label} on Friday');
      }
      expect(find.textContaining('eaten'), findsNothing);
    });

    testWidgets('today carries ticks too', (tester) async {
      await pump(tester, host(plan: planOf(week())));
      expect(tick(MealSlot.lunch), findsOneWidget);
    });

    testWidgets('an empty slot shows no tick on any day', (tester) async {
      await pump(tester, host(plan: planOf(week())));

      for (final d in <int>[0, 1, 2, 4]) {
        await selectDay(tester, d);
        expect(tick(MealSlot.breakfast), findsNothing, reason: 'weekday $d');
        expect(tick(MealSlot.snack), findsNothing, reason: 'weekday $d');
      }
      await selectDay(tester, 0);
      expect(tick(MealSlot.dinner), findsOneWidget);
    });

    testWidgets('untick removes the eaten line when nothing else is ticked',
        (tester) async {
      await tickStore.toggle(nov(2), MealSlot.lunch);
      await tickStore.toggle(nov(2), MealSlot.dinner);
      await pump(
        tester,
        host(plan: planOf(week()), ticks: {
          MealTick(date: nov(2), slot: MealSlot.lunch),
          MealTick(date: nov(2), slot: MealSlot.dinner),
        }),
      );
      await selectDay(tester, 0);
      expect(find.text('37 g eaten'), findsOneWidget); // 27.8 + 9.4

      await tester.tap(tick(MealSlot.lunch));
      await tester.pumpAndSettle();
      expect(find.text('9 g eaten'), findsOneWidget);

      await tester.ensureVisible(tick(MealSlot.dinner));
      await tester.tap(tick(MealSlot.dinner));
      await tester.pumpAndSettle();
      expect(find.textContaining('eaten'), findsNothing);
      expect(await tickStore.read(), isEmpty);
    });

    testWidgets("A5: editing Monday's lunch on Wednesday changes Monday's eaten",
        (tester) async {
      // A stored plan, so the edit goes through the store as a user's would.
      for (final i in week()) {
        await store.addFood(
            weekdays: {i.weekday}, slot: i.slot, foodId: i.foodId, halves: 2);
      }
      await tickStore.toggle(nov(2), MealSlot.lunch);
      await pump(
        tester,
        host(
          plan: await store.readVersions(),
          ticks: {MealTick(date: nov(2), slot: MealSlot.lunch)},
        ),
      );
      await selectDay(tester, 0);
      expect(find.text('28 g eaten'), findsOneWidget);

      await tester.tap(find.byKey(DietSlotCard.rowKey(MealSlot.lunch, 'egg')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FoodServingSheet.removeKey));
      await tester.pumpAndSettle();

      expect(find.text('22 g eaten'), findsOneWidget); // 21.5
    });

    testWidgets(
        'the tick is 48pt, outlined, and its label names slot and state',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, host(plan: planOf(week())));
      await selectDay(tester, 0);

      final size = tester.getSize(tick(MealSlot.lunch));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
          tester.getSemantics(tick(MealSlot.lunch)),
          isSemantics(
              label: 'Lunch not eaten',
              hasTapAction: true,
              hasCheckedState: true,
              isChecked: false));
      expect(
          find.descendant(
              of: tick(MealSlot.lunch),
              matching: find.byIcon(Icons.check_rounded)),
          findsNothing);

      await tester.tap(tick(MealSlot.lunch));
      await tester.pumpAndSettle();
      expect(
          tester.getSemantics(tick(MealSlot.lunch)),
          isSemantics(
              label: 'Lunch eaten',
              hasTapAction: true,
              hasCheckedState: true,
              isChecked: true));
      final glyph = tester.widget<Icon>(find.descendant(
          of: tick(MealSlot.lunch), matching: find.byIcon(Icons.check_rounded)));
      expect(glyph.color, AppPalette.accentStrong);

      // An outline, never a fill.
      final ring = tester.widget<Container>(find.descendant(
          of: tick(MealSlot.lunch),
          matching: find.byKey(DietEatenTick.ringKey)));
      final box = ring.decoration! as BoxDecoration;
      expect(box.color, isNull);
      expect((box.border! as Border).top.color, AppPalette.accentStrong);
      handle.dispose();
    });

    testWidgets(
        'with a target the bar gains the eaten layer and an "Eaten" legend '
        'on a tickable day', (tester) async {
      await tickStore.toggle(nov(2), MealSlot.lunch);
      await pump(
        tester,
        host(
          target: 100,
          plan: planOf(week()),
          ticks: {MealTick(date: nov(2), slot: MealSlot.lunch)},
        ),
      );
      await selectDay(tester, 0);

      // Monday plans 37 g: one line, "to go" then "eaten".
      expect(find.text('63 g to go · 28 g eaten'), findsOneWidget);
      final legend = find.byKey(DietDayCard.legendKey);
      expect(find.descendant(of: legend, matching: find.text('Planned')),
          findsOneWidget);
      expect(find.descendant(of: legend, matching: find.text('Eaten')),
          findsOneWidget);
      expect(
          widthOf(tester, DietDayCard.eatenLayerKey) /
              widthOf(tester, DietDayCard.barKey),
          closeTo(0.28, 0.01));

      await selectDay(tester, 4); // the future: neither
      expect(find.byKey(DietDayCard.eatenLayerKey), findsNothing);
      expect(find.descendant(of: legend, matching: find.text('Eaten')),
          findsNothing);
      expect(find.descendant(of: legend, matching: find.text('Planned')),
          findsOneWidget);
    });

    testWidgets('one accent meaning: only the tick and the eaten layer',
        (tester) async {
      await tickStore.toggle(nov(2), MealSlot.lunch);
      await pump(
        tester,
        host(
          target: 100,
          plan: planOf(week()),
          ticks: {MealTick(date: nov(2), slot: MealSlot.lunch)},
        ),
      );
      await selectDay(tester, 0);

      // Text in the accent: only today's short name on the strip.
      final accentText = tester
          .widgetList<Text>(find.descendant(
              of: find.byType(DietPane), matching: find.byType(Text)))
          .where((t) => t.style?.color == AppPalette.accentStrong)
          .map((t) => t.data)
          .toList();
      expect(accentText, ['Wed']);
    });
  });

  testWidgets('copy ban across every diet state', (tester) async {
    await tickStore.toggle(nov(2), MealSlot.lunch);
    await pump(
      tester,
      host(
        target: 30,
        plan: planOf([
          item('soya', weekday: 0, halves: 8),
          item('paneer'),
        ]),
        ticks: {MealTick(date: nov(2), slot: MealSlot.lunch)},
      ),
    );
    for (final d in <int>[0, 2, 4]) {
      await selectDay(tester, d);
      final copy = tester
          .widgetList<Text>(find.descendant(
              of: find.byType(DietPane), matching: find.byType(Text)))
          .map((t) => t.data ?? t.textSpan!.toPlainText());
      copy.forEach(expectNoBannedCopy);
    }
    for (final text in <String>[
      DietPane.settingsLabel,
      DietPane.targetRowTitle,
      DietPane.targetRowSubtitle,
      DietPane.targetNotSet,
      DietPane.targetValue(120),
      DietPane.setTargetLabel,
      DietDayCard.plannedLegend,
      DietDayCard.eatenLegend,
      DietDayCard.eatenLine(28),
      DietEatenTick.labelFor(MealSlot.lunch, ticked: true),
      DietEatenTick.labelFor(MealSlot.lunch, ticked: false),
    ]) {
      expectNoBannedCopy(text);
    }
  });
}
