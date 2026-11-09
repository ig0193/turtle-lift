import 'dart:math' as math;

/// Light typo tolerance for search: "bech press" → "bench press".
///
/// **Only consulted when a query matched nothing**, so a correct query is
/// never second-guessed and a correction is always shown to the user as a
/// "Did you mean …" rather than applied silently.
///
/// **Words of four letters or more only.** A three-letter word is one edit
/// away from too many others ("ham", "hip", "lat"), so correcting it would be
/// a guess dressed up as a fix. Words of eight letters or more may be two
/// edits away ("sholders" is one, "dumbel" is not long enough for two).
class SearchSpelling {
  /// [words] is every word the search can match, already folded. Repeats are
  /// fine and count as frequency, which breaks ties between equally close
  /// candidates.
  SearchSpelling(Iterable<String> words) {
    for (final word in words) {
      if (word.isEmpty) continue;
      _frequency[word] = (_frequency[word] ?? 0) + 1;
    }
  }

  final Map<String, int> _frequency = <String, int>{};

  /// Whether [word] is one the search knows as spelled.
  bool knows(String word) => _frequency.containsKey(word);

  /// [needle] (already folded) with each unknown word replaced by its closest
  /// known word, or null when nothing would change.
  String? correct(String needle) {
    final words = needle.split(' ');
    var changed = false;
    final fixed = <String>[
      for (final word in words)
        () {
          final better = _closest(word);
          if (better == null) return word;
          changed = true;
          return better;
        }(),
    ];
    return changed ? fixed.join(' ') : null;
  }

  String? _closest(String word) {
    if (word.length < 4 || knows(word)) return null;
    final limit = word.length >= 8 ? 2 : 1;
    String? best;
    var bestDistance = limit + 1;
    var bestFrequency = 0;
    for (final entry in _frequency.entries) {
      final candidate = entry.key;
      if ((candidate.length - word.length).abs() > limit) continue;
      final distance = editDistance(word, candidate);
      if (distance > limit) continue;
      if (distance < bestDistance ||
          (distance == bestDistance &&
              (entry.value > bestFrequency ||
                  (entry.value == bestFrequency &&
                      candidate.compareTo(best!) < 0)))) {
        best = candidate;
        bestDistance = distance;
        bestFrequency = entry.value;
      }
    }
    return best;
  }
}

/// Edit distance with adjacent transpositions counted as one edit (optimal
/// string alignment), so "bnech" is one away from "bench", as a thumb slip is.
int editDistance(String a, String b) {
  final rows = a.length + 1;
  final cols = b.length + 1;
  final d = List<List<int>>.generate(
    rows,
    (i) => List<int>.generate(cols, (j) => i == 0 ? j : (j == 0 ? i : 0)),
  );
  for (var i = 1; i < rows; i++) {
    for (var j = 1; j < cols; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var value = math.min(
        math.min(d[i - 1][j] + 1, d[i][j - 1] + 1),
        d[i - 1][j - 1] + cost,
      );
      if (i > 1 &&
          j > 1 &&
          a[i - 1] == b[j - 2] &&
          a[i - 2] == b[j - 1]) {
        value = math.min(value, d[i - 2][j - 2] + 1);
      }
      d[i][j] = value;
    }
  }
  return d[a.length][b.length];
}
