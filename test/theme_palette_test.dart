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
      // AppPalette.onAccent is the same value as pageBackground (graphite
      // does both jobs), so it is already in the set.
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

  test('the palette is exactly §12 (Chalk & Shell)', () {
    // The values, pinned. A role drifting to a nearby hex would still pass the
    // scheme walk above, because that walk compares against AppPalette itself.
    expect(AppPalette.pageBackground, const Color(0xFF0E0E0F));
    expect(AppPalette.surface, const Color(0xFF18181A));
    expect(AppPalette.border, const Color(0xFF2E2E32));
    expect(AppPalette.mutedSurface, const Color(0xFF222225));
    expect(AppPalette.textPrimary, const Color(0xFFEDEDEB));
    expect(AppPalette.textSecondary, const Color(0xFFA3A3A7));
    expect(AppPalette.textMuted, const Color(0xFF8B8B90));
    expect(AppPalette.accentStrong, const Color(0xFFFFA53D));
    expect(AppPalette.accentLight, const Color(0xFF93ABCB));
    expect(AppPalette.onAccent, AppPalette.pageBackground);
    expect(AppPalette.danger, const Color(0xFFFF7A85));
  });

  test('the primary button is a chalk capsule with no gradient', () {
    // §12: primary action = chalk fill, dark label. Amber means "worked /
    // active / record" and is not a button colour.
    final style = buildAppTheme().filledButtonTheme.style!;
    expect(style.backgroundColor!.resolve(<WidgetState>{}),
        AppPalette.textPrimary);
    expect(style.foregroundColor!.resolve(<WidgetState>{}),
        AppPalette.onAccent);
    expect(style.backgroundBuilder, isNull,
        reason: '§12: no gradients; nothing is painted over the fill');
  });
}
