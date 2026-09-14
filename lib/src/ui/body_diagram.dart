import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/body_gender.dart';
import '../data/generated/body_paths.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../theme/app_palette.dart';

/// Returns the colour one segment is filled with, given **every** sub-muscle
/// group that segment stands for.
///
/// **The set, not a single id, is the parameter that makes this reusable.** One
/// segment in the taxonomy — front-delt — is claimed by two sub-groups, so a
/// callback taking a single id would have forced the widget to pick one of
/// them, and picking is a caller's decision: the exercise page wants
/// accent-strong if *any* of a segment's groups is primary, the landing wants
/// muted regardless. Handing over the whole set lets both answer without the
/// diagram knowing that exercises exist (R22).
typedef BodySegmentFill = Color Function(Set<String> subMuscleGroupIds);

/// Reports the sub-muscle groups a tapped segment stands for.
///
/// The widget deliberately does not resolve a two-group tap. R7 wants the
/// front-delt tap to *ask* which delt was meant, and a disambiguation prompt is
/// a screen decision, not a painter's.
typedef BodySegmentTapped = void Function(Set<String> subMuscleGroupIds);

/// The fill R2 asks for: every segment in the muted surface colour, saying
/// nothing about the user.
///
/// A top-level function rather than a closure so callers — and the tests — can
/// build a `const BodyDiagramPainter` with it.
Color mutedBodyFill(Set<String> subMuscleGroupIds) => AppPalette.mutedSurface;

/// One segment of one asset, already scaled to the rendered size, together with
/// the sub-muscle groups it stands for.
@immutable
class BodyDiagramSegment {
  const BodyDiagramSegment({
    required this.id,
    required this.subMuscleGroupIds,
    required this.path,
  });

  /// `'<muscleGroup>/<subMuscleGroup>'`, matching `body_paths.dart`. It is a
  /// sub-group id *shaped* string but not necessarily a sub-group that exists:
  /// the front-delt segment is drawn once and claimed twice.
  final String id;

  /// Every sub-muscle group that fills this segment. One entry for 40 of the
  /// 42 segments: the exception is the front-delt polygon, which carries both
  /// delts, and it is drawn on two of the four assets.
  final Set<String> subMuscleGroupIds;

  /// In the painter's local coordinates, **before** the centring translation —
  /// see [BodyDiagramPainter.originFor].
  final Path path;
}

/// The sub-muscle groups drawn by [segmentId] on [view].
///
/// This inverts `kSubMuscleGroups`, which is authored the other way round: each
/// sub-group lists the `(view, segment)` pairs it fills. Two sub-groups can
/// name the same pair — `shoulders/front-delt` and `shoulders/side-delt` both
/// point at the front view's `shoulders/front-delt` segment, because side-delt
/// has no artwork of its own anywhere (R5 is why the list on the landing is its
/// only other route). Inverting is therefore many-to-many, and doing it once
/// here is what stops each screen from re-deriving it.
Set<String> subMuscleGroupsForSegment(BodyView view, String segmentId) =>
    _segmentIndex[(view.taxonomyView, segmentId)] ?? const <String>{};

/// Built once on first use: 42 segments across four assets, and the map is
/// read on every tap.
final Map<(String, String), Set<String>> _segmentIndex = () {
  final index = <(String, String), Set<String>>{};
  for (final group in kSubMuscleGroups.values) {
    for (final placement in group.segments) {
      index
          .putIfAbsent(
            (placement.view, placement.segment),
            () => <String>{},
          )
          .add(group.id);
    }
  }
  return index;
}();

/// The body map: one asset, filled per segment by the caller, reporting taps.
///
/// **One widget for every screen in the tab (R20).** The landing, the exercise
/// page and — later — anything that colours a session all render the same four
/// traced assets with the same 42 hit targets; a second implementation would
/// drift on exactly the two exceptions that are easy to miss (the shared
/// front-delt segment, and the per-asset viewBox).
///
/// The gender comes from [bodyGenderProvider] rather than from a parameter, so
/// `docs/04`'s "changing gender later in Profile immediately switches the
/// diagram set app-wide" is true by construction instead of by every caller
/// remembering to thread it through.
class BodyDiagram extends ConsumerWidget {
  const BodyDiagram({
    required this.view,
    required this.fill,
    this.onSegmentTap,
    super.key,
  });

  final BodyView view;
  final BodySegmentFill fill;

  /// Null makes the diagram read-only — the exercise page's use (R16).
  final BodySegmentTapped? onSegmentTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final painter = BodyDiagramPainter(
      view: view,
      gender: ref.watch(bodyGenderProvider),
      fill: fill,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = bodyDiagramSize(constraints, painter.asset.viewBox);
        return GestureDetector(
          // Opaque, not deferToChild: a `CustomPaint` with no child has no hit
          // region of its own, so taps would fall through to whatever is
          // behind the diagram.
          behavior: HitTestBehavior.opaque,
          onTapUp: onSegmentTap == null
              ? null
              : (details) {
                  final segment =
                      painter.segmentAt(details.localPosition, size);
                  if (segment != null) {
                    onSegmentTap!(segment.subMuscleGroupIds);
                  }
                },
          child: CustomPaint(painter: painter, size: size),
        );
      },
    );
  }
}

/// The box the diagram occupies under [constraints].
///
/// When both axes are bounded the diagram takes the whole box and the painter
/// centres the drawing inside it. When only one is — the scrolling landing
/// gives a bounded width and an unbounded height — the other is derived from
/// [viewBox] so the body is never stretched. Each asset has its own viewBox, so
/// this must be asked per asset rather than computed once.
Size bodyDiagramSize(BoxConstraints constraints, Size viewBox) {
  if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) {
    return constraints.biggest;
  }
  if (constraints.hasBoundedWidth) {
    final width = constraints.maxWidth;
    return Size(width, width * viewBox.height / viewBox.width);
  }
  if (constraints.hasBoundedHeight) {
    final height = constraints.maxHeight;
    return Size(height * viewBox.width / viewBox.height, height);
  }
  return viewBox;
}

/// Fills one body asset, and answers which segment a point lands in.
///
/// Public, and with public geometry helpers, for the reason
/// `tab_glyph_test.dart` exists: a painter that silently ignores its fill still
/// renders a perfectly plausible body, and a hit-test that scales differently
/// from the paint still returns *a* muscle for most taps. Neither failure is
/// visible, so both are asserted against what actually reaches the canvas.
class BodyDiagramPainter extends CustomPainter {
  const BodyDiagramPainter({
    required this.view,
    required this.gender,
    required this.fill,
  });

  final BodyView view;
  final BodyGender gender;
  final BodySegmentFill fill;

  /// The `kBodyAssets` key these two fields name. The join lives in
  /// `body_gender.dart`; this is the only thing that asks for it.
  String get assetKey => bodyAssetKey(view, gender);

  BodyAsset get asset => kBodyAssets[assetKey]!;

  /// Uniform, so the body is never stretched, and computed from *this* asset's
  /// viewBox. The four viewBoxes are 700×1324, 712×1324, 700×1268 and 704×1252
  /// — close enough that a scale borrowed from one would render the next at
  /// almost the right size, which is precisely how such a bug survives review.
  double scaleFor(Size size) => math.min(
        size.width / asset.viewBox.width,
        size.height / asset.viewBox.height,
      );

  /// Where the drawing's top-left corner sits inside [size] — half the leftover
  /// space on each axis.
  ///
  /// Kept out of the cached paths so that resizing the box without changing the
  /// scale does not invalidate them, and applied identically by [paint] (as a
  /// canvas translation) and by [segmentAt] (by subtracting it from the tap).
  /// Sharing it is what keeps a tap and the colour it appears to hit from
  /// disagreeing.
  Offset originFor(Size size) {
    final scale = scaleFor(size);
    return Offset(
      (size.width - asset.viewBox.width * scale) / 2,
      (size.height - asset.viewBox.height * scale) / 2,
    );
  }

  /// The non-interactive silhouette — head, neck, knee tie-in — scaled to
  /// [size].
  Path decorativePathFor(Size size) => _scaled(size).decorative;

  /// Every interactive segment of this asset, scaled to [size], in the order
  /// the asset declares them.
  List<BodyDiagramSegment> segmentPathsFor(Size size) => _scaled(size).segments;

  /// The fill [color] is applied with. Antialiased because these are large
  /// polygons meeting along shared edges; without it the seams show.
  Paint buildPaint(Color color) => Paint()
    ..style = PaintingStyle.fill
    ..color = color
    ..isAntiAlias = true;

  /// The segment containing [position] — in the widget's local coordinates —
  /// or null if the point is outside every one of them.
  ///
  /// Walked in reverse so the last-drawn segment wins, matching what the user
  /// sees: the assets overlap slightly at the shoulder and hip, and the painter
  /// draws them in declaration order, so the topmost one is the one at the end.
  BodyDiagramSegment? segmentAt(Offset position, Size size) {
    final local = position - originFor(size);
    final segments = segmentPathsFor(size);
    for (var i = segments.length - 1; i >= 0; i--) {
      final segment = segments[i];
      // A segment claimed by no sub-group would be untappable rather than
      // tappable-but-silent; `test/body_diagram_test.dart` fails if one ever
      // appears, because it means the artwork and the taxonomy have drifted.
      if (segment.subMuscleGroupIds.isEmpty) continue;
      if (segment.path.contains(local)) return segment;
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final origin = originFor(size);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.drawPath(decorativePathFor(size), buildPaint(AppPalette.mutedSurface));
    for (final segment in segmentPathsFor(size)) {
      canvas.drawPath(
        segment.path,
        buildPaint(fill(segment.subMuscleGroupIds)),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BodyDiagramPainter oldDelegate) =>
      oldDelegate.view != view ||
      oldDelegate.gender != gender ||
      oldDelegate.fill != fill;

  /// [view] is handed over rather than left to be read back out of
  /// [assetKey]: this object already knows which side it is drawing, and
  /// recovering it from the key's spelling is a string comparison standing in
  /// for a value that was never lost.
  _ScaledBody _scaled(Size size) => _scaledBody(assetKey, view, scaleFor(size));
}

/// One asset's geometry at one scale.
class _ScaledBody {
  const _ScaledBody(this.decorative, this.segments);

  final Path decorative;
  final List<BodyDiagramSegment> segments;
}

/// Scaled body geometry, keyed by asset and scale.
///
/// **The scaled path is what gets drawn and hit-tested, so caching the
/// unscaled one is not enough** — the trap `CLAUDE.md` and
/// `stroke_glyph.dart`'s header both name. This is a separate cache from that
/// file's rather than an extension of it: `scaledGlyphPath` assumes a square
/// 24-unit viewBox and scales by `shortestSide`, which is wrong for four
/// different non-square viewBoxes, and its paths are stroked rather than
/// filled. The two have nothing in common but the word "cache".
///
/// Keyed on the scale, not the rendered size: a diagram in a 300×600 box and
/// one in a 300×900 box resolve to the same width-limited scale and can share
/// 42 identical paths.
///
/// **Bounded by eviction, not by construction.** This said "bounded by
/// construction — four assets times the handful of scales a phone's layout
/// produces", and that was not true of anything written here: the key's second
/// half is a raw `double` off the layout box, so a resize drag, a split-screen
/// handle or any animated width mints a fresh entry every frame and nothing
/// ever dropped one. Quantising the scale instead would make the key space
/// genuinely small, but it would also paint the body at a scale its box did
/// not ask for — a rendering change — so the map is capped rather than the
/// key. Dart's `Map` iterates in insertion order, which is what makes
/// `keys.first` the oldest entry.
final Map<(String, double), _ScaledBody> _scaledBodies =
    <(String, double), _ScaledBody>{};

/// How many scaled assets are kept at once.
///
/// Four assets at two scales apiece: the steady layout, and whatever a resize
/// is passing through. A miss costs 42 polyline transforms once, so being a
/// little wrong here is a frame's work rather than a correctness problem —
/// which is why this is a plain FIFO and not an LRU.
const int kScaledBodyCacheLimit = 8;

_ScaledBody _scaledBody(String assetKey, BodyView view, double scale) {
  final key = (assetKey, scale);
  final cached = _scaledBodies[key];
  if (cached != null) return cached;

  final asset = kBodyAssets[assetKey]!;
  final matrix = Matrix4.diagonal3Values(scale, scale, 1).storage;

  final decorative = Path();
  for (final outline in asset.decorative) {
    if (outline.length < 4) continue;
    decorative.moveTo(outline[0], outline[1]);
    for (var i = 2; i < outline.length; i += 2) {
      decorative.lineTo(outline[i], outline[i + 1]);
    }
    decorative.close();
  }

  final built = _ScaledBody(
    decorative.transform(matrix),
    [
      for (final segment in asset.segments)
        BodyDiagramSegment(
          id: segment.id,
          subMuscleGroupIds: subMuscleGroupsForSegment(view, segment.id),
          path: segment.toPath().transform(matrix),
        ),
    ],
  );

  if (_scaledBodies.length >= kScaledBodyCacheLimit) {
    _scaledBodies.remove(_scaledBodies.keys.first);
  }
  return _scaledBodies[key] = built;
}

/// How many scaled assets the cache is holding, so a test can prove the cap is
/// real rather than trusting the comment above it.
@visibleForTesting
int get scaledBodyCacheSize => _scaledBodies.length;
