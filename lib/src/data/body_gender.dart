import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which side of the body a diagram shows.
///
/// **The name of the side is not the name of the asset**, and that is the whole
/// reason this file exists. `muscle_taxonomy.dart` records where a sub-muscle
/// group appears as `(view: 'front', segment: 'chest/mid')`, while
/// `body_paths.dart` keys its four assets as `frontMale` / `backFemale`. Two
/// vocabularies for one idea, both generated, neither editable. Joining them in
/// one place keeps every caller from re-deriving the join — and from getting it
/// subtly wrong for the one gender it was never tested against.
enum BodyView {
  front('front'),
  back('back');

  const BodyView(this.taxonomyView);

  /// The string `kSubMuscleGroups` uses in its `segments` records.
  final String taxonomyView;
}

/// The Profile gender field, verbatim from `docs/04` §Personal details:
/// "Options: Male / Female / Prefer not to say."
///
/// **It selects artwork and nothing else.** `docs/04` is explicit that gender
/// "doesn't gate any feature, it only changes which diagram renders", so this
/// enum deliberately carries no bodyweight, no formula, and no behaviour beyond
/// [bodyAssetKey]. [BodyGender.preferNotToSay] is a third option rather than a
/// null, because "I declined" and "I have not reached this screen yet" are the
/// same artwork but not the same answer, and the Profile tab has to render the
/// difference.
enum BodyGender { male, female, preferNotToSay }

/// The `kBodyAssets` key for [view] drawn in [gender]'s artwork.
///
/// Only two asset pairs exist, so [BodyGender.preferNotToSay] resolves to the
/// male pair — the same default `docs/04` gives an unset field, and R21 the
/// same. Tracing a third body was never on the table; what the third option
/// buys is that the Profile screen can say "prefer not to say" and mean it.
String bodyAssetKey(BodyView view, BodyGender gender) {
  final artwork = switch (gender) {
    BodyGender.female => 'Female',
    BodyGender.male || BodyGender.preferNotToSay => 'Male',
  };
  return '${view.name}$artwork';
}

/// The gender every body diagram in the app renders in.
///
/// **There is no Settings column behind this yet, and this unit adds none.**
/// `Settings` holds `id` and `workoutTemplateFilter`, the drift schema is at
/// version 1 with no migration steps, and adding a column here to store a value
/// nothing can yet set would mean a schema bump, a regenerated
/// `app_database.g.dart` and a migration — all to persist a default. So the
/// seam ships as a plain `Provider` returning [BodyGender.male], which is
/// exactly what `docs/04` specifies for an unset field.
///
/// When the Profile tab authors the field it replaces this provider's body with
/// the stored read; every diagram in the app already watches it, so the switch
/// is app-wide by construction rather than by remembering to pass it down.
final bodyGenderProvider = Provider<BodyGender>((ref) => BodyGender.male);
