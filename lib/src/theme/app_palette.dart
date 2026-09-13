import 'package:flutter/painting.dart';

/// The complete palette. `docs/00-build-spec.md` §12 — "No other colours."
abstract final class AppPalette {
  /// Page background.
  static const pageBackground = Color(0xFF17140F);

  /// Card / elevated surface.
  static const surface = Color(0xFF211D18);

  /// Border / divider.
  static const border = Color(0xFF332C22);

  /// Muted surface, and the fill for an untrained diagram region.
  static const mutedSurface = Color(0xFF241F19);

  static const textPrimary = Color(0xFFF5EFE8);
  static const textSecondary = Color(0xFFA89C8E);
  static const textMuted = Color(0xFF6B6156);

  /// Active / trained / primary action, and the primary-muscle diagram fill.
  static const accentStrong = Color(0xFFD85A30);

  /// Secondary muscle only. Never a primary action. (§12)
  static const accentLight = Color(0xFFF0997B);

  /// Text drawn on top of an [accentStrong] fill.
  static const onAccent = Color(0xFF1B0C05);

  /// Destructive action only -- delete a workout, discard a session.
  ///
  /// The eleventh colour, added because [accentStrong] could not carry it:
  /// `01` §Usage rules gives that colour one meaning, "this is active / this
  /// has been worked", *"same meaning wherever it appears"* -- so a delete
  /// confirmation painted in it reads as approval. Value taken from `.danger`
  /// in `prototypes/l0-navigation-prototype.html`, which had already answered
  /// this. Never a primary action, never a fill behind body text.
  static const danger = Color(0xFFC4553A);
}
