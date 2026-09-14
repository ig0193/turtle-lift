import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// A label, a chevron that turns, and a body that is shown or hidden by
/// tapping the label.
///
/// **Hand-rolled over the app's row idiom rather than an `ExpansionTile`**
/// (KTD7). Material's expansion widgets carry their own theming — a tile
/// colour, an icon colour, a divider, a `ListTile`'s density and ripple — none
/// of which exists anywhere in this app, and `test/theme_palette_test.dart`
/// fails on any colour outside `docs/00` §12. The same argument
/// `template_row.dart` makes against `ListTile` applies one level up.
///
/// **The body is present or absent, not faded or sized between two states.**
/// There is no `AnimatedCrossFade` or `AnimatedSize` anywhere in `lib/`, and
/// both would have to be told the collapsed height of text that is 15 words on
/// one exercise and 60 on the next. A row that simply has a child or does not
/// cannot get that wrong, and the chevron carries the state change.
class DisclosureRow extends StatefulWidget {
  const DisclosureRow({
    required this.label,
    required this.body,
    this.initiallyExpanded = false,
    this.emphasised = false,
    super.key,
  });

  /// The always-visible line. Written in the caller's own capitalisation —
  /// this widget does not upper-case it, for the reason
  /// `exerciseEquipmentLabel` gives about keeping display spelling at the call
  /// site.
  final String label;

  /// What the row reveals. Rendered verbatim: on the exercise page this is
  /// reviewed copy carrying injury risk (`CLAUDE.md`), so it is given no
  /// `maxLines` and no overflow treatment anywhere on the way down.
  final String body;

  /// Read once, when the row is first built — a later change does not reopen a
  /// row the reader has closed. Only one row on a page should be true.
  final bool initiallyExpanded;

  /// Draws the label a step brighter, for a field that must not be skimmed
  /// past.
  ///
  /// **Brightness, not colour.** The prototype paints this label
  /// `--accent2`, but `docs/00` §12 gives `#F0997B` exactly one meaning —
  /// "secondary muscle only" — and this page renders that colour ten
  /// centimetres above, on the body map, meaning precisely that. Two meanings
  /// for one colour on one screen is the confusion the eleventh palette entry
  /// was added to avoid, so the emphasis is carried by
  /// [AppPalette.textSecondary] against the other rows' [AppPalette.textMuted].
  final bool emphasised;

  /// The minimum height of the tappable label, matching the app's other tap
  /// targets.
  static const double minHeight = 48;

  @override
  State<DisclosureRow> createState() => _DisclosureRowState();
}

class _DisclosureRowState extends State<DisclosureRow> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppPalette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            button: true,
            expanded: _expanded,
            label: widget.label,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                constraints:
                    const BoxConstraints(minHeight: DisclosureRow.minHeight),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.label,
                        style: widget.emphasised
                            ? kDisclosureLabelEmphasisedStyle
                            : kDisclosureLabelStyle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedRotation(
                      // A quarter turn, so the chevron points down at what it
                      // has revealed. The duration matches the tab bar's own
                      // short transitions; it is feedback on a tap, not an
                      // effect.
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
              child: Text(widget.body, style: kDisclosureBodyStyle),
            ),
        ],
      ),
    );
  }
}

/// The label line: the section-label treatment, because a closed row is a
/// heading for something rather than content in its own right.
const TextStyle kDisclosureLabelStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.9,
  color: AppPalette.textMuted,
);

/// The same line, a step brighter — see [DisclosureRow.emphasised].
const TextStyle kDisclosureLabelEmphasisedStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.9,
  color: AppPalette.textSecondary,
);

/// The revealed text. Read standing, at arm's length, so it is set larger and
/// looser than anything else on the page — and with **no** `maxLines`: this is
/// the reviewed copy, and a clamp would drop the half of a cue that carries
/// the injury risk.
const TextStyle kDisclosureBodyStyle = TextStyle(
  fontSize: 13,
  height: 1.6,
  color: AppPalette.textSecondary,
);
