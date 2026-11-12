import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/muscle_training.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/body_diagram.dart';
import 'package:turtle_lift/src/ui/muscle_exercise_list_screen.dart';
import 'package:turtle_lift/src/ui/muscle_segment_sheet.dart';
import 'package:turtle_lift/src/ui/muscles_root.dart';

/// Training on the Muscles map (ADR 0012): sets this week and last trained,
/// derived on read from the log.
void main() {
  // A Wednesday. Its week runs Monday 2026-11-09 … Sunday 2026-11-15.
  const today = LocalDate(2026, 11, 11);

  Exercise exercise(
    String id, {
    required List<String> primary,
    List<String> secondary = const <String>[],
    bool custom = false,
  }) =>
      Exercise(
        id: id,
        name: id,
        equipment: 'barbell',
        loadType: 'weighted',
        primary: primary,
        secondary: secondary,
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
        isCustom: custom,
      );

  final index = ExerciseIndex(<Exercise>[
    exercise('curl',
        primary: const ['biceps/biceps'],
        secondary: const ['forearms/forearms']),
    exercise('bench',
        primary: const ['chest/mid'],
        secondary: const ['triceps/triceps', 'shoulders/front-delt']),
    exercise('mine', primary: const ['glutes/glutes'], custom: true),
  ]);

  var setCounter = 0;
  SetEntry set({bool completed = true, double kg = 20, int reps = 8}) =>
      SetEntry(
        id: 's${setCounter++}',
        position: 0,
        completed: completed,
        weightKg: kg,
        reps: reps,
      );

  WorkoutSession session(
    String id,
    LocalDate day,
    Map<String, List<SetEntry>> sets, {
    bool open = false,
  }) =>
      WorkoutSession(
        id: id,
        title: null,
        performedOn: day,
        loggedAt: DateTime(day.year, day.month, day.day, 23),
        templateId: null,
        templateName: null,
        isOpen: open,
        exercises: <SessionExercise>[
          for (final entry in sets.entries)
            SessionExercise(
              id: '$id-${entry.key}',
              exerciseId: entry.key,
              position: 0,
              loadType: LoadType.weighted,
              markedDone: false,
              sets: entry.value,
            ),
        ],
      );

  group('muscleTrainingFor', () {
    test('counts completed sets this week, primary and secondary apart', () {
      final map = muscleTrainingFor(<WorkoutSession>[
        session('a', today, {
          'curl': [set(), set(), set(completed: false)],
        }),
      ], index, today: today);
      expect(map['biceps/biceps']!.primarySets, 2);
      expect(map['biceps/biceps']!.secondarySets, 0);
      expect(map['forearms/forearms']!.primarySets, 0);
      expect(map['forearms/forearms']!.secondarySets, 2);
      expect(map['biceps/biceps']!.lastTrained, today);
      expect(map['forearms/forearms']!.lastTrained, isNull,
          reason: 'last trained means trained directly');
    });

    test('the week is Monday to Sunday', () {
      final sunday = today.addDays(-3); // 2026-11-08
      final monday = today.addDays(-2); // 2026-11-09
      final map = muscleTrainingFor(<WorkoutSession>[
        session('old', sunday, {'curl': [set()]}),
        session('new', monday, {'bench': [set(), set()]}),
      ], index, today: today);
      expect(map['biceps/biceps']!.primarySets, 0);
      expect(map['biceps/biceps']!.lastTrained, sunday);
      expect(map['chest/mid']!.primarySets, 2);
    });

    test('an 11pm session counts on its own calendar day', () {
      // performedOn is a local date; loggedAt at 23:00 must not move it.
      final map = muscleTrainingFor(<WorkoutSession>[
        session('late', today.addDays(-2), {'curl': [set()]}),
      ], index, today: today);
      expect(map['biceps/biceps']!.lastTrained, today.addDays(-2));
      expect(map['biceps/biceps']!.primarySets, 1);
    });

    test('deleting a session takes its sets off the map', () {
      final both = [
        session('a', today, {'curl': [set()]}),
        session('b', today, {'curl': [set()]}),
      ];
      expect(muscleTrainingFor(both, index, today: today)['biceps/biceps']!
          .primarySets, 2);
      expect(
          muscleTrainingFor(both.take(1), index, today: today)['biceps/biceps']!
              .primarySets,
          1);
      expect(muscleTrainingFor(const [], index, today: today), isEmpty);
    });

    test('the open workout counts, once even if also saved', () {
      final open = session('o', today, {'curl': [set()]}, open: true);
      final map = muscleTrainingFor([open, open], index, today: today);
      expect(map['biceps/biceps']!.primarySets, 1);
    });

    test('a custom exercise counts for its muscles', () {
      final map = muscleTrainingFor(<WorkoutSession>[
        session('a', today, {'mine': [set()]}),
      ], index, today: today);
      expect(map['glutes/glutes']!.primarySets, 1);
    });

    test('a date after today counts in the week but is not "last trained"',
        () {
      final map = muscleTrainingFor(<WorkoutSession>[
        session('a', today.addDays(2), {'curl': [set()]}),
      ], index, today: today);
      expect(map['biceps/biceps']!.primarySets, 1);
      expect(map['biceps/biceps']!.lastTrained, isNull);
    });
  });

  group('muscleTrainingLine', () {
    test('words each state', () {
      expect(muscleTrainingLine(MuscleTraining.none, today), 'Not trained yet');
      expect(
        muscleTrainingLine(
            MuscleTraining(primarySets: 6, lastTrained: today), today),
        '6 sets this week · Last trained today',
      );
      expect(
        muscleTrainingLine(
            MuscleTraining(primarySets: 1, lastTrained: today.addDays(-1)),
            today),
        '1 set this week · Last trained yesterday',
      );
      expect(
        muscleTrainingLine(
            MuscleTraining(lastTrained: today.addDays(-9)), today),
        'No sets this week · Last trained 9 days ago',
      );
      expect(
        muscleTrainingLine(const MuscleTraining(secondarySets: 2), today),
        '2 secondary sets this week',
      );
      expect(
        muscleTrainingLine(
            MuscleTraining(
                primarySets: 3, secondarySets: 2, lastTrained: today),
            today),
        '3 sets this week · 2 as secondary · Last trained today',
      );
    });
  });

  group('on screen', () {
    Widget host(List<WorkoutSession> saved, Widget child) => ProviderScope(
          key: UniqueKey(),
          overrides: [
            exerciseIndexProvider.overrideWithValue(index),
            initialSavedSessionsProvider.overrideWithValue(saved),
            planClockProvider.overrideWithValue(() => today),
            initialBodyGenderProvider.overrideWithValue(BodyGender.male),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(body: child),
          ),
        );

    void tall(WidgetTester tester) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 2400);
      addTearDown(tester.view.reset);
    }

    BodyDiagramPainter painterOf(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.descendant(
          of: find.byType(BodyDiagram),
          matching: find.byType(CustomPaint),
        ))
        .map((w) => w.painter)
        .whereType<BodyDiagramPainter>()
        .first;

    testWidgets('the landing fills primary in the accent and secondary in '
        'the secondary colour', (tester) async {
      tall(tester);
      await tester.pumpWidget(host([
        session('a', today, {'curl': [set(), set()]}),
      ], const MusclesRoot()));
      await tester.pump();
      final fill = painterOf(tester).fill;
      expect(fill(const {'biceps/biceps'}), AppPalette.accentStrong);
      expect(fill(const {'forearms/forearms'}), AppPalette.accentLight);
      expect(fill(const {'quads/quads'}), AppPalette.mutedSurface);
      expect(find.text(kMusclesEmptyWeekNote), findsNothing);
      expect(find.text(kMusclesLegendWorked), findsOneWidget);
    });

    testWidgets('nothing trained this week says so and the map is grey',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(host([
        session('a', today.addDays(-10), {'curl': [set()]}),
      ], const MusclesRoot()));
      await tester.pump();
      expect(painterOf(tester).fill(const {'biceps/biceps'}),
          AppPalette.mutedSurface);
      expect(find.text(kMusclesEmptyWeekNote), findsOneWidget);
    });

    testWidgets('a muscle list says its sets this week and last trained',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(host([
        session('a', today, {'curl': [set(), set()]}),
      ], const MuscleExerciseListScreen(subGroupId: 'biceps/biceps')));
      await tester.pump();
      expect(find.text('2 sets this week · Last trained today'),
          findsOneWidget);
    });

    testWidgets('the shoulder sheet says each muscle\'s training',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(host([
        session('a', today, {'bench': [set()]}),
      ], const MuscleSegmentSheet(subGroupIds: [
        'shoulders/front-delt',
        'shoulders/side-delt',
      ])));
      await tester.pump();
      expect(find.textContaining('1 secondary set this week'), findsOneWidget);
      expect(find.textContaining('Not trained yet'), findsOneWidget);
    });
  });
}
