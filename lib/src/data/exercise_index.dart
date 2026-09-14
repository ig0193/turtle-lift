import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'exercise.dart';

/// The 260 shipped exercises, arranged for the three lookups the Muscles tab
/// makes: by id, by primary sub-muscle group, and by equipment.
///
/// **Built once, at boot, rather than scanned per screen.** The landing alone
/// needs a primary-muscle count for all 19 sub-groups on its first frame; doing
/// that as 19 linear passes over 260 records, on every rebuild of a list that
/// scrolls, is work this class does exactly once instead.
///
/// **The buckets are built eagerly in the constructor, not lazily on first
/// ask.** A lazy cache would need the index to be mutable and therefore unsafe
/// to hand around as a plain value; the whole fold is a few hundred map inserts
/// over data that is already in memory.
class ExerciseIndex {
  /// Folds a decoded library into its lookup tables.
  ///
  /// Takes the raw decoded array so there is exactly one place the shipped
  /// shape is read — `exerciseLibraryProvider` does the asset read and the
  /// decode, and nothing else in the app touches `rootBundle` for this file.
  factory ExerciseIndex.fromJson(List<Map<String, Object?>> records) =>
      ExerciseIndex(records.map(Exercise.fromJson).toList(growable: false));

  ExerciseIndex(List<Exercise> exercises)
      : all = List<Exercise>.unmodifiable(exercises),
        _byId = <String, Exercise>{
          for (final exercise in exercises) exercise.id: exercise,
        },
        _byPrimary = _bucketBy(exercises, (e) => e.primary),
        _byEquipment = _bucketBy(exercises, (e) => <String>[e.equipment]);

  /// Every exercise, in the order the generator wrote them.
  ///
  /// That order is the library's own and is not alphabetical. A screen that
  /// wants a sorted list sorts it; the index does not impose one, because the
  /// sub-group and equipment lists each want a different one.
  final List<Exercise> all;

  final Map<String, Exercise> _byId;
  final Map<String, List<Exercise>> _byPrimary;
  final Map<String, List<Exercise>> _byEquipment;

  /// The exercise with [id], or null when nothing carries it.
  ///
  /// **Null rather than a throw**, matching `TemplateFilter.fromKey`: an id
  /// that misses is a stale route argument or a hand-typed link, and the caller
  /// is better placed to decide whether that is an empty state or a bug.
  Exercise? byId(String id) => _byId[id];

  /// Every exercise that trains [subGroupId] **directly**.
  ///
  /// Secondary involvement is deliberately excluded (R10): a muscle's exercise
  /// list is what to do to train it, and folding in every lift that merely
  /// works it would make most lists near-identical.
  ///
  /// Returns an empty list for an id no exercise names, including one the
  /// taxonomy does not have.
  List<Exercise> withPrimary(String subGroupId) =>
      _byPrimary[subGroupId] ?? const <Exercise>[];

  /// Every exercise using [equipment], for the equipment result R13 opens.
  List<Exercise> withEquipment(String equipment) =>
      _byEquipment[equipment] ?? const <Exercise>[];

  /// The equipment values the library actually uses, sorted.
  ///
  /// **Derived from the data rather than declared**, so that regenerating the
  /// library with a ninth value surfaces it in search instead of hiding it
  /// behind a hard-coded list. The U1 test is what pins the current set at 8.
  late final List<String> equipmentValues =
      List<String>.unmodifiable(_byEquipment.keys.toList()..sort());

  /// The exercises whose name contains [query], ignoring case and surrounding
  /// whitespace.
  ///
  /// **Substring, not prefix.** "bench press" has to find "Barbell bench
  /// press" — nearly every name in the library leads with its equipment, so a
  /// prefix match would demand the user already know which bar the lift is on.
  ///
  /// **An empty or blank query matches nothing, not everything.** Search here
  /// is one field over three vocabularies (R11); returning all 260 for an empty
  /// box would bury the muscle and equipment matches under the whole library
  /// before the user has typed anything.
  List<Exercise> searchByName(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const <Exercise>[];
    return <Exercise>[
      for (final exercise in all)
        if (exercise.name.toLowerCase().contains(needle)) exercise,
    ];
  }

  static Map<String, List<Exercise>> _bucketBy(
    List<Exercise> exercises,
    List<String> Function(Exercise) keysOf,
  ) {
    final buckets = <String, List<Exercise>>{};
    for (final exercise in exercises) {
      for (final key in keysOf(exercise)) {
        buckets.putIfAbsent(key, () => <Exercise>[]).add(exercise);
      }
    }
    return <String, List<Exercise>>{
      for (final entry in buckets.entries)
        entry.key: List<Exercise>.unmodifiable(entry.value),
    };
  }
}

/// The exercise library, indexed and available **synchronously on the first
/// frame**.
///
/// **This exists to be overridden, and `main()` is what overrides it** — the
/// same boot seam as `initialTemplateFilterProvider`, for the same reason: no
/// tab root in this app renders an `AsyncValue`, and the Muscles landing needs
/// a per-sub-group exercise count before it can draw a single row.
///
/// **Unlike that provider, this one throws instead of falling back.** A missed
/// override there costs a user one wrong filter on a screen they can correct in
/// a tap, so a default is the kinder answer. Here there is no honest default:
/// an empty index renders all 19 muscle rows as zero, every exercise list as
/// blank and every search as no-results, and it does it silently, on a tab
/// whose entire purpose is the content that went missing. Failing loudly is the
/// point.
///
/// **Loudly is not the same as early, and this doc used to conflate them.** The
/// U1 test reads this provider without an override and asserts the throw, which
/// proves only that the throw exists; it says nothing about whether `main()`
/// still installs the override, because it never runs `main()`. What closes
/// that gap is `test/boot_test.dart`, which boots the real entrypoint and looks
/// for the Muscles root — so dropping the boot wiring now fails in CI rather
/// than on a device.
final exerciseIndexProvider = Provider<ExerciseIndex>(
  (ref) => throw UnimplementedError(
    'exerciseIndexProvider must be overridden. main() builds the index from '
    'exerciseLibraryProvider before runApp; a test wanting the real library '
    'does the same, or overrides this with an index of its own fixtures.',
  ),
);
