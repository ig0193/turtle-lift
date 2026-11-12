import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_progress.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/personal_best.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/exercise_history_screen.dart';
import 'package:turtle_lift/src/ui/exercise_progress_chart.dart';

/// Slice 4 of the History build: a per-exercise trend of the best set, by
/// load type, and a quiet "Best at" table (ADR 0013). Derived on read, so an
/// edit or delete moves both.
void main() {
  final today = LocalDate.today();
  var nextId = 0;

  SetEntry set({
    double? weightKg,
    int? reps,
    double? assistKg,
    double? addedKg,
    int? durationSec,
  }) =>
      SetEntry(
        id: 'set-${nextId++}',
        position: 0,
        completed: true,
        weightKg: weightKg,
        reps: reps,
        assistKg: assistKg,
        addedKg: addedKg,
        durationSec: durationSec,
      );

  WorkoutSession workout(
    String id,
    int daysAgo,
    String exerciseId,
    LoadType type,
    List<SetEntry> sets,
  ) {
    final on = today.addDays(-daysAgo);
    return WorkoutSession(
      id: id,
      title: null,
      performedOn: on,
      loggedAt: on.toDateTime(),
      templateId: null,
      templateName: null,
      isOpen: false,
      exercises: <SessionExercise>[
        SessionExercise(
          id: '$id-row',
          exerciseId: exerciseId,
          position: 0,
          loadType: type,
          markedDone: false,
          sets: sets,
        ),
      ],
    );
  }

  ExerciseProgressSeries seriesOf(String exerciseId, List<WorkoutSession> s) =>
      exerciseProgressSeries(exerciseId, s, personalBestProjection(s));

  group('the series, by load type', () {
    test('weighted plots the top weight, oldest first, with its reps', () {
      final sessions = <WorkoutSession>[
        workout('c', 1, 'bench', LoadType.weighted,
            <SetEntry>[set(weightKg: 70, reps: 5), set(weightKg: 65, reps: 8)]),
        workout('a', 20, 'bench', LoadType.weighted,
            <SetEntry>[set(weightKg: 60, reps: 8)]),
        workout('b', 10, 'bench', LoadType.weighted,
            <SetEntry>[set(weightKg: 65, reps: 8), set(weightKg: 65, reps: 6)]),
      ];
      final series = seriesOf('bench', sessions);
      expect(series.points.map((p) => p.value), <double>[60, 65, 70]);
      expect(series.points.last.label, '70kg × 5');
      expect(series.inverted, isFalse);
      expect(series.unit, 'kg');
      expect(series.points.map((p) => p.isRecord), <bool>[false, true, true]);
    });

    test('bodyweight plots reps when nobody added weight', () {
      final series = seriesOf('push', <WorkoutSession>[
        workout('a', 9, 'push', LoadType.bodyweight, <SetEntry>[set(reps: 12)]),
        workout('b', 2, 'push', LoadType.bodyweight,
            <SetEntry>[set(reps: 15), set(reps: 11)]),
      ]);
      expect(series.points.map((p) => p.value), <double>[12, 15]);
      expect(series.unit, 'reps');
    });

    test('bodyweight plots the added weight once any was added', () {
      final series = seriesOf('dip', <WorkoutSession>[
        workout('a', 9, 'dip', LoadType.bodyweight, <SetEntry>[set(reps: 12)]),
        workout('b', 2, 'dip', LoadType.bodyweight,
            <SetEntry>[set(reps: 8, addedKg: 10)]),
      ]);
      expect(series.points.map((p) => p.value), <double>[0, 10]);
      expect(series.unit, 'kg added');
    });

    test('timed plots the longest hold', () {
      final series = seriesOf('plank', <WorkoutSession>[
        workout('a', 9, 'plank', LoadType.timed,
            <SetEntry>[set(durationSec: 45), set(durationSec: 60)]),
        workout('b', 2, 'plank', LoadType.timed, <SetEntry>[set(durationSec: 70)]),
      ]);
      expect(series.points.map((p) => p.value), <double>[60, 70]);
      expect(series.points.last.label, '1:10');
    });

    test('assisted is inverted: less assistance plots higher', () {
      final series = seriesOf('apu', <WorkoutSession>[
        workout('a', 20, 'apu', LoadType.assisted,
            <SetEntry>[set(assistKg: 30, reps: 8)]),
        workout('b', 10, 'apu', LoadType.assisted,
            <SetEntry>[set(assistKg: 25, reps: 8)]),
        workout('c', 1, 'apu', LoadType.assisted,
            <SetEntry>[set(assistKg: 20, reps: 8)]),
      ]);
      expect(series.points.map((p) => p.value), <double>[30, 25, 20]);
      expect(series.inverted, isTrue);
      final first = series.heightFraction(series.points.first.value);
      final last = series.heightFraction(series.points.last.value);
      expect(last, greaterThan(first),
          reason: 'the lightest assist is the best set, so it sits highest');
      expect(series.points.map((p) => p.isRecord), <bool>[false, true, true]);
    });

    test('deleting a session changes the series', () {
      final sessions = <WorkoutSession>[
        workout('a', 20, 'bench', LoadType.weighted,
            <SetEntry>[set(weightKg: 60, reps: 8)]),
        workout('b', 10, 'bench', LoadType.weighted,
            <SetEntry>[set(weightKg: 80, reps: 3)]),
      ];
      expect(seriesOf('bench', sessions).points, hasLength(2));
      expect(seriesOf('bench', sessions.take(1).toList()).points.single.value, 60);
    });
  });

  group('the summary a screen reader hears', () {
    test('weighted rising', () {
      final series = seriesOf('bench', <WorkoutSession>[
        workout('a', 20, 'bench', LoadType.weighted,
            <SetEntry>[set(weightKg: 60, reps: 8)]),
        workout('b', 10, 'bench', LoadType.weighted,
            <SetEntry>[set(weightKg: 65, reps: 8)]),
        workout('c', 1, 'bench', LoadType.weighted,
            <SetEntry>[set(weightKg: 70, reps: 8)]),
      ]);
      expect(series.summary(), 'Best set rose from 60 to 70 kg over 3 sessions');
    });

    test('assisted says less is better', () {
      final series = seriesOf('apu', <WorkoutSession>[
        workout('a', 20, 'apu', LoadType.assisted,
            <SetEntry>[set(assistKg: 30, reps: 8)]),
        workout('b', 1, 'apu', LoadType.assisted,
            <SetEntry>[set(assistKg: 20, reps: 8)]),
      ]);
      expect(series.summary(),
          'Assistance dropped from 30 to 20 kg over 2 sessions. Less is better');
    });
  });

  group('Best at', () {
    test('weighted: the heaviest weight at each rep count', () {
      final rows = bestAtTable('bench', LoadType.weighted, <WorkoutSession>[
        workout('a', 9, 'bench', LoadType.weighted, <SetEntry>[
          set(weightKg: 60, reps: 8),
          set(weightKg: 70, reps: 5),
        ]),
        workout('b', 2, 'bench', LoadType.weighted, <SetEntry>[
          set(weightKg: 62.5, reps: 8),
          set(weightKg: 80, reps: 15),
        ]),
      ]);
      expect(rows.map((r) => '${r.label}: ${r.value}'), <String>[
        '5 reps: 70kg',
        '8 reps: 62.5kg',
      ], reason: 'only 1 to 12 reps, like Strong');
    });

    test('assisted: the lightest assist at each rep count', () {
      final rows = bestAtTable('apu', LoadType.assisted, <WorkoutSession>[
        workout('a', 9, 'apu', LoadType.assisted,
            <SetEntry>[set(assistKg: 30, reps: 8)]),
        workout('b', 2, 'apu', LoadType.assisted,
            <SetEntry>[set(assistKg: 20, reps: 8), set(assistKg: 25, reps: 10)]),
      ]);
      expect(rows.map((r) => '${r.label}: ${r.value}'), <String>[
        '8 reps: 20kg assist',
        '10 reps: 25kg assist',
      ]);
    });

    test('bodyweight: the most reps at each added weight', () {
      final rows = bestAtTable('dip', LoadType.bodyweight, <WorkoutSession>[
        workout('a', 9, 'dip', LoadType.bodyweight,
            <SetEntry>[set(reps: 12), set(reps: 14)]),
        workout('b', 2, 'dip', LoadType.bodyweight,
            <SetEntry>[set(reps: 8, addedKg: 10)]),
      ]);
      expect(rows.map((r) => '${r.label}: ${r.value}'), <String>[
        'Bodyweight: 14 reps',
        '+10kg: 8 reps',
      ]);
    });

    test('timed: the longest hold', () {
      final rows = bestAtTable('plank', LoadType.timed, <WorkoutSession>[
        workout('a', 9, 'plank', LoadType.timed,
            <SetEntry>[set(durationSec: 45), set(durationSec: 72)]),
      ]);
      expect(rows.map((r) => '${r.label}: ${r.value}'),
          <String>['Bodyweight: 1:12']);
    });
  });

  group('on the exercise history screen', () {
    final index = ExerciseIndex(const <Exercise>[
      Exercise(
        id: 'bench',
        name: 'Barbell bench press',
        equipment: 'barbell',
        loadType: 'weighted',
        primary: <String>['chest/mid'],
        secondary: <String>[],
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
      ),
    ]);

    Future<void> pump(WidgetTester tester, List<WorkoutSession> saved) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          exerciseIndexProvider.overrideWithValue(index),
          initialSavedSessionsProvider.overrideWithValue(saved),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const ExerciseHistoryScreen(exerciseId: 'bench'),
        ),
      ));
      await tester.pumpAndSettle();
    }

    List<WorkoutSession> rising(int n, {int spacing = 10}) => <WorkoutSession>[
          for (var i = 0; i < n; i++)
            workout('s$i', (n - i) * spacing, 'bench', LoadType.weighted,
                <SetEntry>[set(weightKg: 60.0 + i * 5, reps: 8)]),
        ];

    testWidgets('under three sessions it says so instead of drawing',
        (tester) async {
      await pump(tester, rising(2));
      expect(find.byType(ExerciseProgressChart), findsNothing);
      expect(find.text(kTooFewForTrend), findsOneWidget);
    });

    testWidgets('three sessions draw the chart with a summary label',
        (tester) async {
      await pump(tester, rising(3));
      expect(find.byType(ExerciseProgressChart), findsOneWidget);
      expect(
        find.bySemanticsLabel('Best set rose from 60 to 70 kg over 3 sessions'),
        findsOneWidget,
      );
    });

    testWidgets('the Best at table is quiet: no amber', (tester) async {
      await pump(tester, rising(3));
      expect(find.text('Best at'), findsOneWidget);
      final value = tester.widget<Text>(find.text('70kg'));
      expect(value.style?.color, isNot(AppPalette.accentStrong));
    });

    testWidgets('range chips narrow the chart and are held in memory only',
        (tester) async {
      // Six sessions 40 days apart: about 200 days of data.
      await pump(tester, rising(6, spacing: 40));
      final chart = find.byType(ExerciseProgressChart);
      expect(tester.widget<ExerciseProgressChart>(chart).series.points,
          hasLength(6));

      await tester.tap(find.byKey(ExerciseHistoryScreen.rangeKey(ProgressRange.threeMonths)));
      await tester.pumpAndSettle();
      expect(tester.widget<ExerciseProgressChart>(chart).series.points,
          hasLength(2));

      // A fresh screen opens on All again: nothing was stored.
      await pump(tester, rising(6, spacing: 40));
      expect(tester.widget<ExerciseProgressChart>(chart).series.points,
          hasLength(6));
    });

    testWidgets('the chart paints only palette colours', (tester) async {
      await pump(tester, rising(3));
      final painter = tester
          .widget<CustomPaint>(find.descendant(
              of: find.byType(ExerciseProgressChart),
              matching: find.byType(CustomPaint)))
          .painter! as ProgressChartPainter;
      final palette = <Color>{
        AppPalette.border,
        AppPalette.textSecondary,
        AppPalette.textMuted,
        AppPalette.accentStrong,
        AppPalette.surface,
      };
      for (final color in painter.colorsUsed) {
        expect(palette, contains(color));
      }
    });
  });
}
