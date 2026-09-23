import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/log_workout_screen.dart';
import 'package:turtle_lift/src/ui/rest_timer.dart';
import 'package:turtle_lift/src/ui/set_table_row.dart';

/// The rest timer, which `00` §13 banned until `adr/0004`.
///
/// **Off is the default and has to stay the default.** A timer that armed
/// itself would start a countdown the user never asked for, on a screen they
/// are holding between sets. The test that matters most here is the one that
/// proves unticking a set does *not* start a rest — correcting a mistyped
/// weight is not finishing a set.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SessionStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = SessionStore(database);
  });
  tearDown(() => database.close());

  final index = ExerciseIndex(<Exercise>[
    Exercise(
      id: 'bench',
      name: 'Barbell bench press',
      equipment: 'Barbell',
      loadType: 'weighted',
      primary: const <String>['chest/mid'],
      secondary: const <String>[],
      setup: '',
      posture: '',
      execution: '',
      commonMistakes: '',
    ),
  ]);

  late ProviderContainer container;

  Future<String> pumpLog(WidgetTester tester, {int? restSeconds}) async {
    late String rowId;
    late WorkoutSession? open;
    await tester.runAsync(() async {
      final session = await store.createSession();
      rowId = await store.addExercise(
        sessionId: session.id,
        exerciseId: 'bench',
        loadType: LoadType.weighted,
      );
      if (restSeconds != null) {
        await store.setExerciseRestTimer(
            sessionExerciseId: rowId, seconds: restSeconds);
      }
      open = await store.readOpenSession();
    });

    final scope = ProviderScope(
      key: UniqueKey(),
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        exerciseIndexProvider.overrideWithValue(index),
        initialActiveSessionProvider.overrideWithValue(open),
        initialSavedSessionsProvider.overrideWithValue(<WorkoutSession>[]),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const LogWorkoutScreen(),
      ),
    );
    await tester.pumpWidget(scope);
    await tester.pump();
    container = ProviderScope.containerOf(
      tester.element(find.byType(LogWorkoutScreen)),
    );
    return rowId;
  }

  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }

  group('the per-exercise setting', () {
    testWidgets('reads OFF until the user sets one', (tester) async {
      await pumpLog(tester);

      expect(find.text('Rest timer: OFF'), findsOneWidget);
    });

    testWidgets('a chosen rest shows on the line and survives a re-read',
        (tester) async {
      final rowId = await pumpLog(tester);

      await tester.tap(find.byKey(RestTimerLine.lineKey(rowId)));
      await tester.pumpAndSettle();
      await act(tester, () async {
        await tester.tap(find.text('1:30'));
      });

      expect(find.text('Rest timer: 1:30'), findsOneWidget);
      final reread = await tester.runAsync(store.readOpenSession);
      expect(reread!.exercises.single.restTimerSec, 90);
    });

    testWidgets('it can be turned back off', (tester) async {
      final rowId = await pumpLog(tester, restSeconds: 90);
      expect(find.text('Rest timer: 1:30'), findsOneWidget);

      await tester.tap(find.byKey(RestTimerLine.lineKey(rowId)));
      await tester.pumpAndSettle();
      await act(tester, () async {
        await tester.tap(find.text('Off'));
      });

      expect(find.text('Rest timer: OFF'), findsOneWidget);
      final reread = await tester.runAsync(store.readOpenSession);
      expect(reread!.exercises.single.restTimerSec, isNull);
    });
  });

  group('what starts it', () {
    testWidgets('no bar while nothing is resting', (tester) async {
      await pumpLog(tester, restSeconds: 60);

      expect(find.byKey(RestTimerBar.barKey), findsNothing);
    });

    testWidgets('ticking a set starts the rest', (tester) async {
      final rowId = await pumpLog(tester, restSeconds: 60);

      await act(tester, () async {
        await tester.enterText(
            find.byKey(SetTableRow.weightFieldKey(rowId, 0)), '60');
      });
      await act(tester, () async {
        await tester.enterText(
            find.byKey(SetTableRow.repsFieldKey(rowId, 0)), '8');
      });
      await act(tester, () async {
        await tester.tap(find.byKey(SetTableRow.checkKey(rowId, 0)));
      });

      expect(container.read(restTimerProvider), isNotNull);
      expect(container.read(restTimerProvider)!.remaining, 60);
    });

    testWidgets('unticking a set does not start one', (tester) async {
      final rowId = await pumpLog(tester, restSeconds: 60);

      await act(tester, () async {
        await tester.enterText(
            find.byKey(SetTableRow.weightFieldKey(rowId, 0)), '60');
      });
      await act(tester, () async {
        await tester.enterText(
            find.byKey(SetTableRow.repsFieldKey(rowId, 0)), '8');
      });
      await act(tester, () async {
        await tester.tap(find.byKey(SetTableRow.checkKey(rowId, 0)));
      });
      container.read(restTimerProvider.notifier).stop();

      // Correcting a mistyped weight is not finishing a set.
      await act(tester, () async {
        await tester.tap(find.byKey(SetTableRow.checkKey(rowId, 0)));
      });

      expect(container.read(restTimerProvider), isNull);
    });

    testWidgets('an exercise with the timer off never starts one',
        (tester) async {
      final rowId = await pumpLog(tester);

      await act(tester, () async {
        await tester.enterText(
            find.byKey(SetTableRow.weightFieldKey(rowId, 0)), '60');
      });
      await act(tester, () async {
        await tester.enterText(
            find.byKey(SetTableRow.repsFieldKey(rowId, 0)), '8');
      });
      await act(tester, () async {
        await tester.tap(find.byKey(SetTableRow.checkKey(rowId, 0)));
      });

      expect(container.read(restTimerProvider), isNull);
    });
  });

  group('the running countdown', () {
    testWidgets('+15 and -15 move it, and it never goes past zero',
        (tester) async {
      await pumpLog(tester, restSeconds: 60);
      container.read(restTimerProvider.notifier).start(60);
      await tester.pump();

      expect(find.byKey(RestTimerBar.barKey), findsOneWidget);

      await tester.tap(find.text('+15'));
      await tester.pump();
      expect(container.read(restTimerProvider)!.remaining, 75);

      await tester.tap(find.text('-15'));
      await tester.pump();
      expect(container.read(restTimerProvider)!.remaining, 60);

      // Taking more off than is left ends the rest rather than counting
      // backwards past zero.
      container.read(restTimerProvider.notifier).adjust(-120);
      await tester.pump();
      expect(container.read(restTimerProvider), isNull);
    });

    testWidgets('Skip ends it outright', (tester) async {
      await pumpLog(tester, restSeconds: 60);
      container.read(restTimerProvider.notifier).start(60);
      await tester.pump();

      await tester.tap(find.text('Skip'));
      await tester.pump();

      expect(container.read(restTimerProvider), isNull);
      expect(find.byKey(RestTimerBar.barKey), findsNothing);
    });

    testWidgets('starting a second rest replaces the first', (tester) async {
      await pumpLog(tester, restSeconds: 60);
      final notifier = container.read(restTimerProvider.notifier);

      notifier.start(60);
      notifier.start(90);
      await tester.pump();

      // One at a time: two countdowns competing for the same glance would be
      // two answers to "how long left".
      expect(container.read(restTimerProvider)!.total, 90);
      expect(find.byKey(RestTimerBar.barKey), findsOneWidget);
    });
  });
}
