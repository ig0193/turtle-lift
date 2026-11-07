import 'package:flutter/painting.dart';

/// The complete palette. `docs/00-build-spec.md` §12 — "No other colours."
///
/// Cool brushed-titanium dark UI with one iridescent accent, taken from
/// `docs/one-day-theme-reference.md` (option A, full re-skin). The role names
/// are unchanged from the warm palette they replace, so every widget keeps
/// asking for the same *meaning*; only the values moved.
abstract final class AppPalette {
  /// Page background. ONE DAY `ink`.
  static const pageBackground = Color(0xFF07080A);

  /// Card / elevated surface. ONE DAY `panel`.
  static const surface = Color(0xFF15171C);

  /// Border / divider. A flat stand-in for ONE DAY's bevel hairline: white at
  /// roughly 10% over [surface], made opaque so it reads the same on every
  /// background it crosses.
  static const border = Color(0xFF2A2D34);

  /// Muted surface, and the fill for an untrained diagram region.
  /// ONE DAY `panelHi`.
  static const mutedSurface = Color(0xFF1D2027);

  /// ONE DAY `text` / `text2`.
  static const textPrimary = Color(0xFFF2F4F7);
  static const textSecondary = Color(0xFF9EA3AE);

  /// Muted text: meta, units, counts, placeholders, inactive labels.
  ///
  /// Lighter than ONE DAY's `text3` (`#5C616C`), which measured 2.9:1 on
  /// [surface] -- unreadable for the counts and sub-lines this colour carries.
  /// `#838A94` is 4.5:1 or better on every surface here ([pageBackground],
  /// [surface], [mutedSurface]), the WCAG AA floor for small text.
  static const textMuted = Color(0xFF838A94);

  /// Active / trained / primary action, and the primary-muscle diagram fill.
  /// ONE DAY `ice` — the solid stand-in for [AppGradients.liquid] wherever a
  /// gradient does not fit (tint, text, icons, a diagram segment).
  static const accentStrong = Color(0xFFA9D8FF);

  /// Secondary muscle only. Never a primary action. (§12) ONE DAY `lilac`.
  static const accentLight = Color(0xFFC9B6FF);

  /// Text drawn on top of an [accentStrong] or liquid fill. ONE DAY `ink`.
  static const onAccent = Color(0xFF07080A);

  /// Destructive action only -- delete a workout, discard a session.
  ///
  /// The eleventh colour, added because [accentStrong] could not carry it:
  /// `01` §Usage rules gives that colour one meaning, "this is active / this
  /// has been worked", *"same meaning wherever it appears"* -- so a delete
  /// confirmation painted in it reads as approval. ONE DAY `bad`. Never a
  /// primary action, never a fill behind body text.
  static const danger = Color(0xFFFF8A8A);
}

/// The gradients §12 allows. Each is a treatment of the palette's accent, not
/// a new meaning: light comes from the top-left, so every one runs diagonal.
abstract final class AppGradients {
  /// Liquid metal — the single accent, as a fill. Primary buttons only, the
  /// same job [AppPalette.accentStrong] does as a solid.
  static const liquid = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFE8ECF2),
      AppPalette.accentStrong,
      AppPalette.accentLight,
      Color(0xFFF4E3FF),
    ],
  );
}
