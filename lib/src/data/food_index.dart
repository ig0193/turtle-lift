import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'food.dart';

/// Where the generated food list ships.
const String kFoodListAsset = 'assets/foods/foods.json';

/// Which foods a Diet chip admits (A1).
///
/// **Egg means eggetarian: veg plus egg.** Veg means veg only and Non-veg
/// means non-veg only. All admits everything.
enum DietFilter {
  all,
  veg,
  egg,
  nonVeg;

  /// Whether a food of [type] passes this filter.
  bool admits(DietType type) => switch (this) {
        DietFilter.all => true,
        DietFilter.veg => type == DietType.veg,
        DietFilter.egg => type == DietType.veg || type == DietType.egg,
        DietFilter.nonVeg => type == DietType.nonVeg,
      };
}

/// The shipped food list, arranged for the two lookups Diet makes: by id (every
/// plan row and total) and by search (the picker).
///
/// **It can be unavailable, unlike `ExerciseIndex`.** A bad food asset must not
/// take the whole app down with it (KTD11): Diet shows a plain unavailable
/// state and every other tab keeps working (R26). An unavailable index answers
/// every lookup empty, so a stray read cannot throw; callers that need to tell
/// "no foods" from "no food list" check [isAvailable].
class FoodIndex {
  /// Folds a decoded food list into its lookup tables. Throws on a record that
  /// does not match the shipped shape; [loadFoodIndex] is what tolerates that.
  factory FoodIndex.fromJson(List<Map<String, Object?>> records) =>
      FoodIndex(records.map(Food.fromJson).toList(growable: false));

  FoodIndex(List<Food> foods)
      : this._(List<Food>.unmodifiable(_sorted(foods)), isAvailable: true);

  /// The index Diet gets when the food list failed to load.
  FoodIndex.unavailable() : this._(const <Food>[], isAvailable: false);

  FoodIndex._(this.all, {required this.isAvailable})
      : _byId = <String, Food>{for (final food in all) food.id: food},
        _searchKeys = <String, List<String>>{
          for (final food in all)
            food.id: <String>[
              _fold(food.name),
              for (final alias in food.aliases) _fold(alias),
            ],
        };

  /// False when the asset failed to load or parse (R26).
  final bool isAvailable;

  /// Every food, in the A15 order: protein per serving, highest first, then
  /// name ignoring case.
  final List<Food> all;

  final Map<String, Food> _byId;
  final Map<String, List<String>> _searchKeys;

  /// The food with [id], or null when nothing carries it.
  ///
  /// **Null rather than a throw**: a plan row can outlive its food (R26 renders
  /// it as "Unknown food"), and the caller decides what that looks like.
  Food? byId(String id) => _byId[id];

  /// The foods [filter] admits whose name or an alias contains [query],
  /// ignoring case, diacritics and surrounding whitespace (A15).
  ///
  /// **A blank query lists every admitted food**, unlike exercise search: the
  /// picker opens on the list to browse, and about a hundred rows sorted by
  /// protein is the useful first view. Results keep the A15 order.
  List<Food> search(String query, DietFilter filter) {
    final needle = _fold(query.trim());
    return <Food>[
      for (final food in all)
        if (filter.admits(food.dietType) &&
            (needle.isEmpty ||
                _searchKeys[food.id]!.any((key) => key.contains(needle))))
          food,
    ];
  }

  static List<Food> _sorted(List<Food> foods) => foods.toList()
    ..sort((a, b) {
      final byProtein = b.proteinPerServingG.compareTo(a.proteinPerServingG);
      if (byProtein != 0) return byProtein;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  /// Lower-cases [text] and strips the Latin diacritics transliterated Indian
  /// food names carry ("dāl", "pānīr"), so they match their plain spelling.
  ///
  /// **A table rather than Unicode normalisation**, because Dart's core
  /// libraries have no NFD; the table covers IAST and the common Western
  /// accents, which is every diacritic a food name here can plausibly carry.
  static String _fold(String text) {
    final lower = text.toLowerCase();
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      out.write(_plain[char] ?? char);
    }
    return out.toString();
  }

  static const Map<String, String> _plain = <String, String>{
    'ā': 'a', 'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'ē': 'e', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'ī': 'i', 'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ō': 'o', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ū': 'u', 'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ṛ': 'r', 'ṝ': 'r', 'ḷ': 'l', 'ṃ': 'm', 'ṁ': 'm', 'ḥ': 'h',
    'ṅ': 'n', 'ñ': 'n', 'ṇ': 'n', 'ń': 'n',
    'ṭ': 't', 'ḍ': 'd', 'ś': 's', 'ṣ': 's', 'š': 's',
    'ç': 'c', 'ý': 'y', 'ÿ': 'y', 'ž': 'z',
  };
}

/// Reads and folds the food list, **never throwing** (KTD11).
///
/// Any failure, from the asset read through the decode to a record of the
/// wrong shape, is reported through [FlutterError.reportError] (visible in
/// debug and in a test's `FlutterError.onError`, but not a throw) and yields
/// [FoodIndex.unavailable]. Boot calls this beside the exercise library, which
/// stays fail-loud.
Future<FoodIndex> loadFoodIndex(Future<String> Function() readAsset) async {
  try {
    final raw = await readAsset();
    return FoodIndex.fromJson(
      (jsonDecode(raw) as List).cast<Map<String, Object?>>(),
    );
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'turtle_lift food list',
      context: ErrorDescription('while loading $kFoodListAsset; Diet will '
          'show its unavailable state'),
    ));
    return FoodIndex.unavailable();
  }
}

/// Reads the shipped food list off the asset bundle.
Future<String> readShippedFoodList() => rootBundle.loadString(kFoodListAsset);

/// The food list, indexed and available **synchronously on the first frame**.
///
/// **Overridden by `main()`**, exactly like `exerciseIndexProvider`, and it
/// throws without the override for the same reason: a silently empty default
/// would hide dropped boot wiring. A *failed load* is a different thing and is
/// not a throw: boot overrides with [FoodIndex.unavailable] (KTD11).
final foodIndexProvider = Provider<FoodIndex>(
  (ref) => throw UnimplementedError(
    'foodIndexProvider must be overridden. main() builds the index with '
    'loadFoodIndex before runApp; a test overrides it with FoodIndex.fromJson '
    'over its own fixtures, or with FoodIndex.unavailable().',
  ),
);
