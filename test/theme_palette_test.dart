import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';

/// Guards docs/00-build-spec.md §12: "No other colours."
///
/// This exists because the failure it catches is invisible: a ColorScheme role
/// left unset does not throw and does not look wrong in code -- it silently
/// keeps Material 3's lavender baseline, and only shows up when some widget
/// deep in a screen reaches for it.
void main() {
  test('the ColorScheme introduces no colour outside §12', () {
    // §12 ends "No other colours." An unset ColorScheme role silently keeps
    // Material's lavender baseline, so this walks every role on the built
    // scheme and fails on anything not in the palette.
    final allowed = <Color>{
      AppPalette.pageBackground,
      AppPalette.surface,
      AppPalette.border,
      AppPalette.mutedSurface,
      AppPalette.textPrimary,
      AppPalette.textSecondary,
      AppPalette.textMuted,
      AppPalette.accentStrong,
      AppPalette.accentLight,
      AppPalette.onAccent,
      AppPalette.danger,
      // Overlays, not palette entries.
      Color(0xFF000000),
      Color(0x00000000),
    };

    final scheme = buildAppTheme().colorScheme;
    final roles = <String, Color>{
      'primary': scheme.primary,
      'onPrimary': scheme.onPrimary,
      'primaryContainer': scheme.primaryContainer,
      'onPrimaryContainer': scheme.onPrimaryContainer,
      'primaryFixed': scheme.primaryFixed,
      'primaryFixedDim': scheme.primaryFixedDim,
      'onPrimaryFixed': scheme.onPrimaryFixed,
      'onPrimaryFixedVariant': scheme.onPrimaryFixedVariant,
      'secondary': scheme.secondary,
      'onSecondary': scheme.onSecondary,
      'secondaryContainer': scheme.secondaryContainer,
      'onSecondaryContainer': scheme.onSecondaryContainer,
      'secondaryFixed': scheme.secondaryFixed,
      'secondaryFixedDim': scheme.secondaryFixedDim,
      'onSecondaryFixed': scheme.onSecondaryFixed,
      'onSecondaryFixedVariant': scheme.onSecondaryFixedVariant,
      'tertiary': scheme.tertiary,
      'onTertiary': scheme.onTertiary,
      'tertiaryContainer': scheme.tertiaryContainer,
      'onTertiaryContainer': scheme.onTertiaryContainer,
      'tertiaryFixed': scheme.tertiaryFixed,
      'tertiaryFixedDim': scheme.tertiaryFixedDim,
      'onTertiaryFixed': scheme.onTertiaryFixed,
      'onTertiaryFixedVariant': scheme.onTertiaryFixedVariant,
      'error': scheme.error,
      'onError': scheme.onError,
      'errorContainer': scheme.errorContainer,
      'onErrorContainer': scheme.onErrorContainer,
      'surface': scheme.surface,
      'onSurface': scheme.onSurface,
      'surfaceDim': scheme.surfaceDim,
      'surfaceBright': scheme.surfaceBright,
      'surfaceContainerLowest': scheme.surfaceContainerLowest,
      'surfaceContainerLow': scheme.surfaceContainerLow,
      'surfaceContainer': scheme.surfaceContainer,
      'surfaceContainerHigh': scheme.surfaceContainerHigh,
      'surfaceContainerHighest': scheme.surfaceContainerHighest,
      'onSurfaceVariant': scheme.onSurfaceVariant,
      'outline': scheme.outline,
      'outlineVariant': scheme.outlineVariant,
      'inverseSurface': scheme.inverseSurface,
      'onInverseSurface': scheme.onInverseSurface,
      'inversePrimary': scheme.inversePrimary,
      'shadow': scheme.shadow,
      'scrim': scheme.scrim,
      'surfaceTint': scheme.surfaceTint,
    };

    for (final entry in roles.entries) {
      expect(
        allowed,
        contains(entry.value),
        reason: 'ColorScheme.${entry.key} is off-palette (§12): '
            '${entry.value}',
      );
    }

    // §12: accent light is "secondary muscle only, never a primary action".
    // The scheme is where Material reaches for interactive chrome, so it must
    // not appear here at all.
    expect(
      roles.values,
      isNot(contains(AppPalette.accentLight)),
      reason: 'accentLight must stay out of the ColorScheme (§12)',
    );
  });
}
