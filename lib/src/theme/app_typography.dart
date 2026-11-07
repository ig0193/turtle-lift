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

/// A section label: "Templates", "Your templates", "Muscles", "12 exercises".
///
/// Not a heading in the `kEmptyStateHeadingStyle` sense: those introduce a
/// screen, this labels a group within one. It is deliberately quiet, because
/// the rows beneath it are the content.
const TextStyle kLandingSectionLabelStyle = TextStyle(
  // Sentence case, no tracking: ONE DAY's eyebrow (13 / semibold / text2), and
  // the taste skill's rule that labels are never tracked capitals.
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: AppPalette.textSecondary,
);
