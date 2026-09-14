/// One of the 260 shipped exercises, typed over the keys the generator writes.
///
/// **Typed rather than the raw map `exerciseLibraryProvider` yields.** That
/// provider's own doc defers a keyed type to the data layer, and this is it:
/// four screens look an exercise up by id, by primary sub-group and by
/// equipment, and raw `Map<String, Object?>` would push a cast and a key
/// spelling into every one of those call sites.
///
/// **Every field is stored, and none is derived.** The app's rule is the
/// reverse — nothing computable is stored (`CLAUDE.md`) — but that rule is
/// about the user's training history, which is editable. This is read-only
/// shipped content: there is no session to recompute it from, and the JSON is
/// the source of truth.
library;

/// A single exercise's reference content.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.equipment,
    required this.loadType,
    required this.primary,
    required this.secondary,
    required this.setup,
    required this.posture,
    required this.execution,
    required this.commonMistakes,
  });

  /// Reads one record of the shipped array.
  ///
  /// **No tolerance for a missing key and no defaults.** The file is generated
  /// and validated by `assets/exercises/validate_exercise_library.py`, which
  /// already proves all ten keys are present on all 260 records. A fallback
  /// here would turn a broken regeneration into a screen full of blanks rather
  /// than a failure at boot, which is the wrong trade for content a reader is
  /// about to lift a barbell on.
  factory Exercise.fromJson(Map<String, Object?> json) => Exercise(
        id: json['id']! as String,
        name: json['name']! as String,
        equipment: json['equipment']! as String,
        loadType: json['loadType']! as String,
        primary: (json['primary']! as List).cast<String>(),
        secondary: (json['secondary']! as List).cast<String>(),
        setup: json['setup']! as String,
        posture: json['posture']! as String,
        execution: json['execution']! as String,
        commonMistakes: json['commonMistakes']! as String,
      );

  /// Stable across renames of [name]; this is what a screen route and, later, a
  /// logged set will reference.
  final String id;

  /// What the exercise is called, as the library spells it.
  final String name;

  /// One of the 8 shipped values — `barbell`, `dumbbell`, `machine`, `cable`,
  /// `bodyweight`, `bands`, `kettlebell`, `other`.
  ///
  /// **A string, not an enum.** The values come from generated data that is
  /// re-run and re-validated on its own, so an enum here would be a second
  /// copy of a list this file does not own; `ExerciseIndex.equipmentValues`
  /// derives the set from the library instead, and the U1 test pins it to 8.
  final String equipment;

  /// One of `weighted`, `bodyweight`, `assisted`, `timed`.
  ///
  /// Kept as the shipped string for the same reason as [equipment]. The
  /// set-logging screen of build-order step 2 is what gives this behaviour —
  /// including the inverted `assisted` record — and the Muscles tab only
  /// displays it.
  final String loadType;

  /// Sub-muscle group ids this exercise trains directly, shaped `group/sub`.
  ///
  /// **A list, not one id.** 31 of the 260 name two or more, so "the primary
  /// muscle" is not a single value and a screen that assumes it is will
  /// mislabel a third of the library.
  final List<String> primary;

  /// Sub-muscle group ids it also works, shaped `group/sub`. Empty for 72 of
  /// the shipped exercises, which is data rather than an omission.
  final List<String> secondary;

  /// Reviewed copy. **Never rewrite, summarise or regenerate these four**
  /// (`CLAUDE.md`) — they carry injury risk and render verbatim.
  final String setup;

  /// Reviewed copy — see [setup].
  final String posture;

  /// Reviewed copy — see [setup].
  final String execution;

  /// Reviewed copy — see [setup].
  final String commonMistakes;
}
