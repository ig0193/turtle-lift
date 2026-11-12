import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/derived.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/training_plan.dart' show planClockProvider, planTodayProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/history_calendar_card.dart';
import 'package:turtle_lift/src/ui/history_root.dart';

/// Slice 5 of the History build: the stats line `docs/00` §11 puts on this
/// tab, a month total for the month shown (never the current week, ADR 0008),
/// and a calendar that sizes to its month, says what each day is, and draws
/// the streak by its own rule (ADR 0013).
void main() {
  const today = LocalDate(2026, 11, 10); // a Tuesday

  HistorySession session(String id, LocalDate on, {int sets = 3}) =>
      HistorySession(
        id: id,
        performedOn: on.toDateTime(),
        exercises: <HistoryExercise>[
          HistoryExercise(
            name: 'Bench',
            primaryGroupIds: const <String>['chest'],
            setScores: <double>[for (var i = 0; i < sets; i++) 60],
          ),
        ],
      );

  Widget host(
    List<HistorySession> sessions, {
    required LocalDate Function() clock,
    Widget home = const Scaffold(body: HistoryRoot()),
  }) =>
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          historySessionsProvider.overrideWithValue(sessions),
          planClockProvider.overrideWithValue(clock),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: home),
      );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('the streak rule, written once', () {
    test('streakFromDays chains gaps of three days or fewer', () {
      expect(
        streakFromDays(<LocalDate>[
          today,
          today.addDays(-3),
          today.addDays(-6),
          today.addDays(-11),
        ], today),
        3,
      );
      expect(streakFromDays(<LocalDate>[today.addDays(-4)], today), 0);
    });

    test('streak links cover the days between chained workouts', () {
      final linked = streakLinkedDays(<LocalDate>[
        today.addDays(-6),
        today.addDays(-3), // gap 3: chained
        today.addDays(1 - 1), // today, gap 3: chained
        today.addDays(-20),
        today.addDays(-16), // gap 4: not chained
      ]);
      for (var d = -6; d < 0; d++) {
        expect(linked, contains(today.addDays(d)), reason: 'day $d');
      }
      expect(linked, isNot(contains(today)),
          reason: 'a link is to the next day; today has none yet');
      for (var d = -20; d < -16; d++) {
        expect(linked, isNot(contains(today.addDays(d))), reason: 'day $d');
      }
    });
  });

  group('the stats line', () {
    testWidgets('equals the derived streak, workouts and sets', (tester) async {
      tall(tester);
      final sessions = <HistorySession>[
        session('a', today, sets: 4),
        session('b', today.addDays(-2), sets: 5),
        session('c', today.addDays(-9), sets: 6),
      ];
      await tester.pumpWidget(host(sessions, clock: () => today));
      await tester.pumpAndSettle();

      final stats = tester.getSemantics(find.byKey(HistoryRoot.statsKey));
      expect(stats.label, contains('2 day streak'));
      expect(stats.label, contains('3 workouts'));
      expect(stats.label, contains('15 sets'));
    });

    testWidgets('the streak explainer opens with the docs/04 copy',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(
          host(<HistorySession>[session('a', today)], clock: () => today));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistoryRoot.streakInfoKey));
      await tester.pumpAndSettle();
      expect(find.text('How your streak works'), findsOneWidget);
      expect(find.textContaining('never went more than 3 days'), findsOneWidget);
    });

    testWidgets('History never shows the current week (ADR 0008)',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(
          host(<HistorySession>[session('a', today)], clock: () => today));
      await tester.pumpAndSettle();
      expect(find.textContaining('this week'), findsNothing);
      expect(find.textContaining('This week'), findsNothing);
    });
  });

  group('the calendar', () {
    Future<void> pumpCalendar(
      WidgetTester tester,
      List<HistorySession> sessions, {
      LocalDate Function()? clock,
    }) async {
      tall(tester);
      await tester.pumpWidget(host(
        sessions,
        clock: clock ?? () => today,
        home: const Scaffold(
          body: SingleChildScrollView(child: HistoryCalendarCard()),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the month total follows paging', (tester) async {
      await pumpCalendar(tester, <HistorySession>[
        session('a', today, sets: 4),
        session('b', today.addDays(-1), sets: 2),
        session('c', const LocalDate(2026, 10, 3), sets: 5),
      ]);
      expect(find.text('2 workouts · 6 sets'), findsOneWidget);

      await tester.tap(find.byKey(HistoryCalendarCard.prevButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('1 workout · 5 sets'), findsOneWidget);

      await tester.tap(find.byKey(HistoryCalendarCard.prevButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('No workouts'), findsOneWidget);
    });

    testWidgets('the grid is as tall as the month has weeks', (tester) async {
      // November 2026 starts on a Sunday: 1 + 29 more days = 6 rows.
      await pumpCalendar(tester, <HistorySession>[session('a', today)]);
      expect(tester.getSize(find.byKey(HistoryCalendarCard.gridKey)).height,
          6 * HistoryCalendarCard.cellHeight);

      // February 2026 starts on a Sunday too, 28 days: 5 rows.
      await pumpCalendar(tester, <HistorySession>[session('a', today)],
          clock: () => const LocalDate(2026, 2, 10));
      expect(tester.getSize(find.byKey(HistoryCalendarCard.gridKey)).height,
          5 * HistoryCalendarCard.cellHeight);
    });

    testWidgets('chevrons and day cells are at least 48pt tall',
        (tester) async {
      await pumpCalendar(tester, <HistorySession>[session('a', today)]);
      final prev = tester.getSize(find.byKey(HistoryCalendarCard.prevButtonKey));
      expect(prev.width, greaterThanOrEqualTo(48));
      expect(prev.height, greaterThanOrEqualTo(48));
      final cell = tester.getSize(
          find.byKey(HistoryCalendarCard.dayKey(today.toDateTime())));
      expect(cell.height, greaterThanOrEqualTo(48));
    });

    testWidgets('a day says its weekday, month and "today"', (tester) async {
      await pumpCalendar(tester, <HistorySession>[
        session('a', today),
        session('b', today),
      ]);
      final label = tester
          .getSemantics(find.byKey(HistoryCalendarCard.dayKey(today.toDateTime())))
          .label;
      expect(label, 'Tuesday 10 November 2026, today, 2 workouts');

      final empty = tester
          .getSemantics(find.byKey(
              HistoryCalendarCard.dayKey(today.addDays(-2).toDateTime())))
          .label;
      expect(empty, 'Sunday 8 November 2026, no workout');
    });

    testWidgets('a future day is muted, says "not yet" and does nothing',
        (tester) async {
      await pumpCalendar(tester, <HistorySession>[session('a', today)]);
      final future = find.byKey(
          HistoryCalendarCard.dayKey(today.addDays(3).toDateTime()));
      final node = tester.getSemantics(future);
      expect(node.label, endsWith('not yet'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    });

    testWidgets('the month refreshes when the clock crosses into a new month',
        (tester) async {
      var now = const LocalDate(2026, 10, 31);
      tall(tester);
      final container = ProviderContainer(overrides: [
        historySessionsProvider
            .overrideWithValue(<HistorySession>[session('a', today)]),
        planClockProvider.overrideWithValue(() => now),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
              body: SingleChildScrollView(child: HistoryCalendarCard())),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);

      // What `RefreshTodayOnResume` does on resume after midnight.
      now = const LocalDate(2026, 11, 1);
      container.invalidate(planTodayProvider);
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      // November is now the newest month: next goes nowhere.
      await tester.tap(find.byKey(HistoryCalendarCard.nextButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      // And October is one page back, not stranded.
      await tester.tap(find.byKey(HistoryCalendarCard.prevButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('streak runs are drawn between chained days only',
        (tester) async {
      await pumpCalendar(tester, <HistorySession>[
        session('a', const LocalDate(2026, 11, 2)),
        session('b', const LocalDate(2026, 11, 5)), // gap 3: a run
        session('c', const LocalDate(2026, 11, 9)), // gap 4: broken
      ]);
      for (final d in <int>[2, 3, 4]) {
        expect(
          find.byKey(HistoryCalendarCard.runKey(DateTime(2026, 11, d))),
          findsOneWidget,
          reason: '$d Nov links to the next day',
        );
        // Built is not drawn: a childless ColoredBox under a loose height
        // laid out at zero and never painted on the device.
        final size = tester
            .getSize(find.byKey(HistoryCalendarCard.runKey(DateTime(2026, 11, d))));
        expect(size.height, 2, reason: '$d Nov connector is visible');
        expect(size.width, greaterThan(10));
      }
      for (final d in <int>[5, 6, 7, 8, 9]) {
        expect(
          find.byKey(HistoryCalendarCard.runKey(DateTime(2026, 11, d))),
          findsNothing,
          reason: '$d Nov is not inside a chain',
        );
      }
    });

    testWidgets('"This month" appears once paged away and comes back',
        (tester) async {
      await pumpCalendar(tester, <HistorySession>[session('a', today)]);
      expect(find.byKey(HistoryCalendarCard.thisMonthKey), findsNothing);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(HistoryCalendarCard.prevButtonKey));
        await tester.pumpAndSettle();
      }
      expect(find.text('August 2026'), findsOneWidget);
      await tester.tap(find.byKey(HistoryCalendarCard.thisMonthKey));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.byKey(HistoryCalendarCard.thisMonthKey), findsNothing);
    });
  });
}
