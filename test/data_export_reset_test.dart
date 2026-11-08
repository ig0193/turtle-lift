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
import 'package:turtle_lift/src/data/diet_plan_store.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/meal_ticks.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/reminder_prefs.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
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
        trainingPlan: <TrainingPlanEntry>[
          TrainingPlanEntry(
            effectiveFrom: LocalDate(2026, 11, 2),
            weekdays: <int>{5, 1, 3},
          ),
        ],
        gender: BodyGender.female,
        index: index,
        dietPlan: const <DietPlanVersion>[],
        mealTicks: const <MealTick>[],
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
        dietPlan: const <DietPlanVersion>[],
        mealTicks: const <MealTick>[],
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
        required List<DietPlanVersion> plan,
        required List<MealTick> ticks,
        required int? target,
      }) async {
        final json = jsonDecode(buildExportJson(
          sessions: const <WorkoutSession>[],
          bodyweight: const <BodyweightEntry>[],
          customTemplates: const <WorkoutTemplate>[],
          trainingPlan: const <TrainingPlanEntry>[],
          gender: BodyGender.male,
          index: index,
          dietPlan: plan,
          mealTicks: ticks,
          proteinTargetG: target,
          foods: foods,
          exportedAt: DateTime.utc(2026, 11, 8),
        )) as Map<String, Object?>;
        return json['diet']! as Map<String, Object?>;
      }

      /// A target, two plan versions and a tick, written through the stores.
      Future<Map<String, Object?>> exportSeeded() async {
        await DietPlanStore(database, today: () => nov(4)).addFood(
          weekdays: <int>{0, 2},
          slot: MealSlot.lunch,
          foodId: 'fixture-paneer',
          halves: 3,
        );
        final week2 = DietPlanStore(database, today: () => nov(10));
        await week2.addFood(
          weekdays: <int>{1},
          slot: MealSlot.dinner,
          foodId: 'retired-food',
          halves: 2,
        );
        await MealTickStore(database, today: () => nov(4))
            .toggle(nov(2), MealSlot.lunch);
        await SettingsStore(database).writeProteinTarget(120);

        return exportDiet(
          plan: await week2.readVersions(),
          ticks: await MealTickStore(database).read(),
          target: await SettingsStore(database).readProteinTarget(),
        );
      }

      test('carries the target, every plan version and the ticks, with food '
          'names beside ids', () async {
        final diet = await exportSeeded();

        expect(diet['proteinTargetG'], 120);
        final versions = diet['planVersions']! as List<Object?>;
        expect(versions, hasLength(2));
        expect(versions.first, <String, Object?>{
          'effectiveFrom': '2026-11-02',
          'items': <Object?>[
            <String, Object?>{
              'weekday': 0,
              'slot': 'lunch',
              'foodId': 'fixture-paneer',
              'name': 'Fixture paneer',
              'servings': 1.5,
            },
            <String, Object?>{
              'weekday': 2,
              'slot': 'lunch',
              'foodId': 'fixture-paneer',
              'name': 'Fixture paneer',
              'servings': 1.5,
            },
          ],
        });
        final second = versions.last! as Map<String, Object?>;
        expect(second['effectiveFrom'], '2026-11-09');
        expect(second['items'], hasLength(3),
            reason: 'the copied week plus the new dinner');
        expect(
          (second['items']! as List).cast<Map<String, Object?>>().firstWhere(
              (i) => i['foodId'] == 'retired-food'),
          <String, Object?>{
            'weekday': 1,
            'slot': 'dinner',
            'foodId': 'retired-food',
            'name': null,
            'servings': 1.0,
          },
          reason: 'an id the food list no longer knows keeps its id, and its '
              'name is null like an unknown exercise name',
        );
        expect(diet['eaten'], <Object?>[
          <String, Object?>{'date': '2026-11-02', 'slot': 'lunch'},
        ]);
      });

      test('stores nothing derived: no planned, eaten total, to go, total or '
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
              ]) {
                expect(key, isNot(contains(banned)), reason: '$path.$key');
              }
              if (key == 'eaten') {
                expect(entry.value, isA<List<Object?>>(),
                    reason: 'eaten is the list of ticks, never a number');
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
        expect(diet.keys.toSet(),
            <String>{'proteinTargetG', 'planVersions', 'eaten'});
      });

      test('with no diet data, diet is a null target and empty lists',
          () async {
        expect(
          await exportDiet(
              plan: const <DietPlanVersion>[],
              ticks: const <MealTick>[],
              target: null),
          <String, Object?>{
            'proteinTargetG': null,
            'planVersions': <Object?>[],
            'eaten': <Object?>[],
          },
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
      await TrainingPlanStore(database).replaceFromWeek('2026-11-02', 0x15);
      await DietPlanStore(database).addFood(
        weekdays: <int>{0, 3},
        slot: MealSlot.breakfast,
        foodId: 'any-food',
        halves: 2,
      );
      await MealTickStore(database).toggle(LocalDate.today(), MealSlot.dinner);
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
