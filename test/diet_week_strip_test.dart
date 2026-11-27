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
import 'package:turtle_lift/src/ui/diet_day_card.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/week_day_meter.dart';

/// The week strip is a window of seven days that slides one day at a time
/// (`docs/adr/0017-diet-date-picker.md`).
///
/// "Today" is Wednesday 4 November 2026, so the strip opens on Monday the 2nd.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LocalDate nov(int day) => LocalDate(2026, 11, day);

  /// The strip is 392 wide in the standalone harness: seven cells of 56.
  const stripWidth = 392.0;
  const cell = stripWidth / 7;

  /// A little over whole cells. Flutter counts the touch slop (up to 20px) in a
  /// drag's first update, so "exactly N cells" is `floor((travel + slop) /
  /// cell)`; every amount below keeps `travel + slop` inside the same whole
  /// number of cells, so a test asserts a day count and not a slop detail.
  const extra = 5.0;

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  // --- The widget on its own ------------------------------------------------

  group('DietWeekStrip', () {
    late List<int> shifts;
    late List<LocalDate> picked;

    Widget host({
      LocalDate? start,
      LocalDate? today,
      LocalDate? selected,
      List<Widget>? meters,
    }) {
      shifts = <int>[];
      picked = <LocalDate>[];
      return MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: stripWidth,
              child: DietWeekStrip(
                start: start ?? nov(2),
                today: today ?? nov(4),
                selected: selected ?? nov(4),
                onSelected: picked.add,
                onShift: shifts.add,
                meters: meters,
              ),
            ),
          ),
        ),
      );
    }

    int totalShift() => shifts.fold(0, (a, b) => a + b);

    Finder strip() => find.byKey(DietWeekStrip.stripKey);

    testWidgets('always has seven days, however it is slid', (tester) async {
      await pumpView(tester);
      await tester.pumpWidget(host());

      for (var i = 0; i < 7; i++) {
        expect(find.byKey(DietWeekStrip.dayKey(i)), findsOneWidget);
      }
      expect(find.byKey(DietWeekStrip.dayKey(7)), findsNothing);

      await tester.pumpWidget(host(start: nov(5)));
      for (var i = 0; i < 7; i++) {
        expect(find.byKey(DietWeekStrip.dayKey(i)), findsOneWidget);
      }
      expect(find.byKey(DietWeekStrip.dayKey(7)), findsNothing);
    });

    testWidgets('names each cell from its own date, not its column',
        (tester) async {
      await pumpView(tester);
      // A strip that opens on a Thursday: the first cell is Thursday the 5th.
      await tester.pumpWidget(host(start: nov(5), today: nov(11)));

      String label(int i) =>
          tester.getSemantics(find.byKey(DietWeekStrip.dayKey(i))).label;
      expect(label(0), 'Thursday 5');
      expect(label(1), 'Friday 6');
      expect(label(4), 'Monday 9');
      expect(label(6), 'Wednesday 11, today');

      // The visible weekday abbreviations follow too.
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
    });

    group('dragging', () {
      testWidgets('left by N cells shows N later days, exactly',
          (tester) async {
        await pumpView(tester);
        await tester.pumpWidget(host());

        await tester.drag(strip(), const Offset(-(cell * 3 + extra), 0));
        await tester.pump();

        expect(shifts, everyElement(1), reason: 'one day per step');
        expect(totalShift(), 3);
      });

      testWidgets('right by N cells shows N earlier days, exactly',
          (tester) async {
        await pumpView(tester);
        await tester.pumpWidget(host());

        await tester.drag(strip(), const Offset(cell * 2 + extra, 0));
        await tester.pump();

        expect(shifts, everyElement(-1));
        expect(totalShift(), -2);
      });

      testWidgets('less than a cell moves nothing', (tester) async {
        await pumpView(tester);
        await tester.pumpWidget(host());

        await tester.drag(strip(), const Offset(-cell * 0.2, 0));
        await tester.pump();

        expect(shifts, isEmpty);
      });

      testWidgets('what a drag has not yet spent carries into its next move',
          (tester) async {
        await pumpView(tester);
        await tester.pumpWidget(host());

        // Three 0.45-cell moves in ONE gesture are 1.35 cells: one day, with
        // the rest still carried -- not zero days because each move was under
        // a cell.
        final gesture = await tester.startGesture(tester.getCenter(strip()));
        await gesture.moveBy(const Offset(-20, 0)); // past the touch slop
        await gesture.moveBy(const Offset(-cell * 0.45, 0));
        expect(shifts, isEmpty, reason: 'under one cell so far');
        await gesture.moveBy(const Offset(-cell * 0.45, 0));
        await gesture.moveBy(const Offset(-cell * 0.45, 0));
        expect(totalShift(), 1);
        await gesture.up();
      });

      testWidgets('a drag back across the same cell undoes its day',
          (tester) async {
        await pumpView(tester);
        await tester.pumpWidget(host());

        final gesture = await tester.startGesture(tester.getCenter(strip()));
        await gesture.moveBy(const Offset(-20, 0));
        await gesture.moveBy(const Offset(-cell * 1.5, 0));
        expect(totalShift(), 1);
        await gesture.moveBy(const Offset(cell * 2, 0));
        expect(totalShift(), 0, reason: 'dragged back, so back to the start');
        await gesture.up();
      });

      testWidgets('a new drag starts from nothing carried', (tester) async {
        await pumpView(tester);
        await tester.pumpWidget(host());

        await tester.drag(strip(), const Offset(-cell * 0.2, 0));
        await tester.drag(strip(), const Offset(-cell * 0.2, 0));
        await tester.pump();

        expect(shifts, isEmpty,
            reason: 'two separate sub-cell drags do not add up');
      });
    });

    group('flinging', () {
      testWidgets('a quick flick that travels under a cell still moves one day',
          (tester) async {
        await pumpView(tester);
        await tester.pumpWidget(host());

        // 50px is under a cell (56) even with the slop counted, so only the
        // fling's speed can move the window.
        await tester.fling(strip(), const Offset(-50, 0), 1000);
        await tester.pumpAndSettle();
        expect(shifts, <int>[1], reason: 'left shows the next day');

        await tester.fling(strip(), const Offset(50, 0), 1000);
        await tester.pumpAndSettle();
        expect(shifts, <int>[1, -1], reason: 'right shows the previous day');
      });

      testWidgets('a slow small drag is not a fling', (tester) async {
        await pumpView(tester);
        await tester.pumpWidget(host());

        await tester.fling(strip(), const Offset(-50, 0), 100);
        await tester.pumpAndSettle();

        expect(shifts, isEmpty);
      });

      testWidgets('a drag that already moved a day does not move a second one '
          'on release', (tester) async {
        await pumpView(tester);
        await tester.pumpWidget(host());

        await tester.fling(strip(), const Offset(-(cell * 1.2), 0), 2000);
        await tester.pumpAndSettle();

        expect(totalShift(), 1,
            reason: 'one cell of travel is one day, fast or not');
      });
    });

    group('taps and the days that have not happened', () {
      testWidgets('a day up to today can be picked', (tester) async {
        await pumpView(tester);
        await tester.pumpWidget(host());

        await tester.tap(find.byKey(DietWeekStrip.dayKey(0)));
        await tester.tap(find.byKey(DietWeekStrip.dayKey(2)));

        expect(picked, <LocalDate>[nov(2), nov(4)]);
      });

      testWidgets('a day after today is inert and not offered as a button',
          (tester) async {
        await pumpView(tester);
        await tester.pumpWidget(host());

        await tester.tap(find.byKey(DietWeekStrip.dayKey(3))); // Thursday 5th
        await tester.tap(find.byKey(DietWeekStrip.dayKey(6))); // Sunday 8th

        expect(picked, isEmpty);
        expect(
          tester.getSemantics(find.byKey(DietWeekStrip.dayKey(3))),
          isNot(matchesSemantics(isButton: true)),
        );
      });

      testWidgets('which cells are inert follows the window as it slides',
          (tester) async {
        await pumpView(tester);
        // The strip slid back two days: 31 Oct to 6 Nov, so the 5th and 6th
        // (positions 5 and 6) are still ahead, and the 3rd and 4th are not.
        await tester.pumpWidget(host(start: nov(1).addDays(-1)));

        await tester.tap(find.byKey(DietWeekStrip.dayKey(4))); // 4 Nov
        await tester.tap(find.byKey(DietWeekStrip.dayKey(5))); // 5 Nov
        await tester.tap(find.byKey(DietWeekStrip.dayKey(6))); // 6 Nov

        expect(picked, <LocalDate>[nov(4)]);
      });
    });

    group('the selected day', () {
      testWidgets('is highlighted when it is inside the window',
          (tester) async {
        await pumpView(tester);
        await tester.pumpWidget(host(selected: nov(3)));

        for (var i = 0; i < 7; i++) {
          final selected = tester.getSemantics(
              find.byKey(DietWeekStrip.dayKey(i)));
          if (i == 1) {
            expect(selected, isSemantics(isSelected: true));
          } else {
            expect(selected, isNot(isSemantics(isSelected: true)),
                reason: 'only the 3rd is selected (cell $i)');
          }
        }
      });

      testWidgets('is highlighted nowhere once the window has slid past it',
          (tester) async {
        await pumpView(tester);
        await tester.pumpWidget(host(start: nov(9), today: nov(20), selected: nov(4)));

        for (var i = 0; i < 7; i++) {
          expect(
            tester.getSemantics(find.byKey(DietWeekStrip.dayKey(i))),
            isNot(isSemantics(isSelected: true)),
            reason: 'the selection is the 4th, not in 9 to 15 Nov (cell $i)',
          );
        }
      });
    });

    testWidgets('puts each meter under its own day', (tester) async {
      await pumpView(tester);
      await tester.pumpWidget(host(meters: <Widget>[
        for (var i = 0; i < 7; i++) WeekDayMeter(fraction: i / 10),
      ]));

      for (var i = 0; i < 7; i++) {
        final fill = find.descendant(
          of: find.byKey(DietWeekStrip.dayKey(i)),
          matching: find.byKey(WeekDayMeter.fillKey),
        );
        expect(tester.widget<FractionallySizedBox>(fill).widthFactor, i / 10,
            reason: 'cell $i');
      }
    });

    testWidgets('offers earlier and later day to a screen reader',
        (tester) async {
      await pumpView(tester);
      await tester.pumpWidget(host());

      final withActions = find.byWidgetPredicate((w) =>
          w is Semantics && w.properties.customSemanticsActions != null);
      expect(withActions, findsOneWidget);
      final actions = tester
          .widget<Semantics>(withActions)
          .properties
          .customSemanticsActions!;
      final byLabel = <String, VoidCallback>{
        for (final e in actions.entries) e.key.label!: e.value,
      };
      expect(byLabel.keys, containsAll(<String>[
        'Show earlier day',
        'Show later day',
      ]));

      byLabel['Show earlier day']!();
      byLabel['Show later day']!();
      byLabel['Show later day']!();
      expect(shifts, <int>[-1, 1, 1], reason: 'one day each');
    });
  });

  // --- The strip in the pane ------------------------------------------------

  group('the strip in the Diet pane', () {
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
      food('chicken', 'Chicken breast', 30.0),
    ]);

    DietLogEntry entry(LocalDate date, String foodId) => DietLogEntry(
          id: '$foodId-${date.encode()}',
          date: date,
          slot: MealSlot.lunch,
          foodId: foodId,
          servingsHalves: 2,
          position: 0,
        );

    Widget app({
      List<DietLogEntry> log = const <DietLogEntry>[],
      int? target,
    }) =>
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            dietLogStoreProvider.overrideWithValue(store),
            foodIndexProvider.overrideWithValue(foods),
            planTodayProvider.overrideWithValue(nov(4)),
            initialDietLogProvider.overrideWithValue(log),
            initialProteinTargetProvider.overrideWithValue(target),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: AppScreen.root(
              title: 'Diet',
              body: Builder(
                builder: (context) => ListView(
                  padding: screenScrollPadding(context),
                  children: const <Widget>[DietPane()],
                ),
              ),
            ),
          ),
        );

    Future<ProviderContainer> pump(
      WidgetTester tester, {
      List<DietLogEntry> log = const <DietLogEntry>[],
      int? target,
    }) async {
      await pumpView(tester);
      await tester.pumpWidget(app(log: log, target: target));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(DietPane)));
    }

    String cellLabel(WidgetTester tester, int i) =>
        tester.getSemantics(find.byKey(DietPane.weekDayKey(i))).label;

    /// Drags the strip the way a thumb does inside the real pane, where the
    /// list's vertical recognizer competes: the first move only wins the
    /// gesture (Flutter drops it), and [travel] after it is counted in full.
    /// Negative is left. One cell is the strip's width over seven.
    Future<void> paneDrag(WidgetTester tester, double travel) async {
      final gesture = await tester
          .startGesture(tester.getCenter(find.byKey(DietWeekStrip.stripKey)));
      await gesture.moveBy(Offset(travel < 0 ? -25 : 25, 0));
      await gesture.moveBy(Offset(travel, 0));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    /// No text of the Diet pane sits above the strip, and none anywhere reads
    /// like a date range ("2 Nov to 8 Nov"): the strip's own dates are the
    /// whole story.
    void expectNothingAboveStrip(WidgetTester tester) {
      final stripTop = tester.getTopLeft(find.byKey(DietWeekStrip.stripKey)).dy;
      final above = <String>[
        for (final element in find
            .descendant(
                of: find.byType(DietPane), matching: find.byType(Text))
            .evaluate())
          if ((element.renderObject! as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dy <
              stripTop)
            (element.widget as Text).data ??
                (element.widget as Text).textSpan?.toPlainText() ??
                '',
      ];
      expect(above, isEmpty, reason: 'nothing is said above the strip');
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            RegExp(r'\d{1,2} [A-Z][a-z]{2}( \d{4})? to \d')
                .hasMatch(w.data ?? w.textSpan?.toPlainText() ?? '')),
        findsNothing,
        reason: 'no "d Mon to d Mon" range line anywhere',
      );
    }

    testWidgets('opens on this week, Monday to Sunday',
        (tester) async {
      final container = await pump(tester);

      expect(container.read(dietStripStartProvider), nov(2));
      expect(cellLabel(tester, 0), 'Monday 2');
      expect(cellLabel(tester, 2), 'Wednesday 4, today');
      expect(cellLabel(tester, 6), 'Sunday 8');
      expectNothingAboveStrip(tester);
    });

    testWidgets('a real drag on the pane slides it a day at a time and back',
        (tester) async {
      final container = await pump(tester);
      final stripWidth = tester.getSize(find.byKey(DietWeekStrip.stripKey)).width;
      final oneCell = stripWidth / 7;

      await paneDrag(tester, oneCell * 2 + extra);
      expect(container.read(dietStripStartProvider), nov(2).addDays(-2));
      expect(cellLabel(tester, 0), 'Saturday 31');
      expect(cellLabel(tester, 6), 'Friday 6');

      await paneDrag(tester, -(oneCell + extra));
      expect(container.read(dietStripStartProvider), nov(2).addDays(-1));
      expect(cellLabel(tester, 0), 'Sunday 1');
    });

    testWidgets('cannot be slid on past this week\'s Monday', (tester) async {
      final container = await pump(tester);
      final oneCell =
          tester.getSize(find.byKey(DietWeekStrip.stripKey)).width / 7;

      // Already on this week's Monday: dragging towards later days is a stop.
      await paneDrag(tester, -(oneCell * 3 + extra));

      expect(container.read(dietStripStartProvider), nov(2));
      expect(cellLabel(tester, 0), 'Monday 2');
    });

    testWidgets('keeps the selected day while it slides, and the card with it',
        (tester) async {
      final container = await pump(tester, log: <DietLogEntry>[
        entry(nov(4), 'paneer'),
      ]);
      expect(find.text('9 g logged'), findsOneWidget);

      container.read(dietStripStartProvider.notifier).shift(-7);
      await tester.pumpAndSettle();

      expect(container.read(dietSelectedDayProvider), nov(4));
      expect(find.text('9 g logged'), findsOneWidget,
          reason: 'the day card still belongs to the selected day');
      for (var i = 0; i < 7; i++) {
        expect(tester.getSemantics(find.byKey(DietPane.weekDayKey(i))),
            isNot(isSemantics(isSelected: true)),
            reason: 'the 4th is outside 26 Oct to 1 Nov (cell $i)');
      }

      container.read(dietStripStartProvider.notifier).shift(7);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.byKey(DietPane.weekDayKey(2))),
          isSemantics(isSelected: true),
          reason: 'back in view, it is highlighted again');
    });

    testWidgets('picking a day in a slid strip selects that exact date',
        (tester) async {
      final container = await pump(tester);
      container.read(dietStripStartProvider.notifier).shift(-3); // 30 Oct
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DietPane.weekDayKey(1))); // 31 Oct
      await tester.pumpAndSettle();

      expect(container.read(dietSelectedDayProvider), nov(1).addDays(-1));
      expect(find.text('Nothing logged for Saturday'), findsOneWidget);
    });

    group('no caption', () {
      testWidgets('nothing is said above the strip after sliding off this week',
          (tester) async {
        final container = await pump(tester);

        container.read(dietStripStartProvider.notifier).shift(-1);
        await tester.pumpAndSettle();
        expectNothingAboveStrip(tester);

        container.read(dietStripStartProvider.notifier).shift(-20);
        await tester.pumpAndSettle();
        expectNothingAboveStrip(tester);
      });

      testWidgets('nor after picking an earlier week, in this year or another',
          (tester) async {
        final container = await pump(tester);

        container.read(dietStripStartProvider.notifier).showWeekOf(nov(1).addDays(-4));
        await tester.pumpAndSettle();
        expectNothingAboveStrip(tester);

        container
            .read(dietStripStartProvider.notifier)
            .showWeekOf(LocalDate(2025, 12, 30));
        await tester.pumpAndSettle();
        expectNothingAboveStrip(tester);
        expect(cellLabel(tester, 0), 'Monday 29',
            reason: 'the dates themselves are all the strip says');
      });

      testWidgets('the strip is the pane\'s first thing, wherever it sits',
          (tester) async {
        final container = await pump(tester);
        final home = tester.getTopLeft(find.byKey(DietWeekStrip.stripKey)).dy;

        container.read(dietStripStartProvider.notifier).shift(-9);
        await tester.pumpAndSettle();

        expect(tester.getTopLeft(find.byKey(DietWeekStrip.stripKey)).dy, home,
            reason: 'no line appears above it and pushes it down');
      });
    });

    group('the meters', () {
      double fillAt(WidgetTester tester, int position) {
        final fill = find.descendant(
          of: find.byKey(DietPane.weekDayKey(position)),
          matching: find.byKey(WeekDayMeter.fillKey),
        );
        return tester.widget<FractionallySizedBox>(fill).widthFactor!;
      }

      testWidgets('follow the days in the window, not the days in the week',
          (tester) async {
        final container = await pump(tester, target: 100, log: <DietLogEntry>[
          entry(nov(2), 'paneer'), // 9 g of 100
          entry(nov(4), 'chicken'), // 30 g of 100
        ]);
        expect(fillAt(tester, 0), closeTo(0.09, 1e-9));
        expect(fillAt(tester, 2), closeTo(0.30, 1e-9));

        container.read(dietStripStartProvider.notifier).shift(-2); // 31 Oct
        await tester.pumpAndSettle();

        // 31 Oct, 1 Nov, 2 Nov, 3 Nov, 4 Nov: the 2nd moved to position 2 and
        // the 4th to position 4.
        expect(fillAt(tester, 0), 0);
        expect(fillAt(tester, 2), closeTo(0.09, 1e-9));
        expect(fillAt(tester, 4), closeTo(0.30, 1e-9));
      });

      testWidgets('are absent without a target', (tester) async {
        await pump(tester);

        expect(find.byKey(WeekDayMeter.fillKey), findsNothing);
      });
    });
  });
}
