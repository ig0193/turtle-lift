import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/diet_log_store.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/sample_history_seed.dart';
import 'package:turtle_lift/src/data/settings_store.dart';

/// The debug-only sample diet: a target and a log of this week, Monday up to
/// today, written through the store and only into a database with no diet in
/// it. `main()` calls it behind `kDebugMode`, and never on the reboot after
/// Delete all data (`test/boot_test.dart` holds that).
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
  Future<List<DietLogEntry>> log() => DietLogStore(database).readEntries();

  test('an empty database gets a target of 120 and Monday to today logged',
      () async {
    await seed();

    expect(await SettingsStore(database).readProteinTarget(), 120);

    final entries = await log();
    final dates = {for (final e in entries) e.date};
    expect(dates, <LocalDate>{
      LocalDate(2026, 11, 2),
      LocalDate(2026, 11, 3),
      LocalDate(2026, 11, 4),
    }, reason: 'every day from this Monday to today, and nothing after');
  });

  test('nothing is logged after today', () async {
    await seed();
    expect((await log()).where((e) => e.date > today), isEmpty);
  });

  test('every logged day has breakfast, lunch and a snack', () async {
    await seed();
    final entries = await log();
    for (final date in {for (final e in entries) e.date}) {
      final slots = {
        for (final e in entries)
          if (e.date == date) e.slot,
      };
      expect(
          slots,
          containsAll(<MealSlot>[
            MealSlot.breakfast,
            MealSlot.lunch,
            MealSlot.snack,
          ]),
          reason: '$date');
    }
  });

  test("today's dinner is left empty, earlier days have one", () async {
    await seed();
    final entries = await log();
    expect(entries.where((e) => e.date == today && e.slot == MealSlot.dinner),
        isEmpty);
    expect(
        entries.where(
            (e) => e.date == LocalDate(2026, 11, 3) && e.slot == MealSlot.dinner),
        isNotEmpty);
  });

  test('every seeded food id is in the shipped food list', () async {
    await seed();
    final foods = await loadFoodIndex(readShippedFoodList);
    for (final entry in await log()) {
      expect(foods.byId(entry.foodId), isNotNull, reason: entry.foodId);
    }
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
    final before = await log();
    await seed();
    expect(await log(), before);
  });

  test('a database with only a target is left alone', () async {
    await SettingsStore(database).writeProteinTarget(150);
    await seed();
    expect(await log(), isEmpty);
    expect(await SettingsStore(database).readProteinTarget(), 150);
  });

  test('a database with only a logged food is left alone', () async {
    await DietLogStore(database, today: () => today).addFood(
      date: today,
      slot: MealSlot.lunch,
      foodId: 'rajma',
      halves: 2,
    );
    await seed();
    expect(await SettingsStore(database).readProteinTarget(), isNull);
    expect(await log(), hasLength(1));
  });

  test('on a Monday only Monday is logged', () async {
    await seedSampleDietIfEmpty(database, today: () => LocalDate(2026, 11, 9));
    expect({for (final e in await log()) e.date}, <LocalDate>{
      LocalDate(2026, 11, 9),
    });
  });
}
