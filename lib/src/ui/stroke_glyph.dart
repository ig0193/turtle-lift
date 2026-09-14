import 'package:flutter/material.dart';

/// Shared scaffolding for the app's hand-drawn stroked glyphs — the tab-bar
/// icons, the empty-state discs and the profile avatar.
///
/// Three painters transcribe SVG paths onto a 24-unit viewBox and stroke them.
/// They draw different shapes with different caps, but the scaling and the
/// `Paint` construction are identical, and each had its own copy until this
/// file existed. The shapes stay separate on purpose (an empty-state disc is
/// not the tab icon of the same name); only the machinery is shared.
const double kGlyphViewBox = 24;

/// Scaled glyph paths, keyed by the base path's identity and the side it was
/// scaled to.
///
/// **The scaled path is what gets drawn, so caching only the base path is not
/// enough.** That is the trap this closes: the glyph a tab strokes is the
/// scaled one, `size` is fixed at the icon's size, and the scale therefore
/// never changes — yet a tint animation repaints ~10 times per tab switch, and
/// every one of those frames was rebuilding a `Path` whose points were
/// identical to the last. `CLAUDE.md` names this exact mistake.
///
/// Bounded by construction: the keys are the memoized base paths (a fixed
/// handful, one per glyph) times the two or three sizes the app draws them at.
final Map<(Path, double), Path> _scaledGlyphs = <(Path, double), Path>{};

/// [base], in viewBox units, scaled to fit [size] — built once per size and
/// reused thereafter.
///
/// [base] must be a stable instance (the painters memoize theirs per glyph),
/// because `Path` has no value equality and the cache keys on identity.
Path scaledGlyphPath(Path base, Size size, {double viewBox = kGlyphViewBox}) {
  final side = size.shortestSide;
  final scale = side / viewBox;
  if (scale == 1) return base;
  return _scaledGlyphs.putIfAbsent(
    (base, side),
    () => base.transform(Matrix4.diagonal3Values(scale, scale, 1).storage),
  );
}

/// The stroke every glyph paints with.
///
/// The stroke is applied after the geometry is scaled, so line weight stays
/// put at any icon size rather than thickening with the drawing.
///
/// Caps and joins are a real choice, not a default: the tab and avatar glyphs
/// are open polylines whose ends would read as chiselled when rounded off, and
/// the empty-state discs deliberately keep SVG's own butt/mitre defaults so
/// they match the markup they were transcribed from.
Paint strokeGlyphPaint({
  required Color color,
  required double strokeWidth,
  StrokeCap cap = StrokeCap.round,
  StrokeJoin join = StrokeJoin.round,
}) =>
    Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = cap
      ..strokeJoin = join
      ..isAntiAlias = true;
