import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/diet_plan_store.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';

/// The Diet plan store: whole-week versions keyed by Monday, written
/// copy-on-write (`docs/adr/0007-diet-in-profile.md`, plan KTD5, KTD6, KTD13).
///
/// November 2026 is used throughout: Monday is the 2nd, 9th, 16th and 23rd,
/// and Sunday the 8th closes the week of the 2nd.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LocalDate nov(int day) => LocalDate(2026, 11, day);

  late AppDatabase database;
  late LocalDate today;
  late DietPlanStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    today = nov(4); // a Wednesday in the week of the 2nd
    store = DietPlanStore(database, today: () => today);
  });

  tearDown(() => database.close());

  Future<List<DietPlanVersion>> versions() => store.readVersions();

  Future<int> itemRowCount() async =>
      (await database.select(database.dietPlanItems).get()).length;

  DietPlanVersion versionAt(List<DietPlanVersion> all, LocalDate monday) =>
      all.singleWhere((v) => v.effectiveFrom == monday);

  group('meal slots', () {
    test('four slots in day order, each with a sentence-case label', () {
      expect(MealSlot.values.map((s) => s.name),
          <String>['breakfast', 'lunch', 'snack', 'dinner']);
      expect(MealSlot.values.map((s) => s.label),
          <String>['Breakfast', 'Lunch', 'Snack', 'Dinner']);
    });
  });

  group('reading', () {
    test('a fresh database has no versions', () async {
      expect(await versions(), isEmpty);
    });

    test('items come back by weekday, then slot in day order, then position',
        () async {
      await store.addFood(
          weekdays: <int>{1}, slot: MealSlot.dinner, foodId: 'paneer', halves: 2);
      await store.addFood(
          weekdays: <int>{1}, slot: MealSlot.breakfast, foodId: 'egg', halves: 4);
      await store.addFood(
          weekdays: <int>{1}, slot: MealSlot.breakfast, foodId: 'milk', halves: 2);
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.snack, foodId: 'chana', halves: 1);

      final items = (await versions()).single.items;
      expect(
        items.map((i) => '${i.weekday} ${i.slot.name} ${i.foodId}'),
        <String>[
          '0 snack chana',
          '1 breakfast egg',
          '1 breakfast milk',
          '1 dinner paneer',
        ],
      );
      expect(items[1].position, lessThan(items[2].position));
    });
  });

  group('adding a food', () {
    test('the first edit creates this week\'s version at its Monday', () async {
      await store.addFood(
          weekdays: <int>{2}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);

      final all = await versions();
      expect(all.single.effectiveFrom, nov(2));
      final item = all.single.items.single;
      expect(item.weekday, 2);
      expect(item.slot, MealSlot.lunch);
      expect(item.foodId, 'dal');
      expect(item.servingsHalves, 2);
    });

    test('Monday to Friday writes five rows in one call', () async {
      await store.addFood(
        weekdays: <int>{0, 1, 2, 3, 4},
        slot: MealSlot.breakfast,
        foodId: 'egg',
        halves: 4,
      );

      final items = (await versions()).single.items;
      expect(items.map((i) => i.weekday), <int>[0, 1, 2, 3, 4]);
      expect(items.every((i) => i.foodId == 'egg' && i.servingsHalves == 4),
          isTrue);
      expect(items.map((i) => i.id).toSet(), hasLength(5));
    });

    test('re-adding an existing food replaces its servings and keeps one row',
        () async {
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      final before = (await versions()).single.items.single;

      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: 5);

      final after = (await versions()).single.items.single;
      expect(after.servingsHalves, 5);
      expect(after.id, before.id);
      expect(after.position, before.position);
      expect(await itemRowCount(), 1);
    });

    test('a weekday out of range throws and leaves no rows and no version',
        () async {
      await expectLater(
        store.addFood(
            weekdays: <int>{0, 1, 9}, slot: MealSlot.lunch, foodId: 'dal', halves: 2),
        throwsArgumentError,
      );
      expect(await versions(), isEmpty);
      expect(await itemRowCount(), 0);
    });

    test('no weekday throws', () async {
      await expectLater(
        store.addFood(
            weekdays: <int>{}, slot: MealSlot.lunch, foodId: 'dal', halves: 2),
        throwsArgumentError,
      );
      expect(await versions(), isEmpty);
    });

    for (final halves in <int>[0, 9, -1]) {
      test('$halves halves throws', () async {
        await expectLater(
          store.addFood(
              weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: halves),
          throwsArgumentError,
        );
        expect(await versions(), isEmpty);
      });
    }

    test('an empty food id throws', () async {
      await expectLater(
        store.addFood(
            weekdays: <int>{0}, slot: MealSlot.lunch, foodId: '', halves: 2),
        throwsArgumentError,
      );
    });

    test('a database failure mid-way rolls back every row and the new version',
        () async {
      // Validation runs before any write, so to prove the transaction itself
      // the database is made to refuse Thursday's row after Monday to
      // Wednesday's have gone in -- and after the version was created.
      await database.customStatement(
        'CREATE TRIGGER refuse_thursday BEFORE INSERT ON diet_plan_items '
        "WHEN NEW.weekday = 3 BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

      await expectLater(
        store.addFood(
          weekdays: <int>{0, 1, 2, 3, 4},
          slot: MealSlot.breakfast,
          foodId: 'egg',
          halves: 4,
        ),
        throwsA(anything),
      );
      expect(await versions(), isEmpty);
      expect(await itemRowCount(), 0);
    });

    test('a mid-way failure in a later week leaves the earlier copy untouched',
        () async {
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      await database.customStatement(
        'CREATE TRIGGER refuse_thursday BEFORE INSERT ON diet_plan_items '
        "WHEN NEW.weekday = 3 BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

      today = nov(11);
      await expectLater(
        store.addFood(
            weekdays: <int>{2, 3}, slot: MealSlot.snack, foodId: 'egg', halves: 2),
        throwsA(anything),
      );

      final all = await versions();
      expect(all.map((v) => v.effectiveFrom), <LocalDate>[nov(2)]);
      expect(all.single.items.single.foodId, 'dal');
    });
  });

  group('copy-on-write', () {
    test('an edit in week W with only a version at W-2 copies W-2 forward and '
        'leaves W-2 unchanged', () async {
      await store.addFood(
          weekdays: <int>{0, 2}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      final original = await versions();

      today = nov(18); // Wednesday of the week of the 16th
      await store.addFood(
          weekdays: <int>{4}, slot: MealSlot.dinner, foodId: 'paneer', halves: 3);

      final all = await versions();
      expect(all.map((v) => v.effectiveFrom), <LocalDate>[nov(2), nov(16)]);

      final old = versionAt(all, nov(2));
      expect(old.items, original.single.items,
          reason: 'no path writes an older version');

      final current = versionAt(all, nov(16));
      expect(
        current.items.map((i) => '${i.weekday} ${i.slot.name} ${i.foodId} '
            '${i.servingsHalves}'),
        <String>['0 lunch dal 2', '2 lunch dal 2', '4 dinner paneer 3'],
      );
      expect(
        current.items.map((i) => i.id).toSet().intersection(
            old.items.map((i) => i.id).toSet()),
        isEmpty,
        reason: 'copied rows get new ids',
      );
    });

    test('two edits in the same week touch one version', () async {
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      today = nov(6);
      await store.addFood(
          weekdays: <int>{1}, slot: MealSlot.lunch, foodId: 'rajma', halves: 2);

      final all = await versions();
      expect(all.single.effectiveFrom, nov(2));
      expect(all.single.items, hasLength(2));
    });

    test('the copy comes from the latest earlier version, not the first',
        () async {
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      today = nov(10);
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: 6);

      today = nov(25);
      await store.addFood(
          weekdays: <int>{1}, slot: MealSlot.snack, foodId: 'egg', halves: 2);

      final current = versionAt(await versions(), nov(23));
      expect(current.items.first.foodId, 'dal');
      expect(current.items.first.servingsHalves, 6);
    });

    test('an edit with no earlier version starts the week empty', () async {
      today = nov(16);
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      expect((await versions()).single.items, hasLength(1));
    });

    test('the store clock decides the week: with the app\'s planTodayProvider '
        'still pinned to Sunday, a store whose clock reads Monday writes into '
        'Monday\'s week', () async {
      today = nov(8); // Sunday: what a cached planTodayProvider would still say
      await store.addFood(
          weekdays: <int>{6}, slot: MealSlot.dinner, foodId: 'paneer', halves: 2);

      today = nov(9); // the device clock has moved on to Monday
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.breakfast, foodId: 'egg', halves: 4);

      final all = await versions();
      expect(all.map((v) => v.effectiveFrom), <LocalDate>[nov(2), nov(9)]);
      expect(versionAt(all, nov(2)).items.single.foodId, 'paneer',
          reason: 'Sunday\'s week was not written by the Monday edit');
      expect(versionAt(all, nov(9)).items.map((i) => i.foodId),
          <String>['egg', 'paneer']);
    });
  });

  group('changing servings', () {
    test('sets the servings of the item in this week', () async {
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      final item = (await versions()).single.items.single;

      await store.setServings(item, 7);

      final after = (await versions()).single.items.single;
      expect(after.servingsHalves, 7);
      expect(after.id, item.id);
    });

    test('on an item read from an older version, copies forward and changes '
        'only the copy', () async {
      await store.addFood(
          weekdays: <int>{0, 1}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      final oldItem = (await versions()).single.items.first;

      today = nov(12);
      await store.setServings(oldItem, 4);

      final all = await versions();
      expect(versionAt(all, nov(2)).items.map((i) => i.servingsHalves),
          <int>[2, 2]);
      expect(versionAt(all, nov(9)).items.map((i) => i.servingsHalves),
          <int>[4, 2]);
    });

    for (final halves in <int>[0, 9]) {
      test('$halves halves throws and writes nothing', () async {
        await store.addFood(
            weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
        final item = (await versions()).single.items.single;
        today = nov(12);

        await expectLater(store.setServings(item, halves), throwsArgumentError);
        expect((await versions()).single.effectiveFrom, nov(2));
      });
    }

    test('an item no longer in the plan throws and rolls back', () async {
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      final item = (await versions()).single.items.single;
      await store.removeItem(item);
      final remaining = await versions();

      await expectLater(store.setServings(item, 4), throwsStateError);
      expect(await versions(), remaining);
    });
  });

  group('removing and restoring', () {
    test('remove returns the removed item and deletes its row', () async {
      await store.addFood(
          weekdays: <int>{0, 1}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      final item = (await versions()).single.items.first;

      final removed = await store.removeItem(item);

      expect(removed, item);
      expect((await versions()).single.items.map((i) => i.weekday), <int>[1]);
    });

    test('remove then restore yields the original row', () async {
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'rajma', halves: 3);
      final before = (await versions()).single.items;

      final removed = await store.removeItem(before.first);
      await store.restoreItem(removed!);

      expect((await versions()).single.items, before);
    });

    test('removing the last item leaves an empty version, not none', () async {
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      final item = (await versions()).single.items.single;

      await store.removeItem(item);

      final all = await versions();
      expect(all.single.effectiveFrom, nov(2));
      expect(all.single.items, isEmpty);
    });

    test('removing an item read from an older version removes it from this '
        'week\'s copy only, and restore puts it back there', () async {
      await store.addFood(
          weekdays: <int>{0, 1}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      final oldItem = (await versions()).single.items.first;

      today = nov(10);
      final removed = await store.removeItem(oldItem);

      var all = await versions();
      expect(versionAt(all, nov(2)).items, hasLength(2));
      expect(versionAt(all, nov(9)).items.map((i) => i.weekday), <int>[1]);
      expect(removed!.weekday, 0);
      expect(removed.id, isNot(oldItem.id),
          reason: 'what was removed is the copy in this week');

      await store.restoreItem(removed);
      all = await versions();
      expect(versionAt(all, nov(9)).items.map((i) => i.weekday), <int>[0, 1]);
      expect(versionAt(all, nov(2)).items, hasLength(2));
    });

    test('removing an item that is not there returns null', () async {
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      final item = (await versions()).single.items.single;
      await store.removeItem(item);

      expect(await store.removeItem(item), isNull);
    });

    test('restore after the week rolled over lands in the new week', () async {
      await store.addFood(
          weekdays: <int>{0, 1}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      final removed =
          await store.removeItem((await versions()).single.items.first);

      today = nov(9);
      await store.restoreItem(removed!);

      final all = await versions();
      expect(versionAt(all, nov(2)).items.map((i) => i.weekday), <int>[1]);
      expect(versionAt(all, nov(9)).items.map((i) => i.weekday), <int>[0, 1]);
    });

    test('restore over a re-added food keeps one row with the restored '
        'servings', () async {
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: 2);
      final removed =
          await store.removeItem((await versions()).single.items.single);
      await store.addFood(
          weekdays: <int>{0}, slot: MealSlot.lunch, foodId: 'dal', halves: 8);

      await store.restoreItem(removed!);

      final items = (await versions()).single.items;
      expect(items, hasLength(1));
      expect(items.single.servingsHalves, 2);
    });
  });
}
