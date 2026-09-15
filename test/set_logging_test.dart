import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/set_logging_screen.dart';
import 'package:turtle_lift/src/ui/set_row.dart';

/// Proves the screen the app is used on most.
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

  Exercise libraryExercise(
    String id, {
    required String name,
    required String loadType,
    String equipment = 'Barbell',
  }) =>
      Exercise(
        id: id,
        name: name,
        equipment: equipment,
        loadType: loadType,
        primary: const <String>['chest/mid'],
        secondary: const <String>[],
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
      );

  final index = ExerciseIndex(<Exercise>[
    libraryExercise('bench', name: 'Barbell bench press', loadType: 'weighted'),
    libraryExercise('pull-up',
        name: 'Pull-up', loadType: 'bodyweight', equipment: 'Bodyweight'),
    libraryExercise('assisted-pull-up',
        name: 'Assisted pull-up machine',
        loadType: 'assisted',
        equipment: 'Machine'),
    libraryExercise('plank',
        name: 'Plank', loadType: 'timed', equipment: 'Bodyweight'),
  ]);

  /// Starts a session, adds [exerciseId], and pumps the logging screen for it.
  Future<String> pumpLogging(
    WidgetTester tester, {
    required String exerciseId,
    required LoadType loadType,
  }) async {
    // Real database I/O has to run outside the fake-async zone `testWidgets`
    // installs, or the awaited future never completes and the test hangs.
    late String rowId;
    late WorkoutSession? open;
    late List<WorkoutSession> saved;
    await tester.runAsync(() async {
      final session = await store.createSession();
      rowId = await store.addExercise(
        sessionId: session.id,
        exerciseId: exerciseId,
        loadType: loadType,
      );
      open = await store.readOpenSession();
      saved = await store.readSavedSessions();
    });

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialActiveSessionProvider.overrideWithValue(open),
          initialSavedSessionsProvider.overrideWithValue(saved),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: SetLoggingScreen(sessionExerciseId: rowId),
        ),
      ),
    );
    await tester.pump();
    return rowId;
  }

  /// Runs an interaction that writes to the database, then lets the write and
  /// the rebuild it triggers actually finish.
  ///
  /// Every UI write here reaches a real SQLite file, and `testWidgets` installs
  /// a fake clock that never advances for it — so `pumpAndSettle` would spin
  /// forever waiting on a future that cannot complete. `runAsync` steps outside
  /// that zone for the duration of the write.
  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }

  group('the screen order', () {
    testWidgets('puts the sets above Add set and Mark exercise done',
        (tester) async {
      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      final setY = tester.getTopLeft(find.byKey(SetRow.rowKey(0))).dy;
      final addY = tester.getTopLeft(find.byKey(SetLoggingScreen.addSetKey)).dy;
      final doneY =
          tester.getTopLeft(find.byKey(SetLoggingScreen.markDoneKey)).dy;

      expect(setY, lessThan(addY));
      expect(
        addY,
        lessThan(doneY),
        reason: 'the inputs come first; reference material sits below the '
            'actions',
      );
    });

    testWidgets('names the exercise and its load type', (tester) async {
      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      expect(find.text('Barbell bench press'), findsOneWidget);
      expect(find.text('Weight × reps'), findsOneWidget);
      expect(find.text('Barbell'), findsOneWidget);
    });
  });

  group('the assisted banner', () {
    testWidgets('explains the inversion on the assisted screen',
        (tester) async {
      await pumpLogging(tester,
          exerciseId: 'assisted-pull-up', loadType: LoadType.assisted);

      expect(find.textContaining('Less assistance is better'), findsOneWidget);
    });

    testWidgets('is absent on the other three', (tester) async {
      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      expect(find.textContaining('Less assistance'), findsNothing);
    });
  });

  group('opening rows', () {
    testWidgets('an exercise with no history opens with one empty row',
        (tester) async {
      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      expect(find.byKey(SetRow.rowKey(0)), findsOneWidget);
      expect(find.byKey(SetRow.rowKey(1)), findsNothing);
    });

    testWidgets('Add set appends a row', (tester) async {
      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      await tester.tap(find.byKey(SetLoggingScreen.addSetKey));
      await tester.pump();

      expect(find.byKey(SetRow.rowKey(1)), findsOneWidget);
    });
  });

  group('logging a set', () {
    testWidgets('a typed value reaches storage without completing it',
        (tester) async {
      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      await act(tester,
          () => tester.enterText(find.byType(TextField).first, '60'));

      final open = await tester.runAsync(() => store.readOpenSession());
      expect(open!.exercises.single.sets, hasLength(1));
      expect(open.exercises.single.sets.single.weightKg, 60);
      expect(open.exercises.single.sets.single.completed, isFalse);
    });

    testWidgets('ticking a filled row completes the set', (tester) async {
      await pumpLogging(
          tester, exerciseId: 'pull-up', loadType: LoadType.bodyweight);

      await act(tester,
          () => tester.enterText(find.byType(TextField).first, '9'));
      await act(tester, () => tester.tap(find.byKey(SetRow.checkKey(0))));

      final open = await tester.runAsync(() => store.readOpenSession());
      expect(open!.exercises.single.sets.single.completed, isTrue);
      expect(open.completedSets, hasLength(1));
    });

    testWidgets('ticking an empty row records nothing', (tester) async {
      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      await act(tester, () => tester.tap(find.byKey(SetRow.checkKey(0))));

      final open = await tester.runAsync(() => store.readOpenSession());
      expect(
        open!.completedSets,
        isEmpty,
        reason: 'the tick focuses the required field rather than completing '
            'a set with nothing in it',
      );
    });
  });

  group('Mark exercise done', () {
    testWidgets('is unavailable until something is logged', (tester) async {
      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      final button = tester.widget<FilledButton>(
        find.byKey(SetLoggingScreen.markDoneKey),
      );
      expect(
        button.onPressed,
        isNull,
        reason: 'marking an exercise done with nothing recorded would fill the '
            'map for work Finish then discards',
      );
    });

    testWidgets('becomes available once a set is complete', (tester) async {
      await pumpLogging(
          tester, exerciseId: 'pull-up', loadType: LoadType.bodyweight);

      await act(tester,
          () => tester.enterText(find.byType(TextField).first, '9'));
      await act(tester, () => tester.tap(find.byKey(SetRow.checkKey(0))));

      final button = tester.widget<FilledButton>(
        find.byKey(SetLoggingScreen.markDoneKey),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('records the mark on the session', (tester) async {
      final rowId = await pumpLogging(
          tester, exerciseId: 'pull-up', loadType: LoadType.bodyweight);

      await act(tester,
          () => tester.enterText(find.byType(TextField).first, '9'));
      await act(tester, () => tester.tap(find.byKey(SetRow.checkKey(0))));
      await act(
          tester, () => tester.tap(find.byKey(SetLoggingScreen.markDoneKey)));

      final open = await tester.runAsync(() => store.readOpenSession());
      expect(
        open!.exercises.firstWhere((e) => e.id == rowId).markedDone,
        isTrue,
      );
    });
  });

  group('the recent block', () {
    testWidgets('is absent entirely for an exercise with no history',
        (tester) async {
      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      expect(
        find.text('RECENT'),
        findsNothing,
        reason: 'an empty group is no group rather than a heading over nothing',
      );
      expect(find.byKey(SetLoggingScreen.seeAllKey), findsNothing);
    });

    testWidgets('shows the last sessions with all of their sets',
        (tester) async {
      // A saved session of the same exercise, two sets.
      await tester.runAsync(() async {
        final past = await store.createSession(
            performedOn: LocalDate.today().addDays(-3));
        final pastRow = await store.addExercise(
          sessionId: past.id,
          exerciseId: 'bench',
          loadType: LoadType.weighted,
        );
        await store.writeSet(
            sessionExerciseId: pastRow,
            position: 0,
            weightKg: 60,
            reps: 10,
            completed: true);
        await store.writeSet(
            sessionExerciseId: pastRow,
            position: 1,
            weightKg: 60,
            reps: 8,
            completed: true);
        await store.saveOpenSession();
      });

      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      expect(find.text('RECENT'), findsOneWidget);
      expect(find.text('60kg × 10 · 60kg × 8'), findsOneWidget);
      expect(find.byKey(SetLoggingScreen.seeAllKey), findsOneWidget);
    });

    testWidgets('opens with as many rows as that history suggests',
        (tester) async {
      await tester.runAsync(() async {
        final past = await store.createSession(
            performedOn: LocalDate.today().addDays(-3));
        final pastRow = await store.addExercise(
          sessionId: past.id,
          exerciseId: 'bench',
          loadType: LoadType.weighted,
        );
        for (var i = 0; i < 3; i++) {
          await store.writeSet(
              sessionExerciseId: pastRow,
              position: i,
              weightKg: 60,
              reps: 8,
              completed: true);
        }
        await store.saveOpenSession();
      });

      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      expect(find.byKey(SetRow.rowKey(2)), findsOneWidget);
      expect(find.byKey(SetRow.rowKey(3)), findsNothing);
    });
  });
}
