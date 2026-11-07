import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/data_export.dart';
import 'package:turtle_lift/src/data/data_reset.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';

/// Proves the two Profile data actions do what their screens promise: the
/// export carries everything entered and nothing derived, and the wipe leaves
/// no row behind.
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

  /// One finished workout: bench, one completed set and one not.
  Future<void> logBench() async {
    await store.createSession(templateId: null, templateName: null);
    final open = (await store.readOpenSession())!;
    final exerciseId = await store.addExercise(
      sessionId: open.id,
      exerciseId: 'barbell-bench-press',
      loadType: LoadType.weighted,
    );
    await store.writeSet(
      sessionExerciseId: exerciseId,
      position: 0,
      completed: true,
      weightKg: 77.5,
      reps: 8,
    );
    await store.writeSet(
      sessionExerciseId: exerciseId,
      position: 1,
      weightKg: 80,
      reps: 5,
    );
    await store.saveOpenSession();
  }

  group('export', () {
    test('carries finished workouts with completed sets only, by name and id',
        () async {
      await logBench();
      final sessions = await store.readSavedSessions();

      final json = jsonDecode(buildExportJson(
        sessions: sessions,
        bodyweight: <BodyweightEntry>[
          BodyweightEntry(date: DateTime(2026, 11, 1), weightKg: 81.4),
        ],
        customTemplates: const <WorkoutTemplate>[
          WorkoutTemplate(
            id: 'mine',
            name: 'Mine',
            exerciseIds: <String>['barbell-bench-press'],
            isPredefined: false,
          ),
        ],
        trainingPlan: <TrainingPlanEntry>[
          TrainingPlanEntry(
            effectiveFrom: LocalDate(2026, 11, 2),
            weekdays: <int>{5, 1, 3},
          ),
        ],
        gender: BodyGender.female,
        index: index,
        exportedAt: DateTime.utc(2026, 11, 7, 12),
      )) as Map<String, Object?>;

      expect(json['formatVersion'], kExportFormatVersion);
      expect(json['bodyDiagram'], 'female');
      final workouts = json['workouts']! as List<Object?>;
      expect(workouts, hasLength(1));
      final exercise = ((workouts.single! as Map)['exercises'] as List).single
          as Map<String, Object?>;
      expect(exercise['exerciseId'], 'barbell-bench-press');
      expect(exercise['name'], 'Barbell bench press');
      expect(exercise['sets'], <Object?>[
        <String, Object?>{'weightKg': 77.5, 'reps': 8},
      ]);
      expect(json['bodyweight'], <Object?>[
        <String, Object?>{'date': '2026-11-01', 'weightKg': 81.4},
      ]);
      expect((json['templates']! as List).single,
          <String, Object?>{'name': 'Mine', 'exerciseIds': <Object?>['barbell-bench-press']});
      expect((json['schedule']! as List).single,
          <String, Object?>{'effectiveFrom': '2026-11-02', 'weekdays': <Object?>[1, 3, 5]});
    });

    test('stores nothing derived: no streak, PB, count or calorie field',
        () async {
      await logBench();
      final text = buildExportJson(
        sessions: await store.readSavedSessions(),
        bodyweight: const <BodyweightEntry>[],
        customTemplates: const <WorkoutTemplate>[],
        trainingPlan: const <TrainingPlanEntry>[],
        gender: BodyGender.male,
        index: index,
        exportedAt: DateTime.utc(2026, 11, 7),
      ).toLowerCase();
      for (final word in <String>['streak', 'personalbest', 'pb', 'kcal', 'calorie', 'count']) {
        expect(text, isNot(contains('"$word')), reason: word);
      }
    });

    test('the file name is dated', () {
      expect(exportFileName(DateTime(2026, 3, 9)),
          'turtlelift-export-2026-03-09.json');
    });
  });

  group('delete all data', () {
    test('leaves every user table empty', () async {
      await logBench();
      await PersonalDetailsStore(database)
          .appendBodyweightEntry('2026-11-01', 80);
      await PersonalDetailsStore(database).writeBodyGender('female');
      await CustomTemplateStore(database).insertCustomTemplate(
        id: 'mine',
        name: 'Mine',
        exerciseIds: 'barbell-bench-press',
      );

      await wipeAllData(database);

      for (final table in <String>[
        'set_entries',
        'session_exercises',
        'sessions',
        'custom_templates',
        'training_plan_entries',
        'bodyweight_entries',
        'settings',
      ]) {
        final rows =
            await database.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle();
        expect(rows.read<int>('n'), 0, reason: table);
      }
      expect(await store.readSavedSessions(), isEmpty);
    });
  });
}
