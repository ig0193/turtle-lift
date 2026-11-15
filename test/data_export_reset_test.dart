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
import 'package:turtle_lift/src/data/diet_log_store.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/reminder_prefs.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';

import 'support/fake_reminder_scheduler.dart';

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
        gender: BodyGender.female,
        index: index,
        dietLog: const <DietLogEntry>[],
        proteinTargetG: null,
        foods: FoodIndex.unavailable(),
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
      expect(json.containsKey('schedule'), isFalse,
          reason: 'the Schedule is gone (ADR 0015), so no key for it');
    });

    test('is format 2: the Schedule and the diet plan keys are gone', () {
      expect(kExportFormatVersion, 2);
      final json = jsonDecode(buildExportJson(
        sessions: const <WorkoutSession>[],
        bodyweight: const <BodyweightEntry>[],
        customTemplates: const <WorkoutTemplate>[],
        gender: BodyGender.male,
        index: index,
        dietLog: const <DietLogEntry>[],
        proteinTargetG: null,
        foods: FoodIndex.unavailable(),
        exportedAt: DateTime.utc(2026, 11, 7),
        reminders: ReminderPreferences.defaults
            .copyWith(dietOn: true)
            .withSlot(MealSlot.lunch,
                const SlotReminder(on: true, minute: 12 * 60 + 15)),
      )) as Map<String, Object?>;

      expect(json['formatVersion'], 2);
      expect(json.containsKey('schedule'), isFalse);
      final diet = json['diet']! as Map<String, Object?>;
      expect(diet.containsKey('planVersions'), isFalse);
      expect(diet.containsKey('eaten'), isFalse);
    });

    test('reminders carry only the Diet switches and meal times', () {
      final json = jsonDecode(buildExportJson(
        sessions: const <WorkoutSession>[],
        bodyweight: const <BodyweightEntry>[],
        customTemplates: const <WorkoutTemplate>[],
        gender: BodyGender.male,
        index: index,
        dietLog: const <DietLogEntry>[],
        proteinTargetG: null,
        foods: FoodIndex.unavailable(),
        exportedAt: DateTime.utc(2026, 11, 7),
        reminders: ReminderPreferences.defaults
            .copyWith(dietOn: true)
            .withSlot(MealSlot.lunch,
                const SlotReminder(on: true, minute: 12 * 60 + 15)),
      )) as Map<String, Object?>;

      final reminders = json['reminders']! as Map<String, Object?>;
      expect(reminders.keys.toSet(), <String>{'diet'},
          reason: 'no training reminder');
      final diet = reminders['diet']! as Map<String, Object?>;
      expect(diet.keys.toSet(),
          <String>{'on', 'breakfast', 'lunch', 'snack', 'dinner'},
          reason: 'no morning summary');
      expect(diet['on'], isTrue);
      expect(diet['lunch'], <String, Object?>{'on': true, 'time': '12:15'});
      expect(diet['breakfast'], <String, Object?>{'on': false, 'time': '08:00'});
    });

    test('stores nothing derived: no streak, PB, count or calorie field',
        () async {
      await logBench();
      final text = buildExportJson(
        sessions: await store.readSavedSessions(),
        bodyweight: const <BodyweightEntry>[],
        customTemplates: const <WorkoutTemplate>[],
        gender: BodyGender.male,
        index: index,
        dietLog: const <DietLogEntry>[],
        proteinTargetG: null,
        foods: FoodIndex.unavailable(),
        exportedAt: DateTime.utc(2026, 11, 7),
      ).toLowerCase();
      for (final word in <String>['streak', 'personalbest', 'pb', 'kcal', 'calorie', 'count']) {
        expect(text, isNot(contains('"$word')), reason: word);
      }
    });

    group('diet', () {
      LocalDate nov(int day) => LocalDate(2026, 11, day);

      // Fixture foods: the shipped list is still under review (U19).
      final foods = FoodIndex.fromJson(<Map<String, Object?>>[
        <String, Object?>{
          'id': 'fixture-paneer',
          'name': 'Fixture paneer',
          'aliases': const <String>[],
          'dietType': 'veg',
          'servingLabel': '1 bowl, 100 g',
          'gramsPerServing': 100,
          'proteinPerServingG': 18.3,
          'proteinPer100g': 18.3,
          'ifctCode': 'X001',
          'reviewedBy': 'pending-owner-review',
        },
      ]);

      Future<Map<String, Object?>> exportDiet({
        required List<DietLogEntry> log,
        required int? target,
      }) async {
        final json = jsonDecode(buildExportJson(
          sessions: const <WorkoutSession>[],
          bodyweight: const <BodyweightEntry>[],
          customTemplates: const <WorkoutTemplate>[],
          gender: BodyGender.male,
          index: index,
          dietLog: log,
          proteinTargetG: target,
          foods: foods,
          exportedAt: DateTime.utc(2026, 11, 8),
        )) as Map<String, Object?>;
        return json['diet']! as Map<String, Object?>;
      }

      /// A target and four logged foods over two days, written through the
      /// store.
      Future<Map<String, Object?>> exportSeeded() async {
        final logStore = DietLogStore(database, today: () => nov(10));
        await logStore.addFood(
          date: nov(4),
          slot: MealSlot.lunch,
          foodId: 'fixture-paneer',
          halves: 3,
        );
        await logStore.addFood(
          date: nov(4),
          slot: MealSlot.breakfast,
          foodId: 'fixture-paneer',
          halves: 1,
        );
        await logStore.addFood(
          date: nov(10),
          slot: MealSlot.dinner,
          foodId: 'retired-food',
          halves: 2,
        );
        await SettingsStore(database).writeProteinTarget(120);

        return exportDiet(
          log: await logStore.readEntries(),
          target: await SettingsStore(database).readProteinTarget(),
        );
      }

      test('carries the target and every logged food, with food names beside '
          'ids', () async {
        final diet = await exportSeeded();

        expect(diet['proteinTargetG'], 120);
        final log = (diet['log']! as List<Object?>).cast<Map<String, Object?>>();
        expect(log, hasLength(3));
        expect(log.first, <String, Object?>{
          'date': '2026-11-04',
          'slot': 'breakfast',
          'foodId': 'fixture-paneer',
          'name': 'Fixture paneer',
          'servings': 0.5,
        });
        expect(log[1], <String, Object?>{
          'date': '2026-11-04',
          'slot': 'lunch',
          'foodId': 'fixture-paneer',
          'name': 'Fixture paneer',
          'servings': 1.5,
        });
        expect(
          log.last,
          <String, Object?>{
            'date': '2026-11-10',
            'slot': 'dinner',
            'foodId': 'retired-food',
            'name': null,
            'servings': 1.0,
          },
          reason: 'an id the food list no longer knows keeps its id, and its '
              'name is null like an unknown exercise name',
        );
      });

      test('stores nothing derived: no logged total, to go, total, meter or '
          'suggested key', () async {
        final diet = await exportSeeded();

        void walk(Object? node, String path) {
          if (node is Map) {
            for (final entry in node.entries) {
              final key = (entry.key as String).toLowerCase();
              for (final banned in <String>[
                'planned',
                'togo',
                'total',
                'suggest',
                'meter',
                'eaten',
              ]) {
                expect(key, isNot(contains(banned)), reason: '$path.$key');
              }
              walk(entry.value, '$path.$key');
            }
          } else if (node is List) {
            for (final child in node) {
              walk(child, path);
            }
          }
        }

        walk(diet, 'diet');
        expect(diet.keys.toSet(), <String>{'proteinTargetG', 'log'});
      });

      test('with no diet data, diet is a null target and an empty log',
          () async {
        expect(
          await exportDiet(log: const <DietLogEntry>[], target: null),
          <String, Object?>{'proteinTargetG': null, 'log': <Object?>[]},
        );
      });
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
      await database.into(database.customExercises).insert(
            CustomExercisesCompanion.insert(
              id: 'custom-mine',
              name: 'Mine',
              equipment: 'machine',
              loadType: 'weighted',
              primaryIds: 'quads/quads',
            ),
          );
      await DietLogStore(database).addFood(
        date: LocalDate.today(),
        slot: MealSlot.breakfast,
        foodId: 'any-food',
        halves: 2,
      );
      await SettingsStore(database).writeProteinTarget(150);
      await ReminderPrefsStore(database)
          .write(ReminderPreferences.defaults.copyWith(dietOn: true));

      Future<int> rowsIn(String table) async => (await database
              .customSelect('SELECT COUNT(*) AS n FROM $table')
              .getSingle())
          .read<int>('n');

      // Every table must have had something to delete, or the check below
      // proves nothing for it. A table a later unit adds fails here until
      // this seed (and `wipeAllData`) learns about it.
      for (final table in database.allTables) {
        expect(await rowsIn(table.actualTableName), greaterThan(0),
            reason: '${table.actualTableName} was not seeded');
      }

      await wipeAllData(database, reminders: FakeReminderScheduler());

      // Every table the schema has, not a hand-kept list, so a table added
      // later cannot dodge the wipe.
      for (final table in database.allTables) {
        expect(await rowsIn(table.actualTableName), 0,
            reason: table.actualTableName);
      }
      expect(await store.readSavedSessions(), isEmpty);
      expect(await SettingsStore(database).readProteinTarget(), isNull);
      expect(await ReminderPrefsStore(database).read(),
          ReminderPreferences.defaults,
          reason: 'every reminder is off again after a wipe');
    });

    test('cancels every scheduled notification, after the rows are gone (R25)',
        () async {
      final reminders = _OrderCheckingScheduler(database);
      await reminders.scheduleWeekly(
        id: dietMealReminderId(2, MealSlot.lunch),
        weekday: 2,
        minute: 13 * 60,
        title: 'Lunch',
        body: 'b',
        target: ReminderTarget.dietToday,
      );
      await ReminderPrefsStore(database)
          .write(ReminderPreferences.defaults.copyWith(dietOn: true));

      await wipeAllData(database, reminders: reminders);

      expect(reminders.cancelAllCount, 1);
      expect(reminders.pending, isEmpty);
      expect(reminders.prefsRowsAtCancel, 0,
          reason: 'cancel after the wipe commits, so a failed wipe never '
              'leaves the user with data but no reminders');
    });
  });
}

/// Records how many reminder rows were left when cancel-all ran.
class _OrderCheckingScheduler extends FakeReminderScheduler {
  _OrderCheckingScheduler(this._db);

  final AppDatabase _db;
  int? prefsRowsAtCancel;

  @override
  Future<void> cancelAll() async {
    prefsRowsAtCancel = (await _db.select(_db.reminderPrefs).get()).length;
    await super.cancelAll();
  }
}
