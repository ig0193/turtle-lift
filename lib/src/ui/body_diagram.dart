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
class BodyDiagram extends ConsumerStatefulWidget {
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
  ConsumerState<BodyDiagram> createState() => _BodyDiagramState();
}

class _BodyDiagramState extends ConsumerState<BodyDiagram> {
  /// The muscle currently under the finger, or null.
  ///
  /// **A press state exists because a body map has no hover on a phone.** The
  /// approved prototype names the muscle under the pointer and lights it; that
  /// is how a reader learns the map is made of 19 nameable parts rather than
  /// being one picture. A finger has no hover, so the press itself stands in:
  /// hold and the muscle answers, release and it opens.
  BodyDiagramSegment? _pressed;
  Offset? _pressedAt;

  /// True once the finger lifts, for the moment before the muscle opens.
  ///
  /// **Hold and commit are different colours because they answer different
  /// questions.** Holding asks "which one is this?" and gets the light accent —
  /// the prototype's hover. Lifting answers "this one", and gets the full
  /// accent, §12's "active", so the choice is visibly made before the screen
  /// changes under it.
  bool _committed = false;

  void _clear() {
    if (_pressed == null && !_committed) return;
    setState(() {
      _pressed = null;
      _pressedAt = null;
      _committed = false;
    });
  }

  /// How long the chosen muscle keeps its full accent after the screen has
  /// already been asked for.
  ///
  /// **The navigation is not delayed to show it.** The push is requested in the
  /// same frame the colour lands, so the route's own transition is what the
  /// commit colour is visible during — holding the tap back to play an
  /// animation would make every muscle slower to open for no gain. This only
  /// decides when the landing underneath stops being painted that way.
  static const Duration _commitHold = Duration(milliseconds: 450);

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onSegmentTap != null;
    final pressedIds = _pressed?.subMuscleGroupIds;

    final painter = BodyDiagramPainter(
      view: widget.view,
      gender: ref.watch(bodyGenderProvider),
      // The muscle under the finger is painted over whatever the caller asked
      // for: the light accent while held, the full accent once chosen. Both are
      // owned by the touch and gone when it ends, so neither ever claims
      // anything about training.
      fill: pressedIds == null
          ? widget.fill
          : (ids) => identical(ids, pressedIds)
              ? (_committed ? AppPalette.accentStrong : AppPalette.accentLight)
              : widget.fill(ids),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = bodyDiagramSize(constraints, painter.asset.viewBox);
        return GestureDetector(
          // Opaque, not deferToChild: a `CustomPaint` with no child has no hit
          // region of its own, so taps would fall through to whatever is
          // behind the diagram.
          behavior: HitTestBehavior.opaque,
          onTapDown: !interactive
              ? null
              : (details) {
                  final segment =
                      painter.segmentAt(details.localPosition, size);
                  if (segment == null) return;
                  setState(() {
                    _pressed = segment;
                    _pressedAt = details.localPosition;
                  });
                },
          onTapCancel: !interactive ? null : _clear,
          onTapUp: !interactive
              ? null
              : (details) async {
                  final segment =
                      painter.segmentAt(details.localPosition, size);
                  if (segment == null) {
                    _clear();
                    return;
                  }
                  setState(() {
                    _pressed = segment;
                    // The name has served its purpose the moment the choice is
                    // made, and the next screen is already coming — leaving it
                    // would park a label over the transition.
                    _pressedAt = null;
                    _committed = true;
                  });
                  widget.onSegmentTap!(segment.subMuscleGroupIds);
                  await Future<void>.delayed(_commitHold);
                  if (mounted) _clear();
                },
          child: SizedBox.fromSize(
            size: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                CustomPaint(painter: painter, size: size),
                if (pressedIds != null && _pressedAt != null)
                  _MuscleNameLabel(
                    ids: pressedIds,
                    at: _pressedAt!,
                    within: size,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The name of the muscle being pressed, shown beside the finger.
///
/// **Naming it is the point, not decorating it.** A segment lighting up says
/// "something is here"; the name says *which* muscle, which is the question a
/// reference tab exists to answer. It sits above the touch so the finger does
/// not cover it, and is clamped to the diagram's bounds so a muscle near an
/// edge still reads.
class _MuscleNameLabel extends StatelessWidget {
  const _MuscleNameLabel({
    required this.ids,
    required this.at,
    required this.within,
  });

  final Set<String> ids;
  final Offset at;
  final Size within;

  /// Two names when the segment carries two — the front-delt polygon is shared,
  /// and saying only one of them would be a lie about what a tap will open.
  static String labelFor(Set<String> ids) =>
      ids.map((id) => kSubMuscleGroups[id]?.label ?? id).join(' · ');

  @override
  Widget build(BuildContext context) {
    const width = 168.0;
    final left = (at.dx - width / 2).clamp(0.0, (within.width - width).clamp(0.0, double.infinity));
    final top = (at.dy - 46).clamp(0.0, within.height);
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: SizedBox(
          width: width,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppPalette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  labelFor(ids),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
/// How thick the line between two muscles is, in logical pixels.
const double kBodySegmentSeparatorWidth = 2.5;

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

  /// The line that separates one muscle from the next.
  ///
  /// **Without it the map is a silhouette, not an anatomy.** Every segment on
  /// the landing is filled the same muted colour, so fill alone cannot show
  /// where one muscle ends and the next begins — the body reads as a single
  /// dark shape and there is nothing to aim a tap at. The approved prototype
  /// strokes each segment for exactly this reason
  /// (`prototypes/muscles-tab-variants.html`), and `CLAUDE.md` gives the
  /// prototype authority over how a screen looks.
  ///
  /// [AppPalette.border] is the palette's own divider colour and is lighter
  /// than the muted fill, so each muscle reads as an outlined region the way an
  /// anatomical drawing does. A darker line was tried first and cut the body
  /// into gaps instead of drawing it; §12 ends "No other colours", so a third
  /// option was never available.
  ///
  /// The width is in logical pixels and is deliberately **not** scaled with the
  /// geometry — the same rule `stroke_glyph.dart` follows, so the separation
  /// stays legible whether the body is drawn at 200pt or 600pt.
  Paint buildSeparatorPaint() => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = kBodySegmentSeparatorWidth
    ..color = AppPalette.border
    ..isAntiAlias = true
    ..strokeJoin = StrokeJoin.round;

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
    canvas.drawPath(decorativePathFor(size), buildPaint(AppPalette.surface));
    final segments = segmentPathsFor(size);
    for (final segment in segments) {
      canvas.drawPath(
        segment.path,
        buildPaint(fill(segment.subMuscleGroupIds)),
      );
    }
    // Separators last, so a muscle's own fill never paints over the line that
    // divides it from its neighbour.
    final separator = buildSeparatorPaint();
    for (final segment in segments) {
      canvas.drawPath(segment.path, separator);
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
