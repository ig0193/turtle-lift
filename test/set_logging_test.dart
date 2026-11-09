import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart';
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

import 'support/haptic_log.dart';

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

    // QA (Maestro): typing "60" into the first, unsaved row stored 6. The first
    // keystroke wrote the row, its id moved from `ghost-0` to the stored id,
    // and the Dismissible keyed on that id rebuilt the fields: the focus and
    // the keyboard's target were lost, so the "0" went nowhere.
    testWidgets('typing digit by digit into a fresh row keeps every digit',
        (tester) async {
      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      final weight = find.byType(TextField).first;
      await tester.showKeyboard(weight);
      await act(tester, () async => tester.testTextInput.enterText('6'));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.focusNode!.hasFocus, isTrue,
          reason: 'the field being typed in must keep focus after the first '
              'keystroke saves the row');

      await act(tester, () async => tester.testTextInput.enterText('60'));
      final open = await tester.runAsync(() => store.readOpenSession());
      expect(open!.exercises.single.sets.single.weightKg, 60);
    });

    // QA (Maestro, iPhone 17e): the iOS number pad has no return key, and a
    // tap anywhere off the field left it up, covering Recent and See all.
    testWidgets('a tap outside the field puts the number pad away',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpLogging(
            tester, exerciseId: 'bench', loadType: LoadType.weighted);
        await tester.showKeyboard(find.byType(TextField).first);
        await tester.pump();
        expect(tester.testTextInput.isVisible, isTrue);

        // Empty space under Add set. (Mark exercise done is pinned to the
        // bottom edge now, so "below it" is off screen.)
        await tester.tapAt(tester
            .getBottomLeft(find.byKey(SetLoggingScreen.addSetKey))
            .translate(10, 40));
        await tester.pump();
        final field = tester.widget<TextField>(find.byType(TextField).first);
        expect(field.focusNode!.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
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

    testWidgets('ticks with one impact and ends with one success haptic',
        (tester) async {
      final haptics = recordHaptics(tester);
      await pumpLogging(
          tester, exerciseId: 'pull-up', loadType: LoadType.bodyweight);

      await act(tester,
          () => tester.enterText(find.byType(TextField).first, '9'));
      await act(tester, () => tester.tap(find.byKey(SetRow.checkKey(0))));
      expect(haptics, <String>[kHapticSetDone]);

      await act(
          tester, () => tester.tap(find.byKey(SetLoggingScreen.markDoneKey)));
      expect(haptics, <String>[kHapticSetDone, kHapticSuccess]);
    });
  });

  group('the recent block', () {
    testWidgets('is absent entirely for an exercise with no history',
        (tester) async {
      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      expect(
        find.text('Recent'),
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

      expect(find.text('Recent'), findsOneWidget);
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

  /// Saves a finished session three days ago holding [sets] of [exerciseId].
  Future<void> savePast(
    WidgetTester tester, {
    required String exerciseId,
    required LoadType loadType,
    required List<({double? weightKg, int? reps, double? assistKg})> sets,
  }) async {
    await tester.runAsync(() async {
      final past =
          await store.createSession(performedOn: LocalDate.today().addDays(-3));
      final row = await store.addExercise(
          sessionId: past.id, exerciseId: exerciseId, loadType: loadType);
      for (final (i, set) in sets.indexed) {
        await store.writeSet(
            sessionExerciseId: row,
            position: i,
            weightKg: set.weightKg,
            reps: set.reps,
            assistKg: set.assistKg,
            completed: true);
      }
      await store.saveOpenSession();
    });
  }

  group('last time, in the row (research item 3)', () {
    testWidgets('each row shows the same set from last time', (tester) async {
      await savePast(tester, exerciseId: 'bench', loadType: LoadType.weighted,
          sets: [
            (weightKg: 60, reps: 8, assistKg: null),
            (weightKg: 62.5, reps: 6, assistKg: null),
          ]);
      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      expect(find.text('Last 60kg × 8'), findsOneWidget);
      expect(find.text('Last 62.5kg × 6'), findsOneWidget);
    });

    testWidgets('a tap on it copies last time into the row', (tester) async {
      await savePast(tester, exerciseId: 'bench', loadType: LoadType.weighted,
          sets: [(weightKg: 62.5, reps: 6, assistKg: null)]);
      final rowId = await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      await act(tester,
          () => tester.enterText(find.byType(TextField).first, '40'));
      await act(tester, () => tester.tap(find.byKey(SetRow.lastKey(0))));

      final open = await tester.runAsync(() => store.readOpenSession());
      final set = open!.exercises.firstWhere((e) => e.id == rowId).sets.single;
      expect(set.weightKg, 62.5);
      expect(set.reps, 6);
      expect(set.completed, isFalse, reason: 'copying is not ticking');
    });
  });

  group('the PB mark (research item 5)', () {
    testWidgets('appears the moment a ticked set beats the record',
        (tester) async {
      await savePast(tester, exerciseId: 'bench', loadType: LoadType.weighted,
          sets: [(weightKg: 60, reps: 8, assistKg: null)]);
      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      await act(tester,
          () => tester.enterText(find.byType(TextField).first, '65'));
      expect(find.text('PB'), findsNothing, reason: 'not ticked yet');

      await act(tester, () => tester.tap(find.byKey(SetRow.checkKey(0))));
      expect(find.text('PB'), findsOneWidget);

      await act(tester, () => tester.tap(find.byKey(SetRow.checkKey(0))));
      expect(find.text('PB'), findsNothing,
          reason: 'derived, never stored: unticking takes it away');
    });

    testWidgets('assisted: lighter assistance is the PB, heavier is not',
        (tester) async {
      await savePast(tester,
          exerciseId: 'assisted-pull-up',
          loadType: LoadType.assisted,
          sets: [(weightKg: null, reps: 8, assistKg: 20)]);
      await pumpLogging(tester,
          exerciseId: 'assisted-pull-up', loadType: LoadType.assisted);

      await act(tester,
          () => tester.enterText(find.byType(TextField).first, '25'));
      await act(tester, () => tester.tap(find.byKey(SetRow.checkKey(0))));
      expect(find.text('PB'), findsNothing,
          reason: 'more assistance than last time is not a record');

      await act(tester,
          () => tester.enterText(find.byType(TextField).first, '15'));
      expect(find.text('PB'), findsOneWidget,
          reason: 'less assistance is the record');
    });
  });

  group('Mark exercise done is pinned (research item 2)', () {
    testWidgets('it sits in a bar at the bottom, outside the scroll',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);

      final done = find.byKey(SetLoggingScreen.markDoneKey);
      expect(
          find.ancestor(of: done, matching: find.byType(Scrollable)),
          findsNothing,
          reason: 'pinned, so it never scrolls out of thumb reach');
      expect(tester.getBottomLeft(done).dy, greaterThan(844 * 0.8));
      expect(find.byKey(SetLoggingScreen.markDoneBarKey), findsOneWidget);
    });

    testWidgets('the scroll keeps its last row clear of the bar',
        (tester) async {
      await pumpLogging(
          tester, exerciseId: 'bench', loadType: LoadType.weighted);
      final bar = tester.getRect(find.byKey(SetLoggingScreen.markDoneBarKey));
      final list = tester.getRect(find.byType(ListView));
      expect(list.bottom, lessThanOrEqualTo(bar.top));
    });

    testWidgets('no bar when correcting a saved workout', (tester) async {
      await savePast(tester, exerciseId: 'bench', loadType: LoadType.weighted,
          sets: [(weightKg: 60, reps: 8, assistKg: null)]);
      late WorkoutSession saved;
      await tester.runAsync(() async {
        saved = (await store.readSavedSessions()).single;
      });
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialSavedSessionsProvider.overrideWithValue(<WorkoutSession>[saved]),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: SetLoggingScreen(
            sessionExerciseId: saved.exercises.single.id,
            savedSessionId: saved.id,
          ),
        ),
      ));
      await tester.pump();

      expect(find.byKey(SetLoggingScreen.markDoneBarKey), findsNothing);
      expect(find.byKey(SetLoggingScreen.markDoneKey), findsNothing);
    });
  });
}
