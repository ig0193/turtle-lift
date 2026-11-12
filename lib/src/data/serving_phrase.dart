/// How a planned food is put into words, shared by the serving sheet and the
/// diet reminders (U17), so a notification reads exactly like the row it
/// came from.
library;

import 'food.dart';

/// Grams for a row or a live line: a whole number when it is one ("24"),
/// otherwise the food list's one decimal ("9.4").
String formatGramsShort(double grams) {
  final tenths = (grams * 10).round();
  return tenths % 10 == 0
      ? '${tenths ~/ 10}'
      : (tenths / 10).toStringAsFixed(1);
}

/// Servings as a number: "1", "1.5", "0.5".
String _formatServings(double servings) => servings == servings.roundToDouble()
    ? servings.toStringAsFixed(0)
    : servings.toStringAsFixed(1);

/// Household measures that read the same in the plural: "2 katori", never
/// "2 katoris". A label starting with one of these after a "1 " swaps the 1
/// for the count.
const Set<String> _countableMeasures = <String>{'katori', 'tbsp', 'tsp'};

/// What [servings] of [food] is in words: "2 katori", "5 cubes",
/// "1.5 × 5 cubes".
///
/// The food list's serving label is free text whose first clause is the
/// household measure ("1 katori cooked dal, 30 g dry"). A katori, tbsp or tsp
/// measure takes the count directly ("2 katori"); anything else, where
/// "2 medium piece" or "3 × 10 almonds" would misread, keeps its measure and
/// gains a multiplier unless it is exactly one serving.
String servingPhrase(Food food, double servings) {
  final measure = food.servingLabel.split(',').first.trim();
  final words = measure.split(' ');
  if (words.length >= 2 &&
      words[0] == '1' &&
      _countableMeasures.contains(words[1])) {
    return '${_formatServings(servings)} ${words[1]}';
  }
  if (servings == 1) return measure;
  return '${_formatServings(servings)} × $measure';
}
