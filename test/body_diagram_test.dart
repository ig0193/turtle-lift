import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/generated/body_paths.dart';
import 'package:turtle_lift/src/data/generated/muscle_taxonomy.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/body_diagram.dart';

/// Guards the two properties a body diagram cannot demonstrate by rendering:
/// that the caller's fill reaches the canvas, and that a tap lands on the
/// segment it looks like it landed on.
///
/// Both failures are invisible. A painter that ignores [BodySegmentFill] still
/// draws a plausible body; a hit-test that scales differently from the paint
/// still returns *a* muscle for most taps, just the wrong one near the edges.
/// So these tests read back the actual `Paint` list and resolve taps through
/// the painter's own geometry rather than trusting that something rendered.
void main() {
  const box = Size(300, 600);

  Widget host(Widget child, {BodyGender gender = BodyGender.male}) =>
      ProviderScope(
        overrides: [bodyGenderProvider.overrideWithValue(gender)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(size: box, child: child),
            ),
          ),
        ),
      );

  group('rendering', () {
    for (final view in BodyView.values) {
      for (final gender in [BodyGender.male, BodyGender.female]) {
        testWidgets('${bodyAssetKey(view, gender)} renders at the given size',
            (tester) async {
          await tester.pumpWidget(
            host(
              BodyDiagram(view: view, fill: mutedBodyFill),
              gender: gender,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(tester.getSize(find.byType(BodyDiagram)), box);
        });
      }
    }

    testWidgets('a bounded width with unbounded height keeps the aspect ratio',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: ListView(
                children: const [
                  BodyDiagram(view: BodyView.front, fill: mutedBodyFill),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final viewBox = kBodyAssets['frontMale']!.viewBox;
      final size = tester.getSize(find.byType(BodyDiagram));
      expect(
        size.height / size.width,
        moreOrLessEquals(viewBox.height / viewBox.width, epsilon: 1e-6),
      );
    });
  });

  group('shouldRepaint', () {
    const base = BodyDiagramPainter(
      view: BodyView.front,
      gender: BodyGender.male,
      fill: mutedBodyFill,
    );

    test('true when the view changes', () {
      expect(
        base.shouldRepaint(
          const BodyDiagramPainter(
            view: BodyView.back,
            gender: BodyGender.male,
            fill: mutedBodyFill,
          ),
        ),
        isTrue,
      );
    });

    test('true when the gender changes', () {
      expect(
        base.shouldRepaint(
          const BodyDiagramPainter(
            view: BodyView.front,
            gender: BodyGender.female,
            fill: mutedBodyFill,
          ),
        ),
        isTrue,
      );
    });

    test('true when the fill function changes', () {
      expect(
        base.shouldRepaint(
          const BodyDiagramPainter(
            view: BodyView.front,
            gender: BodyGender.male,
            fill: _accentEverything,
          ),
        ),
        isTrue,
      );
    });

    test('false when every field is identical', () {
      expect(
        base.shouldRepaint(
          const BodyDiagramPainter(
            view: BodyView.front,
            gender: BodyGender.male,
            fill: mutedBodyFill,
          ),
        ),
        isFalse,
      );
    });
  });

  group('the segment / sub-group mapping', () {
    test('the front-delt segment carries both delts, and nothing else carries '
        'two', () {
      expect(
        subMuscleGroupsForSegment(BodyView.front, 'shoulders/front-delt'),
        {'shoulders/front-delt', 'shoulders/side-delt'},
      );

      for (final view in BodyView.values) {
        for (final gender in [BodyGender.male, BodyGender.female]) {
          final asset = kBodyAssets[bodyAssetKey(view, gender)]!;
          for (final segment in asset.segments) {
            final ids = subMuscleGroupsForSegment(view, segment.id);
            expect(ids, isNotEmpty,
                reason: '${segment.id} on ${view.taxonomyView} is claimed by no '
                    'sub-muscle group; the taxonomy and the artwork have '
                    'drifted apart');
            if (view == BodyView.front &&
                segment.id == 'shoulders/front-delt') {
              continue;
            }
            expect(ids, hasLength(1),
                reason: '${segment.id} on ${view.taxonomyView} resolved to '
                    '$ids; front-delt is meant to be the only ambiguous '
                    'segment in the taxonomy');
          }
        }
      }
    });

    test('side-delt has no segment of its own on either view', () {
      for (final view in BodyView.values) {
        for (final gender in [BodyGender.male, BodyGender.female]) {
          final asset = kBodyAssets[bodyAssetKey(view, gender)]!;
          expect(
            asset.segments.map((s) => s.id),
            isNot(contains('shoulders/side-delt')),
          );
        }
      }
      expect(
        kSubMuscleGroups['shoulders/side-delt']!.segments.single.segment,
        'shoulders/front-delt',
      );
    });
  });

  group('hit-testing', () {
    test('a point inside a known segment resolves to that segment', () {
      const painter = BodyDiagramPainter(
        view: BodyView.front,
        gender: BodyGender.male,
        fill: mutedBodyFill,
      );
      final point = _pointHitting(painter, box, 'quads/quads');

      final hit = painter.segmentAt(point, box);
      expect(hit, isNotNull);
      expect(hit!.id, 'quads/quads');
      expect(hit.subMuscleGroupIds, {'quads/quads'});
    });

    test('a point outside every segment resolves to nothing, and does not '
        'throw', () {
      const painter = BodyDiagramPainter(
        view: BodyView.front,
        gender: BodyGender.male,
        fill: mutedBodyFill,
      );
      // The top-left corner of the box: the drawing is centred and the head is
      // decorative, so nothing interactive can be there.
      expect(painter.segmentAt(Offset.zero, box), isNull);
    });

    testWidgets('a tap on a segment reports its sub-muscle group ids',
        (tester) async {
      Set<String>? reported;
      await tester.pumpWidget(
        host(
          BodyDiagram(
            view: BodyView.front,
            fill: mutedBodyFill,
            onSegmentTap: (ids) => reported = ids,
          ),
        ),
      );
      await tester.pumpAndSettle();

      const painter = BodyDiagramPainter(
        view: BodyView.front,
        gender: BodyGender.male,
        fill: mutedBodyFill,
      );
      final topLeft = tester.getTopLeft(find.byType(BodyDiagram));

      await tester.tapAt(topLeft + _pointHitting(painter, box, 'chest/mid'));
      await tester.pumpAndSettle();
      expect(reported, {'chest/mid'});

      await tester.tapAt(
        topLeft + _pointHitting(painter, box, 'shoulders/front-delt'),
      );
      await tester.pumpAndSettle();
      expect(reported, {'shoulders/front-delt', 'shoulders/side-delt'});
    });

    testWidgets('a tap on empty space reports nothing', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        host(
          BodyDiagram(
            view: BodyView.front,
            fill: mutedBodyFill,
            onSegmentTap: (_) => calls++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(
        tester.getTopLeft(find.byType(BodyDiagram)) + const Offset(2, 2),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(calls, 0);
    });
  });

  group('the painted fill', () {
    test('every segment is painted with the colour the caller returned for it',
        () {
      final canvas = _RecordingCanvas();
      const BodyDiagramPainter(
        view: BodyView.front,
        gender: BodyGender.male,
        fill: _accentByFirstId,
      ).paint(canvas, box);

      final asset = kBodyAssets['frontMale']!;
      // One decorative pass, then one pass per segment, in order.
      expect(canvas.paints, hasLength(asset.segments.length + 1));
      expect(canvas.paints.first.color.toARGB32(),
          AppPalette.mutedSurface.toARGB32());
      expect(canvas.paints.first.style, PaintingStyle.fill);

      for (var i = 0; i < asset.segments.length; i++) {
        final ids = subMuscleGroupsForSegment(
          BodyView.front,
          asset.segments[i].id,
        );
        expect(
          canvas.paints[i + 1].color.toARGB32(),
          _accentByFirstId(ids).toARGB32(),
          reason: '${asset.segments[i].id} was not painted in the colour the '
              'fill function returned for it',
        );
      }
    });

    test('a muted fill paints no segment in an accent colour', () {
      for (final view in BodyView.values) {
        for (final gender in [BodyGender.male, BodyGender.female]) {
          final canvas = _RecordingCanvas();
          BodyDiagramPainter(view: view, gender: gender, fill: mutedBodyFill)
              .paint(canvas, box);

          for (final paint in canvas.paints) {
            expect(paint.color.toARGB32(), AppPalette.mutedSurface.toARGB32());
            expect(paint.color.toARGB32(),
                isNot(AppPalette.accentStrong.toARGB32()));
            expect(paint.color.toARGB32(),
                isNot(AppPalette.accentLight.toARGB32()));
          }
        }
      }
    });
  });

  group('the scaled-path cache', () {
    test('the scaled paths are built once per asset and scale', () {
      const painter = BodyDiagramPainter(
        view: BodyView.front,
        gender: BodyGender.male,
        fill: mutedBodyFill,
      );
      final first = painter.segmentPathsFor(box);
      final second = painter.segmentPathsFor(box);

      expect(identical(first, second), isTrue,
          reason: 'the scaled path is what gets drawn and hit-tested, so '
              'rebuilding it per frame is the exact waste CLAUDE.md names');
      expect(identical(painter.decorativePathFor(box),
          painter.decorativePathFor(box)), isTrue);
    });

    test('it stays capped however many scales pass through it', () {
      const painter = BodyDiagramPainter(
        view: BodyView.front,
        gender: BodyGender.male,
        fill: mutedBodyFill,
      );

      // The header used to say the cache was "bounded by construction — four
      // assets times the handful of scales a phone's layout produces", and
      // nothing enforced it: the key's second half is a raw double off the
      // layout box, so a resize drag mints one entry per frame. Forty
      // width-limited boxes stand in for that drag.
      for (var i = 0; i < kScaledBodyCacheLimit * 5; i++) {
        painter.decorativePathFor(Size(200 + i.toDouble(), 2000));
      }

      expect(scaledBodyCacheSize, lessThanOrEqualTo(kScaledBodyCacheLimit),
          reason: 'a comment claiming a bound has to be backed by one');
    });

    test('a different size gets its own paths', () {
      const painter = BodyDiagramPainter(
        view: BodyView.front,
        gender: BodyGender.male,
        fill: mutedBodyFill,
      );
      final small = painter.decorativePathFor(box);
      final large = painter.decorativePathFor(box * 2);

      expect(identical(small, large), isFalse);
      expect(large.getBounds().width, greaterThan(small.getBounds().width));
    });

    test('the male and female front assets scale to different paths', () {
      const male = BodyDiagramPainter(
        view: BodyView.front,
        gender: BodyGender.male,
        fill: mutedBodyFill,
      );
      const female = BodyDiagramPainter(
        view: BodyView.front,
        gender: BodyGender.female,
        fill: mutedBodyFill,
      );

      // Both viewBoxes are 700 wide but 1324 vs 1268 tall, so a cache keyed on
      // the rendered size alone — or a scale computed once and reused — would
      // hand one asset the other's geometry at exactly the right width.
      expect(
        female.decorativePathFor(box).getBounds().height,
        isNot(moreOrLessEquals(
          male.decorativePathFor(box).getBounds().height,
          epsilon: 1,
        )),
      );
      expect(
        setEquals(
          male.segmentPathsFor(box).map((s) => s.id).toSet(),
          female.segmentPathsFor(box).map((s) => s.id).toSet(),
        ),
        isTrue,
        reason: 'the two assets are the same segments drawn differently',
      );
    });
  });

  group('the gender seam', () {
    test('the unset default is the male asset pair', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(bodyGenderProvider), BodyGender.male);
    });

    test('prefer-not-to-say resolves to the male pair', () {
      expect(bodyAssetKey(BodyView.front, BodyGender.preferNotToSay),
          'frontMale');
      expect(bodyAssetKey(BodyView.back, BodyGender.preferNotToSay),
          'backMale');
    });

    test('every view and gender names a shipped asset', () {
      for (final view in BodyView.values) {
        for (final gender in BodyGender.values) {
          expect(kBodyAssets, contains(bodyAssetKey(view, gender)));
        }
      }
    });
  });
}

/// A point, in the widget's local coordinates, that visibly lands on
/// [segmentId].
///
/// Scanned rather than taken from the segment's bounding-box centre: most
/// segments are two lobes (left and right), so their centre falls in the gap
/// between them, and several sit underneath a later segment that the painter
/// draws over the top of.
///
/// **It must not ask [BodyDiagramPainter.segmentAt] where the point is.** An
/// earlier version did, and a deliberately broken hit-test — one dropping the
/// centring offset, the exact bug this unit is meant to rule out — passed every
/// test: the helper simply picked a point the broken code agreed with. So the
/// point is derived from the painted geometry only (inside this segment, under
/// no later one) and `segmentAt` is then asked to agree with it.
Offset _pointHitting(
  BodyDiagramPainter painter,
  Size size,
  String segmentId,
) {
  final segments = painter.segmentPathsFor(size);
  final index = segments.indexWhere((s) => s.id == segmentId);
  expect(index, isNot(-1), reason: '$segmentId is not in this asset');
  final segment = segments[index];
  final bounds = segment.path.getBounds();
  final origin = painter.originFor(size);

  for (var i = 1; i < 60; i++) {
    for (var j = 1; j < 60; j++) {
      final point = Offset(
        bounds.left + bounds.width * i / 60,
        bounds.top + bounds.height * j / 60,
      );
      if (!segment.path.contains(point)) continue;
      // Anything drawn later covers this one, so it is what the user sees.
      if (segments.skip(index + 1).any((s) => s.path.contains(point))) continue;
      return point + origin;
    }
  }
  fail('no visible point found inside $segmentId');
}

Color _accentEverything(Set<String> ids) => AppPalette.accentStrong;

/// A fill that differs per segment, so a painter hard-coding one colour — or
/// painting the segments in the wrong order — cannot pass.
Color _accentByFirstId(Set<String> ids) =>
    ids.first.codeUnitAt(0).isEven
        ? AppPalette.accentStrong
        : AppPalette.accentLight;

/// A [Canvas] that records the [Paint] of every fill instead of rasterising.
class _RecordingCanvas implements Canvas {
  final List<Paint> paints = <Paint>[];

  @override
  void drawPath(Path path, Paint paint) => paints.add(paint);

  @override
  void save() {}

  @override
  void restore() {}

  @override
  void translate(double dx, double dy) {}

  // Any other Canvas call is a draw or transform this painter is not expected
  // to make; letting it throw is the point.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
