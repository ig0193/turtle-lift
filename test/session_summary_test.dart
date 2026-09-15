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
import 'package:turtle_lift/src/data/personal_details_store.dart'
    show BodyweightEntry, initialBodyweightLogProvider;
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/body_diagram.dart';
import 'package:turtle_lift/src/ui/destructive_confirmation.dart';
import 'package:turtle_lift/src/ui/session_summary_screen.dart';
import 'package:turtle_lift/src/ui/set_logging_screen.dart';

/// Proves the card a finished workout lands on, which is also the record of it.
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

  Exercise ex(
    String id,
    String name, {
    required List<String> primary,
    String loadType = 'weighted',
  }) =>
      Exercise(
        id: id,
        name: name,
        equipment: 'barbell',
        loadType: loadType,
        primary: primary,
        secondary: const <String>[],
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
      );

  final index = ExerciseIndex(<Exercise>[
    ex('bench', 'Barbell bench press', primary: <String>['chest/mid']),
    ex('row', 'Barbell row', primary: <String>['back/lats']),
    ex('assisted-pull-up', 'Assisted pull-up',
        primary: <String>['back/lats'], loadType: 'assisted'),
  ]);

  /// Saves a workout and returns its id.
  Future<String> saveWorkout(
    WidgetTester tester, {
    required String exerciseId,
    required LoadType loadType,
    LocalDate? on,
    double? weightKg,
    int reps = 8,
    double? assistKg,
    String? title,
  }) async {
    late String id;
    await tester.runAsync(() async {
      final session = await store.createSession(performedOn: on);
      id = session.id;
      if (title != null) await store.setTitle(id, title);
      final row = await store.addExercise(
        sessionId: id,
        exerciseId: exerciseId,
        loadType: loadType,
      );
      await store.writeSet(
        sessionExerciseId: row,
        position: 0,
        weightKg: weightKg,
        assistKg: assistKg,
        reps: reps,
        completed: true,
      );
      await store.saveOpenSession();
    });
    return id;
  }

  Future<void> pump(
    WidgetTester tester,
    String sessionId, {
    List<BodyweightEntry> weights = const <BodyweightEntry>[],
  }) async {
    tester.view.physicalSize = const Size(1200, 3400);
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
          initialBodyweightLogProvider.overrideWithValue(weights),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: SessionSummaryScreen(sessionId: sessionId),
        ),
      ),
    );
    await tester.pump();
  }

  group('the card', () {
    testWidgets('shows the set and exercise counts', (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 60);

      await pump(tester, id);

      expect(find.text('Sets'), findsOneWidget);
      expect(find.text('Exercises'), findsOneWidget);
      expect(find.text('Day streak'), findsOneWidget);
    });

    testWidgets('carries the app name', (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 60);

      await pump(tester, id);

      expect(find.text('TURTLELIFT'), findsOneWidget);
    });

    testWidgets('renders the sets through the shared formatter',
        (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 60);

      await pump(tester, id);

      expect(find.text('60kg × 8'), findsOneWidget);
    });
  });

  group('the diagrams', () {
    testWidgets('a front-only workout draws one', (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 60);

      await pump(tester, id);

      expect(
        find.byType(BodyDiagram),
        findsOneWidget,
        reason: 'never an empty second diagram beside a filled one',
      );
    });

    testWidgets('a back-only workout also draws one', (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'row', loadType: LoadType.weighted, weightKg: 70);

      await pump(tester, id);

      expect(find.byType(BodyDiagram), findsOneWidget);
    });
  });

  group('the personal-best pill', () {
    testWidgets('is absent on a first-ever workout', (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 60);

      await pump(tester, id);

      expect(
        find.byKey(SessionSummaryScreen.pbPillKey),
        findsNothing,
        reason: 'never "0 personal bests" on a card built to be screenshotted',
      );
    });

    testWidgets('appears once a record is beaten', (tester) async {
      await saveWorkout(tester,
          exerciseId: 'bench',
          loadType: LoadType.weighted,
          weightKg: 60,
          on: LocalDate.today().addDays(-3));
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 65);

      await pump(tester, id);

      expect(find.byKey(SessionSummaryScreen.pbPillKey), findsOneWidget);
      expect(find.text('1 personal best'), findsOneWidget);
      expect(find.text('★ PB'), findsOneWidget);
    });

    testWidgets('an assisted record says what kind of record it is',
        (tester) async {
      await saveWorkout(tester,
          exerciseId: 'assisted-pull-up',
          loadType: LoadType.assisted,
          assistKg: 25,
          on: LocalDate.today().addDays(-3));
      final id = await saveWorkout(tester,
          exerciseId: 'assisted-pull-up',
          loadType: LoadType.assisted,
          assistKg: 20);

      await pump(tester, id);

      expect(
        find.text('★ PB · lightest assist'),
        findsOneWidget,
        reason: 'a badge beside a smaller number would otherwise read as a bug '
            'weeks later, and the logging screen\'s banner is not on this page',
      );
    });
  });

  group('calories', () {
    testWidgets('show the add-weight prompt with no weight on record',
        (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 60);

      await pump(tester, id);

      expect(find.byKey(SessionSummaryScreen.addWeightKey), findsOneWidget);
      expect(find.byKey(SessionSummaryScreen.calorieInfoKey), findsNothing);
    });

    testWidgets('show a figure and an explanation with one', (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 60);

      await pump(tester, id, weights: <BodyweightEntry>[
        BodyweightEntry(
            date: LocalDate.today().addDays(-30).toDateTime(), weightKg: 78),
      ]);

      expect(find.byKey(SessionSummaryScreen.addWeightKey), findsNothing);
      expect(find.text('kcal'), findsOneWidget);

      await tester.tap(find.byKey(SessionSummaryScreen.calorieInfoKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('standard exercise-science averages'),
          findsOneWidget);
    });
  });

  group('deleting', () {
    testWidgets('asks first and cancelling keeps the workout', (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 60);
      await pump(tester, id);

      await tester.tap(find.byKey(SessionSummaryScreen.deleteKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(confirmCancelKey));
      await tester.pumpAndSettle();

      expect(await tester.runAsync(() => store.readSavedSessions()),
          hasLength(1));
    });

    testWidgets('confirming removes it', (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 60);
      await pump(tester, id);

      await tester.tap(find.byKey(SessionSummaryScreen.deleteKey));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(confirmDestructiveKey));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();

      expect(await tester.runAsync(() => store.readSavedSessions()), isEmpty);
    });

    testWidgets('the delete label is painted in the destructive colour',
        (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 60);
      await pump(tester, id);

      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(SessionSummaryScreen.deleteKey),
          matching: find.byType(Text),
        ),
      );
      expect(label.style!.color, const Color(0xFFC4553A));
    });
  });

  group('the title', () {
    testWidgets('shows the resolved name when the user gave none',
        (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 60);

      await pump(tester, id);

      expect(
        find.text('Barbell bench press'),
        findsWidgets,
        reason: 'a quick log falls back to the single exercise name',
      );
    });

    testWidgets('shows the user\'s own name when they gave one',
        (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench',
          loadType: LoadType.weighted,
          weightKg: 60,
          title: 'Evening push');

      await pump(tester, id);

      expect(find.text('Evening push'), findsWidgets);
    });
  });

  group('editing a saved workout', () {
    testWidgets('tapping an exercise opens its sets for correction',
        (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 60);
      await pump(tester, id);

      await tester.tap(find.text('60kg × 8'));
      await tester.pumpAndSettle();

      expect(
        find.byType(SetLoggingScreen),
        findsOneWidget,
        reason: 'the screen that logs a set is the screen that corrects one, '
            'never a second read-only viewer that would drift from it',
      );
    });

    testWidgets('a correction changes the derived figures', (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 60);
      await pump(tester, id);

      await tester.tap(find.text('60kg × 8'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.enterText(find.byType(TextField).first, '65');
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();

      final saved = await tester.runAsync(() => store.readSavedSessions());
      expect(saved!.single.exercises.single.sets.single.weightKg, 65);
    });

    testWidgets('no Mark exercise done on a workout already saved',
        (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 60);
      await pump(tester, id);

      await tester.tap(find.text('60kg × 8'));
      await tester.pumpAndSettle();

      expect(find.byKey(SetLoggingScreen.markDoneKey), findsNothing);
    });

    testWidgets('long-pressing an exercise offers to remove it',
        (tester) async {
      final id = await saveWorkout(tester,
          exerciseId: 'bench', loadType: LoadType.weighted, weightKg: 60);
      await pump(tester, id);

      await tester.longPress(find.text('60kg × 8'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Barbell bench press?'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(confirmDestructiveKey));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();

      final saved = await tester.runAsync(() => store.readSavedSessions());
      expect(saved!.single.exercises, isEmpty);
    });
  });
}
