import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/routine_store.dart';
import 'package:turtle_lift/src/data/routines.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/exercise_picker_screen.dart';
import 'package:turtle_lift/src/ui/routine_builder_screen.dart';

/// The only place a routine is authored (`adr/0004`).
///
/// **It writes as you go, and that is what these tests pin.** A builder that
/// held the routine in memory until Save would lose fifteen minutes of work to
/// a phone call, so every add and every target reaches disk as it happens —
/// which is checked here by reading the store back, not by reading the widget
/// tree.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late RoutineStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = RoutineStore(database);
  });
  tearDown(() => database.close());

  Exercise entry(String id, String name, String loadType) => Exercise(
        id: id,
        name: name,
        equipment: 'Barbell',
        loadType: loadType,
        primary: const <String>['chest/mid'],
        secondary: const <String>[],
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
      );

  final index = ExerciseIndex(<Exercise>[
    entry('bench', 'Barbell bench press', 'weighted'),
    entry('plank', 'Plank', 'timed'),
  ]);

  Future<void> pumpBuilder(WidgetTester tester, {String? routineId}) async {
    late List<Routine> seeded;
    late List<RoutineFolder> folders;
    await tester.runAsync(() async {
      seeded = await store.readRoutines();
      folders = await store.readFolders();
    });

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialRoutinesProvider.overrideWithValue(seeded),
          initialRoutineFoldersProvider.overrideWithValue(folders),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: RoutineBuilderScreen(routineId: routineId),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
  }

  /// Walks the picker: opens it, ticks [ids], confirms.
  Future<void> addExercises(WidgetTester tester, List<String> ids) async {
    await tester.tap(find.byKey(RoutineBuilderScreen.addExerciseKey));
    await tester.pumpAndSettle();
    for (final id in ids) {
      await tester.tap(find.byKey(ExercisePickerScreen.rowKey(id)));
      await tester.pump();
    }
    await act(tester, () async {
      await tester.tap(find.byKey(ExercisePickerScreen.addKey));
    });
    await tester.pumpAndSettle();
  }

  group('a new routine', () {
    testWidgets('opens empty, and says what to do', (tester) async {
      await pumpBuilder(tester);

      expect(find.text('Create routine'), findsOneWidget);
      expect(
        find.textContaining('adding an exercise to your routine'),
        findsOneWidget,
      );
    });

    testWidgets('is not created just by opening the builder', (tester) async {
      await pumpBuilder(tester);
      await tester.pump();

      // Same rule the ad-hoc session path follows: backing straight out must
      // not leave an empty routine sitting on the landing.
      final routines = await tester.runAsync(store.readRoutines);
      expect(routines, isEmpty);
    });

    testWidgets('is created by the first exercise added, with one planned set',
        (tester) async {
      await pumpBuilder(tester);
      await addExercises(tester, <String>['bench']);

      final routines = await tester.runAsync(store.readRoutines);
      expect(routines, hasLength(1));
      expect(routines!.single.exercises.map((e) => e.exerciseId),
          <String>['bench']);
      // An exercise with no sets is a plan that says nothing.
      expect(routines.single.exercises.single.sets, hasLength(1));
    });

    testWidgets('takes the typed title on Save', (tester) async {
      await pumpBuilder(tester);
      await addExercises(tester, <String>['bench']);

      await tester.enterText(
          find.byKey(RoutineBuilderScreen.titleKey), 'Push day');
      await act(tester, () async {
        await tester.tap(find.byKey(RoutineBuilderScreen.saveKey));
      });

      final routines = await tester.runAsync(store.readRoutines);
      expect(routines!.single.name, 'Push day');
    });

    testWidgets('an untitled routine still gets a name', (tester) async {
      await pumpBuilder(tester);
      await addExercises(tester, <String>['bench']);

      await act(tester, () async {
        await tester.tap(find.byKey(RoutineBuilderScreen.saveKey));
      });

      // A blank row on the landing is unusable; the fallback is a name, not an
      // empty string.
      final routines = await tester.runAsync(store.readRoutines);
      expect(routines!.single.name, 'New routine');
    });
  });

  group('editing an existing routine', () {
    late String routineId;

    setUp(() async {
      final routine = await store.createRoutine(name: 'Push day');
      routineId = routine.id;
      final rowId =
          await store.addExercise(routineId: routineId, exerciseId: 'bench');
      await store.addSet(routineExerciseId: rowId);
    });

    testWidgets('opens with its title and exercises', (tester) async {
      await pumpBuilder(tester, routineId: routineId);

      expect(find.text('Edit routine'), findsOneWidget);
      expect(find.text('Barbell bench press'), findsOneWidget);
    });

    testWidgets('Add set appends a planned set straight to disk',
        (tester) async {
      await pumpBuilder(tester, routineId: routineId);
      final exerciseRowId = (await tester.runAsync(store.readRoutines))!
          .single
          .exercises
          .single
          .id;

      await act(tester, () async {
        await tester
            .tap(find.byKey(RoutineBuilderScreen.addSetKey(exerciseRowId)));
      });

      final routines = await tester.runAsync(store.readRoutines);
      expect(routines!.single.exercises.single.sets, hasLength(2));
    });

    testWidgets('a target with no numbers stays blank rather than zero',
        (tester) async {
      await pumpBuilder(tester, routineId: routineId);

      final set =
          (await tester.runAsync(store.readRoutines))!.single.exercises.single.sets.single;
      // "Three sets of bench, weight to be decided" is a real plan. Defaulting
      // to 0kg would make the builder assert something the user did not.
      expect(set.targetWeightKg, isNull);
      expect(set.targetReps, isNull);
    });

    testWidgets('typed targets reach the store, in the right columns',
        (tester) async {
      await pumpBuilder(tester, routineId: routineId);
      final setId = (await tester.runAsync(store.readRoutines))!
          .single
          .exercises
          .single
          .sets
          .single
          .id;

      await act(tester, () async {
        await tester.enterText(
            find.byKey(RoutineBuilderScreen.targetFieldKey(setId, 0)), '60');
      });
      await act(tester, () async {
        await tester.enterText(
            find.byKey(RoutineBuilderScreen.targetFieldKey(setId, 1)), '8');
      });

      final set = (await tester.runAsync(store.readRoutines))!
          .single
          .exercises
          .single
          .sets
          .single;
      // Column 0 is the weight and column 1 the reps — keyed rather than
      // positional, so swapping them would fail here instead of silently
      // filing 8kg for 60 reps.
      expect(set.targetWeightKg, 60);
      expect(set.targetReps, 8);
    });

    testWidgets('removing the exercise empties the routine but keeps it',
        (tester) async {
      await pumpBuilder(tester, routineId: routineId);

      await act(tester, () async {
        await tester.tap(find.byIcon(Icons.close).first);
      });

      final routines = await tester.runAsync(store.readRoutines);
      expect(routines, hasLength(1), reason: 'the routine itself survives');
      expect(routines!.single.exercises, isEmpty);
    });
  });

  group('load types', () {
    testWidgets('a timed exercise plans a TIME column, and no reps',
        (tester) async {
      await pumpBuilder(tester);
      await addExercises(tester, <String>['plank']);

      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('REPS'), findsNothing);
      expect(find.text('KG'), findsNothing);
    });

    testWidgets('a weighted exercise plans KG and REPS', (tester) async {
      await pumpBuilder(tester);
      await addExercises(tester, <String>['bench']);

      expect(find.text('KG'), findsOneWidget);
      expect(find.text('REPS'), findsOneWidget);
    });
  });
}
