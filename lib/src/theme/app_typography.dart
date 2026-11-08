import 'package:flutter/painting.dart';

import 'app_palette.dart';

/// Type tokens that belong to no one screen.
///
/// **A tab-agnostic home, for the reason `app_palette.dart` is one.** A token
/// used by both tabs has to live somewhere neither owns: the section label
/// below was first written in `template_row.dart`, and six Muscles files ended
/// up importing a Workout-template row widget to reach it. A style is not a
/// widget's property just because the widget happened to need it first.
///
/// Only what is genuinely shared lives here. A style used by one screen stays
/// next to that screen, where its reasoning is readable beside the thing it
/// describes.
///
/// **One size scale: 12 / 13 / 15 / 17 / 20 / 24**, plus the fitted
/// set-logging numeral (`StepperField`). Hierarchy comes from weight and grey
/// level first, size second; a size between two steps reads as a mistake, not
/// a level. Nothing is under 12. Tracking is zero below 16pt.
abstract final class AppTypeScale {
  /// Captions, meta, units.
  static const double caption = 12;

  /// Section labels, secondary lines.
  static const double footnote = 13;

  /// Body, row titles, button labels.
  static const double body = 15;

  /// Pushed-screen titles, card titles, figures.
  static const double title = 17;

  /// Sheet titles.
  static const double title2 = 20;

  /// Tab-root titles, the summary's figures.
  static const double display = 24;
}

/// A section label: "Templates", "Your templates", "Muscles", "12 exercises".
///
/// Not a heading in the `kEmptyStateHeadingStyle` sense: those introduce a
/// screen, this labels a group within one. It is deliberately quiet, because
/// the rows beneath it are the content.
const TextStyle kLandingSectionLabelStyle = TextStyle(
  // Sentence case, no tracking: the taste skill's rule that labels are never
  // tracked capitals.
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: AppPalette.textSecondary,
);

/// The one personal-best mark: the word "PB" (or "2 PB") in amber, semibold.
///
/// **One treatment everywhere.** History used a tinted pill, Session Detail a
/// trophy, and the summary a star glyph -- three marks for one fact. A trophy
/// also reads as an achievement, which the app rules out. Amber is the PB
/// colour (§12), so the word needs no box around it.
const TextStyle kPbMarkStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: AppPalette.accentStrong,
);
