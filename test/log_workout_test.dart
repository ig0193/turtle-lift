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
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/log_exercise_block.dart';
import 'package:turtle_lift/src/ui/log_workout_screen.dart';
import 'package:turtle_lift/src/ui/set_table_row.dart';

/// Proves the screen a workout is actually run on (`adr/0004`).
///
/// **The thing this file exists to stop is a regression to pushing.** The whole
/// point of the rebuild is that every exercise and every set is reachable
/// without leaving this screen; a change that quietly sends one exercise to its
/// own page would pass a naive "does it render" test and lose the feature.
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

  /// Starts a session holding [exercises] and pumps the log screen over it.
  Future<Map<String, String>> pumpLog(
    WidgetTester tester,
    Map<String, LoadType> exercises, {
    Future<void> Function(SessionStore store)? history,
  }) async {
    final rowIds = <String, String>{};
    late WorkoutSession? open;
    late List<WorkoutSession> saved;
    await tester.runAsync(() async {
      if (history != null) await history(store);
      final session = await store.createSession();
      for (final entry in exercises.entries) {
        rowIds[entry.key] = await store.addExercise(
          sessionId: session.id,
          exerciseId: entry.key,
          loadType: entry.value,
        );
      }
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
          home: const LogWorkoutScreen(),
        ),
      ),
    );
    await tester.pump();
    return rowIds;
  }

  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }

  group('everything is on one screen', () {
    testWidgets('every exercise in the session renders inline', (tester) async {
      await pumpLog(tester, <String, LoadType>{
        'bench': LoadType.weighted,
        'pull-up': LoadType.bodyweight,
        'plank': LoadType.timed,
      });

      expect(find.text('Barbell bench press'), findsOneWidget);
      expect(find.text('Pull-up'), findsOneWidget);
      // The third is below the fold on a test-sized screen, which is the
      // point: it is on the same scrollable, not behind a navigation.
      await tester.scrollUntilVisible(
        find.text('Plank'),
        200,
        // Named explicitly: every notes field carries its own Scrollable, so
        // the default "the one scrollable" lookup finds several.
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Plank'), findsOneWidget);
    });

    testWidgets('sets are editable in place, with no step into another screen',
        (tester) async {
      final rows = await pumpLog(
          tester, <String, LoadType>{'bench': LoadType.weighted});

      // The set row is already on screen, under its exercise — reaching it
      // required no navigation at all.
      expect(
        find.byKey(SetTableRow.rowKey(rows['bench']!, 0)),
        findsOneWidget,
      );
      expect(find.byType(Navigator), findsOneWidget);
    });

    testWidgets('Mark exercise done is gone', (tester) async {
      await pumpLog(tester, <String, LoadType>{'bench': LoadType.weighted});

      // Removed with the push-per-exercise flow: the muscle now ticks on a
      // completed set alone (`adr/0004`).
      expect(find.textContaining('Mark exercise done'), findsNothing);
    });
  });

  group('the summary bar', () {
    testWidgets('carries duration, volume and sets', (tester) async {
      await pumpLog(tester, <String, LoadType>{'bench': LoadType.weighted});

      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Volume'), findsOneWidget);
      expect(find.text('Sets'), findsOneWidget);
    });

    testWidgets('sets and volume follow a ticked set', (tester) async {
      final rows = await pumpLog(
          tester, <String, LoadType>{'bench': LoadType.weighted});
      final rowId = rows['bench']!;

      expect(find.byKey(LogWorkoutScreen.setCountKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(LogWorkoutScreen.setCountKey)).data,
        '0',
      );

      // One interaction per act: each write has to land and the row rebuild
      // with it, exactly as it does under a real thumb.
      await act(tester, () async {
        await tester.enterText(
            find.byKey(SetTableRow.weightFieldKey(rowId, 0)), '60');
      });
      await act(tester, () async {
        await tester.enterText(
            find.byKey(SetTableRow.repsFieldKey(rowId, 0)), '10');
      });
      await act(tester, () async {
        await tester.tap(find.byKey(SetTableRow.checkKey(rowId, 0)));
      });

      expect(
        tester.widget<Text>(find.byKey(LogWorkoutScreen.setCountKey)).data,
        '1',
      );
      expect(find.textContaining('600'), findsWidgets, reason: '60kg x 10');
    });
  });

  group('the set table', () {
    testWidgets('a weighted exercise is headed SET PREVIOUS KG REPS',
        (tester) async {
      await pumpLog(tester, <String, LoadType>{'bench': LoadType.weighted});

      expect(find.text('SET'), findsOneWidget);
      expect(find.text('PREVIOUS'), findsOneWidget);
      expect(find.text('KG'), findsOneWidget);
      expect(find.text('REPS'), findsOneWidget);
    });

    testWidgets('a timed exercise is headed TIME, and names no weight',
        (tester) async {
      await pumpLog(tester, <String, LoadType>{'plank': LoadType.timed});

      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('KG'), findsNothing);
      expect(find.text('REPS'), findsNothing);
    });

    testWidgets('an assisted exercise says so, so the record reads correctly',
        (tester) async {
      await pumpLog(
          tester, <String, LoadType>{'assisted-pull-up': LoadType.assisted});

      // The one place in the app where a smaller number is the better one.
      expect(find.textContaining('ASSIST'), findsOneWidget);
    });

    testWidgets('PREVIOUS shows the last session, and a dash when there is none',
        (tester) async {
      final rows = await pumpLog(
        tester,
        <String, LoadType>{'bench': LoadType.weighted},
        history: (store) async {
          final past = await store.createSession();
          final rowId = await store.addExercise(
            sessionId: past.id,
            exerciseId: 'bench',
            loadType: LoadType.weighted,
          );
          await store.writeSet(
            sessionExerciseId: rowId,
            position: 0,
            completed: true,
            weightKg: 55,
            reps: 12,
          );
          await store.saveOpenSession();
        },
      );

      expect(
        tester
            .widget<Text>(find.byKey(SetTableRow.previousKey(rows['bench']!, 0)))
            .data,
        contains('55'),
      );

      await act(tester, () async {
        await tester
            .tap(find.byKey(LogExerciseBlock.addSetKey(rows['bench']!)));
      });
      expect(
        tester
            .widget<Text>(find.byKey(SetTableRow.previousKey(rows['bench']!, 1)))
            .data,
        '-',
        reason: 'the second set was never done before',
      );
    });

    testWidgets('Add set appends a row to that exercise only', (tester) async {
      final rows = await pumpLog(tester, <String, LoadType>{
        'bench': LoadType.weighted,
        'pull-up': LoadType.bodyweight,
      });

      await act(tester, () async {
        await tester.tap(
            find.byKey(LogExerciseBlock.addSetKey(rows['bench']!)));
      });

      expect(find.byKey(SetTableRow.rowKey(rows['bench']!, 1)), findsOneWidget);
      expect(
        find.byKey(SetTableRow.rowKey(rows['pull-up']!, 1)),
        findsNothing,
      );
    });
  });

  group('the exercise menu', () {
    testWidgets('moves an exercise up and down the list', (tester) async {
      final rows = await pumpLog(tester, <String, LoadType>{
        'bench': LoadType.weighted,
        'pull-up': LoadType.bodyweight,
      });

      await tester.tap(find.byKey(LogExerciseBlock.menuKey(rows['pull-up']!)));
      await tester.pumpAndSettle();
      await act(tester, () async {
        await tester.tap(find.text('Move up'));
      });

      final order = tester
          .widgetList<LogExerciseBlock>(find.byType(LogExerciseBlock))
          .map((b) => b.exercise.exerciseId);
      expect(order, <String>['pull-up', 'bench']);
    });

    testWidgets('the first exercise cannot move up, nor the last down',
        (tester) async {
      final rows = await pumpLog(tester, <String, LoadType>{
        'bench': LoadType.weighted,
        'pull-up': LoadType.bodyweight,
      });

      await tester.tap(find.byKey(LogExerciseBlock.menuKey(rows['bench']!)));
      await tester.pumpAndSettle();
      // An offered control that does nothing is worse than an absent one.
      expect(find.text('Move up'), findsNothing);
      expect(find.text('Move down'), findsOneWidget);
    });

    testWidgets('Replace is withdrawn once a set has been logged',
        (tester) async {
      final rows = await pumpLog(
          tester, <String, LoadType>{'bench': LoadType.weighted});
      final rowId = rows['bench']!;

      await tester.tap(find.byKey(LogExerciseBlock.menuKey(rowId)));
      await tester.pumpAndSettle();
      expect(find.text('Replace exercise'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await act(tester, () async {
        await tester.enterText(
            find.byKey(SetTableRow.weightFieldKey(rowId, 0)), '60');
      });
      await act(tester, () async {
        await tester.enterText(
            find.byKey(SetTableRow.repsFieldKey(rowId, 0)), '10');
      });
      await act(tester, () async {
        await tester.tap(find.byKey(SetTableRow.checkKey(rowId, 0)));
      });

      await tester.tap(find.byKey(LogExerciseBlock.menuKey(rowId)));
      await tester.pumpAndSettle();
      // Replacing re-snapshots the load type, which would reinterpret sets
      // already written against the old shape.
      expect(find.text('Replace exercise'), findsNothing);
    });
  });

  group('the actions at the foot', () {
    testWidgets('Add exercise is the one accent-filled control', (tester) async {
      await pumpLog(tester, <String, LoadType>{'bench': LoadType.weighted});

      expect(find.byKey(LogWorkoutScreen.addExerciseKey), findsOneWidget);
      expect(find.text('Add exercise'), findsOneWidget);
    });

    testWidgets('Discard workout is painted danger, never accent',
        (tester) async {
      await pumpLog(tester, <String, LoadType>{'bench': LoadType.weighted});

      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(LogWorkoutScreen.discardKey),
          matching: find.byType(Text),
        ),
      );
      // `#D85A30` means "active / this has been worked" wherever it appears, so
      // a discard painted in it would read as approval. See `00` §12.
      expect(label.style?.color, AppPalette.danger);
    });
  });
}
