import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/all_sessions_screen.dart';
import 'package:turtle_lift/src/ui/history_calendar_card.dart';
import 'package:turtle_lift/src/ui/history_root.dart';
import 'package:turtle_lift/src/ui/history_session_detail_screen.dart';

/// The History tab root: a calendar card, then a short Recent trail, then the
/// door to everything else.
///
/// The projection tests matter more than the rendering ones. A PB pill on
/// every row is only affordable because the whole screen is one chronological
/// pass; if that pass is ever wrong, every row is wrong and nothing else here
/// would notice. The full chronological list this root used to render is
/// tested in `all_sessions_screen_test.dart` now that it lives there.
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

  group('monthYearLabel', () {
    test('names the month and year', () {
      expect(monthYearLabel(DateTime(2026, 9, 14)), 'September 2026');
      expect(monthYearLabel(DateTime(2026, 1, 1)), 'January 2026');
    });
  });

  group('groupSessionsByDay', () {
    test('keys by the local calendar day, dropping any time component', () {
      final s = session('a', 0);
      final byDay = groupSessionsByDay(<HistorySession>[s]);
      final today = DateTime.now();
      expect(byDay[DateTime(today.year, today.month, today.day)], <HistorySession>[s]);
    });

    test('a day with two sessions holds both, in the order given', () {
      final morning = session('a', 2);
      final later = session('b', 2);
      final byDay = groupSessionsByDay(<HistorySession>[morning, later]);
      final key = DateTime(morning.performedOn.year, morning.performedOn.month,
          morning.performedOn.day);
      expect(byDay[key], <HistorySession>[morning, later]);
    });
  });

  group('the root', () {
    // Every test below needs the calendar card plus a full Recent list on
    // screen at once. `ListView`'s sliver backing only builds elements inside
    // the viewport (unlike a plain `Column`), so a row below the fold of the
    // default 800x600 test surface genuinely cannot be found by `find.byKey`
    // -- not because it is missing, but because flutter_test never built it.
    void growViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('shows the empty state when there is nothing to list',
        (tester) async {
      growViewport(tester);
      await tester.pumpWidget(host(const <HistorySession>[]));

      expect(find.text('No workouts yet'), findsOneWidget);
      expect(find.byType(HistoryCalendarCard), findsNothing,
          reason: 'a calendar with nothing on it is not an empty state');
    });

    testWidgets('shows the calendar once there is at least one session',
        (tester) async {
      growViewport(tester);
      await tester.pumpWidget(host(<HistorySession>[session('a', 0)]));

      expect(find.byType(HistoryCalendarCard), findsOneWidget);
    });

    testWidgets('the Recent list caps at HistoryRoot.recentCount, newest first',
        (tester) async {
      growViewport(tester);
      final sessions = <HistorySession>[
        for (var i = 0; i < HistoryRoot.recentCount + 2; i++)
          session('s$i', i, title: 'Session $i'),
      ];
      await tester.pumpWidget(host(sessions));

      for (var i = 0; i < HistoryRoot.recentCount; i++) {
        expect(find.byKey(HistoryRoot.recentRowKey('s$i')), findsOneWidget,
            reason: 'the $i-th newest session should be in Recent');
      }
      for (var i = HistoryRoot.recentCount; i < sessions.length; i++) {
        expect(find.byKey(HistoryRoot.recentRowKey('s$i')), findsNothing,
            reason: 'older sessions belong behind "See all", not in Recent');
      }
    });

    testWidgets('"See all" names the total, not just the Recent count',
        (tester) async {
      growViewport(tester);
      final sessions = <HistorySession>[
        for (var i = 0; i < HistoryRoot.recentCount + 3; i++) session('s$i', i),
      ];
      await tester.pumpWidget(host(sessions));

      expect(find.text('See all ${sessions.length} workouts'), findsOneWidget);
    });

    testWidgets('a single workout has no "See all": nothing is behind it (B14)',
        (tester) async {
      growViewport(tester);
      await tester.pumpWidget(host(<HistorySession>[session('a', 0)]));

      expect(find.byKey(HistoryRoot.seeAllKey), findsNothing);
      expect(find.textContaining('See all 1'), findsNothing);
    });

    // QA (Maestro): a workout edited down to one set read "1 sets" on its row.
    testWidgets('a row with one set reads "1 set", not "1 sets"',
        (tester) async {
      growViewport(tester);
      await tester.pumpWidget(host(<HistorySession>[
        session('a', 0, title: 'Bench', exercises: const <HistoryExercise>[
          HistoryExercise(
            name: 'Bench',
            primaryGroupIds: <String>['chest'],
            setScores: <double>[60],
          ),
        ]),
      ]));

      expect(find.textContaining('1 exercise · 1 set'), findsOneWidget);
      expect(find.textContaining('1 sets'), findsNothing);
    });

    testWidgets('"See all" opens the full chronological list', (tester) async {
      growViewport(tester);
      await tester.pumpWidget(host(<HistorySession>[
        session('a', 0, title: 'Today'),
        for (var i = 1; i < HistoryRoot.recentCount; i++)
          session('f$i', i, title: 'Filler $i'),
        session('b', 40, title: 'Last month'),
      ]));

      await tester.tap(find.byKey(HistoryRoot.seeAllKey));
      await tester.pumpAndSettle();

      expect(find.byType(AllSessionsScreen), findsOneWidget);
      // The older session is reachable there even though Recent never showed
      // it (with a short enough Recent list to make the point meaningfully
      // this would need recentCount+ sessions; here it just confirms the
      // destination renders the full, not a truncated, set).
      expect(find.text('Last month'), findsOneWidget);
    });

    testWidgets('a Recent row opens that session, same as everywhere else',
        (tester) async {
      await tester.pumpWidget(host(<HistorySession>[
        session('a', 0, title: 'Push day'),
      ]));

      await tester.tap(find.byKey(HistoryRoot.recentRowKey('a')));
      await tester.pumpAndSettle();

      expect(find.byType(HistorySessionDetailScreen), findsOneWidget);
    });

    testWidgets('with a bodyweight in effect the detail shows kcal and lays '
        'out without a framework error', (tester) async {
      // The detail reads the saved workout itself now (one card, audit B3),
      // so this hands it one rather than a bare History row.
      final today = LocalDate.today();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          exerciseIndexProvider.overrideWithValue(ExerciseIndex(<Exercise>[
            const Exercise(
              id: 'bench',
              name: 'Bench',
              equipment: 'barbell',
              loadType: 'weighted',
              primary: <String>['chest/mid'],
              secondary: <String>[],
              setup: '',
              posture: '',
              execution: '',
              commonMistakes: '',
            ),
          ])),
          initialSavedSessionsProvider.overrideWithValue(<WorkoutSession>[
            WorkoutSession(
              id: 'a',
              title: 'Push day',
              performedOn: today,
              loggedAt: today.toDateTime(),
              templateId: null,
              templateName: null,
              isOpen: false,
              exercises: <SessionExercise>[
                SessionExercise(
                  id: 'a-bench',
                  exerciseId: 'bench',
                  position: 0,
                  loadType: LoadType.weighted,
                  markedDone: false,
                  sets: <SetEntry>[
                    for (var i = 0; i < 3; i++)
                      SetEntry(
                        id: 'a-$i',
                        position: i,
                        completed: true,
                        weightKg: 60,
                        reps: 8,
                      ),
                  ],
                ),
              ],
            ),
          ]),
          initialBodyweightLogProvider.overrideWithValue(<BodyweightEntry>[
            BodyweightEntry(date: day(30), weightKg: 72),
          ]),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: HistoryRoot()),
        ),
      ));

      await tester.tap(find.byKey(HistoryRoot.recentRowKey('a')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'the kcal figure must not nest one Expanded in another');
      expect(find.text('kcal'), findsOneWidget);
      expect(find.byKey(HistorySessionDetailScreen.calorieKey), findsOneWidget);
    });
  });
}
