import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/diet_log.dart';
import 'package:turtle_lift/src/data/diet_log_store.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/reminder_prefs.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart'
    show reminderSchedulerProvider;
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/today.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/diet_day_card.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/diet_slot_card.dart';
import 'package:turtle_lift/src/ui/food_picker_screen.dart';
import 'package:turtle_lift/src/ui/food_serving_sheet.dart';
import 'package:turtle_lift/src/ui/ghost_button.dart';
import 'package:turtle_lift/src/ui/glass_tab_bar.dart';
import 'package:turtle_lift/src/ui/protein_target_screen.dart';
import 'package:turtle_lift/src/ui/week_day_meter.dart';

import 'protein_target_screen_test.dart' show expectNoBannedCopy;
import 'support/fake_reminder_scheduler.dart';

/// The Diet pane as a log (`docs/adr/0015-diet-is-a-log.md`), on fixture foods
/// (the shipped list is still under owner review). "Today" is Wednesday 4
/// November 2026; Monday is the 2nd, and the days after the 4th cannot be
/// logged.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LocalDate nov(int day) => LocalDate(2026, 11, day);

  late AppDatabase database;
  late DietLogStore store;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = DietLogStore(database, today: () => nov(4));
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

  /// One logged food. [day] is the day of November 2026; the default is today.
  DietLogEntry entry(String foodId,
          {int day = 4, MealSlot slot = MealSlot.lunch, int halves = 2}) =>
      DietLogEntry(
        id: '$foodId-$day-${slot.name}',
        date: nov(day),
        slot: slot,
        foodId: foodId,
        servingsHalves: halves,
        position: 0,
      );

  /// The shell's shape: a root [AppScreen] over the floating tab bar, the
  /// pane in a list padded by [screenScrollPadding], as [YouRoot] does.
  Widget host({
    FoodIndex? index,
    List<DietLogEntry> log = const <DietLogEntry>[],
    int? target,
    ReminderPreferences? reminders,
    FakeReminderScheduler? scheduler,
    LocalDate Function()? clock,
  }) =>
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          dietLogStoreProvider.overrideWithValue(store),
          foodIndexProvider.overrideWithValue(index ?? foods),
          if (clock == null)
            planTodayProvider.overrideWithValue(nov(4))
          else
            planClockProvider.overrideWithValue(clock),
          initialDietLogProvider.overrideWithValue(log),
          initialProteinTargetProvider.overrideWithValue(target),
          if (reminders != null)
            initialReminderPrefsProvider.overrideWithValue(reminders),
          if (scheduler != null)
            reminderSchedulerProvider.overrideWithValue(scheduler),
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
      expect(find.byKey(DietPane.dayViewKey), findsNothing);
    });

    testWidgets('wins over a stored log: nothing can be shown without foods',
        (tester) async {
      await tester.pumpWidget(host(
        index: FoodIndex.unavailable(),
        log: <DietLogEntry>[entry('paneer')],
      ));
      await tester.pumpAndSettle();

      expect(find.text(DietPane.unavailableCopy), findsOneWidget);
      expect(find.text('Paneer'), findsNothing);
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

  Finder slotCard(MealSlot slot) => find.byKey(DietSlotCard.cardKey(slot));

  Finder inSlot(MealSlot slot, String text) =>
      find.descendant(of: slotCard(slot), matching: find.text(text));

  Future<void> selectDay(WidgetTester tester, int weekday) async {
    await tester.tap(find.byKey(DietPane.weekDayKey(weekday)));
    await tester.pumpAndSettle();
  }

  group('opening on an empty log', () {
    testWidgets(
        'goes straight to the day view: no first-time state, no Plan Monday',
        (tester) async {
      await pump(tester, host());

      expect(find.byKey(DietPane.dayViewKey), findsOneWidget);
      expect(find.text('Plan Monday'), findsNothing);
      expect(find.text("Plan your week's protein"), findsNothing);
      expect(find.byType(FilledButton), findsNothing,
          reason: 'the day view has no single primary action');
      for (final slot in MealSlot.values) {
        expect(slotCard(slot), findsOneWidget);
        expect(find.byKey(DietSlotCard.addFoodKey(slot)), findsOneWidget);
      }
    });

    testWidgets('today is selected, and says nothing is logged yet',
        (tester) async {
      await pump(tester, host());

      final container =
          ProviderScope.containerOf(tester.element(find.byType(DietPane)));
      expect(container.read(dietSelectedDayProvider), nov(4));
      expect(find.text('0 g logged'), findsOneWidget);
      expect(find.text('Nothing logged for Wednesday'), findsOneWidget);
      expect(find.textContaining('planned'), findsNothing);
      expect(find.textContaining('Nothing planned'), findsNothing);
    });

    testWidgets('the card offers "Set a daily target", which opens the screen',
        (tester) async {
      await pump(tester, host());

      final link = find.byKey(DietDayCard.setTargetKey);
      expect(find.descendant(of: link, matching: find.text('Set a daily target')),
          findsOneWidget);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byType(ProteinTargetScreen), findsOneWidget);
    });

    testWidgets("+ Add food on a fresh log opens today's picker",
        (tester) async {
      await pump(tester, host());

      await tester.tap(find.byKey(DietSlotCard.addFoodKey(MealSlot.breakfast)));
      await tester.pumpAndSettle();

      final picker =
          tester.widget<FoodPickerScreen>(find.byType(FoodPickerScreen));
      expect(picker.date, nov(4));
      expect(picker.slot, MealSlot.breakfast);
      expect(find.text('Add to Breakfast, Wed'), findsOneWidget);
    });
  });

  group('the week strip', () {
    testWidgets(
        'shows Monday to Sunday of this week with today selected; days after '
        'today are not buttons', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, host(log: <DietLogEntry>[entry('paneer')]));

      for (var d = 0; d < 7; d++) {
        final chip = find.byKey(DietPane.weekDayKey(d));
        expect(chip, findsOneWidget);
        expect(find.descendant(of: chip, matching: find.text('${2 + d}')),
            findsOneWidget,
            reason: 'the date of weekday $d');
        final pickable = d <= 2;
        expect(
            tester.getSemantics(chip),
            isSemantics(
                isButton: pickable,
                isSelected: d == 2,
                hasTapAction: pickable),
            reason: 'weekday $d');
      }
      expect(
        tester.getSemantics(find.byKey(DietPane.weekDayKey(2))).label,
        contains('today'),
      );
      handle.dispose();
    });

    testWidgets('tapping a day after today changes nothing', (tester) async {
      await pump(tester, host(log: <DietLogEntry>[entry('paneer')]));

      await selectDay(tester, 4);
      final container =
          ProviderScope.containerOf(tester.element(find.byType(DietPane)));
      expect(container.read(dietSelectedDayProvider), nov(4));
      expect(inSlot(MealSlot.lunch, 'Paneer'), findsOneWidget,
          reason: 'still on today');
    });

    testWidgets('the selected day is outlined on the 16pt card radius '
        '(taste pass: one radius scale)', (tester) async {
      await pump(tester, host(log: <DietLogEntry>[entry('paneer')]));
      final box = tester.widget<Container>(find.descendant(
        of: find.byKey(DietPane.weekDayKey(2)),
        matching: find.byType(Container),
      ).first);
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(16));
    });

    testWidgets("tapping Monday shows Monday's slots", (tester) async {
      await pump(
        tester,
        host(log: <DietLogEntry>[
          entry('paneer'),
          entry('egg', day: 2, slot: MealSlot.breakfast),
        ]),
      );
      expect(inSlot(MealSlot.lunch, 'Paneer'), findsOneWidget);
      expect(find.text('Boiled egg'), findsNothing);

      await selectDay(tester, 0);
      expect(inSlot(MealSlot.breakfast, 'Boiled egg'), findsOneWidget);
      expect(find.text('Paneer'), findsNothing);
    });

    testWidgets('the selected day is in memory and survives a rebuild',
        (tester) async {
      await pump(tester, host(log: <DietLogEntry>[entry('paneer')]));
      await selectDay(tester, 1);

      final container =
          ProviderScope.containerOf(tester.element(find.byType(DietPane)));
      expect(container.read(dietSelectedDayProvider), nov(3));
    });

    testWidgets(
        'a resume across midnight resets the selection to the new today; a '
        'same-day resume keeps it', (tester) async {
      var today = nov(4);
      await pump(tester,
          host(log: <DietLogEntry>[entry('paneer')], clock: () => today));
      final container =
          ProviderScope.containerOf(tester.element(find.byType(DietPane)));

      await selectDay(tester, 0);
      container.invalidate(planTodayProvider); // resume, same day
      await tester.pumpAndSettle();
      expect(container.read(dietSelectedDayProvider), nov(2));

      today = nov(5); // past midnight
      container.invalidate(planTodayProvider);
      await tester.pumpAndSettle();
      expect(container.read(dietSelectedDayProvider), nov(5));
    });

    testWidgets('after midnight the new day can be picked on the strip',
        (tester) async {
      var today = nov(4);
      await pump(tester, host(clock: () => today));
      final handle = tester.ensureSemantics();
      expect(
          tester.getSemantics(find.byKey(DietPane.weekDayKey(3))),
          isSemantics(isButton: false, isSelected: false, hasTapAction: false));

      today = nov(5);
      ProviderScope.containerOf(tester.element(find.byType(DietPane)))
          .invalidate(planTodayProvider);
      await tester.pumpAndSettle();
      expect(
          tester.getSemantics(find.byKey(DietPane.weekDayKey(3))),
          isSemantics(isButton: true, isSelected: true, hasTapAction: true));
      handle.dispose();
    });
  });

  group('the day card', () {
    testWidgets('AE2: with no target it reads "86 g logged" and no bar',
        (tester) async {
      await pump(tester, host(log: <DietLogEntry>[entry('soya', halves: 8)]));

      final card = find.byKey(DietDayCard.cardKey);
      expect(card, findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('86 g logged')),
          findsOneWidget);
      expect(find.textContaining('to go'), findsNothing);
      expect(find.byKey(DietDayCard.barKey), findsNothing);
      final link = find.byKey(DietDayCard.setTargetKey);
      expect(find.descendant(of: card, matching: link), findsOneWidget);
      expect(find.descendant(of: link, matching: find.text('Set a daily target')),
          findsOneWidget);

      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byType(ProteinTargetScreen), findsOneWidget);
    });

    testWidgets('AE1: with a target it reads "86 of 120 g logged", 34 g to go',
        (tester) async {
      await pump(tester,
          host(target: 120, log: <DietLogEntry>[entry('soya', halves: 8)]));

      expect(find.text('86 of 120 g logged'), findsOneWidget);
      expect(find.text('34 g to go'), findsOneWidget);
    });

    testWidgets('AE1: at the target there is no "to go" line', (tester) async {
      await pump(tester,
          host(target: 120, log: <DietLogEntry>[entry('chicken', halves: 8)]));

      expect(find.text('120 of 120 g logged'), findsOneWidget);
      expect(find.textContaining('to go'), findsNothing);
    });

    testWidgets('a target and nothing logged reads 0 of the target',
        (tester) async {
      await pump(tester, host(target: 120));

      expect(find.byKey(DietPane.dayViewKey), findsOneWidget);
      expect(find.text('0 of 120 g logged'), findsOneWidget);
      expect(find.text('120 g to go'), findsOneWidget);
      expect(find.text('Nothing logged for Wednesday'), findsOneWidget);
    });
  });

  group('the slot cards', () {
    testWidgets('four slots in order, rows read name, serving and grams',
        (tester) async {
      await pump(tester, host(log: <DietLogEntry>[entry('paneer')]));

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
        host(log: <DietLogEntry>[
          entry('paneer'), // 9.4
          entry('dal'), // 6.5
          entry('dal', slot: MealSlot.dinner, halves: 3), // 9.75
        ]),
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
      expect(find.text('26 g logged'), findsOneWidget);
      expect(inSlot(MealSlot.dinner, '1.5 katori'), findsOneWidget);
    });

    testWidgets('a day with nothing logged says so above four empty slots',
        (tester) async {
      await pump(tester, host(log: <DietLogEntry>[entry('paneer')]));
      await selectDay(tester, 1);

      expect(find.text('Nothing logged for Tuesday'), findsOneWidget);
      for (final slot in MealSlot.values) {
        expect(slotCard(slot), findsOneWidget);
        expect(find.byKey(DietSlotCard.totalKey(slot)), findsNothing);
      }
      final line = tester.getTopLeft(find.text('Nothing logged for Tuesday'));
      expect(line.dy,
          lessThan(tester.getTopLeft(slotCard(MealSlot.breakfast)).dy));
    });

    testWidgets('+ Add food opens the picker for the selected date and slot',
        (tester) async {
      await pump(tester, host(log: <DietLogEntry>[entry('paneer')]));
      await selectDay(tester, 1);

      await tester.ensureVisible(find.byKey(DietSlotCard.addFoodKey(MealSlot.snack)));
      await tester.tap(find.byKey(DietSlotCard.addFoodKey(MealSlot.snack)));
      await tester.pumpAndSettle();

      final picker =
          tester.widget<FoodPickerScreen>(find.byType(FoodPickerScreen));
      expect(picker.date, nov(3));
      expect(picker.slot, MealSlot.snack);
      expect(find.text('Add to Snack, Tue'), findsOneWidget);
    });

    testWidgets('an unknown food renders "Unknown food", 0 g, and can be '
        'removed (R26)', (tester) async {
      await store.addFood(
          date: nov(4), slot: MealSlot.lunch, foodId: 'gone', halves: 2);
      await pump(tester, host(log: await store.readEntries()));

      final row = find.byKey(DietSlotCard.rowKey(MealSlot.lunch, 'gone'));
      expect(find.descendant(of: row, matching: find.text('Unknown food')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('0 g')),
          findsOneWidget);
      expect(find.text('0 g logged'), findsOneWidget);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(FoodServingSheet), findsOneWidget);
      expect(find.byKey(FoodServingSheet.commitKey), findsNothing,
          reason: 'nothing to scale on a food the list no longer has');

      await tester.tap(find.byKey(FoodServingSheet.removeKey));
      await tester.pumpAndSettle();
      expect(row, findsNothing);
      expect(await store.readEntries(), isEmpty);
    });

    testWidgets('the last slot card scrolls clear of the floating tab bar',
        (tester) async {
      await pump(
        tester,
        host(log: <DietLogEntry>[
          for (final slot in MealSlot.values) ...[
            entry('paneer', slot: slot),
            entry('dal', slot: slot),
          ],
        ]),
        size: const Size(375, 667),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();

      final add = tester.getRect(find.byKey(DietSlotCard.addFoodKey(MealSlot.dinner)));
      final bar = tester.getRect(find.byType(GlassTabBar));
      expect(add.bottom, lessThanOrEqualTo(bar.top));
    });

    testWidgets('no tick controls, and no verdict copy', (tester) async {
      await pump(tester,
          host(target: 40, log: <DietLogEntry>[entry('soya', halves: 8)]));

      expect(find.byType(FilledButton), findsNothing,
          reason: 'the day view has no single primary action');
      expect(find.byIcon(Icons.check_rounded), findsNothing,
          reason: 'a logged food has been eaten: there is nothing to tick');
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
        expect(text.contains('eaten'), isFalse, reason: '"$text"');
        expect(text.contains('planned'), isFalse, reason: '"$text"');
      }
      expect(find.textContaining('to go'), findsNothing,
          reason: '86 of 40 g: logged past the target, so no "to go"');
    });
  });

  group('logging a day', () {
    testWidgets('four slots are logged in four sheet commits, all on today',
        (tester) async {
      await pump(tester, host(), size: const Size(390, 1400));
      var commits = 0;

      /// From the Diet pane: + Add food, pick, commit.
      Future<void> log(MealSlot slot, String foodId) async {
        final add = find.byKey(DietSlotCard.addFoodKey(slot));
        await tester.ensureVisible(add);
        await tester.tap(add);
        await tester.pumpAndSettle();
        final row = find.byKey(FoodPickerScreen.rowKey(foodId));
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(FoodServingSheet.commitKey));
        await tester.pumpAndSettle();
        commits++;
        expect(find.byType(FoodPickerScreen), findsNothing);
      }

      await log(MealSlot.breakfast, 'egg');
      await log(MealSlot.lunch, 'dal');
      await log(MealSlot.snack, 'soya');
      await log(MealSlot.dinner, 'chicken');

      expect(commits, 4);
      final entries = await store.readEntries();
      expect(entries, hasLength(4));
      expect(entries.map((e) => e.date).toSet(), <LocalDate>{nov(4)},
          reason: 'a log writes to the selected day and nowhere else');
      for (final slot in MealSlot.values) {
        expect(entries.where((e) => e.slot == slot), hasLength(1),
            reason: slot.label);
        expect(find.byKey(DietSlotCard.totalKey(slot)), findsOneWidget);
      }
      // 6.3 + 6.5 + 21.5 + 30 = 64.3 -> 64
      expect(find.text('64 g logged'), findsOneWidget);

      // Another day is untouched.
      await selectDay(tester, 1);
      expect(find.text('Nothing logged for Tuesday'), findsOneWidget);
      expect(find.text('0 g logged'), findsOneWidget);
    });
  });

  double widthOf(WidgetTester tester, Key key) =>
      tester.getSize(find.byKey(key)).width;

  /// To the bottom of the pane, where the settings sit, scrolled clear of the
  /// floating tab bar as a user would.
  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
  }

  group('the target (U13)', () {
    testWidgets('an in-pane Target row reads "Not set" and opens the screen',
        (tester) async {
      await pump(tester, host(log: <DietLogEntry>[entry('paneer')]));

      final row = find.byKey(DietPane.targetRowKey);
      await scrollToEnd(tester);
      expect(find.descendant(of: row, matching: find.text('Target')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Not set')),
          findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Plan settings'), findsNothing);
      expect(
        find.descendant(
            of: row,
            matching:
                find.text('Daily protein, measured against what you log')),
        findsOneWidget,
      );
      expect(tester.getTopLeft(row).dy,
          greaterThan(tester.getTopLeft(slotCard(MealSlot.dinner)).dy),
          reason: 'settings sit below the slots');

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(ProteinTargetScreen), findsOneWidget);
    });

    testWidgets('with a target the row reads "120 g a day"', (tester) async {
      await pump(
          tester, host(target: 120, log: <DietLogEntry>[entry('paneer')]));

      final row = find.byKey(DietPane.targetRowKey);
      expect(find.descendant(of: row, matching: find.text('120 g a day')),
          findsOneWidget);
    });

    testWidgets('saving a target on the screen moves the day card',
        (tester) async {
      await pump(tester, host(log: <DietLogEntry>[entry('soya', halves: 8)]));
      expect(find.text('86 g logged'), findsOneWidget);

      await tester.tap(find.byKey(DietDayCard.setTargetKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(ProteinTargetScreen.fieldKey), '120');
      await tester.pump();
      await tester.tap(find.byKey(ProteinTargetScreen.saveKey));
      await tester.pumpAndSettle();

      expect(find.text('86 of 120 g logged'), findsOneWidget);
      expect(find.text('34 g to go'), findsOneWidget);
      expect(find.byKey(DietDayCard.setTargetKey), findsNothing);
      expect(await SettingsStore(database).readProteinTarget(), 120);
    });

    testWidgets('Clear target returns the day card to the no-target copy',
        (tester) async {
      await pump(tester,
          host(target: 120, log: <DietLogEntry>[entry('soya', halves: 8)]));
      expect(find.text('86 of 120 g logged'), findsOneWidget);

      final row = find.byKey(DietPane.targetRowKey);
      await scrollToEnd(tester);
      await tester.tap(row);
      await tester.pumpAndSettle();
      final clear = find.byKey(ProteinTargetScreen.clearKey);
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(find.text('86 g logged'), findsOneWidget);
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
        'with a target the card shows one logged bar and no legend',
        (tester) async {
      await pump(
          tester,
          host(
              target: 120,
              log: <DietLogEntry>[entry('soya', halves: 4)])); // 43 g

      expect(find.byKey(DietDayCard.barKey), findsOneWidget);
      expect(find.byKey(DietDayCard.setTargetKey), findsNothing);
      expect(
          widthOf(tester, DietDayCard.loggedLayerKey) /
              widthOf(tester, DietDayCard.barKey),
          closeTo(43 / 120, 0.01));
      expect(find.text('Planned'), findsNothing);
      expect(find.text('Eaten'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('the logged bar stops at full past the target',
        (tester) async {
      await pump(tester,
          host(target: 40, log: <DietLogEntry>[entry('soya', halves: 8)]));

      expect(widthOf(tester, DietDayCard.loggedLayerKey),
          closeTo(widthOf(tester, DietDayCard.barKey), 0.01));
    });

    testWidgets('strip chips carry a meter of logged against target',
        (tester) async {
      await pump(
        tester,
        host(target: 100, log: <DietLogEntry>[
          entry('chicken', day: 2, halves: 4), // 60 g Monday
          entry('chicken', day: 3, halves: 8), // 120 g Tuesday
        ]),
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
      await pump(tester, host(log: <DietLogEntry>[entry('paneer')]));
      expect(find.byType(WeekDayMeter), findsNothing);
    });
  });

  group('the Reminders row', () {
    ReminderPreferences prefs({bool dietOn = true, Set<MealSlot> on = const {}}) {
      var p = ReminderPreferences.defaults.copyWith(dietOn: dietOn);
      for (final slot in on) {
        p = p.withSlot(slot, p.slot(slot).copyWith(on: true));
      }
      return p;
    }

    test('says Off, None chosen, Off in Settings, or counts slots only', () {
      expect(DietPane.remindersValue(prefs(dietOn: false)), 'Off');
      expect(DietPane.remindersValue(prefs()), 'None chosen');
      expect(
          DietPane.remindersValue(prefs(on: {MealSlot.lunch, MealSlot.dinner})),
          '2 a day');
      expect(
          DietPane.remindersValue(prefs(on: MealSlot.values.toSet())),
          '4 a day');
      expect(DietPane.remindersValue(prefs(on: {MealSlot.lunch}), permitted: false),
          'Off in Settings');
      expect(DietPane.remindersValue(prefs(on: {MealSlot.lunch}), permitted: true),
          '1 a day');
    });

    testWidgets('shows the slot count where notifications work',
        (tester) async {
      await pump(
        tester,
        host(
          scheduler: FakeReminderScheduler(permitted: true),
          reminders: prefs(on: {MealSlot.breakfast, MealSlot.snack}),
        ),
      );
      await scrollToEnd(tester);

      final row = find.byKey(DietPane.remindersRowKey);
      expect(find.descendant(of: row, matching: find.text('Reminders')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('A nudge to log each meal')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('2 a day')),
          findsOneWidget);
    });
  });

  testWidgets('one accent meaning on the strip: only today\'s short name',
      (tester) async {
    await pump(
        tester, host(target: 100, log: <DietLogEntry>[entry('soya')]));
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

  testWidgets('copy ban across every diet state', (tester) async {
    await pump(
      tester,
      host(
        target: 30,
        log: <DietLogEntry>[
          entry('soya', day: 2, halves: 8),
          entry('paneer'),
        ],
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
      DietPane.remindersRowTitle,
      DietPane.remindersRowSubtitle,
      DietPane.nothingLoggedFor(2),
    ]) {
      expectNoBannedCopy(text);
    }
  });
}
