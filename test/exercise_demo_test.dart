import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/demo/demo_catalogue.dart';
import 'package:turtle_lift/src/demo/demo_painter.dart';
import 'package:turtle_lift/src/demo/figure_rig.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/exercise_demo.dart';
import 'package:turtle_lift/src/ui/exercise_detail_screen.dart';

/// The exercise demonstrations (`docs/adr/0010`).
///
/// The Python validator proves every exercise *names* a pattern from its own
/// list. This proves the other half: that the app can draw every one it was
/// handed, so a pattern added to `animation_map.py` without its Dart motion
/// fails here instead of shipping a page with a silent gap.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Exercise> exercises;
  late ExerciseIndex index;

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final raw = await container.read(exerciseLibraryProvider.future);
    index = ExerciseIndex.fromJson(raw);
    exercises = raw.map(Exercise.fromJson).toList();
  });

  group('coverage', () {
    test('all 260 shipped exercises have a demonstration the app can draw', () {
      expect(exercises, hasLength(260));
      final missing = <String>[
        for (final e in exercises)
          if (demoMotionFor(e.animation) == null) '${e.id} -> ${e.animation}',
      ];
      expect(missing, isEmpty);
    });

    test('every exercise names its gear', () {
      const gears = <String>{
        'none', 'barbell', 'ezbar', 'trapbar', 'smith', 'dumbbell',
        'kettlebell', 'cable', 'machine', 'band', 'plate', 'landmine',
        'wheel', 'ball', 'jumprope', 'roller', 'gripper',
      };
      for (final e in exercises) {
        expect(gears, contains(e.animationGear), reason: e.id);
      }
    });

    test('no motion in the catalogue goes unused', () {
      final used = exercises.map((e) => e.animation).toSet();
      expect(demoPatternIds.where((id) => !used.contains(id)), isEmpty);
    });

    test('every motion solves to finite joints across its whole cycle', () {
      for (final id in demoPatternIds) {
        final motion = demoMotionFor(id)!;
        for (var i = 0; i <= 20; i++) {
          final s = solvePose(motion.poseAt(i / 20), motion.view);
          for (final p in s.points) {
            expect(p.dx.isFinite && p.dy.isFinite, isTrue, reason: '$id at ${i / 20}');
          }
        }
      }
    });

    test('an exercise without a demonstration gets none', () {
      const plain = Exercise(
        id: 'own',
        name: 'Own exercise',
        equipment: 'other',
        loadType: 'weighted',
        primary: <String>['chest/mid'],
        secondary: <String>[],
        setup: 's',
        posture: 'p',
        execution: 'e',
        commonMistakes: 'c',
      );
      expect(ExerciseDemo.forExercise(plain), isNull);
    });
  });

  group('on the page', () {
    Widget host(Exercise exercise) => ProviderScope(
          key: UniqueKey(),
          overrides: [exerciseIndexProvider.overrideWithValue(index)],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: ExerciseDetailScreen(exercise: exercise),
          ),
        );

    ExerciseDemoPainter painter(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.descendant(
          of: find.byType(ExerciseDemo),
          matching: find.byType(CustomPaint),
        ))
        .map((w) => w.painter)
        .whereType<ExerciseDemoPainter>()
        .single;

    testWidgets('it plays on open, labelled, and pauses on the button',
        (tester) async {
      final exercise = index.byId('barbell-back-squat')!;
      await tester.pumpWidget(host(exercise));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(ExerciseDemo), findsOneWidget);
      expect(painter(tester).still, isFalse, reason: 'it is moving');
      expect(find.bySemanticsLabel('Demonstration of Barbell back squat'), findsOneWidget);
      expect(find.byTooltip('Pause demonstration'), findsOneWidget);

      await tester.tap(find.byKey(ExerciseDemo.toggleKey));
      await tester.pump();
      final paused = painter(tester).phase;
      await tester.pump(const Duration(seconds: 1));
      expect(painter(tester).phase, paused, reason: 'paused means frozen');
      expect(find.byTooltip('Play demonstration'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Demonstration of Barbell back squat, paused'),
        findsOneWidget,
      );
    });

    testWidgets('it rests on the still after its reps', (tester) async {
      await tester.pumpWidget(host(index.byId('dumbbell-curl')!));
      await tester.pumpAndSettle();
      expect(painter(tester).still, isTrue);
      expect(find.byTooltip('Play demonstration'), findsOneWidget);
    });

    testWidgets('Reduce Motion shows the still and does not start',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(host(index.byId('push-up')!));
      await tester.pump(const Duration(seconds: 1));
      expect(painter(tester).still, isTrue);
      expect(tester.hasRunningAnimations, isFalse);

      // Pressing play is an explicit request, so it plays.
      await tester.tap(find.byKey(ExerciseDemo.toggleKey));
      await tester.pump(const Duration(milliseconds: 300));
      expect(painter(tester).still, isFalse);
    });
  });
}
