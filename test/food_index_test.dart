import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/food.dart';
import 'package:turtle_lift/src/data/food_index.dart';

/// The food index is what Diet's picker and every protein total read. These
/// tests run on fixtures, not the shipped asset: the food list is reviewed
/// copy that is still being corrected (U19), so a test pinned to its real
/// values would break on every review pass. `test/shipped_data_test.dart`
/// holds the asset to its invariants instead.
void main() {
  Map<String, Object?> food(
    String id,
    String name,
    String dietType,
    double protein, {
    List<String> aliases = const <String>[],
  }) =>
      <String, Object?>{
        'id': id,
        'name': name,
        'aliases': aliases,
        'dietType': dietType,
        'servingLabel': '1 bowl, 100 g',
        'gramsPerServing': 100,
        'proteinPerServingG': protein,
        'proteinPer100g': protein,
        'ifctCode': 'X001',
        'reviewedBy': 'pending-owner-review',
      };

  final index = FoodIndex.fromJson(<Map<String, Object?>>[
    food('curd', 'Curd', 'veg', 3.1, aliases: <String>['dahi', 'yogurt']),
    food('paneer', 'Paneer', 'veg', 18.3, aliases: <String>['panir']),
    food('dal-toor', 'Toor dāl', 'veg', 7.0, aliases: <String>['arhar']),
    food('egg-boiled', 'Egg, boiled', 'egg', 6.3),
    food('chicken-breast', 'Chicken breast', 'nonVeg', 31.0),
    food('fish-rohu', 'Rohu fish', 'nonVeg', 18.3),
    food('omelette', 'Omelette', 'egg', 7.0),
  ]);

  List<String> ids(List<Food> foods) => [for (final f in foods) f.id];

  group('reading a record', () {
    test('every field the generator writes is carried through', () {
      final curd = index.byId('curd')!;
      expect(curd.name, 'Curd');
      expect(curd.aliases, <String>['dahi', 'yogurt']);
      expect(curd.dietType, DietType.veg);
      expect(curd.servingLabel, '1 bowl, 100 g');
      expect(curd.gramsPerServing, 100);
      expect(curd.proteinPerServingG, 3.1);
      expect(curd.proteinPer100g, 3.1);
      expect(curd.ifctCode, 'X001');
    });

    test('diet types read from their stored names and carry their labels', () {
      expect(index.byId('omelette')!.dietType, DietType.egg);
      expect(index.byId('chicken-breast')!.dietType, DietType.nonVeg);
      expect([for (final t in DietType.values) t.label],
          <String>['Veg', 'Egg', 'Non-veg']);
    });

    test('an integer protein value in the JSON still reads as a double', () {
      final whole = FoodIndex.fromJson(<Map<String, Object?>>[
        food('soya', 'Soya chunks', 'veg', 0)..['proteinPerServingG'] = 13,
      ]);
      expect(whole.byId('soya')!.proteinPerServingG, 13.0);
    });

    test('MealSlot is re-exported from food.dart, not redefined', () {
      expect(MealSlot.values.first, MealSlot.breakfast);
    });
  });

  group('byId', () {
    test('a known id returns its food', () {
      expect(index.byId('paneer')!.name, 'Paneer');
    });

    test('an unknown id returns null rather than throwing', () {
      expect(index.byId('no-such-food'), isNull);
    });
  });

  group('search', () {
    test('"dahi" finds curd through its alias', () {
      expect(ids(index.search('dahi', DietFilter.all)), <String>['curd']);
    });

    test('"PANEER" matches "Paneer" ignoring case', () {
      expect(ids(index.search('PANEER', DietFilter.all)), <String>['paneer']);
    });

    test('a plain query matches a name written with diacritics', () {
      expect(ids(index.search('dal', DietFilter.all)), <String>['dal-toor']);
    });

    test('a query with diacritics matches a plain name', () {
      expect(ids(index.search('pānīr', DietFilter.all)), <String>['paneer']);
      expect(ids(index.search('Pānēer', DietFilter.all)), <String>['paneer']);
      expect(ids(index.search('Cūrd', DietFilter.all)), <String>['curd']);
    });

    test('matching is substring and ignores surrounding whitespace', () {
      expect(ids(index.search('  breast ', DietFilter.all)),
          <String>['chicken-breast']);
    });

    test('a blank query lists every food the filter admits', () {
      expect(index.search('', DietFilter.all), hasLength(7));
      expect(index.search('   ', DietFilter.nonVeg), hasLength(2));
    });

    test('a query nothing matches returns an empty list', () {
      expect(index.search('pizza', DietFilter.all), isEmpty);
    });
  });

  group('filters (A1)', () {
    test('Egg returns veg and egg foods and no non-veg', () {
      final types = {
        for (final f in index.search('', DietFilter.egg)) f.dietType,
      };
      expect(types, <DietType>{DietType.veg, DietType.egg});
      expect(index.search('', DietFilter.egg), hasLength(5));
    });

    test('Veg returns no egg and no non-veg', () {
      final types = {
        for (final f in index.search('', DietFilter.veg)) f.dietType,
      };
      expect(types, <DietType>{DietType.veg});
    });

    test('Non-veg returns only non-veg', () {
      final types = {
        for (final f in index.search('', DietFilter.nonVeg)) f.dietType,
      };
      expect(types, <DietType>{DietType.nonVeg});
    });

    test('All returns every diet type', () {
      final types = {
        for (final f in index.search('', DietFilter.all)) f.dietType,
      };
      expect(types, DietType.values.toSet());
    });

    test('the filter and the query apply together', () {
      expect(index.search('dahi', DietFilter.nonVeg), isEmpty);
      expect(ids(index.search('dahi', DietFilter.egg)), <String>['curd']);
    });

    test('admits() is the same rule the search applies', () {
      expect(DietFilter.egg.admits(DietType.veg), isTrue);
      expect(DietFilter.egg.admits(DietType.nonVeg), isFalse);
      expect(DietFilter.veg.admits(DietType.egg), isFalse);
      expect(DietFilter.nonVeg.admits(DietType.veg), isFalse);
      expect(DietFilter.all.admits(DietType.nonVeg), isTrue);
    });
  });

  group('sort (A15)', () {
    test('protein per serving, highest first, ties broken by name', () {
      expect(ids(index.search('', DietFilter.all)), <String>[
        'chicken-breast', // 31.0
        'paneer', // 18.3, "Paneer" before "Rohu fish"
        'fish-rohu', // 18.3
        'omelette', // 7.0, "Omelette" before "Toor dāl"
        'dal-toor', // 7.0
        'egg-boiled', // 6.3
        'curd', // 3.1
      ]);
    });

    test('the name tie-break ignores case', () {
      final mixed = FoodIndex.fromJson(<Map<String, Object?>>[
        food('b', 'banana', 'veg', 1.0),
        food('a', 'Apple', 'veg', 1.0),
      ]);
      expect(ids(mixed.search('', DietFilter.all)), <String>['a', 'b']);
    });
  });

  group('unavailable index (KTD11, R26)', () {
    test('an unavailable index answers every lookup empty', () {
      final none = FoodIndex.unavailable();
      expect(none.isAvailable, isFalse);
      expect(none.all, isEmpty);
      expect(none.byId('curd'), isNull);
      expect(none.search('', DietFilter.all), isEmpty);
    });

    test('a loaded index is available', () {
      expect(index.isAvailable, isTrue);
    });
  });

  group('loadFoodIndex', () {
    // Captures what `FlutterError.reportError` would otherwise print, and
    // proves the failure is reported rather than swallowed. The default
    // handler is restored after each test so a real failure elsewhere in the
    // file is not hidden.
    late List<FlutterErrorDetails> reported;
    late FlutterExceptionHandler? previous;

    setUp(() {
      reported = <FlutterErrorDetails>[];
      previous = FlutterError.onError;
      FlutterError.onError = reported.add;
    });
    tearDown(() => FlutterError.onError = previous);

    test('valid JSON loads an available index and reports nothing', () async {
      final loaded = await loadFoodIndex(() async => '['
          '{"id":"curd","name":"Curd","aliases":["dahi"],"dietType":"veg",'
          '"servingLabel":"1 bowl","gramsPerServing":100,'
          '"proteinPerServingG":3.1,"proteinPer100g":3.1,"ifctCode":"L001",'
          '"reviewedBy":"pending-owner-review"}]');
      expect(loaded.isAvailable, isTrue);
      expect(loaded.byId('curd')!.aliases, <String>['dahi']);
      expect(reported, isEmpty);
    });

    test('malformed JSON yields an unavailable index without throwing, and '
        'the error is reported', () async {
      // Asserts are on under `flutter test`; the fallback must survive them.
      var assertsOn = false;
      assert(assertsOn = true);
      expect(assertsOn, isTrue);

      final loaded = await loadFoodIndex(() async => '[{"id": "curd",');
      expect(loaded.isAvailable, isFalse);
      expect(reported, hasLength(1));
      expect(reported.single.exception, isA<FormatException>());
    });

    test('a record missing a field is a failure, not a blank row', () async {
      final loaded = await loadFoodIndex(() async => '[{"id":"curd"}]');
      expect(loaded.isAvailable, isFalse);
      expect(reported, hasLength(1));
    });

    test('an unknown diet type is a failure', () async {
      final loaded = await loadFoodIndex(() async => '[{"id":"x","name":"X",'
          '"aliases":[],"dietType":"vegan","servingLabel":"1",'
          '"gramsPerServing":1,"proteinPerServingG":1,"proteinPer100g":1,'
          '"ifctCode":"A1"}]');
      expect(loaded.isAvailable, isFalse);
      expect(reported, hasLength(1));
    });

    test('a failed asset read is reported and yields unavailable', () async {
      final loaded =
          await loadFoodIndex(() async => throw StateError('no asset'));
      expect(loaded.isAvailable, isFalse);
      expect(reported.single.exception, isA<StateError>());
    });
  });

  test('foodIndexProvider throws when boot did not override it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(() => container.read(foodIndexProvider), throwsA(anything));
  });
}
