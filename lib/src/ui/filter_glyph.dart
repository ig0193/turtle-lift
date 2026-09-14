import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'stroke_glyph.dart';

/// The filter control's icon: three horizontal lines of decreasing width.
///
/// **Three lines rather than a funnel.** It is the one filter shape Material
/// (`filter_list`) and SF Symbols (`line.3.horizontal.decrease`) agree on, so
/// neither platform's users have to learn anything. It also survives being
/// small: a funnel's meaning lives in its taper, which is the first thing to
/// mush at 16pt, whereas three straight strokes stay three straight strokes.
/// And a funnel reads as spreadsheets and issue trackers; descending lines read
/// as "a list, narrowed", which is what is happening.
///
/// Hand-painted like every other glyph in the app — `CLAUDE.md` rules out an
/// SVG package, and this is three `lineTo` calls.
class FilterGlyphIcon extends StatelessWidget {
  const FilterGlyphIcon({
    this.size = kFilterGlyphSize,
    this.strokeWidth = kFilterGlyphStrokeWidth,
    this.color = AppPalette.textSecondary,
    super.key,
  });

  final double size;
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: FilterGlyphPainter(strokeWidth: strokeWidth, color: color),
        size: Size.square(size),
      ),
    );
  }
}

/// Matches the tab bar's icon weight rather than the empty-state disc's — this
/// sits beside body text, not inside a 46pt disc.
const double kFilterGlyphSize = 16;

/// The tab bar's 1.7, not the empty state's 1.6: at 16pt the lighter stroke
/// reads as grey rather than as lines.
const double kFilterGlyphStrokeWidth = 1.7;

/// Paints [FilterGlyphIcon].
class FilterGlyphPainter extends CustomPainter {
  const FilterGlyphPainter({required this.strokeWidth, required this.color});

  final double strokeWidth;
  final Color color;

  /// Round caps, like the tab glyphs: these are open strokes whose ends would
  /// read as chiselled otherwise.
  Paint buildPaint() =>
      strokeGlyphPaint(color: color, strokeWidth: strokeWidth);

  /// The glyph in viewBox units, scaled to [size]. The stroke is applied after
  /// the scale, so [strokeWidth] is in rendered pixels at any icon size.
  Path pathFor(Size size) => scaledGlyphPath(_basePath, size);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(pathFor(size), buildPaint());
  }

  @override
  bool shouldRepaint(FilterGlyphPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth || oldDelegate.color != color;
}

/// `M4 6h16M7 12h10M10 18h4` on the shared 24-unit viewBox — centred, each line
/// six units shorter than the one above it.
///
/// Built once and cached; the geometry never changes and the chip repaints
/// whenever the filter does.
final Path _basePath = Path()
  ..moveTo(4, 6)
  ..lineTo(20, 6)
  ..moveTo(7, 12)
  ..lineTo(17, 12)
  ..moveTo(10, 18)
  ..lineTo(14, 18);
