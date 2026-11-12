import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/derived.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/exercise_detail_screen.dart';
import 'package:turtle_lift/src/ui/exercise_history_screen.dart';

/// Exercise detail's history line (ADR 0012): "Last 62.5kg × 6 · 2 times ·
/// See history", only when the exercise has been logged.
void main() {
  Exercise make(String id, String loadType) => Exercise(
        id: id,
        name: id == 'bench' ? 'Barbell bench press' : 'Assisted pull-up',
        equipment: 'barbell',
        loadType: loadType,
        primary: const ['chest/mid'],
        secondary: const [],
        setup: 's',
        posture: 'p',
        execution: 'e',
        commonMistakes: 'c',
      );
  final bench = make('bench', 'weighted');
  final assisted = make('assisted', 'assisted');
  final index = ExerciseIndex(<Exercise>[bench, assisted]);

  WorkoutSession session(String id, LocalDate day, String exerciseId,
          LoadType type, List<SetEntry> sets) =>
      WorkoutSession(
        id: id,
        title: null,
        performedOn: day,
        loggedAt: DateTime(day.year, day.month, day.day, 9),
        templateId: null,
        templateName: null,
        isOpen: false,
        exercises: [
          SessionExercise(
            id: '$id-x',
            exerciseId: exerciseId,
            position: 0,
            loadType: type,
            markedDone: false,
            sets: sets,
          ),
        ],
      );

  final saved = <WorkoutSession>[
    session('a', const LocalDate(2026, 11, 2), 'bench', LoadType.weighted, [
      const SetEntry(id: 'a1', position: 0, completed: true, weightKg: 60, reps: 8),
    ]),
    session('b', const LocalDate(2026, 11, 9), 'bench', LoadType.weighted, [
      const SetEntry(id: 'b1', position: 0, completed: true, weightKg: 60, reps: 8),
      const SetEntry(id: 'b2', position: 1, completed: true, weightKg: 62.5, reps: 6),
      const SetEntry(id: 'b3', position: 2, completed: false, weightKg: 70, reps: 1),
    ]),
  ];

  test('timesLogged counts sessions with a completed set', () {
    expect(timesLogged('bench', saved), 2);
    expect(timesLogged('assisted', saved), 0);
  });

  test('lastSetLine reads the last completed set of the last session', () {
    expect(lastSetLine('bench', saved), 'Last 62.5kg × 6');
    expect(lastSetLine('assisted', saved), isNull);
  });

  Future<void> pump(WidgetTester tester, Exercise exercise) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        exerciseIndexProvider.overrideWithValue(index),
        initialSavedSessionsProvider.overrideWithValue(saved),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: ExerciseDetailScreen(exercise: exercise),
      ),
    ));
    await tester.pump();
  }

  testWidgets('a logged exercise shows the line, and it opens its history',
      (tester) async {
    await pump(tester, bench);
    expect(find.byKey(ExerciseDetailScreen.historyLineKey), findsOneWidget);
    expect(find.textContaining('Last 62.5kg × 6 · 2 times'), findsOneWidget);
    expect(find.textContaining('See history'), findsOneWidget);
    await tester.tap(find.byKey(ExerciseDetailScreen.historyLineKey));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseHistoryScreen), findsOneWidget);
  });

  testWidgets('a never-logged exercise shows no line', (tester) async {
    await pump(tester, assisted);
    expect(find.byKey(ExerciseDetailScreen.historyLineKey), findsNothing);
    expect(find.textContaining('See history'), findsNothing);
  });
}
