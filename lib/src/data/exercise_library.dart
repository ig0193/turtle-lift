import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The 260 shipped exercises, in the order the generator wrote them.
///
/// Not keyed by anything -- it is the raw decoded array. Look-ups by id belong
/// on the `Exercise` type that build order step 1 introduces; until that lands,
/// callers index the maps themselves.
///
/// `setup` / `posture` / `execution` / `commonMistakes` are reviewed copy that
/// carries injury risk (CLAUDE.md). Read them, never rewrite or regenerate them.
final exerciseLibraryProvider =
    FutureProvider<List<Map<String, Object?>>>((ref) async {
  final raw = await rootBundle.loadString('assets/exercises/exercises.json');
  // The file is a generated, validated top-level array -- see
  // assets/exercises/validate_exercise_library.py. One shape, no fallback.
  return (jsonDecode(raw) as List).cast<Map<String, Object?>>();
});
