import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/diet_plan_store.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/reminder_prefs.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';

/// QA (second pass, upgrade path): a real user's database, as the last
/// published build (5fcae5f, schema 5) wrote it, opened by this build.
///
/// `test/fixtures/schema_v5_from_5fcae5f.sqlite` was written by that commit's
/// own stores (a throwaway worktree at 5fcae5f): three saved workouts across
/// all four load types, one workout still open, two custom templates (one
/// with an emoji in its name), a training plan, two weigh-ins and a body
/// diagram choice. The same file was pushed into a simulator under the old
/// app and the new app installed over it; this test keeps that proof.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;
  late AppDatabase db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('turtle_v5_');
    final copy = File('${dir.path}/turtle_lift.sqlite');
    await File('test/fixtures/schema_v5_from_5fcae5f.sqlite').copy(copy.path);
    db = AppDatabase.forTesting(NativeDatabase(copy));
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('reaches schema 7', () async {
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.single, 7);
  });

  test('every saved workout survives with its numbers in the right columns',
      () async {
    final saved = await SessionStore(db).readSavedSessions();
    expect(saved.map((s) => s.performedOn), <LocalDate>[
      LocalDate(2026, 10, 12),
      LocalDate(2026, 10, 7),
      LocalDate(2026, 10, 5),
    ]);
    expect(saved.last.title, 'Push day');

    final mixed = saved[1];
    final assisted = mixed.exercises.first;
    expect(assisted.loadType, LoadType.assisted);
    expect(assisted.completedSets.map((s) => s.assistKg), <double>[30, 25]);
    final plank = mixed.exercises.last;
    expect(plank.loadType, LoadType.timed);
    expect(plank.completedSets.map((s) => s.durationSec), <int>[60, 45]);
    expect(plank.completedSets.last.weightKg, 10);

    final push = saved.last.exercises[1];
    expect(push.loadType, LoadType.bodyweight);
    expect(push.completedSets.last.addedKg, 10);
    expect(saved.last.exercises.first.completedSets.last.weightKg, 62.5);
  });

  test('the workout open at upgrade time is still open', () async {
    final open = await SessionStore(db).readOpenSession();
    expect(open, isNotNull);
    expect(open!.performedOn, LocalDate(2026, 10, 20));
    expect(open.exercises.single.exerciseId, 'barbell-back-squat');
    expect(open.exercises.single.sets, hasLength(2));
  });

  test('templates, plan, weigh-ins and diagram choice survive', () async {
    final templates = await CustomTemplateStore(db).readCustomTemplates();
    expect(templates.map((t) => t.name),
        containsAll(<String>['Arms \u{1F4AA} and core', 'Push day (mine)']));
    expect(
        templates.firstWhere((t) => t.id == 'tpl-mine').exerciseIds,
        'barbell-curl,plank,assisted-triceps-dip-machine');

    final plan = await TrainingPlanStore(db).readEntries();
    expect(plan.single.weekdayMask, 0x15);

    final people = PersonalDetailsStore(db);
    expect((await people.readBodyweightEntries()).map((e) => e.weightKg),
        <double>[64.5, 63]);
    expect(await people.readBodyGender(), 'female');
  });

  test('Diet and reminders start empty and work', () async {
    final settings = SettingsStore(db);
    expect(await settings.readProteinTarget(), isNull);
    await settings.writeProteinTarget(110);
    expect(await settings.readProteinTarget(), 110);
    expect(await PersonalDetailsStore(db).readBodyGender(), 'female',
        reason: 'the target shares the settings row and must not blank it');

    final plan = DietPlanStore(db);
    await plan.addFood(
        weekdays: <int>{1, 3}, slot: MealSlot.lunch, foodId: 'paneer',
        halves: 2);
    expect(await plan.readVersions(), hasLength(1));

    await ReminderPrefsStore(db).read();
  });
}
