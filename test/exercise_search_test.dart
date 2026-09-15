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
import 'package:turtle_lift/src/ui/exercise_detail_screen.dart';
import 'package:turtle_lift/src/ui/exercise_search_screen.dart';
import 'package:turtle_lift/src/ui/set_logging_screen.dart';

/// Proves the ad-hoc path's way in.
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

  Exercise ex(String id, String name, {String loadType = 'weighted'}) =>
      Exercise(
        id: id,
        name: name,
        equipment: 'Barbell',
        loadType: loadType,
        primary: const <String>['biceps/biceps'],
        secondary: const <String>[],
        setup: 'Set up.',
        posture: 'Braced.',
        execution: 'Curl, breathing out.',
        commonMistakes: 'No swinging.',
      );

  final index = ExerciseIndex(<Exercise>[
    ex('barbell-curl', 'Barbell curl'),
    ex('dumbbell-curl', 'Dumbbell curl'),
    ex('hammer-curl', 'Hammer curl'),
    ex('bench-press', 'Barbell bench press'),
  ]);

  Future<void> pumpSearch(
    WidgetTester tester, {
    WorkoutSession? session,
    List<WorkoutSession> saved = const <WorkoutSession>[],
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialActiveSessionProvider.overrideWithValue(session),
          initialSavedSessionsProvider.overrideWithValue(saved),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const ExerciseSearchScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
  }

  group('searching', () {
    testWidgets('filters by name, case-insensitively', (tester) async {
      await pumpSearch(tester);

      await tester.enterText(find.byType(TextField), 'CURL');
      await tester.pump();

      expect(find.text('Barbell curl'), findsOneWidget);
      expect(find.text('Hammer curl'), findsOneWidget);
      expect(find.text('Barbell bench press'), findsNothing);
      expect(find.text('3 matches'), findsOneWidget);
    });

    testWidgets('a blank query lists nothing rather than the whole library',
        (tester) async {
      await pumpSearch(tester);

      expect(find.text('Barbell curl'), findsNothing);
      expect(find.byKey(ExerciseSearchScreen.countKey), findsNothing);
    });

    testWidgets('a single match says match, not matches', (tester) async {
      await pumpSearch(tester);

      await tester.enterText(find.byType(TextField), 'hammer');
      await tester.pump();

      expect(find.text('1 match'), findsOneWidget);
    });
  });

  group('creating the workout', () {
    testWidgets('backing out with nothing added leaves no session',
        (tester) async {
      await pumpSearch(tester);

      await tester.enterText(find.byType(TextField), 'curl');
      await tester.pump();

      final count = await tester.runAsync(() => store.sessionCount());
      expect(
        count,
        0,
        reason: 'creating the workout on arrival would strand a user who backs '
            'out in an empty session that has replaced their landing',
      );
    });

    testWidgets('the first add creates an ad-hoc workout', (tester) async {
      // A prior session of this exercise, so the first-time detour does not
      // fire and the add goes straight through.
      await tester.runAsync(() async {
        final past = await store.createSession(
            performedOn: LocalDate.today().addDays(-3));
        final row = await store.addExercise(
            sessionId: past.id,
            exerciseId: 'barbell-curl',
            loadType: LoadType.weighted);
        await store.writeSet(
            sessionExerciseId: row,
            position: 0,
            weightKg: 30,
            reps: 10,
            completed: true);
        await store.saveOpenSession();
      });
      final saved = await tester.runAsync(() => store.readSavedSessions());

      await pumpSearch(tester, saved: saved!);
      await tester.enterText(find.byType(TextField), 'barbell curl');
      await tester.pump();

      await act(tester, () => tester.tap(find.text('Barbell curl')));

      final open = await tester.runAsync(() => store.readOpenSession());
      expect(open, isNotNull);
      expect(open!.templateId, isNull, reason: 'it is an ad-hoc workout');
      expect(open.title, isNull, reason: 'its title starts empty');
      expect(open.exercises.single.exerciseId, 'barbell-curl');
    });

    testWidgets('and lands on the logging screen', (tester) async {
      await tester.runAsync(() async {
        final past = await store.createSession(
            performedOn: LocalDate.today().addDays(-3));
        final row = await store.addExercise(
            sessionId: past.id,
            exerciseId: 'barbell-curl',
            loadType: LoadType.weighted);
        await store.writeSet(
            sessionExerciseId: row,
            position: 0,
            weightKg: 30,
            reps: 10,
            completed: true);
        await store.saveOpenSession();
      });
      final saved = await tester.runAsync(() => store.readSavedSessions());

      await pumpSearch(tester, saved: saved!);
      await tester.enterText(find.byType(TextField), 'barbell curl');
      await tester.pump();
      await act(tester, () => tester.tap(find.text('Barbell curl')));

      expect(find.byType(SetLoggingScreen), findsOneWidget);
    });
  });

  group('the first-time detour', () {
    testWidgets('an exercise never completed opens its page first',
        (tester) async {
      await pumpSearch(tester);

      await tester.enterText(find.byType(TextField), 'hammer');
      await tester.pump();
      await act(tester, () => tester.tap(find.text('Hammer curl')));

      expect(
        find.byType(ExerciseDetailScreen),
        findsOneWidget,
        reason: 'a user cannot know a lift they have never done',
      );
      expect(find.byKey(ExerciseDetailScreen.startLoggingKey), findsOneWidget);
    });

    testWidgets('and Start logging from there adds it and logs it',
        (tester) async {
      final session = await tester.runAsync(() => store.createSession());

      await pumpSearch(tester, session: session);
      await tester.enterText(find.byType(TextField), 'hammer');
      await tester.pump();
      await act(tester, () => tester.tap(find.text('Hammer curl')));
      await act(tester,
          () => tester.tap(find.byKey(ExerciseDetailScreen.startLoggingKey)));

      final open = await tester.runAsync(() => store.readOpenSession());
      expect(open!.exercises.single.exerciseId, 'hammer-curl');
      expect(find.byType(SetLoggingScreen), findsOneWidget);
    });
  });

  group('an exercise already in the workout', () {
    testWidgets('opens rather than being added twice', (tester) async {
      late WorkoutSession session;
      await tester.runAsync(() async {
        session = await store.createSession();
        await store.addExercise(
          sessionId: session.id,
          exerciseId: 'barbell-curl',
          loadType: LoadType.weighted,
        );
        session = (await store.readOpenSession())!;
      });

      await pumpSearch(tester, session: session);
      await tester.enterText(find.byType(TextField), 'barbell curl');
      await tester.pump();
      await act(tester, () => tester.tap(find.text('Barbell curl')));

      final open = await tester.runAsync(() => store.readOpenSession());
      expect(
        open!.exercises,
        hasLength(1),
        reason: 'a second row would split its sets across two prefill chains',
      );
      expect(find.byType(SetLoggingScreen), findsOneWidget);
    });
  });

  group('what a result shows', () {
    testWidgets('carries the last set for an exercise with history',
        (tester) async {
      await tester.runAsync(() async {
        final past = await store.createSession(
            performedOn: LocalDate.today().addDays(-3));
        final row = await store.addExercise(
            sessionId: past.id,
            exerciseId: 'barbell-curl',
            loadType: LoadType.weighted);
        await store.writeSet(
            sessionExerciseId: row,
            position: 0,
            weightKg: 30,
            reps: 10,
            completed: true);
        await store.saveOpenSession();
      });
      final saved = await tester.runAsync(() => store.readSavedSessions());

      await pumpSearch(tester, saved: saved!);
      await tester.enterText(find.byType(TextField), 'curl');
      await tester.pump();

      expect(find.text('Last 30kg × 10'), findsOneWidget);
    });

    testWidgets('shows no history line for an exercise never logged',
        (tester) async {
      await pumpSearch(tester);

      await tester.enterText(find.byType(TextField), 'hammer');
      await tester.pump();

      expect(find.textContaining('Last '), findsNothing);
    });
  });
}
