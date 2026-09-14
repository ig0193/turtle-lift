import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// [kLandingSectionLabelStyle] was written here and then read by both tabs, so
/// it now lives in `app_typography.dart`, which neither tab owns. Re-exported
/// rather than moved outright: this file's own callers ask it for the label
/// their rows sit under, and that is a fair thing to ask a row file for.
export '../theme/app_typography.dart' show kLandingSectionLabelStyle;

/// One tappable row on the Workout landing: a name, a line beneath it, and a
/// chevron.
///
/// **The first list row in the app, so this is the pattern the rest inherits.**
/// There was nothing to copy — no card, no list tile, no row widget existed —
/// which is why the measurements are written down here rather than left to a
/// `ListTile`'s defaults. Material's tile would bring its own density, ripple
/// and text theme, none of which this app has elsewhere.
///
/// **Sized for a thumb, not for a cursor.** The landing is opened standing, in
/// a gym, often one-handed and between sets. The vertical padding is what
/// carries the row past the 48pt floor even when the subtitle wraps to nothing.
class TemplateRow extends StatelessWidget {
  const TemplateRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.background = AppPalette.surface,
    super.key,
  });

  final String title;

  /// The muscle groups this template covers, or what the entry does. Never
  /// empty — a row with a blank second line reads as broken data.
  final String subtitle;

  final VoidCallback onTap;

  /// [AppPalette.surface] for a template; [AppPalette.mutedSurface] for the
  /// ad-hoc entry, which is a different kind of thing rather than one more
  /// template.
  final Color background;

  /// The minimum row height, matching the app's other tap target
  /// (`ProfileAvatarButton.tapTarget`).
  static const double minHeight = 48;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: minHeight),
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppPalette.border),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title, style: kTemplateRowTitleStyle),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: kTemplateRowSubtitleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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

/// The row's name.
const TextStyle kTemplateRowTitleStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.1,
  color: AppPalette.textPrimary,
);

/// The muscle-group line. Muted rather than secondary: it is supporting detail
/// under a name the eye lands on first.
const TextStyle kTemplateRowSubtitleStyle = TextStyle(
  fontSize: 11.5,
  color: AppPalette.textMuted,
);

/// The count line under the filter control.
const TextStyle kLandingCountStyle = TextStyle(
  fontSize: 11.5,
  color: AppPalette.textMuted,
);
