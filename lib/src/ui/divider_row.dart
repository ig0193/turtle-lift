import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// The divider row the tab is built out of: a tappable band with a hairline
/// under it, whatever the caller stacks on the left, and a chevron on the
/// right.
///
/// **One shell, three rows.** `SubGroupRow`, `ExerciseRow` and
/// `SearchResultRow` are the prototype's `.row` three times over, and each had
/// spelled out the same six-deep skeleton — the semantics wrapper, the opaque
/// gesture box, the 48pt floor, the hairline, the 10pt gap, the chevron. Only
/// what goes in the left column actually differs between them. The pattern
/// underneath is still `template_row.dart`'s; this is that pattern without its
/// card.
///
/// **Its own file, and not `sub_group_row.dart`'s.** It lived there because the
/// sub-group row was the first of the three to be written, which is a fact
/// about the order the tab was built and not about what this widget is: two of
/// its three consumers had to import a file named after the third to reach it,
/// and the next one would have too. A shell shared by three screens is not a
/// detail of any one of them.
///
/// **Not a `ListTile`**, for the reason `template_row.dart` gives: Material's
/// tile brings its own density, ripple and text theme, none of which this app
/// has anywhere.
class DividerRow extends StatelessWidget {
  const DividerRow({
    required this.semanticsLabel,
    required this.onTap,
    required this.children,
    this.verticalPadding = defaultVerticalPadding,
    super.key,
  });

  /// What the whole row is read out as. The row excludes its children's own
  /// semantics, so this is the only thing said.
  final String semanticsLabel;

  final VoidCallback onTap;

  /// The left column's contents, top to bottom.
  final List<Widget> children;

  /// How much air the row carries above and below [children].
  ///
  /// **A parameter only because the three rows have already drifted.**
  /// `SubGroupRow` passes 11 where the other two take the default 10; nothing
  /// in the prototype or the docs asks for the difference and it looks
  /// unintentional, but unifying it would move pixels, so it is preserved
  /// until someone decides which of the two is right.
  final double verticalPadding;

  /// The default, and what the exercise and search rows use.
  static const double defaultVerticalPadding = 10;

  /// The minimum row height, matching `TemplateRow.minHeight` and the app's
  /// other tap targets.
  static const double minHeight = 48;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: minHeight),
          padding: EdgeInsets.symmetric(
            horizontal: 2,
            vertical: verticalPadding,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppPalette.border)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppPalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How a count of exercises is written, wherever one is written.
///
/// Three places say it — the sub-group row's second line, the exercise list's
/// header (upper-cased) and a search result's second line — and each had
/// re-derived the plural. One of them getting it wrong would show up as
/// "1 exercises" on exactly the sub-groups with a single lift.
///
/// It travels with [DividerRow] rather than staying behind: the same three
/// screens say it, for the same reason, and splitting the pair would put half
/// of what a row is made of in a file named after one of them.
String exerciseCountLabel(int count) =>
    '$count exercise${count == 1 ? '' : 's'}';
