import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/all_sessions_screen.dart';

/// The full chronological list, moved off [HistoryRoot] and behind its "See
/// all" button. These are the row-rendering tests `history_root_test.dart`
/// carried before the tab root became a calendar plus a short Recent list --
/// the rows themselves (ordering, the PB pill, the quick-log tag, month
/// grouping) did not change, only which screen renders the full run of them.
void main() {
  DateTime day(int daysAgo) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - daysAgo);
  }

  HistorySession session(
    String id,
    int daysAgo, {
    String? title,
    bool quick = false,
    List<HistoryExercise> exercises = const <HistoryExercise>[],
  }) =>
      HistorySession(
        id: id,
        performedOn: day(daysAgo),
        title: title,
        isQuickLog: quick,
        exercises: exercises,
      );

  Widget host(List<HistorySession> sessions) => ProviderScope(
        key: UniqueKey(),
        overrides: [historySessionsProvider.overrideWithValue(sessions)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: AllSessionsScreen()),
        ),
      );

  testWidgets('lists sessions newest first, by the day they happened',
      (tester) async {
    await tester.pumpWidget(host(<HistorySession>[
      session('old', 10, title: 'Older', exercises: const <HistoryExercise>[
        HistoryExercise(
          name: 'A',
          primaryGroupIds: <String>['chest'],
          setScores: <double>[1],
        ),
      ]),
      session('new', 1, title: 'Newer', exercises: const <HistoryExercise>[
        HistoryExercise(
          name: 'A',
          primaryGroupIds: <String>['chest'],
          setScores: <double>[1],
        ),
      ]),
    ]));

    expect(
      tester.getRect(find.byKey(AllSessionsScreen.rowKey('new'))).top,
      lessThan(tester.getRect(find.byKey(AllSessionsScreen.rowKey('old'))).top),
    );
  });

  testWidgets('shows a PB pill only when the session set one', (tester) async {
    await tester.pumpWidget(host(<HistorySession>[
      session('first', 5, title: 'First', exercises: const <HistoryExercise>[
        HistoryExercise(
          name: 'Bench',
          primaryGroupIds: <String>['chest'],
          setScores: <double>[100],
        ),
      ]),
      session('pb', 1, title: 'Record', exercises: const <HistoryExercise>[
        HistoryExercise(
          name: 'Bench',
          primaryGroupIds: <String>['chest'],
          setScores: <double>[105],
        ),
      ]),
    ]));

    expect(find.text('1 PB'), findsOneWidget);
    expect(
      find.textContaining('0 PB'),
      findsNothing,
      reason: 'the spec forbids rendering "0 personal bests"',
    );
  });

  testWidgets('tags a quick log so its shorter line reads as a kind of entry',
      (tester) async {
    await tester.pumpWidget(host(<HistorySession>[
      session('q', 1, quick: true, exercises: const <HistoryExercise>[
        HistoryExercise(
          name: 'Barbell curl',
          primaryGroupIds: <String>['biceps'],
          setScores: <double>[30],
        ),
      ]),
    ]));

    expect(find.text('quick log'), findsOneWidget);
    expect(find.text('Barbell curl'), findsOneWidget);
  });

  testWidgets('a row carries the date, exercise count and set count',
      (tester) async {
    await tester.pumpWidget(host(<HistorySession>[
      session('a', 0, title: 'Push day', exercises: const <HistoryExercise>[
        HistoryExercise(
          name: 'Bench',
          primaryGroupIds: <String>['chest'],
          setScores: <double>[80, 80, 75],
        ),
        HistoryExercise(
          name: 'Press',
          primaryGroupIds: <String>['shoulders'],
          setScores: <double>[45, 45],
        ),
      ]),
    ]));

    expect(find.text('Today · 2 exercises · 5 sets'), findsOneWidget);
  });

  testWidgets('a single-exercise session is not pluralised', (tester) async {
    await tester.pumpWidget(host(<HistorySession>[
      session('a', 2, title: 'One', exercises: const <HistoryExercise>[
        HistoryExercise(
          name: 'Bench',
          primaryGroupIds: <String>['chest'],
          setScores: <double>[80],
        ),
      ]),
    ]));

    expect(find.textContaining('1 exercise ·'), findsOneWidget);
  });

  testWidgets('still shows the empty state when there is nothing to list',
      (tester) async {
    await tester.pumpWidget(host(const <HistorySession>[]));

    expect(find.text('No workouts yet'), findsOneWidget);
    expect(
      find.byKey(AllSessionsScreen.rowKey('anything')),
      findsNothing,
    );
  });

  testWidgets('groups rows under the month they happened in', (tester) async {
    await tester.pumpWidget(host(kPreviewSessions));
    await tester.pumpAndSettle();

    // Whatever today is, the newest session's month heads the list.
    final newest = <HistorySession>[...kPreviewSessions]
      ..sort((a, b) => b.performedOn.compareTo(a.performedOn));
    final first = newest.first.performedOn;

    expect(
      find.byKey(AllSessionsScreen.monthKey(monthYearLabel(first))),
      findsOneWidget,
    );
  });
}
