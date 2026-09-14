import 'package:flutter/material.dart';

import 'stroke_glyph.dart';

import '../theme/app_palette.dart';

/// The three tab-bar icons, drawn as strokes rather than font glyphs.
///
/// **They are hand-painted because the bar animates the stroke.** The L0
/// prototype gives `.bar svg` `stroke-width:1.7` and the selected tab
/// `stroke-width:2.2`, with `transition:stroke-width 160ms ease-out`
/// (`prototypes/l0-tabbar-prototype.html`). A Material font glyph is a filled
/// shape — it has no stroke width to animate, and scaling the whole glyph to
/// fake the weight change moves the icon inside its slot. So each glyph is a
/// `CustomPainter` that takes [strokeWidth] and [color] as plain parameters and
/// the bar drives them.
///
/// The geometry is transcribed from the prototype's `ICON` table verbatim, on
/// the same 24-unit viewBox, with round caps and joins to match
/// `stroke-linecap:round; stroke-linejoin:round`.
///
/// The glyph holds no animation and no state. Nothing here knows which tab is
/// selected — that is the bar's job, and keeping it out of here is what lets
/// the same widget be driven by an `AnimatedBuilder`, a `TweenAnimationBuilder`
/// or nothing at all.
enum TabGlyph {
  /// A barbell. `M4 12h16M7 8v8M17 8v8`
  workout,

  /// A figure. `circle cx=12 cy=5 r=2.5` + `M12 8v7M12 15l-3 6M12 15l3 6M7 10h10`
  muscles,

  /// A clock. `circle cx=12 cy=12 r=8` + `M12 7v5l3 2`
  history,
}

/// Paints one [TabGlyph] at [size]×[size].
///
/// [strokeWidth] is in logical pixels of the rendered widget, **not** in
/// viewBox units: the geometry is scaled to [size] but the stroke is not, so
/// what the bar animates is what lands on screen. At the prototype's 22px slot
/// the difference is small; making it explicit is what keeps 1.7 → 2.2 a
/// meaningful pair of numbers instead of two arbitrary ones.
class TabGlyphIcon extends StatelessWidget {
  const TabGlyphIcon(
    this.glyph, {
    this.size = kTabGlyphSize,
    this.strokeWidth = kTabGlyphStrokeWidth,
    this.color = AppPalette.textSecondary,
    super.key,
  });

  final TabGlyph glyph;
  final double size;
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: TabGlyphPainter(
          glyph: glyph,
          strokeWidth: strokeWidth,
          color: color,
        ),
        size: Size.square(size),
      ),
    );
  }
}

/// Icon box the prototype's `.bar svg` uses (`width:22px;height:22px`).
const double kTabGlyphSize = 22;

/// Resting stroke weight (`.bar svg { stroke-width:1.7 }`).
const double kTabGlyphStrokeWidth = 1.7;

/// Selected stroke weight (`.bar button[aria-current=page] svg`).
const double kTabGlyphSelectedStrokeWidth = 2.2;

/// The painter behind [TabGlyphIcon]. Public so a test can inspect the exact
/// [Paint] it strokes with — the animation is only real if the parameter
/// reaches the canvas.
class TabGlyphPainter extends CustomPainter {
  const TabGlyphPainter({
    required this.glyph,
    required this.strokeWidth,
    required this.color,
  });

  final TabGlyph glyph;
  final double strokeWidth;
  final Color color;

  /// The [Paint] this painter strokes with. Round cap and join are not
  /// decoration: the barbell and the clock hand are open polylines whose ends
  /// and corners would read as chiselled at these weights otherwise.
  Paint buildPaint() =>
      strokeGlyphPaint(color: color, strokeWidth: strokeWidth);

  /// The glyph in viewBox units, scaled to [size]. The stroke is applied after
  /// the scale (see [TabGlyphIcon]), so it is never scaled with the geometry.
  Path pathFor(Size size) => scaledGlyphPath(_basePath(glyph), size);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(pathFor(size), buildPaint());
  }

  @override
  bool shouldRepaint(TabGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.color != color;
}


/// Built paths are cached rather than rebuilt each frame: the bar repaints on
/// every animation tick, and the geometry never changes.
final Map<TabGlyph, Path> _basePaths = <TabGlyph, Path>{};

Path _basePath(TabGlyph glyph) => _basePaths.putIfAbsent(glyph, () {
      final path = Path();
      switch (glyph) {
        // Barbell: 'M4 12h16M7 8v8M17 8v8'
        case TabGlyph.workout:
          path
            ..moveTo(4, 12)
            ..lineTo(20, 12)
            ..moveTo(7, 8)
            ..lineTo(7, 16)
            ..moveTo(17, 8)
            ..lineTo(17, 16);
        // Figure: '<circle cx="12" cy="5" r="2.5"/>
        //          <path d="M12 8v7M12 15l-3 6M12 15l3 6M7 10h10"/>'
        case TabGlyph.muscles:
          path
            ..addOval(Rect.fromCircle(center: const Offset(12, 5), radius: 2.5))
            ..moveTo(12, 8)
            ..lineTo(12, 15)
            ..moveTo(12, 15)
            ..lineTo(9, 21)
            ..moveTo(12, 15)
            ..lineTo(15, 21)
            ..moveTo(7, 10)
            ..lineTo(17, 10);
        // Clock: '<circle cx="12" cy="12" r="8"/><path d="M12 7v5l3 2"/>'
        case TabGlyph.history:
          path
            ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8))
            ..moveTo(12, 7)
            ..lineTo(12, 12)
            ..lineTo(15, 14);
      }
      return path;
    });
