import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'personal_details_store.dart';

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
enum BodyGender {
  male,
  female,
  preferNotToSay;

  /// The gender a stored value names, or null when the value is absent or is
  /// one this build does not recognise.
  ///
  /// **Matched on [name], never on index** — `app_database.dart` stores the
  /// name for the same reason, so that reordering this enum cannot repaint a
  /// user's diagrams.
  ///
  /// Returning null rather than throwing mirrors `TemplateFilter.fromKey`: an
  /// unreadable stored value is a user who downgraded or hand-edited the
  /// database, and the right answer is the ordinary default, not a crash
  /// somewhere between the splash and the first body map.
  static BodyGender? fromName(String? stored) {
    if (stored == null) return null;
    for (final gender in values) {
      if (gender.name == stored) return gender;
    }
    return null;
  }
}

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

/// What a user who has never answered the Profile field sees.
///
/// `docs/04`: gender is "skippable, with a sensible default (the male asset
/// set) if left unset". A named constant rather than a literal at each fallback
/// so that the two places which fall back — [readStoredBodyGender] and
/// [initialBodyGenderProvider] — cannot disagree.
const BodyGender kDefaultBodyGender = BodyGender.male;

/// The gender the app started in, resolved **before the first frame**.
///
/// **This exists to be overridden, and `main()` is what overrides it** — the
/// same shape, and the same reasoning, as `initialTemplateFilterProvider`.
/// Reading the stored value asynchronously inside the provider would resolve a
/// frame or more after the tree first builds, and the Muscles tab draws a body
/// map on the very first frame: a user who chose the female artwork would watch
/// the male body render and then be replaced. There is no loading state that
/// makes that acceptable, and the fix costs one small row read before `runApp`.
///
/// The default here is what a test — or a missed override — gets.
final initialBodyGenderProvider = Provider<BodyGender>(
  (ref) => kDefaultBodyGender,
);

/// Resolves the stored gender name into a [BodyGender], falling back to
/// [kDefaultBodyGender].
///
/// Called once from `main()` before `runApp`. The fallback covers both a first
/// launch (nothing stored) and an unreadable value (a downgrade, or a
/// hand-edited database) — neither is worth failing the app's first body map
/// over, and both mean the same thing to the user: they never chose.
Future<BodyGender> readStoredBodyGender(PersonalDetailsStore store) async {
  final stored = await store.readBodyGender();
  return BodyGender.fromName(stored) ?? kDefaultBodyGender;
}

/// Which artwork the user picked, and the writer for that choice.
///
/// **A `Notifier`, not an `AsyncNotifier`** — see [initialBodyGenderProvider]
/// for why the read happens before the tree builds. And not a `StateProvider`,
/// which is legacy on Riverpod 3 (see `lib/src/ui/tab_index.dart`).
class BodyGenderNotifier extends Notifier<BodyGender> {
  @override
  BodyGender build() => ref.read(initialBodyGenderProvider);

  /// Render every body diagram in [gender]'s artwork, and remember it.
  ///
  /// The write is not skipped when [gender] already equals [state]. On a fresh
  /// install the male artwork is showing but nothing is stored, so choosing
  /// Male is a real answer — swallowing that write would leave "I chose" and "I
  /// never answered" indistinguishable on disk, and those are different states
  /// the Profile screen has to render.
  Future<void> select(BodyGender gender) async {
    state = gender;
    await ref.read(personalDetailsStoreProvider).writeBodyGender(gender.name);
  }
}

/// The gender every body diagram in the app renders in.
///
/// **Every diagram watches this one provider rather than taking a parameter**,
/// which is what makes `docs/04`'s "changing gender later in Profile
/// immediately switches the diagram set app-wide" true by construction instead
/// of by every caller remembering to thread it through. It is also why this
/// name survived the move from a constant to stored state: `body_diagram.dart`
/// and its tests already `ref.watch` it, and a rename would have been a
/// refactor of the one thing that was already right.
///
/// A test that wants a particular artwork overrides [initialBodyGenderProvider]
/// — the same seam `main()` uses, so the test exercises the shipped wiring
/// rather than a shortcut around it.
final bodyGenderProvider = NotifierProvider<BodyGenderNotifier, BodyGender>(
  BodyGenderNotifier.new,
);
