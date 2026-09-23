import 'package:flutter/widgets.dart';

/// The measurements the app is built on: spacing, corner radii and the one
/// touch-target floor.
///
/// **Colour is in `app_palette.dart` and stays there.** This file is the other
/// half of the visual system — the part that decides whether a screen reads as
/// considered or as a pile of widgets. The palette was locked early and tested;
/// the measurements were not, and it showed.
///
/// **A rhythm of 4, used in tiers.** Everything is a multiple of 4, and the
/// tiers are what carry hierarchy: [gapTight] separates parts of one thing,
/// [gap] separates things, [gapSection] separates sections, [gapBlock] separates
/// what would otherwise be mistaken for one screen's worth of content. A screen
/// that uses one gap everywhere has told the reader nothing about what belongs
/// to what.
abstract final class AppMetrics {
  // ----------------------------------------------------------------- spacing

  /// Inside a row: an icon and its label, a value and its unit.
  static const double gapTight = 4;

  /// Between rows of one component, and a component's own inner padding floor.
  static const double gapSnug = 8;

  /// The default. Between sibling controls, and inside a card.
  static const double gap = 12;

  /// A card's inner padding, and the space between cards.
  static const double gapCard = 16;

  /// Between a section label and its content.
  static const double gapLabel = 10;

  /// Between one section and the next.
  static const double gapSection = 28;

  /// Between parts of a screen that answer different questions.
  static const double gapBlock = 40;

  // ------------------------------------------------------------------ radius

  /// Cards and sheets. Generous, because on a dark ground a soft corner is most
  /// of what separates a surface from the page behind it.
  static const double radiusCard = 20;

  /// Buttons, chips and pills.
  static const double radiusControl = 14;

  /// Inputs — tighter than a control, so a field never reads as a button.
  static const double radiusField = 10;

  /// Fully round: avatars, the tab bar, a pill that holds one word.
  static const double radiusPill = 999;

  // ------------------------------------------------------------------ touch

  /// **44pt, and it is a floor rather than a suggestion.** Every tappable
  /// thing gets at least this, expanding its hit area when the glyph inside is
  /// smaller. A 20pt checkbox on a set row is not a control, it is a target
  /// practice.
  static const double touchTarget = 44;

  /// A comfortable primary control: tall enough to hit while holding a phone
  /// one-handed between sets.
  static const double controlHeight = 52;

  /// A set row. Taller than the fields inside it so the row itself is the
  /// target, not just the boxes.
  static const double setRowHeight = 48;

  // ------------------------------------------------------------------ insets

  /// Padding inside a card.
  static const EdgeInsets cardPadding = EdgeInsets.all(gapCard);

  /// A list row's own padding: generous vertically, flush horizontally so the
  /// screen gutter is the only horizontal inset.
  static const EdgeInsets rowPadding =
      EdgeInsets.symmetric(vertical: gap, horizontal: 0);
}
