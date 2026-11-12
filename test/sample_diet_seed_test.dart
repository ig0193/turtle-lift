import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/diet_plan_store.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/meal_ticks.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/sample_history_seed.dart';
import 'package:turtle_lift/src/data/settings_store.dart';

/// The debug-only sample diet (U18): a target, a week filled through the
/// stores with Repeat on, and one tick today, written only into a database
/// with no diet in it. `main()` calls it behind `kDebugMode`, and never on
/// the reboot after Delete all data (`test/boot_test.dart` holds that).
///
/// November 2026: Wednesday the 4th sits in the week of Monday the 2nd.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final today = LocalDate(2026, 11, 4);
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> seed() => seedSampleDietIfEmpty(database, today: () => today);

  test('an empty database gets a target, a full week and one tick today',
      () async {
    await seed();

    expect(await SettingsStore(database).readProteinTarget(), isNotNull);

    final versions = await DietPlanStore(database).readVersions();
    expect(versions.single.effectiveFrom, LocalDate(2026, 11, 2),
        reason: "written through the store, into this week's version");
    final items = versions.single.items;
    for (var weekday = 0; weekday < 7; weekday++) {
      expect(items.where((i) => i.weekday == weekday), isNotEmpty,
          reason: 'every day of the week has food planned');
    }

    final ticks = await MealTickStore(database, today: () => today).read();
    expect(ticks, hasLength(1));
    expect(ticks.single.date, today);
    expect(
      items.any((i) =>
          i.weekday == today.weekday - 1 && i.slot == ticks.single.slot),
      isTrue,
      reason: 'the tick sits on a slot that has food in it',
    );
  });

  test('every seeded food id is in the shipped food list', () async {
    await seed();
    final foods = await loadFoodIndex(readShippedFoodList);
    final items = (await DietPlanStore(database).readVersions()).single.items;
    for (final item in items) {
      expect(foods.byId(item.foodId), isNotNull, reason: item.foodId);
    }
  });

  test('leaves some slot empty, so the empty-slot state shows too', () async {
    await seed();
    final items = (await DietPlanStore(database).readVersions()).single.items;
    final filled = {for (final i in items) (i.weekday, i.slot)};
    expect(filled.length, lessThan(7 * MealSlot.values.length));
  });

  test('records a bodyweight before today when there is none, so the target '
      'screen shows its suggestion', () async {
    await seed();
    final entries =
        await PersonalDetailsStore(database).readBodyweightEntries();
    expect(entries, hasLength(1));
    expect(LocalDate.parse(entries.single.date).compareTo(today),
        lessThan(0));
  });

  test('keeps a bodyweight the user already has', () async {
    await PersonalDetailsStore(database).appendBodyweightEntry('2026-10-01', 80);
    await seed();
    final entries =
        await PersonalDetailsStore(database).readBodyweightEntries();
    expect(entries.single.weightKg, 80);
  });

  test('a second run writes nothing more', () async {
    await seed();
    final before = (await DietPlanStore(database).readVersions()).single.items;
    await seed();
    final after = (await DietPlanStore(database).readVersions()).single.items;
    expect(after, before);
    expect(await MealTickStore(database, today: () => today).read(),
        hasLength(1));
  });

  test('a database with only a target is left alone', () async {
    await SettingsStore(database).writeProteinTarget(150);
    await seed();
    expect(await DietPlanStore(database).readVersions(), isEmpty);
    expect(await SettingsStore(database).readProteinTarget(), 150);
  });

  test('a database with only a plan is left alone', () async {
    await DietPlanStore(database, today: () => today).addFood(
      weekdays: <int>{0},
      slot: MealSlot.lunch,
      foodId: 'rajma',
      halves: 2,
    );
    await seed();
    expect(await SettingsStore(database).readProteinTarget(), isNull);
    expect(
        (await DietPlanStore(database).readVersions()).single.items, hasLength(1));
  });
}
