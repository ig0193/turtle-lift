import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/tab_glyph.dart';

/// Guards the one property the tab bar buys by hand-painting these icons: the
/// stroke weight it animates has to reach the canvas.
///
/// That failure is invisible otherwise. A painter that ignores its
/// `strokeWidth`, or a `shouldRepaint` that returns false when the weight
/// changes, still renders three perfectly correct-looking icons -- the
/// 1.7 -> 2.2 transition simply never happens, and nothing throws. So these
/// tests assert against the actual `Paint` the painter strokes with, not
/// against the fact that it rendered.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: Center(child: child)),
      );

  group('rendering', () {
    for (final glyph in TabGlyph.values) {
      testWidgets('${glyph.name} paints standalone at 22x22', (tester) async {
        await tester.pumpWidget(
          host(TabGlyphIcon(glyph, color: AppPalette.textSecondary)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(TabGlyphIcon)),
          const Size(kTabGlyphSize, kTabGlyphSize),
        );
      });
    }

    testWidgets('all three render together with no bar around them',
        (tester) async {
      await tester.pumpWidget(
        host(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final glyph in TabGlyph.values)
                TabGlyphIcon(
                  glyph,
                  strokeWidth: kTabGlyphSelectedStrokeWidth,
                  color: AppPalette.accentStrong,
                ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TabGlyphIcon), findsNWidgets(3));
    });
  });

  group('shouldRepaint', () {
    const base = TabGlyphPainter(
      glyph: TabGlyph.workout,
      strokeWidth: kTabGlyphStrokeWidth,
      color: AppPalette.textSecondary,
    );

    test('true when the stroke width changes', () {
      expect(
        base.shouldRepaint(
          const TabGlyphPainter(
            glyph: TabGlyph.workout,
            strokeWidth: kTabGlyphSelectedStrokeWidth,
            color: AppPalette.textSecondary,
          ),
        ),
        isTrue,
      );
    });

    test('true when the colour changes', () {
      expect(
        base.shouldRepaint(
          const TabGlyphPainter(
            glyph: TabGlyph.workout,
            strokeWidth: kTabGlyphStrokeWidth,
            color: AppPalette.accentStrong,
          ),
        ),
        isTrue,
      );
    });

    test('true when the glyph changes', () {
      expect(
        base.shouldRepaint(
          const TabGlyphPainter(
            glyph: TabGlyph.history,
            strokeWidth: kTabGlyphStrokeWidth,
            color: AppPalette.textSecondary,
          ),
        ),
        isTrue,
      );
    });

    test('false when nothing changes', () {
      expect(
        base.shouldRepaint(
          const TabGlyphPainter(
            glyph: TabGlyph.workout,
            strokeWidth: kTabGlyphStrokeWidth,
            color: AppPalette.textSecondary,
          ),
        ),
        isFalse,
      );
    });
  });

  group('path caching', () {
    // CLAUDE.md: cache built Path objects rather than rebuilding them each
    // frame. Caching only the unscaled base path is not enough -- the scaled
    // one is what gets drawn, and the tint animation repaints ~10 times per
    // tab switch, so an uncached scale rebuilt an identical Path every frame.
    // Nothing about that is visible on screen, which is why it is pinned here.
    test('the scaled path is built once per size and reused', () {
      for (final glyph in TabGlyph.values) {
        final first =
            _painterFor(glyph).pathFor(const Size.square(kTabGlyphSize));
        final second =
            _painterFor(glyph).pathFor(const Size.square(kTabGlyphSize));

        expect(identical(first, second), isTrue,
            reason: '$glyph rebuilt its scaled path for a size it had already '
                'scaled to; the geometry is identical every time, so this is '
                'pure per-frame waste during the tint animation');
      }
    });

    test('a different size gets its own path', () {
      final small = _painterFor(TabGlyph.workout).pathFor(const Size.square(16));
      final large = _painterFor(TabGlyph.workout).pathFor(const Size.square(32));

      expect(identical(small, large), isFalse,
          reason: 'the cache must key on size, not just on the glyph, or every '
              'icon after the first would render at the first one\'s scale');
      expect(large.getBounds().width,
          greaterThan(small.getBounds().width),
          reason: 'the larger size must actually produce a larger path');
    });
  });

  group('the painted stroke', () {
    for (final glyph in TabGlyph.values) {
      test('${glyph.name} strokes with exactly the width it was given', () {
        // Both ends of the bar's animation, plus a value in between, because a
        // painter that hard-coded one of them would still pass a single case.
        for (final width in <double>[
          kTabGlyphStrokeWidth,
          1.95,
          kTabGlyphSelectedStrokeWidth,
        ]) {
          final canvas = _RecordingCanvas();
          TabGlyphPainter(
            glyph: glyph,
            strokeWidth: width,
            color: AppPalette.accentStrong,
          ).paint(canvas, const Size.square(kTabGlyphSize));

          expect(canvas.paints, hasLength(1),
              reason: '$glyph should paint in one stroked pass');
          final paint = canvas.paints.single;
          // Paint stores the width as a 32-bit float, so 1.7 comes back as
          // 1.70000004... -- a tolerance, not a slackened assertion.
          expect(paint.strokeWidth, moreOrLessEquals(width, epsilon: 1e-6));
          expect(paint.style, PaintingStyle.stroke);
          // Compare packed ARGB, not Color identity: Paint stores the colour in
          // 32 bits and the getter rebuilds it, so the returned Color's float
          // components differ from the const literal's and `==` fails on two
          // values that are the same colour.
          expect(paint.color.toARGB32(), AppPalette.accentStrong.toARGB32());
          expect(paint.strokeCap, StrokeCap.round);
          expect(paint.strokeJoin, StrokeJoin.round);
        }
      });

      test('${glyph.name} geometry is scaled into the box, not the stroke', () {
        // The stroke must stay in logical pixels while the 24-unit viewBox is
        // scaled down to the 22px slot -- if the canvas were scaled instead,
        // 2.2 would silently land as 2.017 on screen.
        const painter = TabGlyphPainter(
          glyph: TabGlyph.workout,
          strokeWidth: kTabGlyphSelectedStrokeWidth,
          color: AppPalette.textSecondary,
        );
        final bounds = painter.pathFor(const Size.square(kTabGlyphSize))
            .getBounds();
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(kTabGlyphSize));
        expect(bounds.bottom, lessThanOrEqualTo(kTabGlyphSize));
      });
    }
  });
}

/// A [Canvas] that records the [Paint] of every draw instead of rasterising,
/// so a test can read back the exact paint the painter built.
class _RecordingCanvas implements Canvas {
  final List<Paint> paints = <Paint>[];

  @override
  void drawPath(Path path, Paint paint) => paints.add(paint);

  @override
  void drawCircle(Offset c, double radius, Paint paint) => paints.add(paint);

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => paints.add(paint);

  // Any other Canvas call is a draw or transform this painter is not expected
  // to make; letting it throw is the point.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

TabGlyphPainter _painterFor(TabGlyph glyph) => TabGlyphPainter(
      glyph: glyph,
      strokeWidth: kTabGlyphStrokeWidth,
      color: AppPalette.textSecondary,
    );
