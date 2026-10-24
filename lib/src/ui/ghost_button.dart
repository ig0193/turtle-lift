import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// A full-width, bordered, secondary-surface button for a "see more" action.
///
/// **Extracted from `set_logging_screen.dart`.** It first existed there, under
/// the "See all N sessions" link below an exercise's recent log, as a private
/// `_GhostButton`. The History tab's "See all N sessions" button below the
/// Recent list is the same shape for the same reason -- a bordered row the
/// weight of a secondary action, never [AppPalette.accentStrong] -- so it moved
/// here rather than being retyped a second time. `divider_row.dart` gives the
/// same reasoning for `DividerRow`: the pattern belongs to neither screen that
/// uses it.
///
/// **Not a `TextButton` or an `OutlinedButton`.** Material's button classes
/// bring a density, ripple and text theme this app has nowhere -- the same
/// reason [DividerRow] and `TemplateRow` are not `ListTile`s.
class GhostButton extends StatelessWidget {
  const GhostButton({
    required this.label,
    required this.onTap,
    this.buttonKey,
    super.key,
  });

  /// Finds the button in a test without matching on its label, which carries a
  /// count and changes as data changes.
  final Key? buttonKey;

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          key: buttonKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppPalette.surface,
              border: Border.all(color: AppPalette.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppPalette.textSecondary,
              ),
            ),
          ),
        ),
      );
}
