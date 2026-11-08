import 'package:flutter/painting.dart';

/// The complete palette. `docs/00-build-spec.md` §12 — "No other colours."
///
/// **Chalk & Shell.** Graphite neutrals with no tint, chalk for text and the
/// primary button, and one warm colour -- shell amber -- that means "worked /
/// active / record" and nothing else. Steel marks the secondary muscle. There
/// is no gradient. The role names are unchanged from the palettes this one
/// replaces, so every widget keeps asking for the same *meaning*; only the
/// values moved.
abstract final class AppPalette {
  /// Page background. Graphite, no tint.
  static const pageBackground = Color(0xFF0E0E0F);

  /// Card / elevated surface: cards, sheets.
  static const surface = Color(0xFF18181A);

  /// Border / divider. A hairline, roughly chalk at 8% over [surface], made
  /// opaque so it reads the same on every background it crosses. Also the
  /// outline that lets an untrained body-map segment read against the page.
  static const border = Color(0xFF2E2E32);

  /// Muted surface: raised controls, and the fill for an untrained diagram
  /// region.
  static const mutedSurface = Color(0xFF222225);

  /// Chalk. Body text, and the fill of the primary button.
  static const textPrimary = Color(0xFFEDEDEB);
  static const textSecondary = Color(0xFFA3A3A7);

  /// Muted text: meta, units, counts, placeholders, inactive labels.
  ///
  /// 4.5:1 or better on every surface here ([pageBackground], [surface],
  /// [mutedSurface]), the WCAG AA floor for small text.
  static const textMuted = Color(0xFF8B8B90);

  /// Shell amber. Trained muscle (the primary-muscle diagram fill), the active
  /// tab, the selection, and the personal-best figure. **Not the primary
  /// button** -- that is chalk ([textPrimary]), so amber keeps one meaning.
  static const accentStrong = Color(0xFFFFA53D);

  /// Steel. Secondary muscle only. Never chrome, never an action. (§12)
  static const accentLight = Color(0xFF93ABCB);

  /// Text drawn on top of a filled control: the chalk primary button, or an
  /// [accentStrong] fill. The same value as [pageBackground].
  static const onAccent = Color(0xFF0E0E0F);

  /// Destructive action only -- delete a workout, discard a session.
  ///
  /// The eleventh colour, added because [accentStrong] could not carry it:
  /// `01` §Usage rules gives that colour one meaning, "this is active / this
  /// has been worked", *"same meaning wherever it appears"* -- so a delete
  /// confirmation painted in it reads as approval. Never a primary action,
  /// never a fill behind body text.
  static const danger = Color(0xFFFF7A85);
}
