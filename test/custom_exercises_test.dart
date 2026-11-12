import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/custom_exercises.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/data_export.dart';
import 'package:turtle_lift/src/data/data_reset.dart';
import 'package:turtle_lift/src/data/derived.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/personal_best.dart';
import 'support/fake_reminder_scheduler.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';

/// The user's own exercises (ADR 0009): they persist, they never collide with
/// a library id, they reach every lookup through the one index, a logged one
/// keeps its history (cannot be deleted, load type fixed), and export and
/// Delete all data cover them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late ExerciseIndex library;
  late AppDatabase db;

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    library = ExerciseIndex.fromJson(
      await container.read(exerciseLibraryProvider.future),
    );
  });

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ProviderContainer> boot() async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      libraryIndexProvider.overrideWithValue(library),
      initialCustomExercisesProvider.overrideWithValue(
        await readStoredCustomExercises(CustomExerciseStore(db)),
      ),
      initialCustomTemplatesProvider.overrideWithValue(
        await readStoredCustomTemplates(CustomTemplateStore(db)),
      ),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  const draft = CustomExerciseDraft(
    name: '  Gym hack squat  ',
    equipment: 'machine',
    loadType: LoadType.weighted,
    primary: <String>['quads/quads'],
    secondary: <String>['glutes/glutes', 'quads/quads'],
  );

  test('no shipped exercise id carries the custom prefix', () {
    expect(
      library.all.where((e) => isCustomExerciseId(e.id)),
      isEmpty,
      reason: 'a custom id must never collide with a library id',
    );
  });

  test('add mints a custom- id, trims the name and survives a restart',
      () async {
    var container = await boot();
    final made =
        await container.read(customExerciseListProvider.notifier).add(draft);

    expect(made.id, startsWith(kCustomExerciseIdPrefix));
    expect(made.name, 'Gym hack squat');
    expect(made.isCustom, isTrue);
    expect(made.secondary, <String>['glutes/glutes'],
        reason: 'a muscle is primary or secondary, never both');
    expect(made.setup, isEmpty);
    expect(made.execution, isEmpty,
        reason: 'the app never writes instructions for a custom exercise');

    container = await boot();
    final read = container.read(customExerciseListProvider).single;
    expect(read.id, made.id);
    expect(read.primary, <String>['quads/quads']);
    expect(read.loadType, 'weighted');
  });

  test('the one index finds library and custom exercises alike', () async {
    final container = await boot();
    final made =
        await container.read(customExerciseListProvider.notifier).add(draft);
    final index = container.read(exerciseIndexProvider);

    expect(index.byId(made.id)?.name, 'Gym hack squat');
    expect(index.byId('barbell-bench-press'), isNotNull);
    expect(index.all.length, library.all.length + 1);
    expect(index.withPrimary('quads/quads'), contains(made));
    expect(index.searchByName('hack squat'), contains(made));
  });

  test('a draft with no name or no main muscle is refused', () {
    expect(
      const CustomExerciseDraft(
        name: ' ',
        equipment: 'machine',
        loadType: LoadType.weighted,
        primary: <String>['quads/quads'],
      ).problem,
      isNotNull,
    );
    expect(
      const CustomExerciseDraft(
        name: 'X',
        equipment: 'machine',
        loadType: LoadType.weighted,
        primary: <String>[],
      ).problem,
      isNotNull,
    );
    expect(
      const CustomExerciseDraft(
        name: 'X',
        equipment: 'machine',
        loadType: LoadType.weighted,
        primary: <String>['chest/everything'],
      ).problem,
      isNotNull,
    );
    expect(draft.problem, isNull);
  });

  test('the database refuses an id without the custom prefix', () async {
    await expectLater(
      db.into(db.customExercises).insert(CustomExercisesCompanion.insert(
            id: 'barbell-bench-press',
            name: 'Clash',
            equipment: 'barbell',
            loadType: 'weighted',
            primaryIds: 'chest/mid',
          )),
      throwsA(isA<Exception>()),
    );
  });

  test('can be logged, and history, records and the title resolve it',
      () async {
    final container = await boot();
    final made =
        await container.read(customExerciseListProvider.notifier).add(draft);
    final session = container.read(activeSessionProvider.notifier);

    // Two workouts, the second heavier: a PB on the second.
    for (final kg in <double>[60, 70]) {
      await session.startAdHoc();
      final rowId = await session.addExercise(
          exerciseId: made.id, loadType: LoadType.weighted);
      await session.writeSet(
        sessionExerciseId: rowId!,
        position: 0,
        completed: true,
        weightKg: kg,
        reps: 8,
      );
      if (kg == 60) {
        // Records advance at a date boundary, so the first is yesterday.
        await session.setPerformedOn(LocalDate.today().addDays(-1));
      }
      await session.finish();
    }

    final saved = container.read(savedSessionsProvider);
    final index = container.read(exerciseIndexProvider);
    expect(saved, hasLength(2));
    expect(resolvedTitle(saved.first, index), 'Gym hack squat');
    expect(timesPerformed(made.id, saved), 2);
    expect(pbCountFor(saved.first, saved), 1);
  });

  test('a logged exercise cannot be deleted and keeps its load type',
      () async {
    final container = await boot();
    final list = container.read(customExerciseListProvider.notifier);
    final made = await list.add(draft);
    final session = container.read(activeSessionProvider.notifier);
    await session.startAdHoc();
    await session.addExercise(exerciseId: made.id, loadType: LoadType.weighted);

    expect(await list.delete(made.id), isFalse);
    expect(container.read(customExerciseListProvider), hasLength(1));

    final edited = await list.edit(
      made.id,
      const CustomExerciseDraft(
        name: 'Hack squat (gym)',
        equipment: 'machine',
        loadType: LoadType.timed,
        primary: <String>['quads/quads'],
      ),
    );
    expect(edited!.name, 'Hack squat (gym)');
    expect(edited.loadType, 'weighted',
        reason: 'a logged exercise keeps the load type its sets were read in');
  });

  test('an unlogged exercise edits freely, and deleting it leaves templates',
      () async {
    final container = await boot();
    final list = container.read(customExerciseListProvider.notifier);
    final made = await list.add(draft);
    final edited = await list.edit(
      made.id,
      const CustomExerciseDraft(
        name: 'Plank on rings',
        equipment: 'other',
        loadType: LoadType.timed,
        primary: <String>['abs/upper'],
      ),
    );
    expect(edited!.loadType, 'timed');

    final template =
        await container.read(customTemplateListProvider.notifier).add(
      name: 'Core',
      exerciseIds: <String>['plank', made.id],
    );
    expect(await list.delete(made.id), isTrue);
    expect(container.read(customExerciseListProvider), isEmpty);
    expect(
      container.read(customTemplatesProvider).single.exerciseIds,
      <String>['plank'],
    );
    final stored = await CustomTemplateStore(db).readCustomTemplates();
    expect(stored.single.id, template.id);
    expect(stored.single.exerciseIds, 'plank',
        reason: 'the template on disk drops it in the same transaction');
  });

  test('export lists what the user typed, and only that', () async {
    final container = await boot();
    final made =
        await container.read(customExerciseListProvider.notifier).add(draft);
    final json = jsonDecode(buildExportJson(
      sessions: const <WorkoutSession>[],
      bodyweight: const [],
      customTemplates: const [],
      trainingPlan: const [],
      gender: BodyGender.male,
      index: container.read(exerciseIndexProvider),
      dietPlan: const [],
      mealTicks: const [],
      proteinTargetG: null,
      foods: FoodIndex(const []),
      exportedAt: DateTime.utc(2026, 11, 9),
      customExercises: container.read(customExerciseListProvider),
    )) as Map<String, Object?>;

    expect(json['exercises'], <Object?>[
      <String, Object?>{
        'id': made.id,
        'name': 'Gym hack squat',
        'equipment': 'machine',
        'loadType': 'weighted',
        'primary': <Object?>['quads/quads'],
        'secondary': <Object?>['glutes/glutes'],
      },
    ]);
  });

  test('Delete all data removes them', () async {
    final container = await boot();
    await container.read(customExerciseListProvider.notifier).add(draft);
    await wipeAllData(db, reminders: FakeReminderScheduler());
    expect(await CustomExerciseStore(db).readAll(), isEmpty);
  });
}
