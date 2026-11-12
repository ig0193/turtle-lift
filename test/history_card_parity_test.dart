import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/personal_best.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/body_diagram.dart';
import 'package:turtle_lift/src/ui/exercise_history_screen.dart';
import 'package:turtle_lift/src/ui/history_session_detail_screen.dart';
import 'package:turtle_lift/src/ui/session_card.dart';
import 'package:turtle_lift/src/ui/session_summary_screen.dart';

/// Slice 2 of the History build (`docs/research/history-tab-audit.md`): one
/// card and one derivation behind History detail, the editor and exercise
/// history, so the three can never disagree again (B3, B5, B7, B9).
void main() {
  final today = LocalDate.today();

  Exercise ex(
    String id,
    String name,
    String loadType, {
    required List<String> primary,
    List<String> secondary = const <String>[],
  }) =>
      Exercise(
        id: id,
        name: name,
        equipment: 'barbell',
        loadType: loadType,
        primary: primary,
        secondary: secondary,
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
      );

  final index = ExerciseIndex(<Exercise>[
    ex('bench', 'Barbell bench press', 'weighted',
        primary: <String>['chest/mid'],
        secondary: <String>['shoulders/front-delt', 'triceps/triceps']),
    ex('ohp', 'Overhead press', 'weighted',
        primary: <String>['shoulders/front-delt']),
    ex('apu', 'Assisted pull-up', 'assisted', primary: <String>['back/lats']),
    ex('push', 'Push-up', 'bodyweight', primary: <String>['chest/mid']),
    ex('plank', 'Plank', 'timed', primary: <String>['abs/upper']),
  ]);

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

  SessionExercise exercise(String exerciseId, LoadType type,
          List<SetEntry> sets) =>
      SessionExercise(
        id: 'se-${nextId++}',
        exerciseId: exerciseId,
        position: 0,
        loadType: type,
        markedDone: false,
        sets: <SetEntry>[
          for (var i = 0; i < sets.length; i++)
            SetEntry(
              id: sets[i].id,
              position: i,
              completed: sets[i].completed,
              weightKg: sets[i].weightKg,
              reps: sets[i].reps,
              assistKg: sets[i].assistKg,
              addedKg: sets[i].addedKg,
              durationSec: sets[i].durationSec,
            ),
        ],
      );

  WorkoutSession workout(
    String id,
    LocalDate on,
    List<SessionExercise> exercises, {
    String? title,
    String? templateName,
    int loggedOffset = 0,
  }) =>
      WorkoutSession(
        id: id,
        title: title,
        performedOn: on,
        loggedAt: on.toDateTime().add(Duration(minutes: loggedOffset)),
        templateId: templateName == null ? null : 'tpl',
        templateName: templateName,
        isOpen: false,
        exercises: exercises,
      );

  group('B5: the personal-best projection is one pass', () {
    test('agrees with pbCountFor on randomised histories', () {
      final random = Random(7);
      const ids = <String>['bench', 'ohp', 'apu', 'push', 'plank'];
      const types = <LoadType>[
        LoadType.weighted,
        LoadType.weighted,
        LoadType.assisted,
        LoadType.bodyweight,
        LoadType.timed,
      ];
      for (var round = 0; round < 25; round++) {
        final sessions = <WorkoutSession>[];
        final count = 5 + random.nextInt(25);
        for (var s = 0; s < count; s++) {
          // Few distinct days, so same-day pairs and out-of-order
          // (backdated) entries are common.
          final on = today.addDays(-random.nextInt(12));
          final exercises = <SessionExercise>[];
          for (var e = 0; e < ids.length; e++) {
            if (random.nextBool()) continue;
            exercises.add(exercise(ids[e], types[e], <SetEntry>[
              for (var k = 0; k < 1 + random.nextInt(3); k++)
                set(
                  weightKg: (random.nextInt(5) * 5).toDouble(),
                  reps: 1 + random.nextInt(6),
                  assistKg: (random.nextInt(4) * 5).toDouble(),
                  addedKg: (random.nextInt(3) * 5).toDouble(),
                  durationSec: 10 + random.nextInt(4) * 10,
                ),
            ]));
          }
          sessions.add(workout('r$round-$s', on, exercises,
              loggedOffset: random.nextInt(100)));
        }

        final projection = personalBestProjection(sessions);
        for (final session in sessions) {
          final records = projection[session.id]!;
          expect(records.count, pbCountFor(session, sessions),
              reason: 'round $round, ${session.id}');
          for (final e in session.exercises) {
            final expected = isPersonalBest(e, session, sessions);
            expect(records.recordSetIds.containsKey(e.id), expected,
                reason: 'round $round, ${session.id} ${e.exerciseId}');
            if (expected) {
              final i = personalBestSetIndex(e, session.performedOn, sessions);
              expect(records.recordSetIds[e.id], e.sets[i!].id);
            }
          }
        }
      }
    });

    test('a thousand sessions project in under 50 ms', () {
      final sessions = <WorkoutSession>[
        for (var s = 0; s < 1000; s++)
          workout('p$s', today.addDays(-s), <SessionExercise>[
            for (final id in <String>['bench', 'ohp', 'push', 'plank', 'apu',
                'bench2'])
              exercise(id, LoadType.weighted, <SetEntry>[
                for (var k = 0; k < 4; k++)
                  set(weightKg: 40.0 + (s % 17) + k, reps: 5 + k),
              ]),
          ]),
      ];
      personalBestProjection(sessions); // warm up the JIT
      final watch = Stopwatch()..start();
      final projection = personalBestProjection(sessions);
      watch.stop();
      expect(projection, hasLength(1000));
      expect(watch.elapsedMilliseconds, lessThan(50),
          reason: 'docs/00 §11: one chronological pass, not O(n^2)');
    });
  });

  group('B7: one title function', () {
    ProviderContainer containerWith(List<WorkoutSession> saved) {
      final container = ProviderContainer(overrides: [
        exerciseIndexProvider.overrideWithValue(index),
        initialSavedSessionsProvider.overrideWithValue(saved),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('a template workout with no title is named after its template', () {
      final container = containerWith(<WorkoutSession>[
        workout('t', today, <SessionExercise>[
          exercise('bench', LoadType.weighted, <SetEntry>[set(weightKg: 60, reps: 8)]),
          exercise('ohp', LoadType.weighted, <SetEntry>[set(weightKg: 40, reps: 8)]),
        ], templateName: 'Push day'),
      ]);
      final row = container.read(historySessionsProvider).single;
      final figures = container.read(historyProjectionProvider)[row.id]!;
      expect(resolvedTitle(row, figures), 'Push day');
    });

    test('a template workout with one finished exercise is not a quick log',
        () {
      final container = containerWith(<WorkoutSession>[
        workout('t', today, <SessionExercise>[
          exercise('bench', LoadType.weighted, <SetEntry>[set(weightKg: 60, reps: 8)]),
        ], templateName: 'Push day'),
      ]);
      expect(container.read(historySessionsProvider).single.isQuickLog, isFalse);
    });
  });

  group('one card', () {
    Future<void> pumpAt(
      WidgetTester tester,
      List<WorkoutSession> saved,
      Widget home, {
      List<Override> extra = const <Override>[],
    }) async {
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          exerciseIndexProvider.overrideWithValue(index),
          initialSavedSessionsProvider.overrideWithValue(saved),
          initialBodyweightLogProvider
              .overrideWithValue(const <BodyweightEntry>[]),
          ...extra,
        ],
        child: MaterialApp(theme: buildAppTheme(), home: home),
      ));
      await tester.pumpAndSettle();
    }

    List<WorkoutSession> pushHistory() => <WorkoutSession>[
          workout('old', today.addDays(-3), <SessionExercise>[
            exercise('bench', LoadType.weighted, <SetEntry>[set(weightKg: 60, reps: 8)]),
            exercise('apu', LoadType.assisted, <SetEntry>[set(assistKg: 30, reps: 8)]),
          ]),
          workout('push', today, <SessionExercise>[
            exercise('bench', LoadType.weighted, <SetEntry>[
              set(weightKg: 62.5, reps: 8),
              set(weightKg: 65, reps: 6),
            ]),
            exercise('apu', LoadType.assisted, <SetEntry>[set(assistKg: 20, reps: 8)]),
          ], title: 'Push day'),
        ];

    String cardFigures(WidgetTester tester) {
      final card = find.byType(SessionCard);
      return tester
          .widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))
          .map((t) => t.data)
          .whereType<String>()
          .join('|');
    }

    testWidgets('detail and editor render the same card with the same figures',
        (tester) async {
      final saved = pushHistory();
      await pumpAt(tester, saved,
          const HistorySessionDetailScreen(sessionId: 'push'));
      expect(find.byType(SessionCard), findsOneWidget);
      final detail = cardFigures(tester);

      await pumpAt(tester, saved, const SessionSummaryScreen(sessionId: 'push'));
      expect(find.byType(SessionCard), findsOneWidget);
      final editor = cardFigures(tester);

      // The editor's title is a field rather than a Text; everything else on
      // the card reads the same.
      expect(detail.replaceAll('Push day|', ''),
          editor.replaceAll('Push day|', ''));
      expect(detail, contains('Day streak'));
      expect(detail, isNot(contains('Streak|')));
    });

    testWidgets('a Push day fills mid chest, not the rear delt', (tester) async {
      await pumpAt(tester, pushHistory(),
          const HistorySessionDetailScreen(sessionId: 'push'));
      final diagram = tester.widget<BodyDiagram>(find.byType(BodyDiagram).first);
      expect(diagram.fill(<String>{'chest/mid'}), AppPalette.accentStrong);
      expect(diagram.fill(<String>{'chest/upper'}), AppPalette.mutedSurface,
          reason: 'sub-muscle precision, not the whole parent group');
      expect(diagram.fill(<String>{'shoulders/front-delt'}),
          AppPalette.accentLight,
          reason: 'secondary muscles show in steel on the detail too');
      expect(find.byType(BodyDiagram), findsNWidgets(2),
          reason: 'assisted pull-up trains the back, so both views draw');
    });

    testWidgets('assisted says "PB · lightest assist" in all three places',
        (tester) async {
      final saved = pushHistory();
      await pumpAt(tester, saved,
          const HistorySessionDetailScreen(sessionId: 'push'));
      expect(find.text('PB · lightest assist'), findsOneWidget);

      await pumpAt(tester, saved, const SessionSummaryScreen(sessionId: 'push'));
      expect(find.text('PB · lightest assist'), findsOneWidget);

      await pumpAt(tester, saved, const ExerciseHistoryScreen(exerciseId: 'apu'));
      expect(find.text('PB · lightest assist'), findsOneWidget);
    });

    testWidgets('the record set is highlighted in the editor as on the detail',
        (tester) async {
      final saved = pushHistory();
      for (final home in <Widget>[
        const HistorySessionDetailScreen(sessionId: 'push'),
        const SessionSummaryScreen(sessionId: 'push'),
      ]) {
        await pumpAt(tester, saved, home);
        final rich = tester
            .widgetList<RichText>(find.byType(RichText))
            .where((r) => r.text.toPlainText().contains('65kg'))
            .single;
        final spans = <TextSpan>[];
        rich.text.visitChildren((span) {
          if (span is TextSpan && (span.text ?? '').contains('65kg')) {
            spans.add(span);
          }
          return true;
        });
        expect(spans.single.style?.color, AppPalette.accentStrong,
            reason: '$home');
      }
    });

    testWidgets('a set never breaks across lines', (tester) async {
      await pumpAt(tester, pushHistory(),
          const HistorySessionDetailScreen(sessionId: 'push'));
      final rich = tester
          .widgetList<RichText>(find.byType(RichText))
          .where((r) => r.text.toPlainText().contains('62.5kg'))
          .single;
      expect(rich.text.toPlainText(), contains('62.5kg × 8'));
    });

    testWidgets('tapping an exercise in the detail log opens its history',
        (tester) async {
      await pumpAt(tester, pushHistory(),
          const HistorySessionDetailScreen(sessionId: 'push'));
      await tester.tap(
          find.byKey(HistorySessionDetailScreen.exerciseKey('Barbell bench press')));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseHistoryScreen), findsOneWidget);
    });

    testWidgets('an exercise history row opens the read-only detail',
        (tester) async {
      await pumpAt(tester, pushHistory(),
          const ExerciseHistoryScreen(exerciseId: 'bench'));
      await tester.tap(find.byKey(ExerciseHistoryScreen.sessionKey('old')));
      await tester.pumpAndSettle();
      expect(find.byType(HistorySessionDetailScreen), findsOneWidget);
      expect(find.byType(SessionSummaryScreen), findsNothing);
    });

    testWidgets('Share on the detail renders the card to the share sheet',
        (tester) async {
      final shared = <String>[];
      await pumpAt(
        tester,
        pushHistory(),
        const HistorySessionDetailScreen(sessionId: 'push'),
        extra: <Override>[
          cardImageSharerProvider.overrideWithValue(
            (Uint8List png, {required String fileName, Rect? origin}) async {
              shared.add(fileName);
            },
          ),
        ],
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(HistorySessionDetailScreen.shareKey));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(shared, <String>['push-day.png']);
    });
  });
}
