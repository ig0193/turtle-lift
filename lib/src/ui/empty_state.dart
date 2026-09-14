import 'package:flutter/material.dart';

import 'stroke_glyph.dart';

import '../theme/app_palette.dart';

/// The empty-state block: a disc-mounted glyph, a heading and a line of body
/// copy, centred.
///
/// **This is a shipping screen state, not a placeholder.** The app has no
/// server and starts with zero data, so every user meets this on day one and
/// keeps meeting it until they log something. Treat the copy and the spacing
/// with the same care as a populated screen.
///
/// Transcribed from `.empty` in `prototypes/screens.html`:
/// `padding:34px 18px`, a 46px `--card` disc with 14px beneath it, a 15px/600
/// heading with 5px beneath it, and 12.5px `--t2` body at `line-height:1.55`.
///
/// The horizontal 18 is the prototype's own, on top of whatever gutter the
/// root's scrollable already applies — the copy is deliberately narrower than
/// the rest of the screen so it reads as a block rather than as content.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.glyph,
    required this.heading,
    required this.body,
    super.key,
  });

  /// The disc's drawing. Each root supplies its own — see [EmptyStateGlyph].
  final EmptyStateGlyph glyph;

  final String heading;
  final String body;

  /// Marks the reserved mascot band so a test can prove the space survives a
  /// refactor. See [kEmptyStateMascotSlot].
  @visibleForTesting
  static const Key mascotSlotKey = Key('empty-state-mascot-slot');

  /// Marks the 46px disc behind the glyph, so a test can measure it without
  /// guessing which `Container` in the tree it is.
  @visibleForTesting
  static const Key discKey = Key('empty-state-disc');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reserved, not laid out. `docs/05-mascot-brief.md` §Where it appears
          // gives empty states a resting turtle "above the empty-state copy",
          // but leaves orientation and exact size open until there are running
          // screens to settle them against. Holding the band open now is what
          // keeps that decision from becoming a re-layout of three screens.
          const SizedBox(key: mascotSlotKey, height: kEmptyStateMascotSlot),
          Container(
            key: discKey,
            width: kEmptyStateDiscSize,
            height: kEmptyStateDiscSize,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              // `.empty .ico { background: var(--card) }`.
              color: AppPalette.surface,
              shape: BoxShape.circle,
            ),
            child: EmptyStateGlyphIcon(glyph),
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              heading,
              textAlign: TextAlign.center,
              style: kEmptyStateHeadingStyle,
            ),
          ),
          const SizedBox(height: 5),
          Text(body, textAlign: TextAlign.center, style: kEmptyStateBodyStyle),
        ],
      ),
    );
  }
}

/// Vertical band held open above the disc for the resting mascot.
///
/// Provisional by design: `docs/05-mascot-brief.md` commits to 52 (corner tile)
/// and 512 (store icon) and deliberately leaves every other surface open. This
/// is a slot, not a measurement — when the mascot lands, it is this constant
/// that changes, in one place.
const double kEmptyStateMascotSlot = 84;

/// `.empty .ico { width:46px; height:46px }`.
const double kEmptyStateDiscSize = 46;

/// `.empty .ico svg { width:22px; height:22px }`.
const double kEmptyStateGlyphSize = 22;

/// `.empty .ico svg { stroke-width:1.6 }` — lighter than the tab bar's 1.7.
const double kEmptyStateGlyphStrokeWidth = 1.6;

/// `.empty h3 { font-size:15px; font-weight:600 }`, inheriting `--t1`.
///
/// Public because the Muscles root borrows the same two styles for its
/// reference landing — it is not an empty state, but it must not read as a
/// different voice from the two screens either side of it.
const TextStyle kEmptyStateHeadingStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: AppPalette.textPrimary,
);

/// `.empty p { font-size:12.5px; color:var(--t2); line-height:1.55 }`.
const TextStyle kEmptyStateBodyStyle = TextStyle(
  fontSize: 12.5,
  height: 1.55,
  color: AppPalette.textSecondary,
);

/// The empty-state discs, one per root.
///
/// **These are not the tab-bar icons and must not be swapped for them.**
/// `TabGlyph.history` is a clock; the History empty state's disc is a logbook
/// page. The two drawings live in different places in the prototype
/// (`.tabs svg` versus `.empty .ico svg`) and diverge on purpose: the tab icon
/// names a destination, the disc illustrates the missing thing. Reaching for
/// `TabGlyph` here compiles, renders, and is silently wrong — which is why the
/// tests assert the glyph rather than merely that a disc appeared.
enum EmptyStateGlyph {
  /// A barbell, from `#w-new`'s disc: `M4 12h16M7 8v8M17 8v8`.
  ///
  /// It happens to be the same drawing as `TabGlyph.workout`; it is transcribed
  /// separately anyway, because that coincidence is the prototype's and not a
  /// rule the two families share.
  barbell,

  /// A logbook page, from the history empty state's disc:
  /// `M5 5h14v14H5z` + `M9 10h6M9 14h4`.
  logbook,
}

/// Paints one [EmptyStateGlyph] at [size]x[size].
///
/// Hand-painted rather than an `Icon`, for the same reason as
/// `lib/src/ui/tab_glyph.dart`: `CLAUDE.md` rules out an SVG package, and no
/// Material font glyph matches these drawings.
class EmptyStateGlyphIcon extends StatelessWidget {
  const EmptyStateGlyphIcon(
    this.glyph, {
    this.size = kEmptyStateGlyphSize,
    this.strokeWidth = kEmptyStateGlyphStrokeWidth,
    this.color = AppPalette.textMuted,
    super.key,
  });

  final EmptyStateGlyph glyph;
  final double size;
  final double strokeWidth;

  /// `.empty .ico svg { stroke: var(--t3) }` — the muted tone, not the
  /// secondary one the copy beneath it uses.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: EmptyStateGlyphPainter(
          glyph: glyph,
          strokeWidth: strokeWidth,
          color: color,
        ),
        size: Size.square(size),
      ),
    );
  }
}

/// The painter behind [EmptyStateGlyphIcon].
class EmptyStateGlyphPainter extends CustomPainter {
  const EmptyStateGlyphPainter({
    required this.glyph,
    required this.strokeWidth,
    required this.color,
  });

  final EmptyStateGlyph glyph;
  final double strokeWidth;
  final Color color;

  /// Butt caps and mitre joins, unlike the tab bar's round ones: `.empty .ico
  /// svg` sets no `stroke-linecap`, so SVG's defaults apply, and the logbook's
  /// square corners are the whole reason that disc reads as a page.
  Paint buildPaint() => strokeGlyphPaint(
        color: color,
        strokeWidth: strokeWidth,
        cap: StrokeCap.butt,
        join: StrokeJoin.miter,
      );

  /// The glyph in viewBox units, scaled to [size]. The stroke is applied after
  /// the scale, so [strokeWidth] is in rendered pixels either way.
  Path pathFor(Size size) => scaledGlyphPath(_basePath(glyph), size);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(pathFor(size), buildPaint());
  }

  @override
  bool shouldRepaint(EmptyStateGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.color != color;
}


/// Built paths are cached, not rebuilt per frame — the geometry never changes.
final Map<EmptyStateGlyph, Path> _basePaths = <EmptyStateGlyph, Path>{};

Path _basePath(EmptyStateGlyph glyph) => _basePaths.putIfAbsent(glyph, () {
      final path = Path();
      switch (glyph) {
        // 'M4 12h16M7 8v8M17 8v8'
        case EmptyStateGlyph.barbell:
          path
            ..moveTo(4, 12)
            ..lineTo(20, 12)
            ..moveTo(7, 8)
            ..lineTo(7, 16)
            ..moveTo(17, 8)
            ..lineTo(17, 16);
        // 'M5 5h14v14H5z' + 'M9 10h6M9 14h4'
        case EmptyStateGlyph.logbook:
          path
            ..moveTo(5, 5)
            ..lineTo(19, 5)
            ..lineTo(19, 19)
            ..lineTo(5, 19)
            ..close()
            ..moveTo(9, 10)
            ..lineTo(15, 10)
            ..moveTo(9, 14)
            ..lineTo(13, 14);
      }
      return path;
    });
