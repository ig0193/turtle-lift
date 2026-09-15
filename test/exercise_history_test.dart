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
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/exercise_history_screen.dart';

/// Proves the full record of one exercise.
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
      equipment: 'barbell',
      loadType: 'weighted',
      primary: const <String>['chest/mid'],
      secondary: const <String>[],
      setup: '',
      posture: '',
      execution: '',
      commonMistakes: '',
    ),
    Exercise(
      id: 'assisted-pull-up',
      name: 'Assisted pull-up',
      equipment: 'machine',
      loadType: 'assisted',
      primary: const <String>['back/lats'],
      secondary: const <String>[],
      setup: '',
      posture: '',
      execution: '',
      commonMistakes: '',
    ),
  ]);

  Future<void> logSession(
    WidgetTester tester, {
    required String exerciseId,
    required LoadType loadType,
    required LocalDate on,
    List<double> weights = const <double>[],
    List<double> assists = const <double>[],
  }) async {
    await tester.runAsync(() async {
      final session = await store.createSession(performedOn: on);
      final row = await store.addExercise(
        sessionId: session.id,
        exerciseId: exerciseId,
        loadType: loadType,
      );
      final values = weights.isNotEmpty ? weights : assists;
      for (var i = 0; i < values.length; i++) {
        await store.writeSet(
          sessionExerciseId: row,
          position: i,
          weightKg: weights.isNotEmpty ? values[i] : null,
          assistKg: assists.isNotEmpty ? values[i] : null,
          reps: 8,
          completed: true,
        );
      }
      await store.saveOpenSession();
    });
  }

  Future<void> pump(WidgetTester tester, String exerciseId) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final saved = await tester.runAsync(() => store.readSavedSessions());
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialSavedSessionsProvider.overrideWithValue(saved!),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: ExerciseHistoryScreen(exerciseId: exerciseId),
        ),
      ),
    );
    await tester.pump();
  }

  group('with no history', () {
    testWidgets('says so in one line rather than showing an empty grid',
        (tester) async {
      await pump(tester, 'bench');

      expect(find.text('You haven’t logged this yet.'), findsOneWidget);
      expect(find.byKey(ExerciseHistoryScreen.seeMoreKey), findsNothing);
    });
  });

  group('with history', () {
    testWidgets('lists sessions newest first with every set', (tester) async {
      await logSession(tester,
          exerciseId: 'bench',
          loadType: LoadType.weighted,
          on: LocalDate.today().addDays(-7),
          weights: <double>[55, 55]);
      await logSession(tester,
          exerciseId: 'bench',
          loadType: LoadType.weighted,
          on: LocalDate.today().addDays(-2),
          weights: <double>[60, 60, 57.5]);

      await pump(tester, 'bench');

      expect(find.text('60kg × 8'), findsNWidgets(2));
      expect(find.text('57.5kg × 8'), findsOneWidget);
      expect(find.text('55kg × 8'), findsNWidgets(2));

      final newest = tester.getTopLeft(find.text('57.5kg × 8')).dy;
      final oldest = tester.getTopLeft(find.text('55kg × 8').first).dy;
      expect(newest, lessThan(oldest));
    });

    testWidgets('counts the sessions and names the best', (tester) async {
      await logSession(tester,
          exerciseId: 'bench',
          loadType: LoadType.weighted,
          on: LocalDate.today().addDays(-7),
          weights: <double>[55]);
      await logSession(tester,
          exerciseId: 'bench',
          loadType: LoadType.weighted,
          on: LocalDate.today().addDays(-2),
          weights: <double>[62.5]);

      await pump(tester, 'bench');

      expect(find.textContaining('2 sessions'), findsOneWidget);
      expect(find.textContaining('best 62.5kg × 8'), findsOneWidget);
    });

    testWidgets('marks the session that set a record', (tester) async {
      await logSession(tester,
          exerciseId: 'bench',
          loadType: LoadType.weighted,
          on: LocalDate.today().addDays(-7),
          weights: <double>[55]);
      await logSession(tester,
          exerciseId: 'bench',
          loadType: LoadType.weighted,
          on: LocalDate.today().addDays(-2),
          weights: <double>[62.5]);

      await pump(tester, 'bench');

      expect(find.text('★ PB'), findsOneWidget);
    });

    testWidgets('an assisted record names what kind of record it is',
        (tester) async {
      await logSession(tester,
          exerciseId: 'assisted-pull-up',
          loadType: LoadType.assisted,
          on: LocalDate.today().addDays(-7),
          assists: <double>[30]);
      await logSession(tester,
          exerciseId: 'assisted-pull-up',
          loadType: LoadType.assisted,
          on: LocalDate.today().addDays(-2),
          assists: <double>[22.5]);

      await pump(tester, 'assisted-pull-up');

      expect(
        find.text('★ PB · lightest assist'),
        findsOneWidget,
        reason: 'without it, a badge beside 22.5 next to a row showing 30 '
            'reads as a bug',
      );
    });

    testWidgets('shows only this exercise', (tester) async {
      await logSession(tester,
          exerciseId: 'bench',
          loadType: LoadType.weighted,
          on: LocalDate.today().addDays(-2),
          weights: <double>[60]);
      await logSession(tester,
          exerciseId: 'assisted-pull-up',
          loadType: LoadType.assisted,
          on: LocalDate.today().addDays(-1),
          assists: <double>[20]);

      await pump(tester, 'bench');

      expect(find.textContaining('1 session'), findsOneWidget);
      expect(find.textContaining('assist'), findsNothing);
    });

    testWidgets('pages twenty at a time', (tester) async {
      for (var i = 1; i <= 22; i++) {
        await logSession(tester,
            exerciseId: 'bench',
            loadType: LoadType.weighted,
            on: LocalDate.today().addDays(-i),
            weights: <double>[50 + i.toDouble()]);
      }

      await pump(tester, 'bench');

      expect(find.byKey(ExerciseHistoryScreen.seeMoreKey), findsOneWidget);

      await tester.tap(find.byKey(ExerciseHistoryScreen.seeMoreKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ExerciseHistoryScreen.seeMoreKey), findsNothing);
    });
  });
}
