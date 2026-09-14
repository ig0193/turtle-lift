import 'package:flutter/material.dart';

import '../data/workout_templates.dart';
import '../theme/app_palette.dart';
import 'filter_glyph.dart';

/// The control that says which split the template list is filtered to, and
/// changes it.
///
/// **It shows the current filter's name, not just an icon.** With no
/// unfiltered "All" value, the list on screen is always a subset — so the one
/// thing the control must do is say *which* subset, or a user seeing three rows
/// concludes the app ships three templates. The icon alone cannot say that.
///
/// **Stateless about selection.** It takes [current] and reports [onSelected],
/// the same shape as `GlassTabBar` — the filter lives in a provider, and a
/// control that held its own copy would drift from it.
class TemplateFilterControl extends StatelessWidget {
  const TemplateFilterControl({
    required this.current,
    required this.onSelected,
    super.key,
  });

  final TemplateFilter current;
  final ValueChanged<TemplateFilter> onSelected;

  /// The tappable box. Its *size* is the accessibility contract; the chip
  /// drawn inside it is smaller on purpose.
  @visibleForTesting
  static const Key tapTargetKey = ValueKey<String>('template-filter-control');

  /// The visible chip, so a test can measure it without guessing which box in
  /// the header row it is.
  @visibleForTesting
  static const Key chipKey = ValueKey<String>('template-filter-chip');

  /// The accessibility floor, matching `ProfileAvatarButton.tapTarget`.
  ///
  /// This is the one control between the user and every template, tapped
  /// one-handed in a gym. The chip is ~34pt tall; the padding around it is
  /// what makes it hittable.
  static const double tapTarget = 48;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Filter templates',
      value: current.label,
      child: GestureDetector(
        key: tapTargetKey,
        // Opaque, so the whole 48pt box is the target rather than the chip
        // drawn inside it.
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: SizedBox(
          height: tapTarget,
          // `widthFactor: 1` rather than a `Center`: Center expands to fill the
          // loose constraints it is given, which made this control report the
          // full screen width as its bounds -- so the dropdown anchored to the
          // screen edge instead of to the chip.
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1,
            child: Container(
              key: chipKey,
              padding: const EdgeInsets.fromLTRB(11, 8, 10, 8),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppPalette.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const FilterGlyphIcon(),
                  const SizedBox(width: 7),
                  Text(current.label, style: kTemplateFilterChipStyle),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppPalette.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final chosen = await showTemplateFilterMenu(context, current: current);
    if (chosen != null) onSelected(chosen);
  }
}

/// `.chip` type: the same 12.5 the empty-state body uses, at the weight a
/// control needs.
const TextStyle kTemplateFilterChipStyle = TextStyle(
  fontSize: 12.5,
  fontWeight: FontWeight.w600,
  color: AppPalette.textPrimary,
);

/// Presents the three filters as a dropdown anchored under the chip, and
/// returns the chosen one, or null if dismissed.
///
/// **Anchored to the control, not a sheet.** The menu belongs to the chip that
/// opened it, so it drops from it — the user's eye never leaves the thing they
/// tapped. The trade is reach: this lands at the top of the screen, which is
/// the harder half to touch one-handed, and the chip's own 48pt target is what
/// keeps the round trip manageable.
///
/// **Built from the app's own surfaces rather than taking Material's.**
/// `lib/src/theme/app_theme.dart` sets no `popupMenuTheme`, so the defaults
/// would bring elevation and a tinted surface that appear nowhere else in this
/// app. Every visual property here is passed explicitly for that reason: flat,
/// palette-coloured, with the app's own border.
Future<TemplateFilter?> showTemplateFilterMenu(
  BuildContext context, {
  required TemplateFilter current,
}) {
  final button = context.findRenderObject()! as RenderBox;
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;

  final chip = Rect.fromPoints(
    button.localToGlobal(Offset.zero, ancestor: overlay),
    button.localToGlobal(
      button.size.bottomRight(Offset.zero),
      ancestor: overlay,
    ),
  );

  // Right edges aligned, dropping just below the control. `showMenu` places
  // the menu at `position.left` under LTR, so right-alignment is expressed by
  // subtracting the menu's own width rather than by setting `right`.
  const menuWidth = kTemplateFilterOptionWidth + kTemplateFilterOptionPadding * 2;

  return showMenu<TemplateFilter>(
    context: context,
    position: RelativeRect.fromLTRB(
      chip.right - menuWidth,
      chip.bottom + 4,
      overlay.size.width - chip.right,
      0,
    ),
    color: AppPalette.surface,
    // Flat, like every other surface. Material's default elevation would also
    // tint the surface off-palette.
    elevation: 0,
    constraints: const BoxConstraints(minWidth: menuWidth),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppPalette.border),
    ),
    items: <PopupMenuEntry<TemplateFilter>>[
      for (final filter in TemplateFilter.values)
        PopupMenuItem<TemplateFilter>(
          value: filter,
          height: 52,
          padding: const EdgeInsets.symmetric(
            horizontal: kTemplateFilterOptionPadding,
          ),
          child: _FilterOption(filter: filter, selected: filter == current),
        ),
    ],
  );
}

/// How wide one option row is, and therefore how wide the dropdown is.
const double kTemplateFilterOptionWidth = 176;

/// Horizontal padding inside each option row.
const double kTemplateFilterOptionPadding = 16;

/// The key for one option row, so a test can tap a named filter.
@visibleForTesting
Key templateFilterOptionKey(TemplateFilter filter) =>
    ValueKey<String>('template-filter-option-${filter.key}');

class _FilterOption extends StatelessWidget {
  const _FilterOption({required this.filter, required this.selected});

  final TemplateFilter filter;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // `AppPalette.accentStrong` is the right colour here and this is a
    // deliberate reading of the one-meaning rule, not an inherited default.
    // That colour means "active / trained / primary action" -- and a selected
    // option is unambiguously the active one. It is *not* borrowed for
    // anything merely derived (a streak, a count); those have no claim on it.
    final tint = selected ? AppPalette.accentStrong : AppPalette.textMuted;

    return Semantics(
      key: templateFilterOptionKey(filter),
      inMutuallyExclusiveGroup: true,
      selected: selected,
      // An explicit width, because the menu measures its items intrinsically
      // to decide how wide to be. An `Expanded` inside an unbounded row asks
      // for every pixel available, which sizes the dropdown to the whole
      // screen -- it still looks plausible, and the first option ends up under
      // wherever the user taps.
      child: SizedBox(
        width: kTemplateFilterOptionWidth,
        child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              filter.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: AppPalette.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tint, width: 1.6),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppPalette.accentStrong,
                      ),
                    ),
                  )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
