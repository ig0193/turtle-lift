import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/generated/muscle_taxonomy.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/history_root.dart';
import 'package:turtle_lift/src/ui/history_session_detail_screen.dart';

/// The History tab as the scannable trail: what a row carries, and the
/// projection behind the figures it carries.
///
/// The projection tests matter more than the rendering ones. A PB pill on every
/// row is only affordable because the whole screen is one chronological pass;
/// if that pass is ever wrong, every row is wrong and nothing else here would
/// notice.
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
          home: Scaffold(body: HistoryRoot()),
        ),
      );

  group('the detail screen muscle map', _detailTests);

  group('the projection', () {
    test('the first time an exercise is done is never a personal best', () {
      final figures = buildHistoryProjection(<HistorySession>[
        session('a', 3, exercises: const <HistoryExercise>[
          HistoryExercise(
            name: 'Bench',
            primaryGroupIds: <String>['chest'],
            setScores: <double>[100],
          ),
        ]),
      ]);

      expect(
        figures['a']!.pbCount,
        0,
        reason: 'a first-ever set is trivially your maximum; badging it would '
            "make a beginner's first weeks a wall of trophies",
      );
    });

    test('beating a previous best counts, matching it does not', () {
      final figures = buildHistoryProjection(<HistorySession>[
        session('older', 5, exercises: const <HistoryExercise>[
          HistoryExercise(
            name: 'Bench',
            primaryGroupIds: <String>['chest'],
            setScores: <double>[100],
          ),
        ]),
        session('equal', 3, exercises: const <HistoryExercise>[
          HistoryExercise(
            name: 'Bench',
            primaryGroupIds: <String>['chest'],
            setScores: <double>[100],
          ),
        ]),
        session('better', 1, exercises: const <HistoryExercise>[
          HistoryExercise(
            name: 'Bench',
            primaryGroupIds: <String>['chest'],
            setScores: <double>[102.5],
          ),
        ]),
      ]);

      expect(figures['equal']!.pbCount, 0,
          reason: 'a personal best must be strictly greater');
      expect(figures['better']!.pbCount, 1);
    });

    test('the pass runs chronologically, not in list order', () {
      // Handed newest-first, which is the order the screen renders in. If the
      // projection walked the list as given, the older session would look like
      // it beat the newer one.
      final figures = buildHistoryProjection(<HistorySession>[
        session('newer', 1, exercises: const <HistoryExercise>[
          HistoryExercise(
            name: 'Bench',
            primaryGroupIds: <String>['chest'],
            setScores: <double>[105],
          ),
        ]),
        session('older', 9, exercises: const <HistoryExercise>[
          HistoryExercise(
            name: 'Bench',
            primaryGroupIds: <String>['chest'],
            setScores: <double>[100],
          ),
        ]),
      ]);

      expect(figures['older']!.pbCount, 0);
      expect(figures['newer']!.pbCount, 1);
    });

    test('counts sets and exercises, and trained groups in taxonomy order', () {
      final figures = buildHistoryProjection(<HistorySession>[
        session('a', 1, exercises: const <HistoryExercise>[
          HistoryExercise(
            name: 'Squat',
            primaryGroupIds: <String>['quads', 'glutes'],
            setScores: <double>[100, 100, 95],
          ),
          HistoryExercise(
            name: 'Bench',
            primaryGroupIds: <String>['chest'],
            setScores: <double>[80, 80],
          ),
        ]),
      ]);

      expect(figures['a']!.setCount, 5);
      expect(figures['a']!.exerciseCount, 2);
      expect(
        figures['a']!.trainedGroupIds,
        <String>['chest', 'quads', 'glutes'],
        reason: 'taxonomy order, not the order the exercises were listed, so '
            'two sessions training the same groups render identically',
      );
    });
  });

  group('the resolved title', () {
    test('a quick log falls back to its single exercise name', () {
      final one = session('a', 1, quick: true, exercises: const <
          HistoryExercise>[
        HistoryExercise(
          name: 'Barbell curl',
          primaryGroupIds: <String>['biceps'],
          setScores: <double>[30],
        ),
      ]);
      final figures = buildHistoryProjection(<HistorySession>[one]);

      expect(resolvedTitle(one, figures['a']!), 'Barbell curl');
    });

    test('an untitled multi-exercise session falls back to its muscles', () {
      final s = session('a', 1, exercises: const <HistoryExercise>[
        HistoryExercise(
          name: 'Squat',
          primaryGroupIds: <String>['quads'],
          setScores: <double>[100],
        ),
        HistoryExercise(
          name: 'Bench',
          primaryGroupIds: <String>['chest'],
          setScores: <double>[80],
        ),
      ]);
      final figures = buildHistoryProjection(<HistorySession>[s]);

      expect(resolvedTitle(s, figures['a']!), 'Chest, quads');
    });

    test('a row is never blank', () {
      for (final s in kPreviewSessions) {
        final figures = buildHistoryProjection(kPreviewSessions);
        expect(resolvedTitle(s, figures[s.id]!), isNotEmpty);
      }
    });
  });

  group('the rows', () {
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
        tester.getRect(find.byKey(HistoryRoot.rowKey('new'))).top,
        lessThan(tester.getRect(find.byKey(HistoryRoot.rowKey('old'))).top),
      );
    });

    testWidgets('shows a PB pill only when the session set one',
        (tester) async {
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
        find.byKey(HistoryRoot.rowKey('anything')),
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
      const months = <String>[
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];

      expect(
        find.byKey(
          HistoryRoot.monthKey('${months[first.month - 1]} ${first.year}'),
        ),
        findsOneWidget,
      );
    });
  });
}

/// The detail screen's muscle map, and the trap it was built over.
///
/// `kMuscleTaxonomy` stores **bare** sub-names while the diagram's fill
/// callback speaks in **qualified** ones, so joining them naively paints a
/// correctly shaped, entirely unfilled body — a failure that looks like a
/// styling choice rather than a bug. These tests are the reason it cannot come
/// back quietly.
void _detailTests() {
  test('parent groups resolve to qualified sub-group ids', () {
    expect(
      subMuscleGroupIdsFor(const <String>['chest']),
      <String>{'chest/upper', 'chest/mid', 'chest/lower'},
      reason: 'bare names like "upper" match nothing the diagram asks about',
    );
  });

  test('every id it produces is one the taxonomy actually knows', () {
    // The whole set, not a sample: a typo in one group would otherwise only
    // show up as that one muscle never filling.
    final ids = subMuscleGroupIdsFor(kMuscleTaxonomy.keys);
    expect(ids, isNotEmpty);
    for (final id in ids) {
      expect(
        kSubMuscleGroups.containsKey(id),
        isTrue,
        reason: '$id is not a sub-muscle group; the diagram would ignore it',
      );
    }
  });

  test('it covers every sub-group, so no muscle is unfillable', () {
    expect(
      subMuscleGroupIdsFor(kMuscleTaxonomy.keys),
      kSubMuscleGroups.keys.toSet(),
    );
  });
}
