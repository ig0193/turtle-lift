import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/food_index.dart';

/// QA (second pass, search with punctuation): what a person types is not the
/// library's spelling.
///
/// 44 exercise names are hyphenated ("Pull-up", "Push-up", "Single-arm
/// dumbbell row"), and two carry an apostrophe ("Farmer's carry"). A beginner
/// types "pull up" or "pushup", and the iOS keyboard turns ' into ’ by default,
/// so all of these found nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ExerciseIndex index;

  setUpAll(() async {
    final boot = ProviderContainer();
    addTearDown(boot.dispose);
    index = ExerciseIndex.fromJson(
      await boot.read(exerciseLibraryProvider.future),
    );
  });

  List<String> names(String query) =>
      index.searchByName(query).map((e) => e.name).toList();

  group('exercise search', () {
    test('"pull up" finds Pull-up', () {
      expect(names('pull up'), contains('Pull-up'));
    });

    test('"pushup" finds Push-up', () {
      expect(names('pushup'), contains('Push-up'));
    });

    test('a curly apostrophe finds Farmer\'s carry', () {
      expect(names('farmer’s'), contains("Farmer's carry"));
      expect(names('farmers carry'), contains("Farmer's carry"));
    });

    test('the plain spelling still works', () {
      expect(names('Pull-up'), contains('Pull-up'));
      expect(names('bench'), contains('Barbell bench press'));
    });

    test('punctuation alone matches nothing', () {
      expect(names('-'), isEmpty);
      expect(names('  '), isEmpty);
    });
  });

  group('food search', () {
    late FoodIndex foods;
    setUpAll(() {
      final raw = jsonDecode(File('assets/foods/foods.json').readAsStringSync())
          as List<Object?>;
      foods = FoodIndex.fromJson(raw.cast<Map<String, Object?>>());
    });

    List<String> foodNames(String query) =>
        foods.search(query, DietFilter.all).map((f) => f.name).toList();

    test('"hard boiled" finds the hard-boiled egg', () {
      final hit = foodNames('hard boiled');
      expect(hit, isNotEmpty);
      expect(foodNames('hard-boiled'), equals(hit));
    });

    test('"black eyed" finds black-eyed beans', () {
      expect(foodNames('black eyed'), equals(foodNames('black-eyed')));
      expect(foodNames('black eyed'), isNotEmpty);
    });
  });
}
