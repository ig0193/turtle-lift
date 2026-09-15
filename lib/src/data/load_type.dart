/// What a set of an exercise consists of.
///
/// **The typed view of `Exercise.loadType`, which is a string on purpose.**
/// `exercise.dart` keeps the shipped value as it appears in
/// `assets/exercises/exercises.json`; this enum is where the four-way decision
/// lives, so a screen never switches on a bare string.
///
/// **Resolved by name, not by a separate stored key.** The four shipped strings
/// are already valid Dart identifiers, so `BodyGender.fromName` is the
/// precedent here rather than `TemplateFilter.fromKey` — that one needs a key
/// because its persisted values (`single`, `multi`, `ppl`) differ from its
/// member names. Inventing a key here would invent a distinction the data does
/// not have.
///
/// **Every numeric input is unsigned.** The sign is carried by the type, never
/// typed by the user: assistance is its own field on its own load type, so
/// nobody can book a `+30kg` record on an assist machine.
enum LoadType {
  /// 196 exercises. A weight and a rep count.
  weighted,

  /// 47 exercises. Reps, with optional added weight.
  bodyweight,

  /// 3 exercises. Machine assistance and reps.
  ///
  /// **The one place in the app where a smaller number is the record.**
  assisted,

  /// 14 exercises. A duration, with optional weight.
  timed;

  /// The load type [stored] names, or null when it is absent or is one this
  /// build does not recognise.
  ///
  /// Returning null rather than throwing matches `TemplateFilter.fromKey`: an
  /// unreadable stored value is a downgrade or a hand-edited database, and the
  /// right answer is a caller that can decide, not a crash.
  static LoadType? fromName(String? stored) {
    if (stored == null) return null;
    for (final type in values) {
      if (type.name == stored) return type;
    }
    return null;
  }

  /// The field a set of this type must have above zero to count as completed.
  ///
  /// `docs/00` §2 fixes this per type, and the completion rule, the set count,
  /// the streak and the calorie tier all read it from here rather than each
  /// repeating the table.
  bool get countsDuration => this == LoadType.timed;

  /// Whether this type offers the collapsed optional-weight chip.
  ///
  /// Offered on every bodyweight and timed exercise with no capability flags —
  /// `docs/01` decided that auditing 61 exercises to hide a chip nobody would
  /// notice is not worth it.
  bool get hasOptionalWeight =>
      this == LoadType.bodyweight || this == LoadType.timed;
}
