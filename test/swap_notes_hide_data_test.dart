import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/custom_exercises.dart';
import 'package:turtle_lift/src/data/data_export.dart';
import 'package:turtle_lift/src/data/data_reset.dart';
import 'package:turtle_lift/src/data/diet_plan_store.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/exercise_notes.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_ticks.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';

import 'support/fake_reminder_scheduler.dart';

/// Schema step 9's three behaviours at data level
/// (`docs/adr/0011-combined-build-decisions.md`): swap an exercise in place,
/// one note per exercise per session, and hiding a custom exercise from the
/// picker.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late SessionStore store;
  late ExerciseIndex index;

  setUpAll(() async {
    final boot = ProviderContainer();
    addTearDown(boot.dispose);
    index = ExerciseIndex.fromJson(
      await boot.read(exerciseLibraryProvider.future),
    );
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = SessionStore(database);
  });
  tearDown(() => database.close());

  Future<WorkoutSession> openWith(List<String> ids) async {
    await store.createSession(templateId: null, templateName: null);
    final open = (await store.readOpenSession())!;
    for (final id in ids) {
      await store.addExercise(
        sessionId: open.id,
        exerciseId: id,
        loadType: LoadType.fromName(index.byId(id)!.loadType)!,
      );
    }
    return (await store.readOpenSession())!;
  }

  group('swap in place', () {
    test('replaces the exercise at the same position, under its load type',
        () async {
      final open = await openWith(
          <String>['barbell-bench-press', 'push-up', 'barbell-curl']);
      final middle = open.exercises[1];
      await store.writeSet(
          sessionExerciseId: middle.id, position: 0, reps: 5); // not ticked

      final result = await store.swapExercise(
        sessionExerciseId: middle.id,
        exerciseId: 'plank',
        loadType: LoadType.timed,
      );

      expect(result, SwapResult.swapped);
      final after = (await store.readOpenSession())!;
      expect(after.exercises.map((e) => e.exerciseId),
          <String>['barbell-bench-press', 'plank', 'barbell-curl']);
      expect(after.exercises[1].loadType, LoadType.timed,
          reason: 'the load type is snapshotted for the new exercise');
      expect(after.exercises[1].sets, isEmpty,
          reason: 'an untouched half-typed set of the old lift means nothing '
              'for the new one');
    });

    test('is refused when the exercise has a completed set', () async {
      final open = await openWith(<String>['barbell-bench-press']);
      final bench = open.exercises.single;
      await store.writeSet(
        sessionExerciseId: bench.id,
        position: 0,
        completed: true,
        weightKg: 60,
        reps: 8,
      );

      final result = await store.swapExercise(
        sessionExerciseId: bench.id,
        exerciseId: 'push-up',
        loadType: LoadType.bodyweight,
      );

      expect(result, SwapResult.hasCompletedSets);
      final after = (await store.readOpenSession())!;
      expect(after.exercises.single.exerciseId, 'barbell-bench-press');
      expect(after.exercises.single.completedSets, hasLength(1));
    });

    test('is refused when the new exercise is already in the workout',
        () async {
      final open = await openWith(<String>['barbell-bench-press', 'push-up']);

      final result = await store.swapExercise(
        sessionExerciseId: open.exercises.first.id,
        exerciseId: 'push-up',
        loadType: LoadType.bodyweight,
      );

      expect(result, SwapResult.alreadyInWorkout);
      expect((await store.readOpenSession())!.exercises.map((e) => e.exerciseId),
          <String>['barbell-bench-press', 'push-up']);
    });

    test('a template draft swaps by position', () {
      expect(
        swapInList(<String>['a', 'b', 'c'], 1, 'z'),
        <String>['a', 'z', 'c'],
      );
      expect(swapInList(<String>['a', 'b'], 0, 'b'), <String>['a', 'b'],
          reason: 'already in the list: nothing changes');
    });
  });

  group('notes', () {
    test('one note per exercise, trimmed; blank clears it', () async {
      final open = await openWith(<String>['barbell-bench-press']);
      final id = open.exercises.single.id;

      await store.setNote(id, '  Seat 4, grip 81cm  ');
      expect((await store.readOpenSession())!.exercises.single.note,
          'Seat 4, grip 81cm');

      await store.setNote(id, '   ');
      expect((await store.readOpenSession())!.exercises.single.note, isNull);
    });

    test('is capped, so a pasted essay cannot break a row', () {
      expect(normaliseNote('x' * 500)!.length, kExerciseNoteMax);
      expect(normaliseNote(''), isNull);
      expect(normaliseNote(null), isNull);
    });

    test('a swap clears the old exercise note', () async {
      final open = await openWith(<String>['barbell-bench-press']);
      final id = open.exercises.single.id;
      await store.setNote(id, 'Bench 3');
      await store.swapExercise(
          sessionExerciseId: id,
          exerciseId: 'push-up',
          loadType: LoadType.bodyweight);
      expect((await store.readOpenSession())!.exercises.single.note, isNull);
    });

    WorkoutSession saved(String id, LocalDate on, Map<String, String?> notes) =>
        WorkoutSession(
          id: id,
          title: null,
          performedOn: on,
          loggedAt: DateTime(on.year, on.month, on.day, 18),
          templateId: null,
          templateName: null,
          isOpen: false,
          exercises: <SessionExercise>[
            for (final (i, e) in notes.entries.indexed)
              SessionExercise(
                id: '$id-$i',
                exerciseId: e.key,
                position: i,
                loadType: LoadType.weighted,
                markedDone: false,
                sets: const <SetEntry>[],
                note: e.value,
              ),
          ],
        );

    test('the last note is the most recent earlier session that has one', () {
      final history = <WorkoutSession>[
        saved('c', const LocalDate(2026, 11, 6), <String, String?>{'leg-press': null}),
        saved('b', const LocalDate(2026, 11, 4), <String, String?>{'leg-press': 'Seat 5'}),
        saved('a', const LocalDate(2026, 11, 1), <String, String?>{'leg-press': 'Seat 3'}),
      ];
      final today = saved('now', const LocalDate(2026, 11, 9), <String, String?>{'leg-press': null});

      expect(lastNoteFor(history, 'leg-press', current: today), 'Seat 5',
          reason: 'a session with no note does not hide an older one');
      expect(lastNoteFor(history, 'squat', current: today), isNull);
      expect(lastNoteFor(history, 'leg-press', current: history[1]), 'Seat 3',
          reason: 'editing a past session looks only before it');
    });

    test('export carries the note; delete all data wipes it', () async {
      final open = await openWith(<String>['barbell-bench-press']);
      final id = open.exercises.single.id;
      await store.writeSet(
          sessionExerciseId: id,
          position: 0,
          completed: true,
          weightKg: 60,
          reps: 8);
      await store.setNote(id, 'Bench 3');
      await store.saveOpenSession();

      final json = jsonDecode(buildExportJson(
        sessions: await store.readSavedSessions(),
        bodyweight: const <BodyweightEntry>[],
        customTemplates: const <WorkoutTemplate>[],
        trainingPlan: const <TrainingPlanEntry>[],
        gender: BodyGender.male,
        index: index,
        dietPlan: const <DietPlanVersion>[],
        mealTicks: const <MealTick>[],
        proteinTargetG: null,
        foods: FoodIndex.unavailable(),
        exportedAt: DateTime.utc(2026, 11, 9),
      )) as Map<String, Object?>;
      final exercise =
          (((json['workouts']! as List).single! as Map)['exercises'] as List)
              .single as Map;
      expect(exercise['note'], 'Bench 3');

      await wipeAllData(database, reminders: FakeReminderScheduler());
      expect(await database.select(database.sessionExercises).get(), isEmpty);
    });
  });

  group('hide from picker', () {
    test('a hidden custom exercise stays hidden across a restart', () async {
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(database),
      ]);
      addTearDown(container.dispose);
      final list = container.read(customExerciseListProvider.notifier);
      final made = await list.add(const CustomExerciseDraft(
        name: 'Gym hack squat',
        equipment: 'machine',
        loadType: LoadType.weighted,
        primary: <String>['quads/quads'],
      ));

      await list.setHidden(made.id, true);
      expect(container.read(customExerciseListProvider).single.hidden, isTrue);

      final reread = await readStoredCustomExercises(
          container.read(customExerciseStoreProvider));
      expect(reread.single.hidden, isTrue);

      // An edit keeps it hidden.
      await list.edit(
          made.id,
          const CustomExerciseDraft(
            name: 'Hack squat (old gym)',
            equipment: 'machine',
            loadType: LoadType.weighted,
            primary: <String>['quads/quads'],
          ));
      expect(container.read(customExerciseListProvider).single.hidden, isTrue);

      await list.setHidden(made.id, false);
      expect(container.read(customExerciseListProvider).single.hidden, isFalse);
    });
  });
}
