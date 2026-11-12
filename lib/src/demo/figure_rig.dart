/// The skeleton behind every exercise demonstration: a pose, the limbs in it,
/// and the kinematics that turn a pose into joint positions.
///
/// **Original, parametric, and drawn by the app** (`docs/adr/0010-exercise-
/// demonstrations-are-drawn-not-bundled.md`). No third-party artwork, no
/// bundled frames: a demonstration is a few keyframed poses, so 260 exercises
/// cost kilobytes of Dart rather than megabytes of GIFs, and every one of them
/// is licence-free and in one consistent style.
///
/// **World space is y-up, in figure heights.** The floor is `y = 0` and a
/// standing figure's head tops out a little under `y = 1`. The painter flips
/// and scales it; nothing here knows about pixels.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, lerpDouble;

/// Which way the camera looks at the figure.
enum DemoView {
  /// Profile, facing +x. Near limbs are the figure's right side.
  side,

  /// Facing the camera. "Near" is the figure's right, drawn at screen left.
  front,
}

/// Segment lengths, in figure heights.
abstract final class Bone {
  static const double shin = 0.245;
  static const double thigh = 0.245;
  static const double torso = 0.29;
  static const double neck = 0.045;
  static const double headRadius = 0.058;
  static const double upperArm = 0.165;
  static const double forearm = 0.145;
  static const double hand = 0.05;
  static const double foot = 0.075;
  static const double heel = 0.022;

  /// Ankle height above the floor when standing.
  static const double ankle = 0.04;

  /// Half the distance between the hip joints, front view.
  static const double hipHalf = 0.055;

  /// Half the distance between the shoulders, front view.
  static const double shoulderHalf = 0.11;

  /// Pelvis height of a figure standing straight.
  static const double standingHip = ankle + shin + thigh;
}

/// What a limb position is anchored to.
enum Rel {
  /// A fixed point in the world: a bar, the floor, a bench.
  world,

  /// The limb's own root joint (shoulder for an arm, hip for a leg), so the
  /// target travels with the body — a goblet held at the chest.
  root,

  /// The pelvis.
  hip,

  /// The limb's root, in the torso's own frame: `dx` forward of the torso,
  /// `dy` along it toward the head. Hands crossed on the chest stay on the
  /// chest however far the torso leans.
  torso,
}

/// How one arm or leg is placed.
sealed class Limb {
  const Limb();

  /// Interpolates two limbs of the same kind. A demonstration keeps each limb
  /// in one mode for its whole cycle; mixing modes is an authoring error.
  static Limb lerp(Limb a, Limb b, double t) {
    if (a is Fk && b is Fk) {
      return Fk(lerpDouble(a.upper, b.upper, t)!, lerpDouble(a.lower, b.lower, t)!);
    }
    if (a is Ik && b is Ik) {
      assert(a.rel == b.rel, 'an IK limb keeps one anchor for the whole cycle');
      return Ik(
        Offset.lerp(a.target, b.target, t)!,
        bend: lerpDouble(a.bend, b.bend, t)!,
        rel: a.rel,
      );
    }
    throw ArgumentError('a limb cannot change between FK and IK mid-cycle');
  }

  /// The same limb reflected across `x = 0`, for front-view symmetry.
  Limb mirrored();
}

/// Forward kinematics: absolute segment angles in degrees, measured from
/// straight down and rotating toward +x (forward in the side view).
///
/// Absolute rather than relative because gravity is what the eye reads: a
/// hanging arm is `0` whatever the torso does. Used where the motion is a
/// rotation — a curl, a raise, a fly — so the hand travels the arc it really
/// travels.
class Fk extends Limb {
  const Fk(this.upper, this.lower);

  final double upper;
  final double lower;

  @override
  Limb mirrored() => Fk(-upper, -lower);
}

/// Inverse kinematics: the end of the limb (hand or ankle) at [target], with
/// the middle joint bent to the side [bend] names.
///
/// Used where the end is what is fixed or travels straight — feet planted
/// through a squat, a bar path, hands on a pull-up bar.
///
/// [bend] is `+1` or `-1`: which side of the root-to-target line the elbow or
/// knee sits on (counter-clockwise of it for `+1`, in y-up space). For a
/// standing leg in the side view `+1` puts the knee forward.
class Ik extends Limb {
  const Ik(this.target, {this.bend = 1, this.rel = Rel.world});

  final Offset target;
  final double bend;
  final Rel rel;

  @override
  Limb mirrored() => Ik(Offset(-target.dx, target.dy), bend: -bend, rel: rel);
}

/// One keyframe of a demonstration.
class Pose {
  const Pose({
    required this.hip,
    this.torso = 0,
    this.torsoLen = 1,
    this.neck = 0,
    this.shrug = 0,
    required this.armN,
    required this.armF,
    required this.legN,
    required this.legF,
    this.footN = 90,
    this.footF = 90,
    this.wristN = 0,
    this.wristF = 0,
    this.reachN = 1,
    this.reachF = 1,
    this.strideN = 1,
    this.strideF = 1,
  });

  /// Pelvis centre, world.
  final Offset hip;

  /// Torso angle in degrees. Side view: lean forward is positive, `90` is
  /// lying face down along +x, `-90` lying on the back with the head at -x.
  /// Front view: lean toward screen right is positive.
  final double torso;

  /// Torso length as a fraction of [Bone.torso]: a front view of a body bent
  /// toward the camera is foreshortened, not shorter.
  final double torsoLen;

  /// Head tilt relative to the torso, degrees, forward positive.
  final double neck;

  /// Shoulder elevation, 0 to 1.
  final double shrug;

  final Limb armN;
  final Limb armF;
  final Limb legN;
  final Limb legF;

  /// Absolute foot angle, degrees from straight down toward +x: `90` is flat
  /// and pointing forward; larger points the toes down (a calf raise).
  final double footN;
  final double footF;

  /// Hand angle relative to the forearm, degrees: positive flexes toward the
  /// palm side (a wrist curl).
  final double wristN;
  final double wristF;

  /// Arm length as a fraction of full, for an arm pointing at the camera:
  /// hands meeting in front of the chest, seen from the front, are hands at
  /// the chest on screen.
  final double reachN;
  final double reachF;

  /// The same foreshortening for a leg.
  final double strideN;
  final double strideF;

  /// The pose at [t] between [a] and [b].
  static Pose lerp(Pose a, Pose b, double t) => Pose(
        hip: Offset.lerp(a.hip, b.hip, t)!,
        torso: lerpDouble(a.torso, b.torso, t)!,
        torsoLen: lerpDouble(a.torsoLen, b.torsoLen, t)!,
        neck: lerpDouble(a.neck, b.neck, t)!,
        shrug: lerpDouble(a.shrug, b.shrug, t)!,
        armN: Limb.lerp(a.armN, b.armN, t),
        armF: Limb.lerp(a.armF, b.armF, t),
        legN: Limb.lerp(a.legN, b.legN, t),
        legF: Limb.lerp(a.legF, b.legF, t),
        footN: lerpDouble(a.footN, b.footN, t)!,
        footF: lerpDouble(a.footF, b.footF, t)!,
        wristN: lerpDouble(a.wristN, b.wristN, t)!,
        wristF: lerpDouble(a.wristF, b.wristF, t)!,
        reachN: lerpDouble(a.reachN, b.reachN, t)!,
        reachF: lerpDouble(a.reachF, b.reachF, t)!,
        strideN: lerpDouble(a.strideN, b.strideN, t)!,
        strideF: lerpDouble(a.strideF, b.strideF, t)!,
      );

  /// A copy with the named fields replaced.
  Pose copyWith({
    Offset? hip,
    double? torso,
    double? torsoLen,
    double? neck,
    double? shrug,
    Limb? armN,
    Limb? armF,
    Limb? legN,
    Limb? legF,
    double? footN,
    double? footF,
    double? wristN,
    double? wristF,
    double? reachN,
    double? reachF,
    double? strideN,
    double? strideF,
  }) =>
      Pose(
        hip: hip ?? this.hip,
        torso: torso ?? this.torso,
        torsoLen: torsoLen ?? this.torsoLen,
        neck: neck ?? this.neck,
        shrug: shrug ?? this.shrug,
        armN: armN ?? this.armN,
        armF: armF ?? this.armF,
        legN: legN ?? this.legN,
        legF: legF ?? this.legF,
        footN: footN ?? this.footN,
        footF: footF ?? this.footF,
        wristN: wristN ?? this.wristN,
        wristF: wristF ?? this.wristF,
        reachN: reachN ?? this.reachN,
        reachF: reachF ?? this.reachF,
        strideN: strideN ?? this.strideN,
        strideF: strideF ?? this.strideF,
      );
}

/// A limb resolved to three points.
class LimbJoints {
  const LimbJoints(this.root, this.mid, this.end);

  /// Shoulder or hip joint.
  final Offset root;

  /// Elbow or knee.
  final Offset mid;

  /// Wrist or ankle.
  final Offset end;
}

/// Every joint of a solved pose, world space.
class Skeleton {
  const Skeleton({
    required this.view,
    required this.hip,
    required this.shoulder,
    required this.headCentre,
    required this.neckTop,
    required this.armN,
    required this.armF,
    required this.legN,
    required this.legF,
    required this.handN,
    required this.handF,
    required this.toeN,
    required this.toeF,
    required this.heelN,
    required this.heelF,
  });

  final DemoView view;

  /// Pelvis centre.
  final Offset hip;

  /// Midpoint between the shoulders.
  final Offset shoulder;
  final Offset headCentre;
  final Offset neckTop;
  final LimbJoints armN;
  final LimbJoints armF;
  final LimbJoints legN;
  final LimbJoints legF;

  /// Fingertip end of each hand.
  final Offset handN;
  final Offset handF;
  final Offset toeN;
  final Offset toeF;
  final Offset heelN;
  final Offset heelF;

  /// Where a held implement sits: a little way into the hand.
  Offset gripN() => Offset.lerp(armN.end, handN, 0.55)!;
  Offset gripF() => Offset.lerp(armF.end, handF, 0.55)!;

  /// Every point, for fitting the camera.
  Iterable<Offset> get points sync* {
    yield hip;
    yield shoulder;
    yield headCentre + const Offset(0, Bone.headRadius);
    yield headCentre - const Offset(0, Bone.headRadius);
    yield headCentre + const Offset(Bone.headRadius, 0);
    yield headCentre - const Offset(Bone.headRadius, 0);
    for (final l in <LimbJoints>[armN, armF, legN, legF]) {
      yield l.root;
      yield l.mid;
      yield l.end;
    }
    yield handN;
    yield handF;
    yield toeN;
    yield toeF;
    yield heelN;
    yield heelF;
  }
}

/// Direction of an absolute limb angle (degrees from straight down, toward +x).
Offset limbDirection(double degrees) {
  final r = degrees * math.pi / 180;
  return Offset(math.sin(r), -math.cos(r));
}

/// Direction of a torso angle (degrees from straight up, toward +x).
Offset torsoDirection(double degrees) {
  final r = degrees * math.pi / 180;
  return Offset(math.sin(r), math.cos(r));
}

Offset _unit(Offset o) {
  final d = o.distance;
  return d == 0 ? const Offset(0, -1) : o / d;
}

/// Two-bone inverse kinematics. Returns the middle joint and the reached end
/// (which falls short of [target] when it is out of reach).
(Offset, Offset) solveTwoBone(
  Offset root,
  Offset target,
  double l1,
  double l2,
  double bend,
) {
  final delta = target - root;
  final dir = _unit(delta);
  final dist = delta.distance.clamp((l1 - l2).abs() + 1e-4, l1 + l2 - 1e-4);
  final a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist);
  final h = math.sqrt(math.max(0, l1 * l1 - a * a));
  final perp = Offset(-dir.dy, dir.dx);
  final mid = root + dir * a + perp * (h * bend.sign) * bend.abs().clamp(0, 1);
  final end = root + dir * dist;
  return (mid, end);
}

LimbJoints _solveLimb(
  Limb limb,
  Offset root,
  Offset hip,
  Offset torsoUp,
  double l1,
  double l2,
) {
  switch (limb) {
    case Fk(:final upper, :final lower):
      final mid = root + limbDirection(upper) * l1;
      return LimbJoints(root, mid, mid + limbDirection(lower) * l2);
    case Ik(:final target, :final bend, :final rel):
      final world = switch (rel) {
        Rel.world => target,
        Rel.root => root + target,
        Rel.hip => hip + target,
        Rel.torso => root +
            Offset(torsoUp.dy, -torsoUp.dx) * target.dx +
            torsoUp * target.dy,
      };
      final (mid, end) = solveTwoBone(root, world, l1, l2, bend);
      return LimbJoints(root, mid, end);
  }
}

/// Solves [pose] seen from [view].
Skeleton solvePose(Pose pose, DemoView view) {
  final dir = torsoDirection(pose.torso);
  // Screen-right of the torso axis, for spreading shoulders and hips in the
  // front view.
  final across = Offset(dir.dy, -dir.dx);
  final shrugLift = Offset(0, pose.shrug * 0.04);
  final shoulder = pose.hip + dir * (Bone.torso * pose.torsoLen) + shrugLift;

  final Offset hipN, hipF, shoulderN, shoulderF;
  if (view == DemoView.front) {
    hipN = pose.hip - across * Bone.hipHalf;
    hipF = pose.hip + across * Bone.hipHalf;
    shoulderN = shoulder - across * Bone.shoulderHalf;
    shoulderF = shoulder + across * Bone.shoulderHalf;
  } else {
    hipN = hipF = pose.hip;
    shoulderN = shoulderF = shoulder;
  }

  final headDir = torsoDirection(pose.torso + pose.neck);
  final neckTop = shoulder - shrugLift * 0.6 + headDir * Bone.neck;
  // The side view offsets the head a touch forward of the neck so the figure
  // has a face side; a perfectly centred circle reads the same both ways.
  final faceSide = view == DemoView.side
      ? Offset(headDir.dy, -headDir.dx) * 0.012
      : Offset.zero;
  final headCentre = neckTop + headDir * Bone.headRadius + faceSide;

  final armN = _solveLimb(pose.armN, shoulderN, pose.hip, dir,
      Bone.upperArm * pose.reachN, Bone.forearm * pose.reachN);
  final armF = _solveLimb(pose.armF, shoulderF, pose.hip, dir,
      Bone.upperArm * pose.reachF, Bone.forearm * pose.reachF);
  final legN = _solveLimb(pose.legN, hipN, pose.hip, dir,
      Bone.thigh * pose.strideN, Bone.shin * pose.strideN);
  final legF = _solveLimb(pose.legF, hipF, pose.hip, dir,
      Bone.thigh * pose.strideF, Bone.shin * pose.strideF);

  Offset hand(LimbJoints arm, double wrist) {
    final forearm = _unit(arm.end - arm.mid);
    // Flexion turns the hand toward the palm. Which way that is on screen
    // depends on the view and the side; the side view treats the palm as the
    // forearm's counter-clockwise side, which reads right for a curl.
    final r = wrist * math.pi / 180;
    final rotated = Offset(
      forearm.dx * math.cos(r) - forearm.dy * math.sin(r),
      forearm.dx * math.sin(r) + forearm.dy * math.cos(r),
    );
    return arm.end + rotated * Bone.hand;
  }

  (Offset, Offset) foot(LimbJoints leg, double angle, double side) {
    if (view == DemoView.front) {
      // A foot pointing at the camera is a short stub, turned out a little.
      final toe = leg.end + Offset(0.02 * side, -0.03);
      return (toe, leg.end);
    }
    final d = limbDirection(angle);
    return (leg.end + d * Bone.foot, leg.end - d * Bone.heel);
  }

  final (toeN, heelN) = foot(legN, pose.footN, -1);
  final (toeF, heelF) = foot(legF, pose.footF, 1);

  return Skeleton(
    view: view,
    hip: pose.hip,
    shoulder: shoulder,
    headCentre: headCentre,
    neckTop: neckTop,
    armN: armN,
    armF: armF,
    legN: legN,
    legF: legF,
    handN: hand(armN, pose.wristN),
    handF: hand(armF, pose.wristF),
    toeN: toeN,
    toeF: toeF,
    heelN: heelN,
    heelF: heelF,
  );
}
