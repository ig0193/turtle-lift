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
    this.isCustom = false,
    this.hidden = false,
    this.animation,
    this.animationGear,
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
        // Optional on the type, required of the shipped file: the validator
        // proves all 260 carry both, and `test/exercise_demo_test.dart` proves
        // the app can draw every one. A record without them — a user's own
        // exercise, later — simply has no demonstration.
        animation: json['animation'] as String?,
        animationGear: json['animationGear'] as String?,
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

  /// True for an exercise the user created (`docs/adr/0009-custom-exercises-and-template-editing.md`).
  ///
  /// **A custom exercise has no reviewed content.** Its four content fields are
  /// empty strings and must never be filled in by the app: nothing is
  /// generated, summarised or borrowed from a library exercise. Its page says
  /// so plainly instead (`CustomExerciseScreen`).
  final bool isCustom;

  /// A custom exercise the user hid from the picker (schema step 9). Always
  /// false for a library exercise. It is still found by id everywhere else —
  /// History, records, export — because a logged exercise cannot be deleted.
  final bool hidden;

  /// The movement pattern the detail page demonstrates, an id in
  /// `lib/src/demo/demo_catalogue.dart`. Generated from
  /// `assets/exercises/animation_map.py`; `null` means no demonstration.
  final String? animation;

  /// What the demonstration figure holds: `barbell`, `dumbbell`, `cable`,
  /// `none`, … (`GEARS` in `animation_map.py`).
  final String? animationGear;
}
