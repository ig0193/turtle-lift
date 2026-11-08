import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// A quiet, full-width secondary action: "Add set", "See all N sessions",
/// "Edit workout".
///
/// **Extracted from `set_logging_screen.dart`.** It first existed there, under
/// the "See all N sessions" link below an exercise's recent log, as a private
/// `_GhostButton`. The History tab's "See all N sessions" button below the
/// Recent list is the same action for the same reason, so it moved here rather
/// than being retyped a second time. `divider_row.dart` gives the same
/// reasoning for `DividerRow`: the pattern belongs to neither screen that uses
/// it.
///
/// **Text, not a capsule.** A screen gets one filled capsule, its primary
/// action. Secondary actions drawn as full-width bordered capsules stacked
/// three to a screen beside it, and the eye could not find the one that
/// mattered. This keeps the 48pt tap target and drops the box.
///
/// **Chalk, never [AppPalette.accentStrong].** Amber means "worked / active /
/// record"; a secondary action is none of those.
///
/// **Not a `TextButton`.** Material's button classes bring a density, ripple
/// and text theme this app has nowhere -- the same reason [DividerRow] and
/// `TemplateRow` are not `ListTile`s.
class GhostButton extends StatelessWidget {
  const GhostButton({
    required this.label,
    required this.onTap,
    this.buttonKey,
    this.leadingIcon,
    this.trailingIcon,
    super.key,
  });

  /// Finds the button in a test without matching on its label, which carries a
  /// count and changes as data changes.
  final Key? buttonKey;

  final String label;
  final VoidCallback onTap;

  /// An icon before the label: `Icons.add_rounded` for an "add" action.
  final IconData? leadingIcon;

  /// An icon after the label: `Icons.chevron_right_rounded` for a link that
  /// opens another screen.
  final IconData? trailingIcon;

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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (leadingIcon != null) ...<Widget>[
                  Icon(leadingIcon, size: 20, color: AppPalette.textPrimary),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...<Widget>[
                  const SizedBox(width: 2),
                  Icon(trailingIcon, size: 20, color: AppPalette.textSecondary),
                ],
              ],
            ),
          ),
        ),
      );
}
