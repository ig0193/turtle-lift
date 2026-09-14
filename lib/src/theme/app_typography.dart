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

/// A small-caps section label — "Templates", "Your templates", "MUSCLES",
/// "12 EXERCISES".
///
/// Not a heading in the `kEmptyStateHeadingStyle` sense: those introduce a
/// screen, this labels a group within one. It is deliberately quiet, because
/// the rows beneath it are the content.
const TextStyle kLandingSectionLabelStyle = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.1,
  color: AppPalette.textMuted,
);
