import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/custom_templates.dart';
import '../data/workout_templates.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'divider_row.dart';
import 'personal_details_screen.dart';
import 'template_library_screen.dart';
import 'empty_state.dart';

/// Where the "My workout templates" row goes.
///
/// **A seam, not an import, and the seam is the point.** Three units were
/// building this screen and its two destinations at the same time, so the row
/// could not name a class that did not exist yet. It survives that scheduling
/// accident because it is also the only way to test this screen for what it is
/// — a list of four doors — without standing up whatever lives behind each
/// door, its providers and its database.
///
/// **A [WidgetBuilder] rather than a `Widget`**, because the destination is
/// built when the row is tapped and handed straight to
/// [MaterialPageRoute.builder]. A pre-built `Widget` would be constructed on
/// every rebuild of this screen whether or not anyone ever opened it.
///
/// **Every destination is a push, including the two data actions.** A push is
/// the only navigation this app has that covers the floating tab bar (see
/// `L0Shell`), and "delete everything on this device" is the last thing that
/// should be confirmable from a dialog with the tab bar still inviting you
/// elsewhere behind it. A destination that wants a dialog can push a screen
/// that shows one; a destination that pushes cannot be un-pushed into a sheet
/// without that regression.
///
/// **To wire a real screen in, replace this provider's default body** — one
/// line, here, where the placeholder is. Tests override it by value:
/// `profileTemplatesDestinationProvider.overrideWithValue((_) => const Foo())`.
final profileTemplatesDestinationProvider = Provider<WidgetBuilder>(
  (ref) => (_) => const TemplateLibraryScreen(),
);

/// Where the "Personal details" row goes. See
/// [profileTemplatesDestinationProvider] for the shape and how to wire it.
final profilePersonalDetailsDestinationProvider = Provider<WidgetBuilder>(
  (ref) => (_) => const PersonalDetailsScreen(),
);

/// Where the "Export everything" row goes. See
/// [profileTemplatesDestinationProvider] for the shape and how to wire it.
final profileExportDestinationProvider = Provider<WidgetBuilder>(
  (ref) => (_) => const _UnbuiltDestination(title: exportRowTitle),
);

/// Where the "Delete all data" row goes. See
/// [profileTemplatesDestinationProvider] for the shape and how to wire it —
/// and note that the row's destructive tint is this screen's, not the
/// destination's: replacing the builder does not change how the row is
/// painted.
final profileDeleteAllDestinationProvider = Provider<WidgetBuilder>(
  (ref) => (_) => const _UnbuiltDestination(title: deleteAllRowTitle),
);

/// The first row: the user's template library, predefined and custom together.
const String templatesRowTitle = 'My workout templates';

/// The second row: bodyweight series and body-diagram gender.
const String personalDetailsRowTitle = 'Personal details';

/// The third row: the escape hatch out of the app with your data in hand.
const String exportRowTitle = 'Export everything';

/// The fourth row, and the only destructive one in the app so far.
const String deleteAllRowTitle = 'Delete all data';

/// The second line under [templatesRowTitle].
///
/// **Both numbers are authored, and that is why this screen is allowed to show
/// them at all** (KD1, R2). [predefined] is the length of a `const` list
/// compiled into the app; [custom] is a count of rows the user typed. Neither
/// is computed from a session, so neither goes stale when a session is edited
/// or deleted, and neither belongs on the History tab. Any figure that *is*
/// computed from session rows — streak, workouts, sets, personal bests,
/// calories — lives on the History tab and may not appear here; the sweep in
/// `test/profile_screen_test.dart` is what enforces that rather than this
/// comment.
///
/// Written here rather than inline so the test can build the expected string
/// from the same source the screen does, instead of re-typing the format and
/// passing while the screen says something else.
String templateCountLabel({required int predefined, required int custom}) =>
    '$predefined predefined · $custom custom';

/// The second line under [personalDetailsRowTitle]. Names the two things that
/// screen holds, because "Personal details" alone does not say whether that is
/// a weight, a name or an account — and this app has no account.
const String personalDetailsRowSubtitle = 'Weight log · gender';

/// The destination behind the L0 header avatar: everything the app remembers
/// because the user *told* it, and the two ways out of it.
///
/// **Authored lives here; derived lives on the History tab** (KD1). The split
/// is not a layout preference — it is the same axis `app_database.dart` already
/// sorts storage on ("Everything here is a preference, never a derived value"),
/// so a field's home on screen and its home in the schema can never disagree,
/// and the next field the app grows is placed by the rule rather than by
/// argument. Concretely: no streak, no workout or set count, no personal-best
/// tally and no calorie figure appears on this screen. `docs/04` §Screen list
/// says the same thing ("**No stats summary**").
///
/// **`prototypes/screens.html` screen 4 is stale here and is deliberately not
/// followed.** It still renders the three-stat grid and the history list that
/// `docs/adr/0003-l0-navigation-variant-a.md` moved to the History tab. The
/// prototype leads the docs on *layout*; it does not lead them on *where a
/// figure lives*, and this is that case. The corrected mockup in `docs/04`
/// §Profile landing — four rows, two groups, nothing derived — is what this
/// screen is built from.
///
/// **Four rows, and the fourth is the reason the palette has eleven colours.**
/// Delete-all is painted [AppPalette.danger]; nothing else on this screen is.
///
/// **A `ConsumerWidget`** only to read the custom-template count and the four
/// destination seams. It watches no session provider, and a future edit that
/// makes it watch one is the regression the test sweep is aimed at.
///
/// The body is a `ListView` carrying [screenScrollPadding] — four rows do not
/// fill a phone today, but a pushed screen still picks up the home indicator on
/// the bottom edge, and there is one rule for that edge rather than one per
/// screen. **No `SafeArea`**: see [AppScreen]'s doc for why adding one silently
/// zeroes that padding.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// The heading over the two rows that lead to the user's own content.
  @visibleForTesting
  static const String yoursGroupLabel = 'YOURS';

  /// The heading over the two data actions. Separate from [yoursGroupLabel]
  /// because these two do not open your things — they hand all of them over or
  /// destroy all of them, and a row that erases everything should not sit in
  /// the same block as a row that renames a template.
  @visibleForTesting
  static const String dataGroupLabel = 'DATA';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The only provider this screen reads for *content*, and it is authored
    // data: templates the user saved. Watched rather than read, so adding a
    // template and coming back shows the new count.
    final customCount = ref.watch(customTemplatesProvider).length;

    return AppScreen.pushed(
      title: 'Profile',
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const _GroupLabel(ProfileScreen.yoursGroupLabel),
          _ProfileRow(
            id: 'templates',
            title: templatesRowTitle,
            subtitle: templateCountLabel(
              predefined: kPredefinedTemplates.length,
              custom: customCount,
            ),
            destination: profileTemplatesDestinationProvider,
          ),
          _ProfileRow(
            id: 'personal-details',
            title: personalDetailsRowTitle,
            subtitle: personalDetailsRowSubtitle,
            destination: profilePersonalDetailsDestinationProvider,
          ),
          const _GroupLabel(ProfileScreen.dataGroupLabel),
          _ProfileRow(
            id: 'export',
            title: exportRowTitle,
            destination: profileExportDestinationProvider,
          ),
          _ProfileRow(
            id: 'delete-all',
            title: deleteAllRowTitle,
            destructive: true,
            destination: profileDeleteAllDestinationProvider,
          ),
        ],
      ),
    );
  }
}

/// A section heading with the air the mockup gives it above and below.
///
/// Announced as a header, matching `MusclesRoot` and `WorkoutRoot`: a screen
/// reader moving by heading has to be able to tell "yours" from "data", which
/// is the whole distinction the two groups exist to draw.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 6),
      child: Semantics(
        header: true,
        child: Text(label, style: kLandingSectionLabelStyle),
      ),
    );
  }
}

/// One row of the profile list: a title, an optional second line, a chevron,
/// and the push it performs.
///
/// **[DividerRow], not the Workout landing's card** — `docs/04`'s mockup draws these
/// four as hairline-separated bands under a section label, not as bordered
/// cards, and the app already owns that shell. And not a `ListTile`, for the
/// reason `template_row.dart` and `disclosure_row.dart` both give (KTD7):
/// Material's tile brings a density, a ripple and a text theme that exist
/// nowhere in this app, and `test/theme_palette_test.dart` fails on any colour
/// outside `docs/00` §12.
///
/// **It reads its own destination.** The alternative — the screen reading four
/// providers and passing four callbacks down — puts the navigation of every row
/// in one build method and makes each row's `onTap` a closure over something it
/// cannot name. Here the row owns the pair "which door" / "how doors open", and
/// the screen owns the list.
class _ProfileRow extends ConsumerWidget {
  const _ProfileRow({
    required this.id,
    required this.title,
    required this.destination,
    this.subtitle,
    this.destructive = false,
  });

  /// The stable half of [profileRowKey], so a test reaches a row by what it is
  /// rather than by its position in a list that is about to grow.
  final String id;

  final String title;

  /// The second line, or null for a row whose title says everything. Unlike
  /// `TemplateRow`, a blank line here is a real answer: "Export everything"
  /// has nothing to add, and inventing a line for it would be noise on a row
  /// that must read as an action.
  final String? subtitle;

  /// Painted in [AppPalette.danger] — reserved for the destructive action and
  /// used on exactly one row in the app. The chevron stays
  /// [AppPalette.textMuted] (it is [DividerRow]'s, and the same on every row):
  /// the warning belongs to the words, and a red arrow on a row that only
  /// *opens* a confirmation would be crying wolf one screen early.
  final bool destructive;

  /// The seam this row pushes. See [profileTemplatesDestinationProvider].
  final Provider<WidgetBuilder> destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DividerRow(
      key: profileRowKey(id),
      semanticsLabel: subtitle == null ? title : '$title. $subtitle',
      onTap: () => Navigator.of(context).push(
        // Opaque, like every other push in this app: only an opaque route
        // covers the floating tab bar, and every one of these four screens is
        // somewhere you go rather than something you glance at.
        MaterialPageRoute<void>(builder: ref.read(destination)),
      ),
      children: <Widget>[
        Text(
          title,
          style: destructive
              ? kProfileRowDestructiveTitleStyle
              : kProfileRowTitleStyle,
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: kProfileRowSubtitleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// The row for [id], so a test can tap "delete all" without matching on copy.
@visibleForTesting
Key profileRowKey(String id) => ValueKey<String>('profile-row-$id');

/// What is behind a destination that has not been built yet.
///
/// **A real screen rather than a no-op tap.** A row that does nothing when
/// tapped is indistinguishable from a bug, and this app's own rule is that a
/// push must be an [AppScreen.pushed] on an opaque route (see `L0Shell`) — so
/// the placeholder is the same shape as the thing that replaces it, and
/// swapping one in changes a builder rather than a navigation model.
///
/// Delete this class when the last of the four seams points at a real screen.
class _UnbuiltDestination extends StatelessWidget {
  const _UnbuiltDestination({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AppScreen.pushed(
      title: title,
      body: ListView(
        padding: screenScrollPadding(context),
        children: const <Widget>[
          SizedBox(height: 24),
          Text('Not built yet.', style: kEmptyStateBodyStyle),
        ],
      ),
    );
  }
}

/// The row's name.
///
/// **Half a point larger than `kSubGroupRowLabelStyle`'s 13.5**, which is the
/// setting tuned for scanning a list of nineteen. This list is four rows read
/// once, at the top of the screen you reach from the avatar, and `docs/04`'s
/// mockup sets it at 14. The pair below moves with it.
const TextStyle kProfileRowTitleStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.1,
  color: AppPalette.textPrimary,
);

/// [kProfileRowTitleStyle] in the destructive colour. A separate `const`
/// rather than a `copyWith` at the call site so the one place the app spends
/// [AppPalette.danger] is greppable.
const TextStyle kProfileRowDestructiveTitleStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.1,
  color: AppPalette.danger,
);

/// The second line. Muted, like every other supporting line in the app — it
/// says what is behind the row, and the row's name is what the eye lands on.
const TextStyle kProfileRowSubtitleStyle = TextStyle(
  fontSize: 12,
  color: AppPalette.textMuted,
);
