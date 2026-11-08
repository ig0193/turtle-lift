import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/food.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/generated/body_paths.dart';
import 'package:turtle_lift/src/data/generated/muscle_taxonomy.dart';
import 'package:turtle_lift/src/data/shipped_data.dart';

/// The shipped data is generated, so nothing in `lib/` would notice it
/// drifting. These counts come from `docs/00-build-spec.md` §1 and §3: a
/// failure here means a generator ran and its output changed, which is a fact
/// to reconcile against the spec rather than a test to "fix".
void main() {
  // Loading assets/exercises.json below needs the services binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shipped taxonomy matches the spec', () {
    expect(kMuscleGroupCount, 12, reason: '12 parent groups');
    expect(kSubMuscleGroupCount, 19, reason: '19 sub-muscle groups');
  });

  test('four body assets carry 42 segments between them', () {
    expect(kBodyAssets.keys.toSet(), {
      'frontMale',
      'backMale',
      'frontFemale',
      'backFemale',
    });
    expect(kBodyAssetCount, 4);
    expect(kBodySegmentCount, 42);

    // Every segment id must resolve in the taxonomy: '<group>/<subGroup>'.
    for (final asset in kBodyAssets.values) {
      for (final segment in asset.segments) {
        final parts = segment.id.split('/');
        expect(parts.length, 2, reason: 'malformed segment id ${segment.id}');
        expect(
          kMuscleTaxonomy[parts.first],
          contains(parts.last),
          reason: 'orphan segment ${segment.id}',
        );
      }
    }
  });

  test('the bundled exercise library parses to 260 entries', () async {
    // 260 exercises, docs/00-build-spec.md §3. Content fields are reviewed
    // copy -- this only checks the file is present, valid and complete.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final exercises = await container.read(exerciseLibraryProvider.future);
    expect(exercises, hasLength(260));
  });

  test('the bundled food list parses and meets the A10 minimums', () async {
    // Invariants only, never exact counts or protein values: the list is
    // reviewed copy still being corrected (U19), and its generator's own
    // validator (assets/foods/validate_food_catalogue.py) is what pins the
    // values. This proves the app can read what the generator wrote.
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    final index = await loadFoodIndex(readShippedFoodList);
    expect(reported, isEmpty,
        reason: 'the shipped food list must load without a reported error');
    expect(index.isAvailable, isTrue);

    final foods = index.all;
    expect({for (final f in foods) f.id}, hasLength(foods.length),
        reason: 'food ids are unique');
    for (final f in foods) {
      expect(f.ifctCode.trim(), isNotEmpty, reason: '${f.id} has no IFCT code');
      expect(f.gramsPerServing, greaterThan(0), reason: f.id);
      expect(f.proteinPerServingG, greaterThan(0), reason: f.id);
      expect(f.proteinPerServingG, lessThanOrEqualTo(f.gramsPerServing),
          reason: f.id);
    }

    // A10: at least 100 foods, 60 veg and 25 non-veg, and every IFCT 2017
    // egg entry (group M, M001 to M015) carried by an egg row.
    int count(DietType type) => foods.where((f) => f.dietType == type).length;
    expect(foods.length, greaterThanOrEqualTo(100));
    expect(count(DietType.veg), greaterThanOrEqualTo(60));
    expect(count(DietType.nonVeg), greaterThanOrEqualTo(25));
    final eggCodes = {
      for (final f in foods)
        if (f.dietType == DietType.egg) f.ifctCode,
    };
    for (var n = 1; n <= 15; n++) {
      final code = 'M${n.toString().padLeft(3, '0')}';
      expect(eggCodes, contains(code),
          reason: 'IFCT egg entry $code is carried by no egg food');
    }
  });
}
