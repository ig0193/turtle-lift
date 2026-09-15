import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/exercise_detail_screen.dart';

/// Proves which action the exercise's page offers, and when.
///
/// The page is three things depending on how you reached it: a reference page
/// from the Muscles tab, the first-time gate inside the workout flow, and the
/// info button's destination mid-set. `docs/03` fixes all three.
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

  final bench = Exercise(
    id: 'bench',
    name: 'Barbell bench press',
    equipment: 'Barbell',
    loadType: 'weighted',
    primary: const <String>['chest/mid'],
    secondary: const <String>[],
    setup: 'Set up.',
    posture: 'Stay braced.',
    execution: 'Press, breathing out.',
    commonMistakes: 'Do not bounce the bar.',
  );

  final index = ExerciseIndex(<Exercise>[bench]);

  Future<void> pumpDetail(
    WidgetTester tester, {
    required ExerciseDetailEntry entry,
    WorkoutSession? session,
  }) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialActiveSessionProvider.overrideWithValue(session),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: ExerciseDetailScreen(exercise: bench, entry: entry),
        ),
      ),
    );
    await tester.pump();
  }

  Future<WorkoutSession> openAdHoc(WidgetTester tester) async {
    late WorkoutSession session;
    await tester.runAsync(() async {
      session = await store.createSession();
    });
    return session;
  }

  Future<WorkoutSession> openTemplate(WidgetTester tester) async {
    late WorkoutSession session;
    await tester.runAsync(() async {
      session = await store.createSession(
        templateId: 'push',
        templateName: 'Push day',
        groupIds: <String>['chest'],
      );
    });
    return session;
  }

  group('browsed from the Muscles tab', () {
    testWidgets('offers nothing with no workout open', (tester) async {
      await pumpDetail(tester, entry: ExerciseDetailEntry.reference);

      expect(find.byKey(ExerciseDetailScreen.addToWorkoutKey), findsNothing);
      expect(find.byKey(ExerciseDetailScreen.startLoggingKey), findsNothing);
    });

    testWidgets('offers to add during an ad-hoc workout', (tester) async {
      final session = await openAdHoc(tester);

      await pumpDetail(tester,
          entry: ExerciseDetailEntry.reference, session: session);

      expect(find.byKey(ExerciseDetailScreen.addToWorkoutKey), findsOneWidget);
    });

    testWidgets('offers nothing during a template workout', (tester) async {
      final session = await openTemplate(tester);

      await pumpDetail(tester,
          entry: ExerciseDetailEntry.reference, session: session);

      expect(
        find.byKey(ExerciseDetailScreen.addToWorkoutKey),
        findsNothing,
        reason: 'a template session is locked to the muscle groups the user '
            'chose; that is the point of choosing one',
      );
    });

    testWidgets('adding puts the exercise in the session', (tester) async {
      final session = await openAdHoc(tester);
      await pumpDetail(tester,
          entry: ExerciseDetailEntry.reference, session: session);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(ExerciseDetailScreen.addToWorkoutKey));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();

      final open = await tester.runAsync(() => store.readOpenSession());
      expect(open!.exercises, hasLength(1));
      expect(open.exercises.single.exerciseId, 'bench');
    });
  });

  group('the first-time gate inside the workout flow', () {
    testWidgets('offers to start logging', (tester) async {
      final session = await openAdHoc(tester);

      await pumpDetail(tester,
          entry: ExerciseDetailEntry.workoutStart, session: session);

      expect(find.byKey(ExerciseDetailScreen.startLoggingKey), findsOneWidget);
      expect(find.text('Start logging'), findsOneWidget);
    });

    testWidgets('does not also offer to add', (tester) async {
      final session = await openAdHoc(tester);

      await pumpDetail(tester,
          entry: ExerciseDetailEntry.workoutStart, session: session);

      expect(find.byKey(ExerciseDetailScreen.addToWorkoutKey), findsNothing);
    });
  });

  group('opened from the logging screen', () {
    testWidgets('offers neither action', (tester) async {
      final session = await openAdHoc(tester);

      await pumpDetail(tester,
          entry: ExerciseDetailEntry.fromLogging, session: session);

      expect(find.byKey(ExerciseDetailScreen.startLoggingKey), findsNothing);
      expect(
        find.byKey(ExerciseDetailScreen.addToWorkoutKey),
        findsNothing,
        reason: 'the user is already logging this exercise',
      );
    });
  });

  group('the reviewed content', () {
    testWidgets('renders identically in every mode', (tester) async {
      for (final entry in ExerciseDetailEntry.values) {
        final session = await openAdHoc(tester);
        await pumpDetail(tester, entry: entry, session: session);

        expect(find.text('Do not bounce the bar.'), findsOneWidget,
            reason: 'the reviewed copy is never conditional on how you arrived');
        expect(find.text('Barbell bench press'), findsWidgets);
      }
    });
  });
}
