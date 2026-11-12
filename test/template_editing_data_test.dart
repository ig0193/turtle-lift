import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';

/// Editing a custom template's exercises (built from scratch, renamed,
/// reordered) and reordering a live workout's list — the two data writes the
/// workout-gaps pass adds. Both survive a restart; neither touches anything
/// else.
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
      initialCustomTemplatesProvider.overrideWithValue(
        await readStoredCustomTemplates(CustomTemplateStore(db)),
      ),
      initialActiveSessionProvider.overrideWithValue(
        await readOpenSession(SessionStore(db)),
      ),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  group('a template built from scratch', () {
    test('update renames and replaces the list, in order, across a restart',
        () async {
      var container = await boot();
      final list = container.read(customTemplateListProvider.notifier);
      final made = await list.add(
        name: 'Monday',
        exerciseIds: <String>['barbell-bench-press', 'push-up'],
      );

      await list.update(
        made.id,
        name: 'Monday upper',
        exerciseIds: <String>['push-up', 'barbell-bench-press', 'plank'],
      );
      expect(container.read(customTemplatesProvider).single.exerciseIds,
          <String>['push-up', 'barbell-bench-press', 'plank']);

      container = await boot();
      final read = container.read(customTemplatesProvider).single;
      expect(read.id, made.id);
      expect(read.name, 'Monday upper');
      expect(read.exerciseIds,
          <String>['push-up', 'barbell-bench-press', 'plank']);
    });

    test('an empty template can be saved and started', () async {
      final container = await boot();
      final made = await container
          .read(customTemplateListProvider.notifier)
          .add(name: 'Blank', exerciseIds: const <String>[]);
      expect(made.exerciseIds, isEmpty);
      await container.read(activeSessionProvider.notifier).startFromTemplate(
            templateId: made.id,
            templateName: made.name,
            exerciseIds: made.exerciseIds,
          );
      expect(container.read(activeSessionProvider)!.exercises, isEmpty);
    });

    test('editing a template never changes a workout started from it',
        () async {
      final container = await boot();
      final list = container.read(customTemplateListProvider.notifier);
      final made = await list.add(
        name: 'Pull',
        exerciseIds: <String>['pull-up', 'barbell-bent-over-row'],
      );
      await container.read(activeSessionProvider.notifier).startFromTemplate(
            templateId: made.id,
            templateName: made.name,
            exerciseIds: made.exerciseIds,
          );
      await list.update(made.id,
          name: 'Pull 2', exerciseIds: <String>['plank']);
      expect(
        container
            .read(activeSessionProvider)!
            .exercises
            .map((e) => e.exerciseId),
        <String>['pull-up', 'barbell-bent-over-row'],
      );
    });
  });

  group('reordering a live workout', () {
    Future<ProviderContainer> withThree() async {
      final container = await boot();
      await container.read(activeSessionProvider.notifier).startFromTemplate(
        templateId: 'push',
        templateName: 'Push day',
        exerciseIds: <String>['barbell-bench-press', 'push-up', 'plank'],
      );
      return container;
    }

    List<String> order(ProviderContainer c) => c
        .read(activeSessionProvider)!
        .exercises
        .map((e) => e.exerciseId)
        .toList();

    test('moves a row down and up, and the order survives a restart',
        () async {
      var container = await withThree();
      final session = container.read(activeSessionProvider.notifier);

      await session.moveExercise(0, 2);
      expect(order(container), <String>['push-up', 'plank', 'barbell-bench-press']);
      await session.moveExercise(2, 0);
      expect(order(container), <String>['barbell-bench-press', 'push-up', 'plank']);
      await session.moveExercise(1, 2);

      container = await boot();
      expect(order(container), <String>['barbell-bench-press', 'plank', 'push-up']);
    });

    test('a move out of range is ignored, and sets travel with their row',
        () async {
      final container = await withThree();
      final session = container.read(activeSessionProvider.notifier);
      final bench = container.read(activeSessionProvider)!.exercises.first;
      await session.writeSet(
        sessionExerciseId: bench.id,
        position: 0,
        completed: true,
        weightKg: 60,
        reps: 5,
      );

      await session.moveExercise(5, 0);
      expect(order(container).first, 'barbell-bench-press');

      await session.moveExercise(0, 1);
      final moved = container
          .read(activeSessionProvider)!
          .exercises
          .firstWhere((e) => e.exerciseId == 'barbell-bench-press');
      expect(moved.sets.single.weightKg, 60);
      expect(order(container)[1], 'barbell-bench-press');
    });

    // Regression (workout-gaps audit): `addExercise` used the row count as the
    // new position, so after a removal the new row shared a position with an
    // existing one and the list order was undefined.
    test('an exercise added after a removal goes to the end', () async {
      final container = await withThree();
      final session = container.read(activeSessionProvider.notifier);
      await session.removeExercise(
          container.read(activeSessionProvider)!.exercises.first.id);
      await session.addExercise(
          exerciseId: 'barbell-back-squat', loadType: LoadType.weighted);
      final positions = container
          .read(activeSessionProvider)!
          .exercises
          .map((e) => e.position)
          .toList();
      expect(positions.toSet(), hasLength(positions.length),
          reason: 'no two rows may share a position');
      expect(order(container).last, 'barbell-back-squat');
    });

    test('an exercise added after a reorder goes to the end', () async {
      final container = await withThree();
      final session = container.read(activeSessionProvider.notifier);
      await session.moveExercise(2, 0);
      await session.addExercise(
          exerciseId: 'barbell-back-squat', loadType: LoadType.weighted);
      expect(order(container).last, 'barbell-back-squat');
      expect(order(container).toSet(), hasLength(4));
    });
  });
}

