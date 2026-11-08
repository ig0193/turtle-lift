import 'package:flutter/material.dart';

import '../data/food.dart';
import '../theme/app_palette.dart';

/// The diet-type marker: a rounded square with a mark inside, from `.dt` in
/// `prototypes/diet.html`. A dot is veg, an egg-shaped oval is egg, a
/// triangle is non-veg.
///
/// **Shape, never colour.** The palette has no green or red (KTD20, R27), so
/// the familiar Indian dots cannot carry the meaning; the shape does, in
/// [AppPalette.textSecondary] by default.
///
/// **Always paired with its word.** The shapes are not a vocabulary anyone
/// has learned, so every surface that draws one also writes [DietType.label]
/// beside it. The glyph is therefore decorative to a screen reader: the
/// word, in the row's or chip's own label, is what is announced.
///
/// Hand-painted like `empty_state.dart`'s discs: no SVG package (`CLAUDE.md`).
class DietTypeGlyph extends StatelessWidget {
  const DietTypeGlyph(
    this.type, {
    this.size = kDietTypeGlyphSize,
    this.color = AppPalette.textSecondary,
    super.key,
  });

  final DietType type;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: DietTypeGlyphPainter(type: type, color: color),
            size: Size.square(size),
          ),
        ),
      );
}

/// `.dt { width:14px; height:14px }`.
const double kDietTypeGlyphSize = 14;

/// The painter behind [DietTypeGlyph]. Drawn in a 14-unit viewBox.
class DietTypeGlyphPainter extends CustomPainter {
  const DietTypeGlyphPainter({required this.type, required this.color});

  final DietType type;
  final Color color;

  static const double _viewBox = 14;

  /// `.dt rect { stroke-width:1.4 }`, in viewBox units.
  static const double _strokeWidth = 1.4;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _viewBox;
    canvas.save();
    canvas.scale(scale);
    // `<rect x="1" y="1" width="12" height="12" rx="2"/>`
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1, 1, 12, 12),
        const Radius.circular(2),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..color = color
        ..isAntiAlias = true,
    );
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..isAntiAlias = true;
    switch (type) {
      // `<circle cx="7" cy="7" r="3"/>`
      case DietType.veg:
        canvas.drawCircle(const Offset(7, 7), 3, fill);
      // `<ellipse cx="7" cy="7.4" rx="2.4" ry="3.2"/>`
      case DietType.egg:
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(7, 7.4), width: 4.8, height: 6.4),
          fill,
        );
      // `<path d="M7 3.6l3.4 6H3.6z"/>`
      case DietType.nonVeg:
        canvas.drawPath(
          Path()
            ..moveTo(7, 3.6)
            ..lineTo(10.4, 9.6)
            ..lineTo(3.6, 9.6)
            ..close(),
          fill,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(DietTypeGlyphPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
