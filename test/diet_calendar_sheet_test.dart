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
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/today.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/diet_calendar_sheet.dart';
import 'package:turtle_lift/src/ui/diet_day_card.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/diet_slot_card.dart';
import 'package:turtle_lift/src/ui/food_picker_screen.dart';
import 'package:turtle_lift/src/ui/food_serving_sheet.dart';

/// The Diet date picker (`docs/adr/0017-diet-date-picker.md`): a calendar
/// button in the Diet header, a month calendar with a dot on every logged day,
/// and a pick that moves the week strip to that day's week.
///
/// "Today" is Wednesday 4 November 2026. The 26th of October is a Wednesday
/// too, so its Monday-to-Sunday week is 26 Oct to 1 Nov.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LocalDate nov(int day) => LocalDate(2026, 11, day);
  LocalDate oct(int day) => LocalDate(2026, 10, day);

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
    food('soya', 'Soya chunks', 21.5),
  ]);

  DietLogEntry entry(LocalDate date,
          {String foodId = 'paneer', MealSlot slot = MealSlot.lunch}) =>
      DietLogEntry(
        id: '$foodId-${date.encode()}-${slot.name}',
        date: date,
        slot: slot,
        foodId: foodId,
        servingsHalves: 2,
        position: 0,
      );

  /// The Diet root's shape, with the calendar button in the header as
  /// `L0Shell` puts it there.
  Widget host({List<DietLogEntry> log = const <DietLogEntry>[]}) =>
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          dietLogStoreProvider.overrideWithValue(store),
          foodIndexProvider.overrideWithValue(foods),
          planTodayProvider.overrideWithValue(nov(4)),
          initialDietLogProvider.overrideWithValue(log),
          initialProteinTargetProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: AppScreen.root(
            title: 'Diet',
            actions: const <Widget>[DietCalendarButton()],
            body: Builder(
              builder: (context) => ListView(
                padding: screenScrollPadding(context),
                children: const <Widget>[DietPane()],
              ),
            ),
          ),
        ),
      );

  Future<void> pump(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DietPane)));

  /// Picking a date moves the strip and says nothing more: no "26 Oct to
  /// 1 Nov" line is added above it, this week or any other.
  void expectNoRangeLine() {
    expect(
      find.byWidgetPredicate((w) =>
          w is Text &&
          RegExp(r'\d{1,2} [A-Z][a-z]{2}( \d{4})? to \d')
              .hasMatch(w.data ?? w.textSpan?.toPlainText() ?? '')),
      findsNothing,
      reason: 'no date-range caption anywhere',
    );
  }

  Future<void> openCalendar(WidgetTester tester) async {
    await tester.tap(find.byKey(DietCalendarButton.buttonKey));
    await tester.pumpAndSettle();
  }

  Future<void> tapDay(WidgetTester tester, LocalDate day) async {
    await tester.tap(find.byKey(DietCalendarSheet.dayKey(day)));
    await tester.pumpAndSettle();
  }

  String monthText(WidgetTester tester) => tester
      .widget<Text>(find.descendant(
        of: find.byKey(DietCalendarSheet.monthLabelKey),
        matching: find.byType(Text),
      ))
      .data!;

  group('the header button', () {
    testWidgets('is a calendar glyph named "Pick a date"', (tester) async {
      await pump(tester, host());

      expect(find.byKey(DietCalendarButton.buttonKey), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
      expect(DietCalendarButton.label, 'Pick a date');
      expect(
        tester.getSemantics(find.byKey(DietCalendarButton.buttonKey)).label,
        'Pick a date',
      );
      expect(
        tester.getSize(find.byKey(DietCalendarButton.buttonKey)),
        const Size(48, 48),
        reason: 'a 48pt tap target',
      );
      expect(find.byType(DietCalendarSheet), findsNothing);
    });

    testWidgets('opens the calendar sheet', (tester) async {
      await pump(tester, host());
      await openCalendar(tester);

      expect(find.byType(DietCalendarSheet), findsOneWidget);
      expect(find.byKey(DietCalendarSheet.gridKey), findsOneWidget);
    });
  });

  group('the calendar', () {
    testWidgets('opens on the month of the selected day', (tester) async {
      await pump(tester, host());
      await openCalendar(tester);

      expect(monthText(tester), 'November 2026');
    });

    testWidgets('reopens on the month of the day that was picked',
        (tester) async {
      await pump(tester, host());
      await openCalendar(tester);
      await tester.tap(find.byKey(DietCalendarSheet.prevButtonKey));
      await tester.pumpAndSettle();
      await tapDay(tester, oct(28));

      expect(find.byType(DietCalendarSheet), findsNothing);
      await openCalendar(tester);
      expect(monthText(tester), 'October 2026',
          reason: 'the sheet starts where the selection is');
    });

    testWidgets('pages back a month and forward again, never past this month',
        (tester) async {
      await pump(tester, host());
      await openCalendar(tester);

      // There is no month after the current one: Next does nothing.
      await tester.tap(find.byKey(DietCalendarSheet.nextButtonKey));
      await tester.pumpAndSettle();
      expect(monthText(tester), 'November 2026');
      expect(find.byKey(DietCalendarSheet.dayKey(LocalDate(2026, 12, 1))),
          findsNothing);

      await tester.tap(find.byKey(DietCalendarSheet.prevButtonKey));
      await tester.pumpAndSettle();
      expect(monthText(tester), 'October 2026');
      expect(find.byKey(DietCalendarSheet.dayKey(oct(28))), findsOneWidget);

      await tester.tap(find.byKey(DietCalendarSheet.nextButtonKey));
      await tester.pumpAndSettle();
      expect(monthText(tester), 'November 2026');
    });

    testWidgets('a month label names the month and the year', (tester) async {
      await pump(tester, host());
      await openCalendar(tester);
      await tester.tap(find.byKey(DietCalendarSheet.prevButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DietCalendarSheet.prevButtonKey));
      await tester.pumpAndSettle();

      expect(monthText(tester), 'September 2026');
    });

    testWidgets('the grid has as many rows as the month has weeks',
        (tester) async {
      await pump(tester, host());
      await openCalendar(tester);

      // November 2026 starts on a Sunday: 30 days over six Monday-first rows.
      expect(tester.getSize(find.byKey(DietCalendarSheet.gridKey)).height,
          DietCalendarSheet.cellHeight * 6);
      await tester.tap(find.byKey(DietCalendarSheet.prevButtonKey));
      await tester.pumpAndSettle();
      // October 2026 starts on a Thursday: five rows.
      expect(tester.getSize(find.byKey(DietCalendarSheet.gridKey)).height,
          DietCalendarSheet.cellHeight * 5);
    });
  });

  group('markers', () {
    testWidgets('sit on exactly the days with food logged', (tester) async {
      await pump(
        tester,
        host(log: <DietLogEntry>[
          entry(nov(2)),
          entry(nov(4)),
          // Two foods in one day is still one marker.
          entry(nov(4), foodId: 'soya', slot: MealSlot.snack),
        ]),
      );
      await openCalendar(tester);

      for (final d in <int>[2, 4]) {
        expect(find.byKey(DietCalendarSheet.markerKey(nov(d))), findsOneWidget,
            reason: 'Nov $d has food logged');
      }
      for (final d in <int>[1, 3]) {
        expect(find.byKey(DietCalendarSheet.markerKey(nov(d))), findsNothing,
            reason: 'Nov $d is empty');
      }
      expect(find.byType(Container).evaluate().where((e) {
        final key = e.widget.key;
        return key is ValueKey<String> && key.value.startsWith('diet-cal-dot');
      }), hasLength(2));
    });

    testWidgets('never sit on a day that has not happened yet', (tester) async {
      await pump(
        tester,
        host(log: <DietLogEntry>[entry(nov(4)), entry(nov(6))]),
      );
      await openCalendar(tester);

      expect(find.byKey(DietCalendarSheet.markerKey(nov(4))), findsOneWidget);
      expect(find.byKey(DietCalendarSheet.markerKey(nov(6))), findsNothing,
          reason: 'a future day shows no marker even with a stray row');
    });

    testWidgets('follow the month paged to', (tester) async {
      await pump(
        tester,
        host(log: <DietLogEntry>[entry(oct(28)), entry(nov(4))]),
      );
      await openCalendar(tester);
      expect(find.byKey(DietCalendarSheet.markerKey(oct(28))), findsNothing,
          reason: 'October is not on screen yet');

      await tester.tap(find.byKey(DietCalendarSheet.prevButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(DietCalendarSheet.markerKey(oct(28))), findsOneWidget);
    });

    testWidgets('appear once a food is logged and go when it is removed',
        (tester) async {
      await pump(tester, host());
      await openCalendar(tester);
      expect(find.byKey(DietCalendarSheet.markerKey(nov(4))), findsNothing);

      final container = containerOf(tester);
      await container.read(dietLogProvider.notifier).addFood(
            date: nov(4),
            slot: MealSlot.lunch,
            foodId: 'paneer',
            halves: 2,
          );
      await tester.pumpAndSettle();
      expect(find.byKey(DietCalendarSheet.markerKey(nov(4))), findsOneWidget);

      final only = container.read(dietLogProvider).single;
      await container.read(dietLogProvider.notifier).removeEntry(only);
      await tester.pumpAndSettle();
      expect(find.byKey(DietCalendarSheet.markerKey(nov(4))), findsNothing);
    });

    testWidgets('are named in the cell\'s semantics, not by dot alone',
        (tester) async {
      await pump(tester, host(log: <DietLogEntry>[entry(nov(4))]));
      await openCalendar(tester);

      expect(
        tester.getSemantics(find.byKey(DietCalendarSheet.dayKey(nov(4)))).label,
        'Wednesday 4 November 2026, today, food logged, selected',
      );
      expect(
        tester.getSemantics(find.byKey(DietCalendarSheet.dayKey(nov(3)))).label,
        'Tuesday 3 November 2026, nothing logged',
      );
      expect(
        tester.getSemantics(find.byKey(DietCalendarSheet.dayKey(nov(6)))).label,
        'Friday 6 November 2026, not yet',
      );
    });
  });

  group('picking a day', () {
    testWidgets('a day after today is inert: the sheet stays, nothing changes',
        (tester) async {
      await pump(tester, host());
      await openCalendar(tester);

      await tapDay(tester, nov(6));

      expect(find.byType(DietCalendarSheet), findsOneWidget,
          reason: 'a future cell does not close the sheet');
      final container = containerOf(tester);
      expect(container.read(dietSelectedDayProvider), nov(4));
      expect(container.read(dietStripStartProvider), nov(2));
      expect(
        tester.getSemantics(find.byKey(DietCalendarSheet.dayKey(nov(6)))),
        isNot(matchesSemantics(isButton: true)),
        reason: 'a future cell is not offered as a button',
      );
    });

    testWidgets('a day this week selects it and leaves the strip where it is',
        (tester) async {
      await pump(tester, host());
      await openCalendar(tester);

      await tapDay(tester, nov(3));

      expect(find.byType(DietCalendarSheet), findsNothing);
      final container = containerOf(tester);
      expect(container.read(dietSelectedDayProvider), nov(3));
      expect(container.read(dietStripStartProvider), nov(2));
      expectNoRangeLine();
    });

    testWidgets(
        'a past day selects it, closes the sheet and moves the strip to its '
        'Monday to Sunday week', (tester) async {
      await pump(tester, host(log: <DietLogEntry>[entry(oct(28))]));
      await openCalendar(tester);
      await tester.tap(find.byKey(DietCalendarSheet.prevButtonKey));
      await tester.pumpAndSettle();

      await tapDay(tester, oct(28));

      expect(find.byType(DietCalendarSheet), findsNothing);
      final container = containerOf(tester);
      expect(container.read(dietSelectedDayProvider), oct(28));
      expect(container.read(dietStripStartProvider), oct(26),
          reason: 'the Monday of the picked day\'s week');

      // The strip shows 26 Oct to 1 Nov, seven cells, the 28th selected.
      final shown = <String>[
        for (var i = 0; i < 7; i++)
          tester.getSemantics(find.byKey(DietWeekStrip.dayKey(i))).label,
      ];
      expect(shown, <String>[
        'Monday 26',
        'Tuesday 27',
        'Wednesday 28',
        'Thursday 29',
        'Friday 30',
        'Saturday 31',
        'Sunday 1',
      ]);
      expect(
        tester.getSemantics(find.byKey(DietWeekStrip.dayKey(2))),
        isSemantics(isSelected: true),
      );
      // The strip's dates are the whole story: no range line is added.
      expectNoRangeLine();
      // The day card is that day's: one paneer, 9.4 g rounded.
      expect(find.text('9 g logged'), findsOneWidget);
      expect(find.text('Nothing logged for Wednesday'), findsNothing);
    });

    testWidgets('the Today button selects today and closes the sheet',
        (tester) async {
      await pump(tester, host(log: <DietLogEntry>[entry(oct(28))]));
      await openCalendar(tester);
      await tester.tap(find.byKey(DietCalendarSheet.prevButtonKey));
      await tester.pumpAndSettle();
      await tapDay(tester, oct(28));
      expect(containerOf(tester).read(dietStripStartProvider), oct(26));

      await openCalendar(tester);
      await tester.tap(find.byKey(DietCalendarSheet.todayKey));
      await tester.pumpAndSettle();

      expect(find.byType(DietCalendarSheet), findsNothing);
      final container = containerOf(tester);
      expect(container.read(dietSelectedDayProvider), nov(4));
      expect(container.read(dietStripStartProvider), nov(2));
      expectNoRangeLine();
    });
  });

  group('editing a past day', () {
    testWidgets('logging a food on the picked past date writes that date',
        (tester) async {
      await pump(tester, host());
      await openCalendar(tester);
      await tester.tap(find.byKey(DietCalendarSheet.prevButtonKey));
      await tester.pumpAndSettle();
      await tapDay(tester, oct(28));

      await tester.tap(find.byKey(DietSlotCard.addFoodKey(MealSlot.snack)));
      await tester.pumpAndSettle();
      expect(find.text('Add to Snack, Wed'), findsOneWidget);
      await tester.tap(find.byKey(FoodPickerScreen.rowKey('soya')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FoodServingSheet.commitKey));
      await tester.pumpAndSettle();

      final entries = await store.readEntries();
      expect(entries, hasLength(1));
      expect(entries.single.date, oct(28),
          reason: 'it is written to the day that was picked, not to today');
      expect(entries.single.slot, MealSlot.snack);
      expect(entries.single.foodId, 'soya');
      expect(containerOf(tester).read(dietSelectedDayProvider), oct(28));
    });
  });
}
