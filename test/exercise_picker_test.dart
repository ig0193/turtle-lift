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
import 'package:turtle_lift/src/data/session_progress.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/exercise_detail_screen.dart';
import 'package:turtle_lift/src/ui/exercise_picker_sheet.dart';
import 'package:turtle_lift/src/ui/session_entry.dart';
import 'package:turtle_lift/src/ui/set_logging_screen.dart';

/// Proves the way into logging an exercise: the picker sheet, and the rules
/// that apply whichever list the exercise was chosen from.
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
    String primary = 'biceps/biceps',
    String loadType = 'weighted',
  }) =>
      Exercise(
        id: id,
        name: name,
        equipment: 'barbell',
        loadType: loadType,
        primary: <String>[primary],
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
    ex('bench-press', 'Barbell bench press', primary: 'chest/mid'),
  ]);

  /// A host with one button, so the picker opens the way it does in the app:
  /// from a widget that holds a `WidgetRef` and a mounted context.
  Future<void> pumpHost(
    WidgetTester tester, {
    WorkoutSession? session,
    List<WorkoutSession> saved = const <WorkoutSession>[],
    String title = 'Add an exercise',
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
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                key: const ValueKey<String>('open-picker'),
                onPressed: () =>
                    pickAndOpenExercise(context, ref, title: title),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey<String>('open-picker')));
    await tester.pumpAndSettle();
  }

  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
  }

  /// A saved session that completed a set of [exerciseId], so that exercise is
  /// not new to the user and the first-time detour does not fire.
  Future<List<WorkoutSession>> savedWith(
    WidgetTester tester,
    String exerciseId,
  ) async {
    await tester.runAsync(() async {
      final past = await store.createSession(
          performedOn: LocalDate.today().addDays(-3));
      final row = await store.addExercise(
          sessionId: past.id,
          exerciseId: exerciseId,
          loadType: LoadType.weighted);
      await store.writeSet(
          sessionExerciseId: row,
          position: 0,
          weightKg: 30,
          reps: 10,
          completed: true);
      await store.saveOpenSession();
    });
    return (await tester.runAsync(() => store.readSavedSessions()))!;
  }

  group('the sheet', () {
    testWidgets('carries the title it was asked for', (tester) async {
      await pumpHost(tester, title: 'What are you starting with?');
      await openPicker(tester);

      expect(find.text('What are you starting with?'), findsOneWidget);
    });

    testWidgets('lists the whole library before anything is typed',
        (tester) async {
      await pumpHost(tester);
      await openPicker(tester);

      expect(find.byKey(ExercisePickerSheet.rowKey('barbell-curl')),
          findsOneWidget);
      expect(find.byKey(ExercisePickerSheet.rowKey('bench-press')),
          findsOneWidget);
      expect(find.text('EXERCISES'), findsOneWidget,
          reason: 'with nothing in the workout there is no planned section');
    });

    testWidgets('filters by name, case-insensitively', (tester) async {
      await pumpHost(tester);
      await openPicker(tester);

      await tester.enterText(find.byType(TextField), 'CURL');
      await tester.pump();

      expect(find.text('Barbell curl'), findsOneWidget);
      expect(find.text('Hammer curl'), findsOneWidget);
      expect(find.text('Barbell bench press'), findsNothing);
    });

    testWidgets('a muscle chip narrows the list, and All brings it back',
        (tester) async {
      await pumpHost(tester);
      await openPicker(tester);

      await tester.tap(find.byKey(ExercisePickerSheet.chipKey('chest')));
      await tester.pump();
      expect(find.text('Barbell bench press'), findsOneWidget);
      expect(find.text('Barbell curl'), findsNothing);

      await tester.tap(find.byKey(ExercisePickerSheet.chipKey('all')));
      await tester.pump();
      expect(find.text('Barbell curl'), findsOneWidget);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await pumpHost(tester);
      await openPicker(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();

      expect(find.text('No exercise matches.'), findsOneWidget);
    });

    testWidgets("the workout's own exercises come first, under their own label",
        (tester) async {
      late WorkoutSession session;
      await tester.runAsync(() async {
        session = await store.createSession();
        await store.addExercise(
          sessionId: session.id,
          exerciseId: 'hammer-curl',
          loadType: LoadType.weighted,
        );
        session = (await store.readOpenSession())!;
      });

      await pumpHost(tester, session: session);
      await openPicker(tester);

      expect(find.text('IN THIS WORKOUT'), findsOneWidget);
      expect(find.text('ADD ANOTHER'), findsOneWidget);
      final planned = tester.getTopLeft(
          find.byKey(ExercisePickerSheet.rowKey('hammer-curl')));
      final other = tester.getTopLeft(
          find.byKey(ExercisePickerSheet.rowKey('barbell-curl')));
      expect(planned.dy, lessThan(other.dy));
    });

    testWidgets('shows the last set for an exercise with history',
        (tester) async {
      final saved = await savedWith(tester, 'barbell-curl');

      await pumpHost(tester, saved: saved);
      await openPicker(tester);

      expect(find.text('Last 30kg × 10'), findsOneWidget);
    });

    testWidgets('shows no history line for an exercise never logged',
        (tester) async {
      await pumpHost(tester);
      await openPicker(tester);

      expect(find.textContaining('Last '), findsNothing);
    });

    testWidgets('dismissing it chooses nothing and creates nothing',
        (tester) async {
      await pumpHost(tester);
      await openPicker(tester);

      await tester.tapAt(const Offset(10, 10)); // the scrim
      await tester.pumpAndSettle();

      expect(find.byType(ExercisePickerSheet), findsNothing);
      final count = await tester.runAsync(() => store.sessionCount());
      expect(count, 0);
    });
  });

  group('choosing an exercise', () {
    testWidgets('with no workout open starts an ad-hoc one', (tester) async {
      final saved = await savedWith(tester, 'barbell-curl');

      await pumpHost(tester, saved: saved);
      await openPicker(tester);
      await act(tester,
          () => tester.tap(find.byKey(ExercisePickerSheet.rowKey('barbell-curl'))));

      final open = await tester.runAsync(() => store.readOpenSession());
      expect(open, isNotNull);
      expect(open!.templateId, isNull, reason: 'it is an ad-hoc workout');
      expect(open.title, isNull, reason: 'its title starts empty');
      expect(open.exercises.single.exerciseId, 'barbell-curl');
    });

    testWidgets('and lands on the logging screen', (tester) async {
      final saved = await savedWith(tester, 'barbell-curl');

      await pumpHost(tester, saved: saved);
      await openPicker(tester);
      await act(tester,
          () => tester.tap(find.byKey(ExercisePickerSheet.rowKey('barbell-curl'))));

      expect(find.byType(SetLoggingScreen), findsOneWidget);
    });

    testWidgets('records that logging has started', (tester) async {
      final saved = await savedWith(tester, 'barbell-curl');

      await pumpHost(tester, saved: saved);
      await openPicker(tester);
      await act(tester,
          () => tester.tap(find.byKey(ExercisePickerSheet.rowKey('barbell-curl'))));

      final container = ProviderScope.containerOf(
          tester.element(find.byType(SetLoggingScreen)));
      final open = container.read(activeSessionProvider)!;
      expect(
        container.read(loggingStartedProvider).contains(open.id),
        isTrue,
        reason: 'this is what takes the session screen from its ready view to '
            'the list',
      );
    });
  });

  group('the first-time detour', () {
    testWidgets('an exercise never completed opens its page first',
        (tester) async {
      await pumpHost(tester);
      await openPicker(tester);
      await act(tester,
          () => tester.tap(find.byKey(ExercisePickerSheet.rowKey('hammer-curl'))));

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

      await pumpHost(tester, session: session);
      await openPicker(tester);
      await act(tester,
          () => tester.tap(find.byKey(ExercisePickerSheet.rowKey('hammer-curl'))));
      await act(tester,
          () => tester.tap(find.byKey(ExerciseDetailScreen.startLoggingKey)));

      final open = await tester.runAsync(() => store.readOpenSession());
      expect(open!.exercises.single.exerciseId, 'hammer-curl');
      expect(find.byType(SetLoggingScreen), findsOneWidget);
    });

    testWidgets('a planned exercise the user has never done still gets it',
        (tester) async {
      // On a fresh install every exercise on a template is new, so the rule
      // applies to a row already on the list, not only to one just added.
      late WorkoutSession session;
      await tester.runAsync(() async {
        session = await store.createSession();
        await store.addExercise(
          sessionId: session.id,
          exerciseId: 'hammer-curl',
          loadType: LoadType.weighted,
        );
        session = (await store.readOpenSession())!;
      });

      await pumpHost(tester, session: session);
      await openPicker(tester);
      await act(tester,
          () => tester.tap(find.byKey(ExercisePickerSheet.rowKey('hammer-curl'))));

      expect(find.byType(ExerciseDetailScreen), findsOneWidget);
    });
  });

  group('an exercise already in the workout', () {
    testWidgets('opens rather than being added twice', (tester) async {
      final saved = await savedWith(tester, 'barbell-curl');
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

      await pumpHost(tester, session: session, saved: saved);
      await openPicker(tester);
      await act(tester,
          () => tester.tap(find.byKey(ExercisePickerSheet.rowKey('barbell-curl'))));

      final open = await tester.runAsync(() => store.readOpenSession());
      expect(
        open!.exercises,
        hasLength(1),
        reason: 'a second row would split its sets across two prefill chains',
      );
      expect(find.byType(SetLoggingScreen), findsOneWidget);
    });

    testWidgets('one with sets already written never goes back through its page',
        (tester) async {
      late WorkoutSession session;
      await tester.runAsync(() async {
        session = await store.createSession();
        final row = await store.addExercise(
          sessionId: session.id,
          exerciseId: 'hammer-curl',
          loadType: LoadType.weighted,
        );
        await store.writeSet(
            sessionExerciseId: row, position: 0, weightKg: 12, reps: 8);
        session = (await store.readOpenSession())!;
      });

      await pumpHost(tester, session: session);
      await openPicker(tester);
      await act(tester,
          () => tester.tap(find.byKey(ExercisePickerSheet.rowKey('hammer-curl'))));

      expect(find.byType(SetLoggingScreen), findsOneWidget,
          reason: 'a user mid-set is not a user who needs the form cues');
    });
  });
}
