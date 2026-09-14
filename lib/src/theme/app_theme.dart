import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Dark-only. There is no light theme: the palette in §12 is the whole app.
ThemeData buildAppTheme() {
  // Every role is set explicitly. `00` §12 ends "No other colours", and an
  // unset role is not neutral -- it keeps Material 3's baseline dark scheme,
  // which is lavender. Any widget reaching for a role we skipped (a Chip, a
  // Slider, the date picker behind the editable `performedOn`) would paint
  // off-palette. Roles with no counterpart in §12 resolve to a neutral rather
  // than to an accent: a widget picking one up must not read as "active".
  const scheme = ColorScheme(
    brightness: Brightness.dark,

    // Primary = the one action colour. §12: "#D85A30 = active / trained /
    // primary action."
    primary: AppPalette.accentStrong,
    onPrimary: AppPalette.onAccent,
    primaryContainer: AppPalette.accentStrong,
    onPrimaryContainer: AppPalette.onAccent,
    primaryFixed: AppPalette.accentStrong,
    primaryFixedDim: AppPalette.accentStrong,
    onPrimaryFixed: AppPalette.onAccent,
    onPrimaryFixedVariant: AppPalette.onAccent,

    // accentLight (#F0997B) is deliberately absent from this scheme. §12:
    // "secondary muscle only, never a primary action" -- and `secondary` is
    // exactly the slot Material paints interactive chrome from. It belongs to
    // the diagram painter, nowhere else.
    secondary: AppPalette.accentStrong,
    onSecondary: AppPalette.onAccent,
    secondaryContainer: AppPalette.mutedSurface,
    onSecondaryContainer: AppPalette.textPrimary,
    secondaryFixed: AppPalette.mutedSurface,
    secondaryFixedDim: AppPalette.mutedSurface,
    onSecondaryFixed: AppPalette.textPrimary,
    onSecondaryFixedVariant: AppPalette.textPrimary,

    // There is no third accent in §12, so the whole tertiary family is neutral.
    tertiary: AppPalette.mutedSurface,
    onTertiary: AppPalette.textPrimary,
    tertiaryContainer: AppPalette.mutedSurface,
    onTertiaryContainer: AppPalette.textPrimary,
    tertiaryFixed: AppPalette.mutedSurface,
    tertiaryFixedDim: AppPalette.mutedSurface,
    onTertiaryFixed: AppPalette.textPrimary,
    onTertiaryFixedVariant: AppPalette.textPrimary,

    error: AppPalette.danger,
    onError: AppPalette.textPrimary,
    errorContainer: AppPalette.surface,
    onErrorContainer: AppPalette.danger,

    surface: AppPalette.surface,
    onSurface: AppPalette.textPrimary,
    surfaceDim: AppPalette.pageBackground,
    surfaceBright: AppPalette.surface,
    surfaceContainerLowest: AppPalette.pageBackground,
    surfaceContainerLow: AppPalette.mutedSurface,
    surfaceContainer: AppPalette.surface,
    surfaceContainerHigh: AppPalette.surface,
    surfaceContainerHighest: AppPalette.surface,
    onSurfaceVariant: AppPalette.textSecondary,

    outline: AppPalette.border,
    outlineVariant: AppPalette.border,

    // SnackBar's background in M3. Light-on-dark inverts to our text colour.
    inverseSurface: AppPalette.textPrimary,
    onInverseSurface: AppPalette.pageBackground,
    inversePrimary: AppPalette.accentStrong,

    // Shadow and scrim are overlays, not palette entries -- black at low alpha
    // darkens whatever is behind it rather than introducing a hue.
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),

    // M3 tints elevated surfaces with `primary`. That tint is a colour §12 does
    // not list, so there is no elevation overlay anywhere in this app.
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppPalette.pageBackground,
    canvasColor: AppPalette.pageBackground,
    dividerColor: AppPalette.border,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppPalette.textPrimary,
      displayColor: AppPalette.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.pageBackground,
      foregroundColor: AppPalette.textPrimary,
      elevation: 0,
      centerTitle: false,
      // The app bar is pinned, so content passes underneath it constantly.
      // Material 3 would tint it on scroll-under; that tint is a colour §12
      // does not list, and a header that changes shade as you scroll reads as
      // an accident. Keep it flat and opaque at every scroll offset.
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: AppPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppPalette.border),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppPalette.border,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.accentStrong,
        foregroundColor: AppPalette.onAccent,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppPalette.accentStrong),
    ),
    // The app's first text input is the Muscles search field, and Material's
    // default decoration is the one place a palette this strict leaks: an
    // unstyled `TextField` paints a filled surface from `surfaceContainerHighest`
    // and an underline from `onSurfaceVariant`, neither of which is a shape this
    // app uses anywhere -- every other box in it is a 1pt bordered rectangle on
    // `surface`. So every colour and every border is named here rather than
    // left to the defaults, the same way `showTemplateFilterMenu` names every
    // property of its menu.
    inputDecorationTheme: InputDecorationTheme(
      // Filled *and* outlined, which Material treats as unusual: the prototype's
      // `.search` is a filled box with a hairline border, so both are set.
      filled: true,
      fillColor: AppPalette.surface,
      // Dense, because the height comes from the content padding below rather
      // than from Material's 48pt minimum -- the prototype's field is 11px of
      // padding around a 13.5px line.
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      hintStyle: const TextStyle(
        fontSize: 13.5,
        color: AppPalette.textMuted,
      ),
      prefixIconColor: AppPalette.textMuted,
      suffixIconColor: AppPalette.textMuted,
      // One shape, four states. `border` alone is not enough: Material resolves
      // the enabled, focused, disabled and error borders separately and only
      // falls back to its own defaults for the ones left unset.
      border: _inputBorder(AppPalette.border),
      enabledBorder: _inputBorder(AppPalette.border),
      disabledBorder: _inputBorder(AppPalette.border),
      // Accent on focus is the one-meaning rule applied, not decoration: §12
      // gives that colour "active", and a focused field is the active one. It
      // is also the only visible focus indicator this field has.
      focusedBorder: _inputBorder(AppPalette.accentStrong),
      errorBorder: _inputBorder(AppPalette.danger),
      focusedErrorBorder: _inputBorder(AppPalette.danger),
      errorStyle: const TextStyle(fontSize: 11.5, color: AppPalette.danger),
    ),
    // The caret and the selection band. Left unset they come from
    // `colorScheme.primary`, which happens to be on-palette today and would
    // stop being so the moment that role moved; naming them keeps the input's
    // colours in one place with the rest of its decoration.
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppPalette.accentStrong,
      selectionColor: AppPalette.accentLight,
      selectionHandleColor: AppPalette.accentStrong,
    ),
    // No bottomNavigationBarTheme: that themes Material 2's BottomNavigationBar,
    // which this app does not use. The L0 tab bar is a custom widget (see
    // prototypes/l0-tabbar-prototype.html) and carries its own styling.
  );
}

/// The search field's box: the app's one border radius for a control, drawn as
/// a hairline in [color].
///
/// A function rather than six literals, because the four border states below
/// differ only in that colour -- and a state that drifted to a different radius
/// would look like a rendering bug rather than a theme edit.
OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
