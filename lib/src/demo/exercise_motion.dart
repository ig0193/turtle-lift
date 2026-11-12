/// A demonstration: keyframed poses, the scenery around them, and how the
/// equipment is held.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'figure_rig.dart';

/// One keyframe on a cycle that runs from 0 to 1 and wraps back to the first.
class MotionKey {
  const MotionKey(this.t, this.pose);

  final double t;
  final Pose pose;
}

/// Fixed scenery, world space. Drawn behind the figure.
sealed class Prop {
  const Prop();

  /// The world rectangle the prop occupies, for fitting the camera.
  Rect get bounds;
}

/// A padded surface from [a] to [b] — a bench, a seat, a back pad. With
/// [legs] it stands on the floor; without, it hangs off a post.
class PadProp extends Prop {
  const PadProp(this.a, this.b, {this.legs = true, this.post = false});

  final Offset a;
  final Offset b;
  final bool legs;

  /// A single central post to the floor instead of two legs (machine seats).
  final bool post;

  @override
  Rect get bounds =>
      Rect.fromPoints(a, b).expandToInclude(Rect.fromLTWH(a.dx, 0, 0, 0));
}

/// A horizontal bar seen end-on (side view) or across (front view): pull-up
/// bars, dip bars, a Smith rack's hooks.
class BarProp extends Prop {
  const BarProp(this.at, {this.width = 0, this.uprights = true});

  final Offset at;

  /// Front-view half width; zero draws the end-on circle.
  final double width;
  final bool uprights;

  @override
  Rect get bounds => Rect.fromLTRB(at.dx - width - 0.03, 0, at.dx + width + 0.03, at.dy + 0.03);
}

/// A box or step, floor-standing.
class BoxProp extends Prop {
  const BoxProp(this.rect);

  final Rect rect;

  @override
  Rect get bounds => rect;
}

/// A wall at [x], from the floor to [top].
class WallProp extends Prop {
  const WallProp(this.x, {this.top = 1.0});

  final double x;
  final double top;

  @override
  Rect get bounds => Rect.fromLTRB(x - 0.02, 0, x + 0.02, top);
}

/// A stability ball that stays put.
class BallProp extends Prop {
  const BallProp(this.centre, {this.radius = 0.13});

  final Offset centre;
  final double radius;

  @override
  Rect get bounds => Rect.fromCircle(center: centre, radius: radius);
}

/// Which point of the body an implement is attached to.
enum GearAt { hands, hip, shoulders, ankles, knees, feet }

/// How this demonstration holds whatever the exercise's gear turns out to be.
///
/// **The gear itself is not decided here.** The same squat is a barbell squat,
/// a band squat or a Smith squat depending on the exercise; the exercise
/// library names the gear (`animationGear`) and this says where it goes.
class GearRig {
  const GearRig({
    this.at = GearAt.hands,
    this.anchorN,
    this.anchorF,
    this.oneHand = false,
    this.shared = false,
    this.padLength = 0.09,
    this.offset = Offset.zero,
  });

  final GearAt at;

  /// Where a cable runs to, a band is tied, a lever pivots, or a landmine is
  /// seated. `null` for a band means it runs under the feet.
  final Offset? anchorN;

  /// The far hand's anchor, when the two hands pull from different places
  /// (a crossover). Defaults to [anchorN].
  final Offset? anchorF;

  /// Only the near hand holds anything (a single-arm row, a suitcase carry).
  final bool oneHand;

  /// One implement held in both hands: a goblet dumbbell, a plate, a rope.
  final bool shared;

  /// Length of a machine's contact pad, across the lever.
  final double padLength;

  /// Where the implement sits relative to its attachment point: a bar resting
  /// on the hips, a ball under the heels.
  final Offset offset;
}

/// A complete demonstration.
class ExerciseMotion {
  ExerciseMotion({
    required this.view,
    required List<MotionKey> keys,
    this.seconds = 2.8,
    this.props = const <Prop>[],
    this.gear = const GearRig(),
    this.peak = 1,
    this.hold = false,
  })  : keys = List<MotionKey>.unmodifiable(keys),
        assert(keys.isNotEmpty),
        assert(keys.first.t == 0, 'a cycle starts at its first key');

  final DemoView view;
  final List<MotionKey> keys;

  /// One full cycle, at real speed.
  final double seconds;
  final List<Prop> props;
  final GearRig gear;

  /// The key that best shows the work — the bottom of a squat, the top of a
  /// curl. The still frame shows it solid over a ghost of the first key.
  final int peak;

  /// A timed hold rather than reps: the demonstration breathes in place and
  /// shows a timer.
  final bool hold;

  /// The pose at cycle position [t] (0 to 1), eased between keys.
  Pose poseAt(double t) {
    final c = t - t.floorToDouble();
    if (keys.length == 1) return keys.single.pose;
    for (var i = 0; i < keys.length; i++) {
      final a = keys[i];
      final b = i + 1 < keys.length ? keys[i + 1] : null;
      final bt = b?.t ?? 1.0;
      if (c >= a.t && c <= bt) {
        final span = bt - a.t;
        final local = span <= 0 ? 0.0 : (c - a.t) / span;
        // Sine ease in and out: weight decelerates into each position and
        // accelerates out of it, the way a controlled rep looks.
        final eased = 0.5 - 0.5 * math.cos(math.pi * local);
        return Pose.lerp(a.pose, (b ?? keys.first).pose, eased);
      }
    }
    return keys.first.pose;
  }

  /// The still frame's solid pose.
  Pose get peakPose => keys[peak.clamp(0, keys.length - 1)].pose;
}
