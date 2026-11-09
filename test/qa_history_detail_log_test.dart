import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/history_session_detail_screen.dart';

/// QA (Maestro, iPhone 17e): History → a saved workout's "Logged" list read
/// "Push-up 0kg", "Assisted pull-up machine -25kg" and "Plank 0kg", and the
/// bench press lost its reps ("60kg · 60kg"). The list printed each set's
/// personal-best score (addedKg, -assistKg, weightKg) with a "kg" suffix
/// instead of the set itself. It must read the way the summary card does.
void main() {
  Exercise ex(String id, String name, String loadType, String primary) =>
      Exercise(
        id: id,
        name: name,
        equipment: 'Machine',
        loadType: loadType,
        primary: <String>[primary],
        secondary: const <String>[],
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
      );

  final index = ExerciseIndex(<Exercise>[
    ex('bench', 'Barbell bench press', 'weighted', 'chest/mid'),
    ex('push-up', 'Push-up', 'bodyweight', 'chest/mid'),
    ex('apu', 'Assisted pull-up machine', 'assisted', 'back/lats'),
    ex('plank', 'Plank', 'timed', 'abs/abs'),
  ]);

  SessionExercise row(String exerciseId, LoadType type, List<SetEntry> sets) =>
      SessionExercise(
        id: 'row-$exerciseId',
        exerciseId: exerciseId,
        position: 0,
        loadType: type,
        markedDone: true,
        sets: sets,
      );

  WorkoutSession session(
    String id,
    LocalDate day,
    List<SessionExercise> rows,
  ) => WorkoutSession(
    id: id,
    title: null,
    performedOn: day,
    loggedAt: day.toDateTime(),
    templateId: null,
    templateName: null,
    isOpen: false,
    exercises: rows,
  );

  // Earlier: assisted at 30kg assist. Today: 25kg assist, which is less help
  // and so a record. Bench repeats at the same weight with more reps: also a
  // record by the (weight, reps) pair.
  final earlier = session('s1', const LocalDate(2026, 11, 1), <SessionExercise>[
    row('bench', LoadType.weighted, const <SetEntry>[
      SetEntry(id: 'a', position: 0, completed: true, weightKg: 60, reps: 6),
    ]),
    row('apu', LoadType.assisted, const <SetEntry>[
      SetEntry(id: 'b', position: 0, completed: true, assistKg: 30, reps: 8),
    ]),
  ]);
  final latest = session('s2', const LocalDate(2026, 11, 8), <SessionExercise>[
    row('bench', LoadType.weighted, const <SetEntry>[
      SetEntry(id: 'c', position: 0, completed: true, weightKg: 60, reps: 8),
      SetEntry(id: 'd', position: 1, completed: true, weightKg: 60, reps: 8),
    ]),
    row('push-up', LoadType.bodyweight, const <SetEntry>[
      SetEntry(id: 'e', position: 0, completed: true, reps: 15),
    ]),
    row('apu', LoadType.assisted, const <SetEntry>[
      SetEntry(id: 'f', position: 0, completed: true, assistKg: 25, reps: 8),
    ]),
    row('plank', LoadType.timed, const <SetEntry>[
      SetEntry(id: 'g', position: 0, completed: true, durationSec: 45),
    ]),
  ]);

  Future<void> pump(WidgetTester tester) async {
    // Tall enough that every log block is built, not left to the lazy list.
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exerciseIndexProvider.overrideWithValue(index),
          initialSavedSessionsProvider.overrideWithValue(<WorkoutSession>[
            latest,
            earlier,
          ]),
          initialBodyweightLogProvider.overrideWithValue(const []),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const HistorySessionDetailScreen(sessionId: 's2'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String logLine(WidgetTester tester, String name) {
    final block = find.byKey(HistorySessionDetailScreen.exerciseKey(name));
    final texts = tester
        .widgetList<RichText>(
          find.descendant(of: block, matching: find.byType(RichText)),
        )
        .map((t) => t.text.toPlainText())
        .toList();
    return texts.join('\n');
  }

  testWidgets('each set reads as the summary card writes it', (tester) async {
    await pump(tester);
    expect(
      logLine(tester, 'Barbell bench press'),
      contains('60kg × 8 · 60kg × 8'),
    );
    expect(logLine(tester, 'Push-up'), contains('15 reps'));
    expect(
      logLine(tester, 'Assisted pull-up machine'),
      contains('25kg assist × 8'),
    );
    expect(logLine(tester, 'Plank'), contains('0:45'));
    for (final name in <String>[
      'Push-up',
      'Plank',
      'Assisted pull-up machine',
    ]) {
      expect(logLine(tester, name), isNot(contains('0kg')));
      expect(
        logLine(tester, name).replaceFirst(name, ''),
        isNot(contains('-')),
        reason: 'no number in the app carries a sign',
      );
    }
  });

  testWidgets('the PB marks agree with the personal-best count', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Logged · 2 personal bests'), findsOneWidget);
    for (final name in <String>[
      'Barbell bench press',
      'Assisted pull-up machine',
    ]) {
      expect(
        find.descendant(
          of: find.byKey(HistorySessionDetailScreen.exerciseKey(name)),
          matching: find.text('PB'),
        ),
        findsOneWidget,
        reason: '$name beat its previous best (less assistance is better)',
      );
    }
    for (final name in <String>['Push-up', 'Plank']) {
      expect(
        find.descendant(
          of: find.byKey(HistorySessionDetailScreen.exerciseKey(name)),
          matching: find.text('PB'),
        ),
        findsNothing,
        reason: 'a first-ever exercise is never a record',
      );
    }
  });
}
