import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';

/// A low-emphasis pill: an affordance for something that has nothing to show
/// yet, or a small value once it has.
///
/// **The alternative is a bordered field on every row, forever.** A notes input
/// and a rest-timer line rendered under every exercise cost two rows of
/// furniture each, on every block, stating the absence of a feature. As a chip
/// the same affordance costs half a row and disappears into the page until it
/// holds something.
///
/// Shared by the live workout and the routine screen so the two cannot drift —
/// they render the same two affordances against the same two fields.
class GhostChip extends StatelessWidget {
  const GhostChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.chipKey,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Whether this carries a value rather than offering to take one. An active
  /// chip earns accent and weight; an empty one stays out of the way.
  final bool active;

  final Key? chipKey;

  @override
  Widget build(BuildContext context) {
    final colour = active ? AppPalette.accentLight : AppPalette.textMuted;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        height: AppMetrics.touchTarget,
        child: InkWell(
          key: chipKey,
          borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppMetrics.gapSnug),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 15, color: colour),
                const SizedBox(width: AppMetrics.gapTight + 2),
                Text(
                  label,
                  style: TextStyle(
                    color: colour,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The rest-timer options, shared by both screens that offer one.
const List<int?> kRestTimerOptions = <int?>[null, 30, 45, 60, 90, 120, 180];
