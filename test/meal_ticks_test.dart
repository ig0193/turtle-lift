import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/meal_ticks.dart';

/// The optional "eaten" tick (plan KTD8): presence means eaten, an untick is a
/// hard delete, and only this week up to today can be ticked.
///
/// November 2026: Monday is the 9th, so Sunday the 8th is last week.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LocalDate nov(int day) => LocalDate(2026, 11, day);

  late AppDatabase database;
  late LocalDate today;
  late MealTickStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    today = nov(11); // Wednesday
    store = MealTickStore(database, today: () => today);
  });

  tearDown(() => database.close());

  Future<int> rowCount() async =>
      (await database.select(database.mealTicks).get()).length;

  test('a fresh database has no ticks', () async {
    expect(await store.read(), isEmpty);
  });

  test('toggling today inserts a tick and reports it on', () async {
    expect(await store.toggle(nov(11), MealSlot.lunch), isTrue);
    expect(await store.read(),
        <MealTick>[MealTick(date: nov(11), slot: MealSlot.lunch)]);
  });

  test('toggling again deletes the row', () async {
    await store.toggle(nov(11), MealSlot.lunch);
    expect(await store.toggle(nov(11), MealSlot.lunch), isFalse);
    expect(await store.read(), isEmpty);
    expect(await rowCount(), 0, reason: 'untick is a hard delete');
  });

  test('this week\'s Monday can be ticked', () async {
    expect(await store.toggle(nov(9), MealSlot.breakfast), isTrue);
  });

  test('tomorrow throws and writes nothing', () async {
    await expectLater(
        store.toggle(nov(12), MealSlot.dinner), throwsArgumentError);
    expect(await rowCount(), 0);
  });

  test('last week\'s Sunday throws and writes nothing', () async {
    await expectLater(
        store.toggle(nov(8), MealSlot.dinner), throwsArgumentError);
    expect(await rowCount(), 0);
  });

  test('the window follows the store clock at write time', () async {
    today = nov(8); // Sunday
    expect(await store.toggle(nov(8), MealSlot.snack), isTrue);

    today = nov(9); // Monday: Sunday is now last week
    await expectLater(
        store.toggle(nov(8), MealSlot.snack), throwsArgumentError);
    expect(await store.read(),
        <MealTick>[MealTick(date: nov(8), slot: MealSlot.snack)],
        reason: 'a past tick stays; it just cannot be changed');
  });

  test('read narrows to a date range, inclusive, oldest first', () async {
    await store.toggle(nov(11), MealSlot.dinner);
    await store.toggle(nov(9), MealSlot.lunch);
    await store.toggle(nov(10), MealSlot.breakfast);
    await store.toggle(nov(11), MealSlot.breakfast);

    expect(
      await store.read(from: nov(10), to: nov(11)),
      <MealTick>[
        MealTick(date: nov(10), slot: MealSlot.breakfast),
        MealTick(date: nov(11), slot: MealSlot.breakfast),
        MealTick(date: nov(11), slot: MealSlot.dinner),
      ],
    );
    expect(await store.read(), hasLength(4));
  });
}
