/// One food of the shipped Diet food list, typed over the keys the generator
/// writes to `assets/foods/foods.json`.
///
/// **Every field is stored, none derived**, for the same reason as `Exercise`:
/// this is read-only shipped content, and the JSON is its source of truth. The
/// user's plan stores a food id and a serving count only (KTD9); protein per
/// serving is read from here on every total, so a corrected value flows into
/// the plan rather than being snapshotted on its rows.
library;

export 'meal_slot.dart';

/// What a food is, for the Veg / Egg / Non-veg chips (A1).
///
/// **Stored in the JSON by [name]** (`veg`, `egg`, `nonVeg`), so reordering
/// this enum moves nothing.
enum DietType {
  veg('Veg'),
  egg('Egg'),
  nonVeg('Non-veg');

  const DietType(this.label);

  /// Sentence-case display word.
  final String label;
}

/// A single food's reference content.
class Food {
  const Food({
    required this.id,
    required this.name,
    required this.aliases,
    required this.dietType,
    required this.servingLabel,
    required this.gramsPerServing,
    required this.proteinPerServingG,
    required this.proteinPer100g,
    required this.ifctCode,
  });

  /// Reads one record of the shipped array.
  ///
  /// **No defaults for a missing key.** The file is generated and validated by
  /// `assets/foods/validate_food_catalogue.py`; a record that does not match is
  /// a broken regeneration, and the boot loader turns that into Diet's
  /// unavailable state (KTD11) rather than a row of blanks with a wrong total.
  /// `reviewedBy` is provenance for the reviewer, not app data, and is not
  /// read.
  factory Food.fromJson(Map<String, Object?> json) => Food(
        id: json['id']! as String,
        name: json['name']! as String,
        aliases: List<String>.unmodifiable(
          (json['aliases']! as List).cast<String>(),
        ),
        dietType: DietType.values.byName(json['dietType']! as String),
        servingLabel: json['servingLabel']! as String,
        gramsPerServing: json['gramsPerServing']! as int,
        // `num`, because JSON writes 13.0 as 13 and Dart decodes that as int.
        proteinPerServingG: (json['proteinPerServingG']! as num).toDouble(),
        proteinPer100g: (json['proteinPer100g']! as num).toDouble(),
        ifctCode: json['ifctCode']! as String,
      );

  /// Stable across renames of [name]; this is what a plan row references.
  final String id;

  /// What the food is called, sentence case.
  final String name;

  /// Other names search should find it by ("dahi" for curd). May be empty.
  final List<String> aliases;

  final DietType dietType;

  /// The household serving, e.g. "1 katori, 150 g".
  final String servingLabel;

  final int gramsPerServing;

  /// Protein in one serving, to one decimal (R7).
  final double proteinPerServingG;

  final double proteinPer100g;

  /// The IFCT 2017 entry the protein value comes from.
  final String ifctCode;
}
