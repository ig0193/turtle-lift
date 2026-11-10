import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/date_labels.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/all_sessions_screen.dart';
import 'package:turtle_lift/src/ui/history_calendar_card.dart';
import 'package:turtle_lift/src/ui/history_root.dart';
import 'package:turtle_lift/src/ui/history_session_row.dart';
import 'package:turtle_lift/src/ui/session_date_control.dart';

/// Slice 3 of the History build: one date format, and the year whenever it
/// is not this year (audit B4, B13, B14; ADR 0013).
void main() {
  const today = LocalDate(2026, 11, 10);

  group('lists omit the year only in the current year', () {
    test('same year', () {
      expect(shortDateLabel(const LocalDate(2026, 11, 7), today: today),
          '7 Nov');
      expect(weekdayDateLabel(const LocalDate(2026, 7, 28), today: today),
          'Tue 28 Jul');
    });

    test('previous year', () {
      expect(shortDateLabel(const LocalDate(2025, 11, 7), today: today),
          '7 Nov 2025');
      expect(weekdayDateLabel(const LocalDate(2025, 12, 31), today: today),
          'Wed 31 Dec 2025');
    });

    test('Today and Yesterday stay relative, then the short date', () {
      expect(relativeDayLabel(today, today: today), 'Today');
      expect(relativeDayLabel(today.addDays(-1), today: today), 'Yesterday');
      expect(relativeDayLabel(const LocalDate(2025, 11, 10), today: today),
          '10 Nov 2025');
    });

    test('the History row label carries the year from another year', () {
      expect(
        historyDateLabel(DateTime(2025, 12, 30), now: DateTime(2026, 1, 2)),
        '30 Dec 2025',
      );
      expect(
        historyDateLabel(DateTime(2026, 1, 1), now: DateTime(2026, 1, 2)),
        'Yesterday',
      );
    });

    test('the live date chip names the year of a backdated workout', () {
      final lastYear = LocalDate(LocalDate.today().year - 1, 12, 1);
      expect(longDateLabel(lastYear), endsWith(' ${lastYear.year}'));
    });
  });

  group('the share card and first logged always carry the year', () {
    test('card date', () {
      expect(cardDateLabel(const LocalDate(2026, 11, 10)), 'Tue 10 Nov 2026');
    });

    test('first logged', () {
      expect(dateWithYearLabel(const LocalDate(2026, 10, 18)), '18 Oct 2026');
    });

    test('screen readers hear the whole date', () {
      expect(spokenDateLabel(const LocalDate(2026, 11, 10)),
          'Tuesday 10 November 2026');
    });
  });

  group('"ago" switches to years past 12 months', () {
    test('weeks and months', () {
      expect(agoLabel(today.addDays(-3), today: today), '3 days ago');
      expect(agoLabel(today.addDays(-10), today: today), '1 week ago');
      expect(agoLabel(const LocalDate(2026, 9, 10), today: today),
          '2 months ago');
      expect(agoLabel(const LocalDate(2025, 12, 10), today: today),
          '11 months ago');
    });

    test('12, 13 and 25 months', () {
      expect(agoLabel(const LocalDate(2025, 11, 10), today: today),
          '1 year ago');
      expect(agoLabel(const LocalDate(2025, 10, 10), today: today),
          '1 year ago');
      expect(agoLabel(const LocalDate(2024, 10, 10), today: today),
          '2 years ago');
    });

    test('a day short of the anniversary is still months', () {
      expect(agoLabel(const LocalDate(2025, 11, 11), today: today),
          '11 months ago');
    });

    test('a spring-forward weekend does not shorten a gap', () {
      // Calendar dates, not durations: 23-hour days cannot lose a day.
      expect(
        agoLabel(const LocalDate(2026, 3, 27), today: const LocalDate(2026, 3, 30)),
        '3 days ago',
      );
    });
  });

  group('screens', () {
    DateTime day(int daysAgo) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day - daysAgo);
    }

    HistorySession session(String id, DateTime on, {String? title}) =>
        HistorySession(
          id: id,
          performedOn: on,
          title: title,
          exercises: const <HistoryExercise>[
            HistoryExercise(
              name: 'Bench',
              primaryGroupIds: <String>['chest'],
              setScores: <double>[60],
            ),
          ],
        );

    Widget host(List<HistorySession> sessions, Widget home) => ProviderScope(
          key: UniqueKey(),
          overrides: [historySessionsProvider.overrideWithValue(sessions)],
          child: MaterialApp(theme: buildAppTheme(), home: home),
        );

    testWidgets('All workouts spanning years heads each month with its year',
        (tester) async {
      final now = DateTime.now();
      final lastYear = DateTime(now.year - 1, 12, 3);
      await tester.pumpWidget(host(<HistorySession>[
        session('now', day(0), title: 'This year'),
        session('old', lastYear, title: 'Last year'),
      ], const AllSessionsScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('December ${now.year - 1}'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Last year, .*3 Dec ${now.year - 1}')),
        findsOneWidget,
      );
    });

    testWidgets('the calendar day panel uses the one date order',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final today = day(0);
      await tester.pumpWidget(host(<HistorySession>[
        session('a', today, title: 'One'),
        session('b', today, title: 'Two'),
      ], const Scaffold(body: SingleChildScrollView(child: HistoryCalendarCard()))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistoryCalendarCard.dayKey(today)));
      await tester.pumpAndSettle();

      final label = weekdayDateLabel(LocalDate.fromDateTime(today));
      expect(find.text('$label · 2 workouts'), findsOneWidget);
      expect(find.textContaining('sessions'), findsNothing);
    });

    testWidgets('"See all" says workouts and hides when nothing is hidden',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(<HistorySession>[
        for (var i = 0; i < HistoryRoot.recentCount; i++)
          session('s$i', day(i)),
      ], const Scaffold(body: HistoryRoot())));
      await tester.pumpAndSettle();
      expect(find.byKey(HistoryRoot.seeAllKey), findsNothing,
          reason: 'every workout is already in Recent (B14)');

      await tester.pumpWidget(host(<HistorySession>[
        for (var i = 0; i < HistoryRoot.recentCount + 2; i++)
          session('s$i', day(i)),
      ], const Scaffold(body: HistoryRoot())));
      await tester.pumpAndSettle();
      expect(find.text('See all ${HistoryRoot.recentCount + 2} workouts'),
          findsOneWidget);
    });

    test('row label helper is the History row date', () {
      expect(historyDateLabel(day(0)), 'Today');
    });

    testWidgets('a row from last year carries the year on screen',
        (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(host(<HistorySession>[
        session('old', DateTime(now.year - 1, 7, 4), title: 'Old'),
      ], const Scaffold(body: HistoryRoot())));
      await tester.pumpAndSettle();
      expect(find.textContaining('4 Jul ${now.year - 1}'), findsWidgets);
      expect(find.byType(HistorySessionRow), findsWidgets);
    });
  });
}
