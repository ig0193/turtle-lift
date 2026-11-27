import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/diet_log_store.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';

/// The Diet log store: one row per food per meal slot per day, today and
/// earlier only (`docs/adr/0015-diet-is-a-log.md`).
///
/// November 2026 is used throughout; the 4th is a Wednesday.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LocalDate nov(int day) => LocalDate(2026, 11, day);

  late AppDatabase database;
  late LocalDate today;
  late DietLogStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    today = nov(4);
    store = DietLogStore(database, today: () => today);
  });

  tearDown(() => database.close());

  Future<List<DietLogEntry>> entries() => store.readEntries();

  Future<int> rowCount() async =>
      (await database.select(database.dietLogEntries).get()).length;

  Future<void> add(
    String foodId, {
    LocalDate? date,
    MealSlot slot = MealSlot.lunch,
    int halves = 2,
  }) =>
      store.addFood(
        date: date ?? today,
        slot: slot,
        foodId: foodId,
        halves: halves,
      );

  group('meal slots', () {
    test('four slots in day order, each with a sentence-case label', () {
      expect(MealSlot.values.map((s) => s.name),
          <String>['breakfast', 'lunch', 'snack', 'dinner']);
      expect(MealSlot.values.map((s) => s.label),
          <String>['Breakfast', 'Lunch', 'Snack', 'Dinner']);
    });
  });

  group('reading', () {
    test('a fresh database has no entries', () async {
      expect(await entries(), isEmpty);
    });

    test('entries come back by date, then slot in day order, then position',
        () async {
      await add('paneer', date: nov(3), slot: MealSlot.dinner);
      await add('egg', date: nov(3), slot: MealSlot.breakfast, halves: 4);
      await add('milk', date: nov(3), slot: MealSlot.breakfast);
      await add('chana', date: nov(2), slot: MealSlot.snack, halves: 1);

      final all = await entries();
      expect(
        all.map((e) => '${e.date} ${e.slot.name} ${e.foodId}'),
        <String>[
          '${nov(2)} snack chana',
          '${nov(3)} breakfast egg',
          '${nov(3)} breakfast milk',
          '${nov(3)} dinner paneer',
        ],
      );
      expect(all[1].position, lessThan(all[2].position));
    });
  });

  group('adding a food', () {
    test('writes one row on that date, slot and food', () async {
      await add('paneer', slot: MealSlot.lunch, halves: 3);

      final e = (await entries()).single;
      expect(e.date, nov(4));
      expect(e.slot, MealSlot.lunch);
      expect(e.foodId, 'paneer');
      expect(e.servingsHalves, 3);
      expect(e.position, 0);
    });

    test('foods in a slot take the next position in the order added',
        () async {
      await add('a');
      await add('b');
      await add('c');

      expect((await entries()).map((e) => '${e.foodId}:${e.position}'),
          <String>['a:0', 'b:1', 'c:2']);
    });

    test('positions are per slot and per day', () async {
      await add('a', slot: MealSlot.lunch);
      await add('b', slot: MealSlot.dinner);
      await add('c', date: nov(3), slot: MealSlot.lunch);

      expect((await entries()).map((e) => e.position), everyElement(0));
    });

    test('adding the same food to the same slot and day replaces the '
        'servings and keeps one row, id and position', () async {
      await add('a');
      await add('b');
      final before = (await entries()).first;
      await add('a', halves: 5);

      expect(await rowCount(), 2);
      final after = (await entries()).first;
      expect(after.foodId, 'a');
      expect(after.servingsHalves, 5);
      expect(after.id, before.id);
      expect(after.position, before.position);
    });

    test('the same food in another slot, or on another day, is its own row',
        () async {
      await add('a');
      await add('a', slot: MealSlot.dinner);
      await add('a', date: nov(3));
      expect(await rowCount(), 3);
    });

    test('a row on one day never changes another day', () async {
      await add('a', date: nov(3), halves: 2);
      final monday = await entries();

      await add('a', date: nov(4), halves: 6);
      await add('b', date: nov(4));

      final onThird = (await entries()).where((e) => e.date == nov(3));
      expect(onThird.toList(), monday);
    });

    test('the database UNIQUE blocks a second row for the same food',
        () async {
      await add('a');
      final first = (await entries()).single;
      expect(
        () => database.into(database.dietLogEntries).insert(
              DietLogEntriesCompanion.insert(
                id: 'dup',
                date: first.date,
                slot: first.slot.name,
                foodId: first.foodId,
                servingsHalves: 2,
                position: 9,
              ),
            ),
        throwsA(anything),
      );
    });

    test('logging on today and on earlier days is allowed', () async {
      await add('a', date: nov(4));
      await add('a', date: nov(1));
      await add('a', date: LocalDate(2026, 10, 1));
      expect(await rowCount(), 3);
    });

    test('a future date is rejected and nothing is written', () async {
      expect(() => add('a', date: nov(5)), throwsArgumentError);
      expect(await rowCount(), 0);
    });

    test('"today" is the store clock, read at write time', () async {
      today = nov(9);
      await add('a', date: nov(9));
      today = nov(4);
      await expectLater(add('b', date: nov(9)), throwsArgumentError);
      expect(await rowCount(), 1);
    });

    test('servings are 1 to 8 halves; anything else writes nothing', () async {
      for (final bad in <int>[0, 9, -1]) {
        await expectLater(add('a', halves: bad), throwsArgumentError);
      }
      expect(await rowCount(), 0);
      await add('a', halves: 1);
      await add('b', halves: 8);
      expect(await rowCount(), 2);
    });

    test('an empty food id is rejected', () async {
      await expectLater(add(''), throwsArgumentError);
      expect(await rowCount(), 0);
    });
  });

  group('setting servings', () {
    test('changes only that row', () async {
      await add('a');
      await add('b');
      final a = (await entries()).first;

      await store.setServings(a, 7);

      final all = await entries();
      expect(all.firstWhere((e) => e.foodId == 'a').servingsHalves, 7);
      expect(all.firstWhere((e) => e.foodId == 'b').servingsHalves, 2);
    });

    test('rejects a bad serving count before touching anything', () async {
      await add('a');
      final a = (await entries()).single;
      await expectLater(store.setServings(a, 0), throwsArgumentError);
      await expectLater(store.setServings(a, 9), throwsArgumentError);
      expect((await entries()).single.servingsHalves, 2);
    });

    test('throws StateError when the entry is no longer in the log',
        () async {
      await add('a');
      final a = (await entries()).single;
      await store.removeEntry(a);
      await expectLater(store.setServings(a, 4), throwsStateError);
    });
  });

  group('removing and restoring', () {
    test('remove returns the row and deletes it', () async {
      await add('a');
      final a = (await entries()).single;

      final removed = await store.removeEntry(a);

      expect(removed, a);
      expect(await rowCount(), 0);
    });

    test('removing something already gone returns null', () async {
      await add('a');
      final a = (await entries()).single;
      await store.removeEntry(a);
      expect(await store.removeEntry(a), isNull);
    });

    test('restore puts the row back with its id, servings and position',
        () async {
      await add('a');
      await add('b', halves: 5);
      final b = (await entries()).last;
      await store.removeEntry(b);

      await store.restoreEntry(b);

      expect((await entries()).last, b);
    });

    test('restore picks a fresh id when the old one is taken', () async {
      await add('a');
      final a = (await entries()).single;
      await store.removeEntry(a);
      // A different food now owns that id.
      await database.into(database.dietLogEntries).insert(
            DietLogEntriesCompanion.insert(
              id: a.id,
              date: a.date,
              slot: MealSlot.dinner.name,
              foodId: 'other',
              servingsHalves: 2,
              position: 0,
            ),
          );

      await store.restoreEntry(a);

      final all = await entries();
      expect(all, hasLength(2));
      final restored = all.singleWhere((e) => e.foodId == 'a');
      expect(restored.id, isNot(a.id));
      expect(restored.slot, a.slot);
    });

    test('restore after the same food was logged again keeps one row with '
        'the restored servings', () async {
      await add('a', halves: 6);
      final a = (await entries()).single;
      await store.removeEntry(a);
      await add('a', halves: 2);

      await store.restoreEntry(a);

      expect(await rowCount(), 1);
      final e = (await entries()).single;
      expect(e.servingsHalves, 6);
      expect(e.position, a.position);
    });

    test('restore rejects a future date', () async {
      final future = DietLogEntry(
        id: 'x',
        date: nov(10),
        slot: MealSlot.lunch,
        foodId: 'a',
        servingsHalves: 2,
        position: 0,
      );
      await expectLater(store.restoreEntry(future), throwsArgumentError);
      expect(await rowCount(), 0);
    });
  });
}
