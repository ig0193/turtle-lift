import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/history_calendar_card.dart';

/// The calendar card on the History tab: real month arithmetic, a bounded
/// forward edge, and a tap-to-reveal day detail that reuses the same row the
/// Recent list renders.
///
/// Every test anchors on *today* rather than a fixed date on the calendar
/// grid, because today is guaranteed to be on the initially-shown page
/// regardless of which day this suite happens to run on -- picking an
/// arbitrary day-of-month would risk landing on a different month than the
/// one the card opens to.
void main() {
  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  HistorySession session(String id, DateTime performedOn, {String? title}) =>
      HistorySession(
        id: id,
        performedOn: performedOn,
        title: title,
        exercises: const <HistoryExercise>[],
      );

  Widget host(List<HistorySession> sessions) => ProviderScope(
        overrides: [historySessionsProvider.overrideWithValue(sessions)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: SingleChildScrollView(child: HistoryCalendarCard())),
        ),
      );

  testWidgets('opens on the current month', (tester) async {
    await tester.pumpWidget(host(const <HistorySession>[]));

    expect(find.text(monthYearLabel(today())), findsOneWidget);
  });

  testWidgets('the next-month button starts disabled: there is no future month',
      (tester) async {
    await tester.pumpWidget(host(const <HistorySession>[]));

    await tester.tap(find.byKey(HistoryCalendarCard.nextButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text(monthYearLabel(today())),
      findsOneWidget,
      reason: 'tapping next from the current month must not move anywhere',
    );
  });

  testWidgets('the previous-month button moves the grid back a month',
      (tester) async {
    await tester.pumpWidget(host(const <HistorySession>[]));

    await tester.tap(find.byKey(HistoryCalendarCard.prevButtonKey));
    await tester.pumpAndSettle();

    final now = today();
    final previous = DateTime(now.year, now.month - 1);
    expect(find.text(monthYearLabel(previous)), findsOneWidget);
  });

  testWidgets('a day with no session does not open a detail panel when tapped',
      (tester) async {
    await tester.pumpWidget(host(const <HistorySession>[]));

    await tester.tap(find.byKey(HistoryCalendarCard.dayKey(today())));
    await tester.pumpAndSettle();

    expect(find.textContaining('·'), findsNothing,
        reason: 'no day-detail panel should appear for a day with no session');
  });

  testWidgets('tapping a single-session day reveals it, tapping again hides it',
      (tester) async {
    await tester.pumpWidget(
      host(<HistorySession>[session('a', today(), title: 'Push day')]),
    );

    expect(find.text('Push day'), findsNothing,
        reason: 'collapsed by default -- a dot carries no title on its own');

    await tester.tap(find.byKey(HistoryCalendarCard.dayKey(today())));
    await tester.pumpAndSettle();
    expect(find.text('Push day'), findsOneWidget);

    await tester.tap(find.byKey(HistoryCalendarCard.dayKey(today())));
    await tester.pumpAndSettle();
    expect(find.text('Push day'), findsNothing);
  });

  testWidgets('a day with two sessions reveals both, with a count in the label',
      (tester) async {
    await tester.pumpWidget(host(<HistorySession>[
      session('a', today(), title: 'Shoulders day'),
      session('b', today(), title: 'Barbell curl'),
    ]));

    await tester.tap(find.byKey(HistoryCalendarCard.dayKey(today())));
    await tester.pumpAndSettle();

    expect(find.text('Shoulders day'), findsOneWidget);
    expect(find.text('Barbell curl'), findsOneWidget);
    expect(find.textContaining('· 2 sessions'), findsOneWidget);
  });

  testWidgets('swiping to a different month closes the open day detail',
      (tester) async {
    await tester.pumpWidget(
      host(<HistorySession>[session('a', today(), title: 'Push day')]),
    );

    await tester.tap(find.byKey(HistoryCalendarCard.dayKey(today())));
    await tester.pumpAndSettle();
    expect(find.text('Push day'), findsOneWidget);

    await tester.tap(find.byKey(HistoryCalendarCard.prevButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Push day'), findsNothing);
  });
}
