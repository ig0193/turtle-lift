/// Every movement pattern the 260 exercises are demonstrated with.
///
/// **One pattern, many exercises.** A barbell, dumbbell and Smith bench press
/// are the same movement with different gear, so the exercise library names a
/// pattern (`animation`) and the gear (`animationGear`) separately and this
/// file only knows movements. The ids here and `ANIMATION_PATTERNS` in
/// `assets/exercises/animation_map.py` are the same set — the Python validator
/// proves every exercise names one, and `test/exercise_demo_test.dart` proves
/// every one it names is defined here.
///
/// Conventions (see `figure_rig.dart`): world y-up in figure heights, floor at
/// 0, side view facing +x, limb angles from straight down toward +x.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'exercise_motion.dart';
import 'figure_rig.dart';

/// The motion for [patternId], or `null` for an id this build does not know.
ExerciseMotion? demoMotionFor(String? patternId) {
  if (patternId == null) return null;
  final build = _patterns[patternId];
  if (build == null) return null;
  return _cache.putIfAbsent(patternId, build);
}

/// Every pattern id defined here.
Iterable<String> get demoPatternIds => _patterns.keys;

final Map<String, ExerciseMotion> _cache = <String, ExerciseMotion>{};

// ------------------------------------------------------------------ helpers

const double _ank = Bone.ankle;
const double _hipY = Bone.standingHip;
const double _seatHip = 0.31;

Limb _foot(double x, [double y = _ank, double bend = 1]) =>
    Ik(Offset(x, y), bend: bend);

/// Arms hanging at the sides, near and far a touch apart.
const Limb _hangN = Fk(3, 5);
const Limb _hangF = Fk(-3, 0);

/// A standing pose, side view.
Pose _stand({
  Offset hip = const Offset(0, _hipY),
  double torso = 0,
  Limb armN = _hangN,
  Limb armF = _hangF,
  Limb? legN,
  Limb? legF,
  double neck = 0,
  double footN = 90,
  double footF = 90,
  double wristN = 0,
  double wristF = 0,
  double shrug = 0,
}) =>
    Pose(
      hip: hip,
      torso: torso,
      neck: neck,
      shrug: shrug,
      armN: armN,
      armF: armF,
      legN: legN ?? _foot(0.02),
      legF: legF ?? _foot(-0.03),
      footN: footN,
      footF: footF,
      wristN: wristN,
      wristF: wristF,
    );

/// Seated on a bench, side view: thighs forward, shins down.
Pose _seated({
  double torso = 0,
  Limb armN = _hangN,
  Limb armF = _hangF,
  Limb? legN,
  Limb? legF,
  double hipY = _seatHip,
  double neck = 0,
  double wristN = 0,
  double wristF = 0,
}) =>
    Pose(
      hip: Offset(0, hipY),
      torso: torso,
      neck: neck,
      armN: armN,
      armF: armF,
      legN: legN ?? _foot(0.31),
      legF: legF ?? _foot(0.27),
      wristN: wristN,
      wristF: wristF,
    );

/// Front view: a pose given for the near side, mirrored for the far side.
Pose _front({
  Offset hip = const Offset(0, _hipY),
  double torso = 0,
  double torsoLen = 1,
  required Limb arm,
  Limb? armF,
  Limb? leg,
  Limb? legF,
  double shrug = 0,
  double reach = 1,
  double? reachF,
  double stride = 1,
  double? strideF,
  double neck = 0,
}) {
  final l = leg ?? _foot(-0.075, _ank, -1);
  return Pose(
    hip: hip,
    torso: torso,
    torsoLen: torsoLen,
    neck: neck,
    shrug: shrug,
    armN: arm,
    armF: armF ?? arm.mirrored(),
    legN: l,
    legF: legF ?? l.mirrored(),
    reachN: reach,
    reachF: reachF ?? reach,
    strideN: stride,
    strideF: strideF ?? stride,
  );
}

/// A straight body from [ankle] to a shoulder at height [shoulderY], ahead
/// of the ankle along +x: a plank or a push-up. Returns hip and torso angle.
(Offset, double) _plank(Offset ankle, double shoulderY) {
  const total = Bone.thigh + Bone.shin + Bone.torso;
  final dy = shoulderY - ankle.dy;
  final theta = math.asin((dy / total).clamp(-1.0, 1.0));
  final hip = ankle +
      Offset(math.cos(theta), math.sin(theta)) * (Bone.thigh + Bone.shin);
  final torso = 90 - theta * 180 / math.pi;
  return (hip, torso);
}

/// A pad behind a torso — a bench back, an incline — from the torso of [p].
PadProp _backPad(Pose p, {double extend = 0.08, double below = 0.0}) {
  final d = torsoDirection(p.torso);
  final back = Offset(-d.dy, d.dx);
  final from = p.hip - d * below + back * 0.09;
  final to = p.hip + d * (Bone.torso + extend) + back * 0.09;
  return PadProp(from, to, legs: false, post: true);
}

/// A pad in front of a torso — a chest support.
PadProp _chestPad(Pose p, {double from = 0.15, double to = 0.95}) {
  final d = torsoDirection(p.torso);
  final front = Offset(d.dy, -d.dx);
  return PadProp(
    p.hip + d * (Bone.torso * from) + front * 0.09,
    p.hip + d * (Bone.torso * to) + front * 0.09,
    legs: false,
    post: true,
  );
}

const PadProp _seat = PadProp(Offset(-0.12, 0.235), Offset(0.16, 0.235));
const PadProp _flatBench = PadProp(Offset(-0.42, 0.235), Offset(0.26, 0.235));

ExerciseMotion _reps(
  DemoView view,
  Pose a,
  Pose b, {
  double seconds = 2.8,
  List<Prop> props = const <Prop>[],
  GearRig gear = const GearRig(),
  double down = 0.42,
  double hold = 0.1,
}) =>
    ExerciseMotion(
      view: view,
      seconds: seconds,
      props: props,
      gear: gear,
      keys: <MotionKey>[
        MotionKey(0, a),
        MotionKey(down, b),
        MotionKey(down + hold, b),
      ],
    );

ExerciseMotion _side(Pose a, Pose b,
        {double seconds = 2.8,
        List<Prop> props = const <Prop>[],
        GearRig gear = const GearRig(),
        double down = 0.42,
        double hold = 0.1}) =>
    _reps(DemoView.side, a, b,
        seconds: seconds, props: props, gear: gear, down: down, hold: hold);

ExerciseMotion _frontReps(Pose a, Pose b,
        {double seconds = 2.8,
        List<Prop> props = const <Prop>[],
        GearRig gear = const GearRig(),
        double down = 0.42,
        double hold = 0.1}) =>
    _reps(DemoView.front, a, b,
        seconds: seconds, props: props, gear: gear, down: down, hold: hold);

/// A static hold that breathes: the torso rises a hair and settles.
ExerciseMotion _hold(DemoView view, Pose p,
    {List<Prop> props = const <Prop>[], GearRig gear = const GearRig()}) {
  final breathe = p.copyWith(
    hip: p.hip + const Offset(0, 0.006),
    shrug: p.shrug + 0.15,
  );
  return ExerciseMotion(
    view: view,
    seconds: 4,
    props: props,
    gear: gear,
    hold: true,
    peak: 0,
    keys: <MotionKey>[MotionKey(0, p), MotionKey(0.5, breathe)],
  );
}

/// Two halves of a cycle: one side, then the other.
ExerciseMotion _alternating(DemoView view, Pose rest, Pose near, Pose far,
        {double seconds = 4.4,
        List<Prop> props = const <Prop>[],
        GearRig gear = const GearRig()}) =>
    ExerciseMotion(
      view: view,
      seconds: seconds,
      props: props,
      gear: gear,
      keys: <MotionKey>[
        MotionKey(0, rest),
        MotionKey(0.22, near),
        MotionKey(0.28, near),
        MotionKey(0.5, rest),
        MotionKey(0.72, far),
        MotionKey(0.78, far),
      ],
    );

// --------------------------------------------------------------- patterns

final Map<String, ExerciseMotion Function()> _patterns =
    <String, ExerciseMotion Function()>{
  // ------------------------------------------------------------ presses
  'bench-press': () => _benchPress(0),
  'bench-press-incline': () => _benchPress(35),
  'bench-press-decline': () => _benchPress(-18),
  'floor-press': _floorPress,
  'chest-press-seated': () => _seatedChestPress(0),
  'chest-press-seated-incline': () => _seatedChestPress(25),
  'chest-press-seated-decline': () => _seatedChestPress(-20),
  'chest-press-standing': () => _standingChestPress(0),
  'chest-press-standing-incline': () => _standingChestPress(30),
  'svend-press': _svendPress,
  'push-up': () => _pushUp(),
  'push-up-feet-elevated': () => _pushUp(feetY: 0.3),
  'push-up-hands-elevated': () => _pushUp(handsY: 0.3),
  'pike-push-up': _pikePushUp,
  'fly-lying': _flyLying,
  'pec-deck': _pecDeck,
  'cable-crossover': () => _crossover(0),
  'cable-crossover-low': () => _crossover(-1),
  'cable-crossover-high': () => _crossover(1),
  'dip': () => _dip(25),
  'dip-upright': () => _dip(4),
  'bench-dip': _benchDip,
  'pullover': _pullover,
  'pullover-machine': _pulloverMachine,
  'straight-arm-pulldown': _straightArmPulldown,
  // --------------------------------------------------------------- pulls
  'pull-up': () => _pullUp(0.27),
  'chin-up': () => _pullUp(0.13),
  'lat-pulldown': () => _latPulldown(0.25),
  'lat-pulldown-wide': () => _latPulldown(0.33),
  'lat-pulldown-close': () => _latPulldown(0.12),
  'row-bent': _rowBent,
  'row-single-arm': _rowSingleArm,
  'row-chest-supported': _rowChestSupported,
  'row-seated-cable': _rowSeatedCable,
  'row-machine': _rowMachine,
  'inverted-row': _invertedRow,
  'shrug': _shrug,
  'face-pull': _facePull,
  'upright-row': _uprightRow,
  'high-pull': _highPull,
  'prone-y-raise': _proneYRaise,
  'pull-apart': () => _pullApart(seated: false),
  'pull-apart-seated': () => _pullApart(seated: true),
  // ---------------------------------------------------------- lower back
  'back-extension': _backExtension,
  'reverse-hyper': _reverseHyper,
  'superman': _superman,
  'bird-dog': _birdDog,
  'deadlift': () => _deadlift(rack: false),
  'deadlift-rack': () => _deadlift(rack: true),
  'deadlift-sumo': _sumo,
  'good-morning': _goodMorning,
  'rdl': _rdl,
  'rdl-single-leg': _rdlSingleLeg,
  'pull-through': _pullThrough,
  'kb-swing': _kbSwing,
  // ----------------------------------------------------------- shoulders
  'overhead-press': () => _overheadPress(dip: false),
  'push-press': () => _overheadPress(dip: true),
  'overhead-press-seated': _overheadPressSeated,
  'landmine-press': _landminePress,
  'front-raise': _frontRaise,
  'lateral-raise': () => _lateralRaise(top: -88, seated: false),
  'lateral-raise-seated': () => _lateralRaise(top: -88, seated: true),
  'lu-raise': () => _lateralRaise(top: -176, seated: false),
  'y-raise': () => _lateralRaise(top: -140, seated: false),
  'reverse-fly-bent': _reverseFlyBent,
  // ---------------------------------------------------------------- arms
  'curl': () => _curl(),
  'curl-alternating': _curlAlternating,
  'drag-curl': _dragCurl,
  'curl-bayesian': _curlBayesian,
  'curl-incline': _curlIncline,
  'curl-concentration': _curlConcentration,
  'curl-spider': _curlSpider,
  'curl-preacher': _curlPreacher,
  'pushdown': _pushdown,
  'overhead-extension': _overheadExtension,
  'kickback': _kickback,
  'skull-crusher': _skullCrusher,
  'triceps-machine': _tricepsMachine,
  'wrist-curl': _wristCurl,
  'wrist-curl-behind': _wristCurlBehind,
  'wrist-roller': _wristRoller,
  'grip-squeeze': _gripSqueeze,
  'dead-hang': _deadHang,
  'carry': () => _carry(overhead: false),
  'carry-overhead': () => _carry(overhead: true),
  'hold-standing': _holdStanding,
  // ----------------------------------------------------------------- core
  'crunch': _crunch,
  'toe-touch-crunch': _toeTouchCrunch,
  'sit-up': () => _sitUp(decline: false),
  'sit-up-decline': () => _sitUp(decline: true),
  'v-up': _vUp,
  'cable-crunch': _cableCrunch,
  'machine-crunch': _machineCrunch,
  'ball-crunch': _ballCrunch,
  'plank': _plankHold,
  'side-plank': _sidePlank,
  'ab-wheel': _abWheel,
  'hanging-leg-raise': () => _hangingRaise(knees: false),
  'hanging-knee-raise': () => _hangingRaise(knees: true),
  'captains-chair': _captainsChair,
  'hanging-oblique-raise': _hangingObliqueRaise,
  'lying-leg-raise': _lyingLegRaise,
  'reverse-crunch': _reverseCrunch,
  'flutter-kick': () => _flutter(amplitude: 14, seconds: 1.1),
  'scissor-kick': () => _flutter(amplitude: 22, seconds: 1.5),
  'mountain-climber': _mountainClimber,
  'dead-bug': _deadBug,
  'dragon-flag': _dragonFlag,
  'russian-twist': () => _twist(seated: false),
  'torso-rotation-seated': () => _twist(seated: true),
  'bicycle-crunch': _bicycleCrunch,
  'woodchopper': _woodchopper,
  'pallof-press': _pallofPress,
  'side-bend': _sideBend,
  'landmine-rotation': _landmineRotation,
  // ----------------------------------------------------------------- legs
  'squat': () => _squat(_Hold.back),
  'front-squat': () => _squat(_Hold.front),
  'goblet-squat': () => _squat(_Hold.goblet),
  'squat-bodyweight': () => _squat(_Hold.arms),
  'squat-box': () => _squat(_Hold.back, box: true),
  'squat-belt': () => _squat(_Hold.belt),
  'hack-squat': _hackSquat,
  'leg-press': () => _legPress(calf: false),
  'leg-press-calf': () => _legPress(calf: true),
  'leg-extension': _legExtension,
  'split-squat': () => _splitSquat(bulgarian: false),
  'split-squat-bulgarian': () => _splitSquat(bulgarian: true),
  'lunge-forward': () => _lunge(forward: true),
  'lunge-reverse': () => _lunge(forward: false),
  'step-up': _stepUp,
  'pistol-squat': _pistol,
  'sissy-squat': _sissy,
  'wall-sit': _wallSit,
  'curtsy-lunge': _curtsy,
  'leg-curl-lying': () => _legCurlLying(band: false),
  'leg-curl-lying-band': () => _legCurlLying(band: true),
  'leg-curl-seated': _legCurlSeated,
  'leg-curl-standing': _legCurlStanding,
  'glute-ham-raise': _gluteHam,
  'nordic-curl': _nordic,
  'ball-leg-curl': _ballLegCurl,
  'hip-thrust': _hipThrust,
  'glute-bridge': () => _bridge(single: false),
  'glute-bridge-single': () => _bridge(single: true),
  'glute-kickback-standing': _kickbackStanding,
  'donkey-kick': _donkeyKick,
  'fire-hydrant': _fireHydrant,
  'hip-abduction': _hipAbduction,
  'lateral-walk': _lateralWalk,
  'calf-raise': () => _calfRaise(loaded: false, single: false),
  'calf-raise-loaded': () => _calfRaise(loaded: true, single: false),
  'calf-raise-single': () => _calfRaise(loaded: false, single: true),
  'donkey-calf-raise': _donkeyCalf,
  'seated-calf-raise': _seatedCalf,
  'jump-rope': _jumpRope,
};

// ---------------------------------------------------------------- presses

/// Lying on a bench at [incline] degrees (negative is a decline), pressing
/// a bar straight up over the chest.
ExerciseMotion _benchPress(double incline) {
  final torso = -90 + incline;
  final hip = incline > 0
      ? const Offset(0.12, 0.33)
      : incline < 0
          ? const Offset(0.1, 0.36)
          : const Offset(0.14, 0.32);
  final d = torsoDirection(torso);
  final front = Offset(d.dy, -d.dx);
  final shoulder = hip + d * Bone.torso;
  final top = shoulder + const Offset(0.02, 0.305);
  final bottom = shoulder + front * 0.11 - d * 0.12;
  final legs = incline < 0
      ? (Ik(hip + const Offset(0.2, -0.3), bend: -1), Ik(hip + const Offset(0.17, -0.3), bend: -1))
      : (_foot(hip.dx + 0.3), _foot(hip.dx + 0.26));
  Pose p(Offset hand) => Pose(
        hip: hip,
        torso: torso,
        armN: Ik(hand, bend: -1),
        armF: Ik(hand + const Offset(-0.01, 0), bend: -1),
        legN: legs.$1,
        legF: legs.$2,
      );
  final a = p(top);
  return _side(
    a,
    p(bottom),
    props: <Prop>[
      if (incline == 0) _flatBench else ...<Prop>[_backPad(a), _seat],
    ],
  );
}

ExerciseMotion _floorPress() {
  const hip = Offset(0.14, 0.065);
  final shoulder = hip + const Offset(-Bone.torso, 0);
  Pose p(Offset hand) => Pose(
        hip: hip,
        torso: -90,
        armN: Ik(hand, bend: -1),
        armF: Ik(hand + const Offset(-0.01, 0), bend: -1),
        legN: _foot(0.42),
        legF: _foot(0.38),
      );
  return _side(
    p(shoulder + const Offset(0.02, 0.305)),
    p(shoulder + const Offset(0.12, 0.12)),
  );
}

ExerciseMotion _seatedChestPress(double angle) {
  final a = angle * math.pi / 180;
  Pose p(double reach) {
    final shoulder = Offset(-0.03, _seatHip + Bone.torso);
    final hand = shoulder +
        Offset(math.cos(a), math.sin(a)) * (0.08 + 0.22 * reach) +
        const Offset(0, -0.03);
    return _seated(
      torso: -6,
      armN: Ik(hand, bend: -1),
      armF: Ik(hand + const Offset(-0.01, 0), bend: -1),
    );
  }

  final rest = p(0);
  return _side(
    rest,
    p(1),
    props: <Prop>[_seat, _backPad(rest, extend: 0.12)],
    gear: const GearRig(anchorN: Offset(0.06, 0.86), padLength: 0.08),
  );
}

ExerciseMotion _standingChestPress(double angle) {
  final a = angle * math.pi / 180;
  Pose p(double reach) {
    const shoulder = Offset(0.05, _hipY - 0.01 + Bone.torso);
    final hand = shoulder +
        Offset(math.cos(a), math.sin(a)) * (0.08 + 0.22 * reach) +
        const Offset(0, -0.03);
    return _stand(
      hip: const Offset(0, _hipY - 0.01),
      torso: 10,
      armN: Ik(hand, bend: -1),
      armF: Ik(hand + const Offset(-0.01, 0), bend: -1),
      legN: _foot(0.16),
      legF: _foot(-0.16),
    );
  }

  return _side(
    p(0),
    p(1),
    gear: GearRig(anchorN: Offset(-0.55, angle > 0 ? 0.25 : 0.78)),
  );
}

ExerciseMotion _svendPress() {
  Pose p(double reach) {
    final hand = Offset(0.09 + 0.24 * reach, 0.76);
    return _stand(
      armN: Ik(hand, bend: -1),
      armF: Ik(hand + const Offset(-0.01, 0), bend: -1),
    );
  }

  return _side(p(0), p(1), gear: const GearRig(shared: true));
}

ExerciseMotion _pushUp({double feetY = _ank + 0.03, double handsY = 0.03}) {
  final ankle = Offset(-0.6, feetY);
  Pose p(double shoulderAbove) {
    final (hip, torso) = _plank(ankle, handsY + shoulderAbove);
    return Pose(
      hip: hip,
      torso: torso,
      armN: Ik(Offset(0.12, handsY), bend: -1),
      armF: Ik(Offset(0.1, handsY), bend: -1),
      legN: Ik(ankle),
      legF: Ik(ankle + const Offset(-0.01, 0)),
      footN: 20,
      footF: 20,
    );
  }

  return _side(
    p(0.3),
    p(0.11),
    props: <Prop>[
      if (feetY > 0.1) BoxProp(Rect.fromLTRB(-0.78, 0, -0.5, feetY - 0.04)),
      if (handsY > 0.1) BoxProp(Rect.fromLTRB(0.0, 0, 0.26, handsY - 0.02)),
    ],
  );
}

ExerciseMotion _pikePushUp() {
  Pose p(Offset hip, double torso) => Pose(
        hip: hip,
        torso: torso,
        neck: 10,
        armN: const Ik(Offset(0.16, 0.03), bend: -1),
        armF: const Ik(Offset(0.14, 0.03), bend: -1),
        legN: const Ik(Offset(-0.43, 0.07), bend: -1),
        legF: const Ik(Offset(-0.44, 0.07), bend: -1),
        footN: 20,
        footF: 20,
      );
  return _side(
    p(const Offset(-0.2, 0.5), 150),
    p(const Offset(-0.14, 0.45), 166),
  );
}

/// Seen from the foot of the bench: the arms open in an arc and close again.
ExerciseMotion _flyLying() {
  Pose p(double upper, double lower) => _front(
        hip: const Offset(0, 0.3),
        torsoLen: 0.12,
        arm: Fk(upper, lower),
        leg: const Ik(Offset(-0.22, _ank), bend: -1),
      );
  return _frontReps(
    p(172, 165),
    p(262, 250),
    props: const <Prop>[PadProp(Offset(-0.13, 0.235), Offset(0.13, 0.235))],
  );
}

ExerciseMotion _pecDeck() {
  Pose p(double reach) => _front(
        hip: const Offset(0, 0.36),
        arm: const Fk(-90, -180),
        reach: reach,
        leg: const Ik(Offset(-0.12, _ank), bend: -1),
      );
  return _frontReps(
    p(1),
    p(0.3),
    props: const <Prop>[PadProp(Offset(-0.16, 0.3), Offset(0.16, 0.3), legs: false, post: true)],
  );
}

/// [height] -1 low-to-high, 0 mid, 1 high-to-low.
ExerciseMotion _crossover(int height) {
  final anchorY = height < 0 ? 0.12 : height > 0 ? 1.12 : 0.82;
  final startY = height < 0 ? 0.42 : height > 0 ? 1.02 : 0.8;
  final endY = height < 0 ? 0.9 : height > 0 ? 0.52 : 0.76;
  Pose p(double x, double y, double reach) => _front(
        torsoLen: 0.96,
        arm: Ik(Offset(x, y), bend: 1),
        reach: reach,
        leg: _foot(-0.1, _ank, -1),
      );
  return _frontReps(
    p(-0.4, startY, 1),
    p(-0.035, endY, 0.4),
    gear: GearRig(anchorN: Offset(-0.58, anchorY), anchorF: Offset(0.58, anchorY)),
  );
}

ExerciseMotion _dip(double lean) {
  const bar = Offset(0.03, 0.95);
  Pose p(double drop, double torso) {
    final hip = Offset(-0.03 - drop * 0.3, 0.95 + 0.31 - Bone.torso - drop);
    return Pose(
      hip: hip,
      torso: torso,
      armN: const Ik(bar, bend: -1),
      armF: Ik(bar + const Offset(-0.01, 0), bend: -1),
      legN: const Fk(10, -45),
      legF: const Fk(4, -55),
      footN: 40,
      footF: 40,
    );
  }

  return _side(
    p(0, lean * 0.6),
    p(0.15, lean),
    props: const <Prop>[BarProp(bar)],
    gear: const GearRig(at: GearAt.knees, anchorN: Offset(-0.15, 0.32), padLength: 0.1),
  );
}

ExerciseMotion _benchDip() {
  const hand = Offset(-0.13, 0.265);
  Pose p(double shoulderY) => Pose(
        hip: Offset(-0.07, shoulderY - Bone.torso),
        torso: 3,
        armN: const Ik(hand, bend: -1),
        armF: Ik(hand + const Offset(-0.01, 0), bend: -1),
        legN: _foot(0.36),
        legF: _foot(0.33),
      );
  return _side(
    p(0.565),
    p(0.43),
    props: const <Prop>[PadProp(Offset(-0.5, 0.21), Offset(-0.1, 0.21))],
  );
}

ExerciseMotion _pullover() {
  Pose p(double arm) => Pose(
        hip: const Offset(0.14, 0.32),
        torso: -90,
        armN: Fk(arm, arm + 4),
        armF: Fk(arm - 2, arm + 2),
        legN: _foot(0.44),
        legF: _foot(0.4),
      );
  return _side(
    p(178),
    p(262),
    props: const <Prop>[_flatBench],
    gear: const GearRig(shared: true),
  );
}

ExerciseMotion _pulloverMachine() {
  Pose p(double arm) => _seated(
        torso: -4,
        armN: Fk(arm, arm),
        armF: Fk(arm - 2, arm - 2),
      );
  final a = p(168);
  return _side(
    a,
    p(40),
    props: <Prop>[_seat, _backPad(a, extend: 0.15)],
    gear: const GearRig(anchorN: Offset(0.0, 0.64), padLength: 0.08),
  );
}

ExerciseMotion _straightArmPulldown() {
  Pose p(double arm) => _stand(
        hip: const Offset(-0.04, _hipY - 0.02),
        torso: 22,
        armN: Fk(arm, arm + 3),
        armF: Fk(arm - 2, arm),
        legN: _foot(0.03),
        legF: _foot(-0.02),
      );
  return _side(
    p(150),
    p(12),
    gear: const GearRig(anchorN: Offset(0.62, 1.12), shared: true),
  );
}

// ------------------------------------------------------------------ pulls

ExerciseMotion _pullUp(double gripHalf) {
  const barY = 1.27;
  Pose p(double shoulderY) => _front(
        hip: Offset(0, shoulderY - Bone.torso),
        arm: Ik(Offset(-gripHalf, barY - 0.02), bend: 1),
        leg: const Fk(4, 2),
      );
  final reach = math.sqrt(
    math.max(0, 0.3 * 0.3 - math.pow(gripHalf - Bone.shoulderHalf, 2)),
  );
  return _frontReps(
    p(barY - 0.02 - reach),
    p(barY - 0.14),
    props: <Prop>[BarProp(const Offset(0, barY), width: math.max(0.4, gripHalf + 0.12))],
    gear: const GearRig(at: GearAt.knees, anchorN: Offset(-0.25, 0.3), padLength: 0.12),
  );
}

ExerciseMotion _latPulldown(double gripHalf) {
  const hip = Offset(0, 0.36);
  const shoulderY = 0.36 + Bone.torso;
  Pose p(Offset hand) => _front(
        hip: hip,
        arm: Ik(hand, bend: 1),
        leg: const Ik(Offset(-0.13, _ank), bend: -1),
      );
  final top = Offset(-gripHalf, shoulderY + math.sqrt(math.max(0, 0.29 * 0.29 - math.pow(gripHalf - 0.11, 2))));
  return _frontReps(
    p(top),
    p(Offset(-gripHalf * 0.95, shoulderY + 0.0)),
    props: const <Prop>[PadProp(Offset(-0.16, 0.3), Offset(0.16, 0.3), legs: false, post: true)],
    gear: const GearRig(anchorN: Offset(0, 1.16), shared: true),
  );
}

ExerciseMotion _rowBent() {
  Pose p(Offset hand) => _stand(
        hip: const Offset(-0.06, 0.48),
        torso: 62,
        neck: -20,
        armN: Ik(hand, bend: -1),
        armF: Ik(hand + const Offset(-0.01, 0), bend: -1),
        legN: _foot(0.05),
        legF: _foot(0.0),
      );
  return _side(
    p(const Offset(0.2, 0.31)),
    p(const Offset(0.1, 0.5)),
    gear: const GearRig(anchorN: Offset(-0.62, 0.03)),
  );
}

ExerciseMotion _rowSingleArm() {
  Pose p(Offset hand) => Pose(
        hip: const Offset(-0.08, 0.5),
        torso: 80,
        neck: -20,
        armN: Ik(hand, bend: -1),
        armF: const Ik(Offset(0.3, 0.29), bend: -1),
        legN: _foot(0.1),
        legF: const Ik(Offset(-0.3, 0.3)),
        footF: -90,
      );
  return _side(
    p(const Offset(0.22, 0.24)),
    p(const Offset(0.08, 0.46)),
    props: const <Prop>[PadProp(Offset(-0.36, 0.235), Offset(0.4, 0.235))],
    gear: const GearRig(oneHand: true),
  );
}

ExerciseMotion _rowChestSupported() {
  Pose p(Offset hand) => Pose(
        hip: const Offset(-0.02, 0.5),
        torso: 48,
        neck: -10,
        armN: Ik(hand, bend: -1),
        armF: Ik(hand + const Offset(-0.01, 0), bend: -1),
        legN: _foot(-0.2),
        legF: _foot(-0.24),
      );
  final a = p(const Offset(0.23, 0.38));
  return _side(
    a,
    p(const Offset(0.1, 0.58)),
    props: <Prop>[_chestPad(a, from: 0.0, to: 1.05)],
  );
}

ExerciseMotion _rowSeatedCable() {
  Pose p(double torso, Offset hand) => Pose(
        hip: const Offset(0, 0.3),
        torso: torso,
        armN: Ik(hand, bend: -1),
        armF: Ik(hand + const Offset(-0.01, 0), bend: -1),
        legN: const Ik(Offset(0.43, 0.16)),
        legF: const Ik(Offset(0.41, 0.16)),
        footN: 175,
        footF: 175,
      );
  return _side(
    p(18, const Offset(0.36, 0.5)),
    p(-6, const Offset(0.13, 0.43)),
    props: <Prop>[
      const PadProp(Offset(-0.15, 0.235), Offset(0.1, 0.235)),
      BoxProp(Rect.fromLTRB(0.47, 0, 0.53, 0.26)),
    ],
    gear: const GearRig(anchorN: Offset(0.62, 0.2), shared: true),
  );
}

ExerciseMotion _rowMachine() {
  Pose p(Offset hand) => _seated(
        hipY: 0.36,
        torso: 8,
        armN: Ik(hand, bend: -1),
        armF: Ik(hand + const Offset(-0.01, 0), bend: -1),
      );
  return _side(
    p(const Offset(0.33, 0.6)),
    p(const Offset(0.1, 0.58)),
    props: const <Prop>[
      PadProp(Offset(-0.12, 0.29), Offset(0.16, 0.29), legs: false, post: true),
      PadProp(Offset(0.16, 0.5), Offset(0.16, 0.75), legs: false, post: true),
    ],
    gear: const GearRig(anchorN: Offset(0.42, 0.22), padLength: 0.07),
  );
}

ExerciseMotion _invertedRow() {
  const bar = Offset(0.0, 0.64);
  const ankle = Offset(0.7, 0.05);
  Pose p(double angle) {
    final t = angle * math.pi / 180;
    final hip = ankle + Offset(-math.cos(t), math.sin(t)) * (Bone.thigh + Bone.shin);
    return Pose(
      hip: hip,
      torso: -(90 - angle),
      armN: const Ik(bar, bend: -1),
      armF: Ik(bar + const Offset(-0.01, 0), bend: -1),
      legN: const Ik(ankle),
      legF: Ik(ankle + const Offset(0.01, 0)),
      footN: 165,
      footF: 165,
    );
  }

  return _side(
    p(22),
    p(36),
    props: const <Prop>[BarProp(Offset(0.0, 0.66))],
  );
}

ExerciseMotion _shrug() {
  Pose p(double shrug) => _front(arm: const Fk(-7, -5), shrug: shrug);
  return _frontReps(
    p(0),
    p(1),
    seconds: 2.4,
    gear: const GearRig(anchorN: Offset(-0.36, 0.14), anchorF: Offset(0.36, 0.14)),
  );
}

ExerciseMotion _facePull() {
  Pose p(Offset hand) => _stand(
        torso: -6,
        armN: Ik(hand, bend: 1),
        armF: Ik(hand + const Offset(-0.01, 0), bend: 1),
        legN: _foot(0.12),
        legF: _foot(-0.14),
      );
  return _side(
    p(const Offset(0.33, 0.88)),
    p(const Offset(0.07, 0.95)),
    gear: const GearRig(anchorN: Offset(0.66, 0.92), shared: true),
  );
}

ExerciseMotion _uprightRow() {
  Pose p(Offset hand) => _front(arm: Ik(hand, bend: 1));
  return _frontReps(
    p(const Offset(-0.06, 0.48)),
    p(const Offset(-0.05, 0.84)),
    gear: const GearRig(anchorN: Offset(0, 0.06), shared: true),
  );
}

ExerciseMotion _highPull() {
  final a = _stand(
    hip: const Offset(-0.1, 0.46),
    torso: 38,
    armN: const Ik(Offset(0.1, 0.24), bend: 1),
    armF: const Ik(Offset(0.09, 0.24), bend: 1),
    legN: _foot(0.04),
    legF: _foot(-0.01),
  );
  final b = _stand(
    armN: const Ik(Offset(0.1, 0.86), bend: 1),
    armF: const Ik(Offset(0.09, 0.86), bend: 1),
    footN: 110,
    footF: 110,
  );
  return _side(a, b, down: 0.35, hold: 0.08, gear: const GearRig(shared: true));
}

ExerciseMotion _proneYRaise() {
  Pose p(double arm) => Pose(
        hip: const Offset(-0.02, 0.5),
        torso: 48,
        armN: Fk(arm, arm),
        armF: Fk(arm - 3, arm - 3),
        legN: _foot(-0.2),
        legF: _foot(-0.24),
      );
  final a = p(0);
  return _side(a, p(132), props: <Prop>[_chestPad(a, from: 0.0, to: 1.05)]);
}

ExerciseMotion _pullApart({required bool seated}) {
  Pose p(double reach) => _front(
        hip: Offset(0, seated ? 0.36 : _hipY),
        arm: const Fk(-90, -90),
        reach: reach,
        leg: seated ? const Ik(Offset(-0.13, _ank), bend: -1) : null,
      );
  return _frontReps(
    p(0.18),
    p(1),
    props: <Prop>[
      if (seated) const PadProp(Offset(-0.16, 0.3), Offset(0.16, 0.3), legs: false, post: true),
    ],
    gear: const GearRig(anchorN: Offset(0.6, 0.84), anchorF: Offset(-0.6, 0.84)),
  );
}

// -------------------------------------------------------------- lower back

ExerciseMotion _backExtension() {
  const hip = Offset(0, 0.62);
  Pose p(double torso) => Pose(
        hip: hip,
        torso: torso,
        neck: torso > 90 ? -30 : 0,
        armN: const Ik(Offset(0.08, -0.12), bend: -1, rel: Rel.torso),
        armF: const Ik(Offset(0.07, -0.13), bend: -1, rel: Rel.torso),
        legN: const Ik(Offset(-0.33, 0.27), bend: 1),
        legF: const Ik(Offset(-0.34, 0.27), bend: 1),
        footN: 130,
        footF: 130,
      );
  return _side(
    p(150),
    p(48),
    props: const <Prop>[
      PadProp(Offset(0.04, 0.55), Offset(-0.06, 0.45), legs: false, post: true),
      PadProp(Offset(-0.32, 0.2), Offset(-0.38, 0.26), legs: false, post: true),
    ],
  );
}

ExerciseMotion _reverseHyper() {
  Pose p(double leg) => Pose(
        hip: const Offset(0, 0.68),
        torso: 90,
        armN: const Ik(Offset(0.42, 0.56), bend: -1),
        armF: const Ik(Offset(0.41, 0.56), bend: -1),
        legN: Fk(leg, leg),
        legF: Fk(leg + 3, leg + 3),
        footN: leg - 90,
        footF: leg - 90,
      );
  return _side(
    p(-2),
    p(-96),
    props: const <Prop>[PadProp(Offset(0.0, 0.595), Offset(0.4, 0.595))],
  );
}

ExerciseMotion _superman() {
  Pose p(double lift) => Pose(
        hip: const Offset(0, 0.065),
        torso: 90 - lift,
        neck: -lift * 0.5,
        armN: Fk(95 + lift, 95 + lift),
        armF: Fk(93 + lift, 93 + lift),
        legN: Fk(-90 - lift * 0.8, -90 - lift * 0.8),
        legF: Fk(-90 - lift * 0.7, -90 - lift * 0.7),
        footN: -100 - lift,
        footF: -100 - lift,
      );
  return _side(p(0), p(16), seconds: 3.2, hold: 0.18);
}

ExerciseMotion _birdDog() {
  final rest = Pose(
    hip: const Offset(0, 0.3),
    torso: 90,
    neck: -10,
    armN: const Fk(2, 2),
    armF: const Fk(0, 0),
    legN: const Fk(0, -90),
    legF: const Fk(2, -88),
    footN: -170,
    footF: -170,
  );
  return _alternating(
    DemoView.side,
    rest,
    rest.copyWith(armN: const Fk(92, 92), legF: const Fk(-92, -92), footF: -100),
    rest.copyWith(armF: const Fk(92, 92), legN: const Fk(-92, -92), footN: -100),
    seconds: 5,
  );
}

ExerciseMotion _deadlift({required bool rack}) {
  final bottom = rack
      ? _stand(
          hip: const Offset(-0.08, 0.42),
          torso: 45,
          armN: const Ik(Offset(0.07, 0.3), bend: 1),
          armF: const Ik(Offset(0.06, 0.3), bend: 1),
          legN: _foot(0.04),
          legF: _foot(0.0),
        )
      : _stand(
          hip: const Offset(-0.1, 0.3),
          torso: 60,
          neck: -20,
          armN: const Ik(Offset(0.07, 0.14), bend: 1),
          armF: const Ik(Offset(0.06, 0.14), bend: 1),
          legN: _foot(0.04),
          legF: _foot(0.0),
        );
  final mid = _stand(
    hip: const Offset(-0.07, 0.44),
    torso: 38,
    armN: const Ik(Offset(0.07, 0.33), bend: 1),
    armF: const Ik(Offset(0.06, 0.33), bend: 1),
    legN: _foot(0.04),
    legF: _foot(0.0),
  );
  final top = _stand(
    torso: -2,
    armN: const Ik(Offset(0.03, 0.51), bend: 1),
    armF: const Ik(Offset(0.02, 0.51), bend: 1),
    legN: _foot(0.04),
    legF: _foot(0.0),
  );
  return ExerciseMotion(
    view: DemoView.side,
    seconds: 3.2,
    peak: rack ? 1 : 2,
    props: <Prop>[
      if (rack) BoxProp(Rect.fromLTRB(-0.0, 0, 0.16, 0.18)),
    ],
    keys: rack
        ? <MotionKey>[MotionKey(0, bottom), MotionKey(0.4, top), MotionKey(0.5, top)]
        : <MotionKey>[
            MotionKey(0, bottom),
            MotionKey(0.22, mid),
            MotionKey(0.42, top),
            MotionKey(0.52, top),
            MotionKey(0.76, mid),
          ],
  );
}

ExerciseMotion _sumo() {
  Pose p(double hipY, double handY, double lean) => _front(
        hip: Offset(0, hipY),
        torsoLen: lean,
        arm: Ik(Offset(-0.07, handY), bend: 1),
        leg: const Ik(Offset(-0.22, _ank), bend: -1),
      );
  return _frontReps(
    p(0.34, 0.15, 0.8),
    p(0.52, 0.48, 1),
    seconds: 3.2,
    gear: const GearRig(shared: true),
  );
}

ExerciseMotion _goodMorning() {
  Pose p(Offset hip, double torso) => _stand(
        hip: hip,
        torso: torso,
        neck: torso > 40 ? -25 : 0,
        armN: const Ik(Offset(-0.07, 0.02), bend: -1, rel: Rel.torso),
        armF: const Ik(Offset(-0.07, 0.01), bend: -1, rel: Rel.torso),
      );
  return _side(p(const Offset(0, _hipY - 0.01), 0), p(const Offset(-0.12, 0.5), 78));
}

ExerciseMotion _rdl() {
  Pose p(Offset hip, double torso) => _stand(
        hip: hip,
        torso: torso,
        neck: torso > 40 ? -25 : 0,
        armN: const Fk(0, 0),
        armF: const Fk(-1, -1),
      );
  return _side(
    p(const Offset(0, _hipY - 0.01), 0),
    p(const Offset(-0.13, 0.49), 74),
    seconds: 3.2,
  );
}

ExerciseMotion _rdlSingleLeg() {
  Pose p(double t) => _stand(
        hip: Offset(-0.04 * t, _hipY - 0.02 * t),
        torso: 80 * t,
        neck: -25 * t,
        armN: const Fk(0, 0),
        armF: const Fk(-1, -1),
        legF: Fk(-80 * t, -80 * t - 2),
        footF: 90 - 160 * t,
      );
  return _side(p(0), p(1), seconds: 3.4, gear: const GearRig(oneHand: true));
}

ExerciseMotion _pullThrough() {
  Pose p(double t) => _stand(
        hip: Offset(-0.12 * t, _hipY - 0.04 * t),
        torso: 70 * t,
        neck: -20 * t,
        armN: Fk(-8 - 16 * t, -10 - 20 * t),
        armF: Fk(-9 - 16 * t, -11 - 20 * t),
        legN: _foot(0.12),
        legF: _foot(-0.12),
      );
  return _side(
    p(0),
    p(1),
    gear: const GearRig(anchorN: Offset(-0.62, 0.08), shared: true),
  );
}

ExerciseMotion _kbSwing() {
  final back = _stand(
    hip: const Offset(-0.12, 0.45),
    torso: 62,
    neck: -20,
    armN: const Fk(-28, -30),
    armF: const Fk(-29, -31),
    legN: _foot(0.1),
    legF: _foot(-0.1),
  );
  final front = _stand(
    torso: -3,
    armN: const Fk(88, 90),
    armF: const Fk(87, 89),
    legN: _foot(0.1),
    legF: _foot(-0.1),
  );
  return ExerciseMotion(
    view: DemoView.side,
    seconds: 1.8,
    gear: const GearRig(shared: true),
    keys: <MotionKey>[MotionKey(0, back), MotionKey(0.5, front)],
  );
}

// -------------------------------------------------------------- shoulders

ExerciseMotion _overheadPress({required bool dip}) {
  Pose p(Offset hand, {double sink = 0}) => _stand(
        hip: Offset(0, _hipY - sink),
        armN: Ik(hand, bend: -1),
        armF: Ik(hand + const Offset(-0.01, 0), bend: -1),
        legN: Ik(Offset(0.02 + sink, _ank)),
        legF: Ik(Offset(-0.03 + sink, _ank)),
      );
  final rack = p(const Offset(0.11, 0.82));
  final top = p(const Offset(0.0, 1.12));
  if (!dip) return _side(rack, top, gear: const GearRig());
  return ExerciseMotion(
    view: DemoView.side,
    seconds: 2.6,
    keys: <MotionKey>[
      MotionKey(0, rack),
      MotionKey(0.18, p(const Offset(0.08, 0.81), sink: 0.05)),
      MotionKey(0.42, top),
      MotionKey(0.55, top),
    ],
  );
}

ExerciseMotion _overheadPressSeated() {
  Pose p(Offset hand) => _seated(
        torso: -4,
        armN: Ik(hand, bend: -1),
        armF: Ik(hand + const Offset(-0.01, 0), bend: -1),
      );
  final a = p(const Offset(0.06, 0.64));
  return _side(
    a,
    p(const Offset(-0.02, 0.9)),
    props: <Prop>[_seat, _backPad(a, extend: 0.12)],
    gear: const GearRig(anchorN: Offset(-0.25, 0.5), padLength: 0.06),
  );
}

ExerciseMotion _landminePress() {
  Pose p(Offset hand) => _stand(
        torso: 10,
        armN: Ik(hand, bend: -1),
        armF: Ik(hand + const Offset(-0.01, 0), bend: -1),
        legN: _foot(0.14),
        legF: _foot(-0.16),
      );
  return _side(
    p(const Offset(0.13, 0.8)),
    p(const Offset(0.36, 1.0)),
    gear: const GearRig(anchorN: Offset(1.0, 0.02), shared: true),
  );
}

ExerciseMotion _frontRaise() {
  Pose p(double arm) => _stand(armN: Fk(arm, arm + 2), armF: Fk(arm - 1, arm + 1));
  return _side(
    p(4),
    p(90),
    gear: const GearRig(anchorN: Offset(-0.3, 0.08), shared: true),
  );
}

ExerciseMotion _lateralRaise({required double top, required bool seated}) {
  Pose p(double arm) => _front(
        hip: Offset(0, seated ? 0.36 : _hipY),
        arm: Fk(arm, arm + (arm < -100 ? 0 : 4)),
        leg: seated ? const Ik(Offset(-0.13, _ank), bend: -1) : null,
      );
  return _frontReps(
    p(-8),
    p(top),
    props: <Prop>[
      if (seated) const PadProp(Offset(-0.16, 0.3), Offset(0.16, 0.3), legs: false, post: true),
    ],
    gear: const GearRig(anchorN: Offset(0.32, 0.08), anchorF: Offset(-0.32, 0.08)),
  );
}

ExerciseMotion _reverseFlyBent() {
  Pose p(double arm) => _front(
        hip: const Offset(0, 0.5),
        torsoLen: 0.42,
        neck: 0,
        arm: Fk(arm, arm),
        leg: const Ik(Offset(-0.09, _ank), bend: -1),
      );
  return _frontReps(
    p(-4),
    p(-82),
    gear: const GearRig(anchorN: Offset(0.4, 0.08), anchorF: Offset(-0.4, 0.08)),
  );
}

// ------------------------------------------------------------------ arms

ExerciseMotion _curl() {
  Pose p(double upper, double lower, double wrist) => _stand(
        armN: Fk(upper, lower),
        armF: Fk(upper - 4, lower - 4),
        wristN: wrist,
        wristF: wrist,
      );
  return _side(
    p(-2, 2, 0),
    p(10, 148, 12),
    gear: const GearRig(anchorN: Offset(0.32, 0.06)),
  );
}

ExerciseMotion _curlAlternating() {
  final rest = _stand(armN: const Fk(-2, 2), armF: const Fk(-5, -1));
  return _alternating(
    DemoView.side,
    rest,
    rest.copyWith(armN: const Fk(10, 148), wristN: 12),
    rest.copyWith(armF: const Fk(6, 144), wristF: 12),
  );
}

ExerciseMotion _dragCurl() {
  Pose p(Offset hand) => _stand(
        armN: Ik(hand, bend: -1),
        armF: Ik(hand + const Offset(-0.01, 0), bend: -1),
      );
  return _side(p(const Offset(0.04, 0.52)), p(const Offset(0.1, 0.75)));
}

ExerciseMotion _curlBayesian() {
  Pose p(double lower) => _stand(
        torso: 8,
        armN: Fk(-26, lower),
        armF: Fk(-28, lower - 2),
        legN: _foot(0.14),
        legF: _foot(-0.16),
      );
  return _side(
    p(-24),
    p(120),
    gear: const GearRig(anchorN: Offset(-0.6, 0.14), oneHand: true),
  );
}

ExerciseMotion _curlIncline() {
  Pose p(double lower) => _seated(
        torso: -32,
        armN: Fk(-4, lower),
        armF: Fk(-6, lower - 2),
      );
  final a = p(-4);
  return _side(a, p(132), props: <Prop>[_seat, _backPad(a, extend: 0.1)]);
}

ExerciseMotion _curlConcentration() {
  Pose p(double lower) => _seated(
        torso: 34,
        neck: -10,
        armN: Fk(6, lower),
        armF: const Ik(Offset(0.09, -0.1), bend: 1, rel: Rel.hip),
        legN: _foot(0.36),
        legF: _foot(0.3),
      );
  return _side(p(4), p(165), props: const <Prop>[_seat], gear: const GearRig(oneHand: true));
}

ExerciseMotion _curlSpider() {
  Pose p(double lower) => Pose(
        hip: const Offset(-0.02, 0.5),
        torso: 48,
        armN: Fk(2, lower),
        armF: Fk(0, lower - 2),
        legN: _foot(-0.2),
        legF: _foot(-0.24),
      );
  final a = p(2);
  return _side(a, p(150), props: <Prop>[_chestPad(a, from: 0.0, to: 1.05)]);
}

ExerciseMotion _curlPreacher() {
  Pose p(double lower) => _seated(
        hipY: 0.34,
        torso: 10,
        armN: Fk(42, lower),
        armF: Fk(40, lower - 2),
      );
  final a = p(52);
  final s = solvePose(a, DemoView.side);
  final dir = s.armN.mid - s.armN.root;
  final u = dir / dir.distance;
  final under = Offset(u.dy, -u.dx) * 0.05;
  return _side(
    a,
    p(160),
    props: <Prop>[
      const PadProp(Offset(-0.12, 0.27), Offset(0.16, 0.27), legs: false, post: true),
      PadProp(s.armN.root + u * 0.03 + under, s.armN.mid + u * 0.03 + under, legs: false, post: true),
    ],
    gear: GearRig(anchorN: s.armN.mid + const Offset(0, -0.02), padLength: 0.06),
  );
}

ExerciseMotion _pushdown() {
  Pose p(double lower) => _stand(
        torso: 10,
        armN: Fk(4, lower),
        armF: Fk(2, lower - 2),
      );
  return _side(
    p(100),
    p(4),
    gear: const GearRig(anchorN: Offset(0.36, 1.06), shared: true),
  );
}

ExerciseMotion _overheadExtension() {
  Pose p(double lower) => _stand(
        torso: 6,
        armN: Fk(172, lower),
        armF: Fk(170, lower - 2),
        legN: _foot(0.12),
        legF: _foot(-0.14),
      );
  return _side(
    p(338),
    p(176),
    gear: const GearRig(anchorN: Offset(-0.46, 0.9), shared: true),
  );
}

ExerciseMotion _kickback() {
  Pose p(double lower) => _stand(
        hip: const Offset(-0.05, 0.5),
        torso: 70,
        neck: -20,
        armN: Fk(-62, lower),
        armF: const Ik(Offset(0.08, -0.06), bend: 1, rel: Rel.hip),
        legN: _foot(0.08),
        legF: _foot(-0.08),
      );
  return _side(
    p(0),
    p(-66),
    gear: const GearRig(anchorN: Offset(0.55, 0.3), oneHand: true),
  );
}

ExerciseMotion _skullCrusher() {
  Pose p(double lower) => Pose(
        hip: const Offset(0.14, 0.32),
        torso: -90,
        armN: Fk(190, lower),
        armF: Fk(188, lower - 2),
        legN: _foot(0.44),
        legF: _foot(0.4),
      );
  return _side(p(186), p(300), props: const <Prop>[_flatBench], gear: const GearRig(shared: true));
}

ExerciseMotion _tricepsMachine() {
  Pose p(double lower) => _seated(
        torso: 4,
        armN: Fk(58, lower),
        armF: Fk(56, lower - 2),
      );
  final a = p(168);
  final s = solvePose(a, DemoView.side);
  return _side(
    a,
    p(62),
    props: const <Prop>[_seat],
    gear: GearRig(anchorN: s.armN.mid, padLength: 0.07),
  );
}

ExerciseMotion _wristCurl() {
  Pose p(double wrist) => _seated(
        torso: 30,
        armN: const Fk(6, 90),
        armF: const Fk(4, 88),
        wristN: wrist,
        wristF: wrist,
      );
  return _side(
    p(-60),
    p(40),
    seconds: 2.0,
    props: const <Prop>[_seat],
    gear: const GearRig(anchorN: Offset(0.55, 0.06)),
  );
}

ExerciseMotion _wristCurlBehind() {
  Pose p(double wrist) => _stand(
        armN: const Fk(-8, -8),
        armF: const Fk(-10, -10),
        wristN: wrist,
        wristF: wrist,
      );
  return _side(p(0), p(-55), seconds: 2.0);
}

ExerciseMotion _wristRoller() {
  Pose p(double a, double b) => _stand(
        armN: const Fk(88, 90),
        armF: const Fk(87, 89),
        wristN: a,
        wristF: b,
      );
  return ExerciseMotion(
    view: DemoView.side,
    seconds: 3.6,
    hold: true,
    peak: 1,
    gear: const GearRig(shared: true),
    keys: <MotionKey>[
      MotionKey(0, p(-30, 20)),
      MotionKey(0.25, p(20, -30)),
      MotionKey(0.5, p(-30, 20)),
      MotionKey(0.75, p(20, -30)),
    ],
  );
}

ExerciseMotion _gripSqueeze() {
  Pose p(double wrist) => _stand(armN: const Fk(2, 92), armF: const Fk(0, 90), wristN: wrist);
  return _side(p(-5), p(12), seconds: 1.6, gear: const GearRig(oneHand: true));
}

ExerciseMotion _deadHang() {
  const barY = 1.27;
  final p = _front(
    hip: const Offset(0, barY - 0.31 - Bone.torso - 0.02),
    arm: const Ik(Offset(-0.18, barY - 0.02), bend: 1),
    leg: const Fk(3, 1),
    shrug: 0.3,
  );
  return _hold(DemoView.front, p, props: const <Prop>[BarProp(Offset(0, barY), width: 0.4)]);
}

ExerciseMotion _carry({required bool overhead}) {
  Pose step(double n, double f, double lift, double bob) => _stand(
        hip: Offset(0, _hipY - 0.015 + bob),
        armN: overhead ? const Fk(176, 178) : const Fk(4, 4),
        armF: overhead ? const Fk(174, 176) : const Fk(2, 2),
        legN: Ik(Offset(n, _ank + (lift > 0 ? lift : 0))),
        legF: Ik(Offset(f, _ank + (lift < 0 ? -lift : 0))),
      );
  return ExerciseMotion(
    view: DemoView.side,
    seconds: 1.3,
    peak: 1,
    keys: <MotionKey>[
      MotionKey(0, step(0.12, -0.12, 0, 0)),
      MotionKey(0.25, step(0.0, 0.0, -0.06, 0.012)),
      MotionKey(0.5, step(-0.12, 0.12, 0, 0)),
      MotionKey(0.75, step(0.0, 0.0, 0.06, 0.012)),
    ],
  );
}

ExerciseMotion _holdStanding() =>
    _hold(DemoView.side, _stand(armN: const Fk(3, 3), armF: const Fk(1, 1)));

// ------------------------------------------------------------------ core

const Limb _handsBehindHead = Ik(Offset(0.02, 0.1), bend: 1, rel: Rel.torso);
const Limb _handsBehindHeadF = Ik(Offset(0.01, 0.09), bend: 1, rel: Rel.torso);

Pose _supine({
  double torso = -90,
  Offset hip = const Offset(0, 0.065),
  Limb armN = _handsBehindHead,
  Limb armF = _handsBehindHeadF,
  Limb? legN,
  Limb? legF,
  double neck = 0,
  double footN = 90,
  double footF = 90,
}) =>
    Pose(
      hip: hip,
      torso: torso,
      neck: neck,
      armN: armN,
      armF: armF,
      legN: legN ?? Ik(Offset(hip.dx + 0.3, _ank)),
      legF: legF ?? Ik(Offset(hip.dx + 0.27, _ank)),
      footN: footN,
      footF: footF,
    );

ExerciseMotion _crunch() =>
    _side(_supine(), _supine(torso: -58, neck: 10), seconds: 2.4);

ExerciseMotion _toeTouchCrunch() {
  Pose p(double torso, double arm) => _supine(
        torso: torso,
        armN: Fk(arm, arm),
        armF: Fk(arm - 2, arm - 2),
        legN: const Fk(178, 182),
        legF: const Fk(176, 180),
        footN: 175,
        footF: 175,
      );
  return _side(p(-90, 178), p(-62, 165), seconds: 2.4);
}

ExerciseMotion _sitUp({required bool decline}) {
  const crossed = Ik(Offset(0.07, -0.1), bend: -1, rel: Rel.torso);
  const crossedF = Ik(Offset(0.06, -0.11), bend: -1, rel: Rel.torso);
  if (!decline) {
    return _side(
      _supine(armN: crossed, armF: crossedF),
      _supine(torso: -12, armN: crossed, armF: crossedF),
      seconds: 3,
    );
  }
  const hip = Offset(0.05, 0.42);
  Pose p(double torso) => Pose(
        hip: hip,
        torso: torso,
        armN: crossed,
        armF: crossedF,
        legN: const Ik(Offset(0.35, 0.36)),
        legF: const Ik(Offset(0.34, 0.36)),
      );
  return _side(
    p(-110),
    p(-20),
    seconds: 3,
    props: const <Prop>[
      PadProp(Offset(-0.45, 0.24), Offset(0.22, 0.38), legs: false, post: true),
      PadProp(Offset(0.36, 0.3), Offset(0.36, 0.3), legs: false, post: true),
    ],
  );
}

ExerciseMotion _vUp() {
  Pose p(double torso, double leg, double arm) => _supine(
        torso: torso,
        armN: Fk(arm, arm),
        armF: Fk(arm - 2, arm - 2),
        legN: Fk(leg, leg),
        legF: Fk(leg - 2, leg - 2),
      );
  return _side(p(-90, 90, 270), p(-42, 138, 148), seconds: 2.6);
}

ExerciseMotion _cableCrunch() {
  Pose p(double torso) => Pose(
        hip: const Offset(0, 0.3),
        torso: torso,
        neck: torso * 0.2,
        armN: const Ik(Offset(0.05, 0.1), bend: 1, rel: Rel.torso),
        armF: const Ik(Offset(0.04, 0.09), bend: 1, rel: Rel.torso),
        legN: const Fk(2, -90),
        legF: const Fk(0, -90),
        footN: -170,
        footF: -170,
      );
  return _side(
    p(18),
    p(78),
    gear: const GearRig(anchorN: Offset(0.32, 1.1), shared: true),
  );
}

ExerciseMotion _machineCrunch() {
  Pose p(double torso) => _seated(
        torso: torso,
        armN: const Ik(Offset(0.05, 0.0), bend: -1, rel: Rel.torso),
        armF: const Ik(Offset(0.04, -0.01), bend: -1, rel: Rel.torso),
      );
  return _side(
    p(-4),
    p(42),
    props: const <Prop>[_seat],
    gear: const GearRig(anchorN: Offset(-0.08, 0.86), padLength: 0.06),
  );
}

ExerciseMotion _ballCrunch() {
  Pose p(double torso) => Pose(
        hip: const Offset(0.04, 0.3),
        torso: torso,
        armN: _handsBehindHead,
        armF: _handsBehindHeadF,
        legN: _foot(0.38),
        legF: _foot(0.35),
      );
  return _side(
    p(-82),
    p(-50),
    props: const <Prop>[BallProp(Offset(-0.06, 0.15), radius: 0.15)],
  );
}

ExerciseMotion _plankHold() {
  const ankle = Offset(-0.62, 0.07);
  final (hip, torso) = _plank(ankle, 0.19);
  return _hold(
    DemoView.side,
    Pose(
      hip: hip,
      torso: torso,
      armN: const Fk(2, 90),
      armF: const Fk(0, 88),
      legN: const Ik(ankle),
      legF: Ik(ankle + const Offset(-0.01, 0)),
      footN: 20,
      footF: 20,
    ),
  );
}

ExerciseMotion _sidePlank() {
  return _hold(
    DemoView.front,
    const Pose(
      hip: Offset(0, 0.25),
      torso: 72,
      armN: Fk(-180, -180),
      armF: Ik(Offset(0.36, 0.03), bend: 1),
      legN: Ik(Offset(-0.46, 0.1), bend: -1),
      legF: Ik(Offset(-0.47, 0.05), bend: -1),
    ),
  );
}

ExerciseMotion _abWheel() {
  Pose p(Offset hip, double torso, Offset wheel) => Pose(
        hip: hip,
        torso: torso,
        neck: -15,
        armN: Ik(wheel, bend: -1),
        armF: Ik(wheel + const Offset(-0.01, 0), bend: -1),
        legN: const Ik(Offset(-0.4, 0.04)),
        legF: const Ik(Offset(-0.41, 0.04)),
        footN: -170,
        footF: -170,
      );
  return _side(
    p(const Offset(-0.12, 0.27), 50, const Offset(0.13, 0.07)),
    p(const Offset(0.02, 0.2), 82, const Offset(0.6, 0.07)),
    seconds: 3.2,
  );
}

ExerciseMotion _hangingRaise({required bool knees}) {
  const barY = 1.27;
  Pose p(double up) => Pose(
        hip: const Offset(0, barY - 0.33 - Bone.torso),
        torso: up * -8,
        armN: const Fk(180, 180),
        armF: const Fk(178, 178),
        legN: knees ? Fk(100 * up, 0) : Fk(90 * up, 90 * up),
        legF: knees ? Fk(98 * up - 2, -2) : Fk(88 * up - 2, 88 * up - 2),
        footN: knees ? 90 : 90 + 80 * up,
        footF: knees ? 90 : 90 + 80 * up,
      );
  return _side(p(0), p(1), props: const <Prop>[BarProp(Offset(0, barY))]);
}

ExerciseMotion _captainsChair() {
  Pose p(double up) => Pose(
        hip: const Offset(0, 0.68),
        torso: -2,
        armN: const Fk(0, 90),
        armF: const Fk(-2, 88),
        legN: Fk(100 * up, 0),
        legF: Fk(98 * up - 2, -2),
      );
  return _side(
    p(0),
    p(1),
    props: const <Prop>[
      PadProp(Offset(-0.02, 0.78), Offset(0.2, 0.78), legs: false, post: true),
      PadProp(Offset(-0.09, 0.6), Offset(-0.09, 1.02), legs: false, post: true),
    ],
  );
}

ExerciseMotion _hangingObliqueRaise() {
  const barY = 1.27;
  Pose p(double side) => _front(
        hip: const Offset(0, barY - 0.33 - Bone.torso),
        torso: side * -6,
        arm: const Ik(Offset(-0.18, barY - 0.02), bend: 1),
        leg: side == 0 ? const Fk(3, 1) : Fk(side * 55, side * 5),
        legF: side == 0 ? const Fk(-3, -1) : Fk(side * 55, side * 5),
        stride: side == 0 ? 1 : 0.62,
      );
  return _alternating(
    DemoView.front,
    p(0),
    p(-1),
    p(1),
    props: const <Prop>[BarProp(Offset(0, barY), width: 0.4)],
  );
}

ExerciseMotion _lyingLegRaise() {
  Pose p(double leg) => _supine(
        armN: const Fk(88, 90),
        armF: const Fk(86, 88),
        legN: Fk(leg, leg),
        legF: Fk(leg - 2, leg - 2),
        footN: leg + 80,
        footF: leg + 80,
      );
  return _side(p(92), p(176), seconds: 3);
}

ExerciseMotion _reverseCrunch() {
  Pose p(double t) => _supine(
        hip: Offset(0, 0.065 + 0.04 * t),
        torso: -90 - 8 * t,
        armN: const Fk(88, 90),
        armF: const Fk(86, 88),
        legN: Fk(180 + 40 * t, 90 + 60 * t),
        legF: Fk(178 + 40 * t, 88 + 60 * t),
      );
  return _side(p(0), p(1), seconds: 2.4, gear: const GearRig(anchorN: Offset(0.7, 0.08), at: GearAt.ankles, oneHand: true));
}

ExerciseMotion _flutter({required double amplitude, required double seconds}) {
  Pose p(double n, double f) => _supine(
        neck: 15,
        armN: const Fk(88, 90),
        armF: const Fk(86, 88),
        legN: Fk(n, n),
        legF: Fk(f, f),
        footN: n + 70,
        footF: f + 70,
      );
  const base = 108.0;
  return ExerciseMotion(
    view: DemoView.side,
    seconds: seconds,
    peak: 1,
    keys: <MotionKey>[
      MotionKey(0, p(base - amplitude / 2, base + amplitude / 2)),
      MotionKey(0.5, p(base + amplitude / 2, base - amplitude / 2)),
    ],
  );
}

ExerciseMotion _mountainClimber() {
  const ankle = Offset(-0.6, 0.07);
  final (hip, torso) = _plank(ankle, 0.33);
  Pose p(bool nearIn, bool farIn) => Pose(
        hip: hip,
        torso: torso,
        armN: const Ik(Offset(0.12, 0.03), bend: -1),
        armF: const Ik(Offset(0.1, 0.03), bend: -1),
        legN: Ik(nearIn ? const Offset(-0.06, 0.1) : ankle),
        legF: Ik(farIn ? const Offset(-0.07, 0.1) : ankle + const Offset(-0.01, 0)),
        footN: 20,
        footF: 20,
      );
  return ExerciseMotion(
    view: DemoView.side,
    seconds: 1.2,
    peak: 1,
    keys: <MotionKey>[MotionKey(0, p(false, false)), MotionKey(0.25, p(true, false)), MotionKey(0.5, p(false, false)), MotionKey(0.75, p(false, true))],
  );
}

ExerciseMotion _deadBug() {
  final rest = _supine(
    armN: const Fk(180, 180),
    armF: const Fk(178, 178),
    legN: const Fk(180, 90),
    legF: const Fk(178, 88),
  );
  return _alternating(
    DemoView.side,
    rest,
    rest.copyWith(armN: const Fk(264, 264), legF: const Fk(96, 96)),
    rest.copyWith(armF: const Fk(262, 262), legN: const Fk(96, 96)),
  );
}

ExerciseMotion _dragonFlag() {
  const shoulder = Offset(-0.2, 0.32);
  Pose p(double phi) {
    final r = phi * math.pi / 180;
    final hip = shoulder + Offset(math.cos(r), math.sin(r)) * Bone.torso;
    final torso = math.atan2(-math.cos(r), -math.sin(r)) * 180 / math.pi;
    final leg = math.atan2(math.cos(r), -math.sin(r)) * 180 / math.pi;
    // Keep the angles continuous through the cycle.
    final t = torso > 0 ? torso - 360 : torso;
    return Pose(
      hip: hip,
      torso: t,
      armN: const Ik(Offset(-0.4, 0.27), bend: 1),
      armF: const Ik(Offset(-0.41, 0.27), bend: 1),
      legN: Fk(leg, leg),
      legF: Fk(leg - 2, leg - 2),
      footN: leg + 70,
      footF: leg + 70,
    );
  }

  return _side(p(72), p(14), seconds: 3.6, props: const <Prop>[_flatBench]);
}

ExerciseMotion _twist({required bool seated}) {
  Pose p(double side) => _front(
        hip: Offset(0, seated ? 0.36 : 0.08),
        torso: side * 12,
        torsoLen: seated ? 1 : 0.86,
        arm: Ik(Offset(side * 0.17, seated ? 0.62 : 0.2), bend: 1),
        armF: Ik(Offset(side * 0.17 + 0.02, seated ? 0.62 : 0.2), bend: -1),
        leg: seated
            ? const Ik(Offset(-0.13, _ank), bend: -1)
            : const Ik(Offset(-0.1, 0.12), bend: -1),
        stride: seated ? 1 : 0.7,
      );
  return _alternating(
    DemoView.front,
    p(0),
    p(-1),
    p(1),
    seconds: 3,
    props: <Prop>[
      if (seated) const PadProp(Offset(-0.16, 0.3), Offset(0.16, 0.3), legs: false, post: true),
    ],
    gear: const GearRig(shared: true),
  );
}

ExerciseMotion _bicycleCrunch() {
  final rest = _supine(torso: -70, legN: const Fk(150, 100), legF: const Fk(148, 98));
  return _alternating(
    DemoView.side,
    rest,
    rest.copyWith(torso: -62, legN: const Fk(205, 120), legF: const Fk(108, 108)),
    rest.copyWith(torso: -62, legF: const Fk(203, 118), legN: const Fk(108, 108)),
    seconds: 2.4,
  );
}

ExerciseMotion _woodchopper() {
  Pose p(Offset hand, double torso, double sink) => _front(
        hip: Offset(0, _hipY - sink),
        torso: torso,
        arm: Ik(hand, bend: 1),
        armF: Ik(hand + const Offset(0.03, 0), bend: 1),
        leg: Ik(Offset(-0.12 + sink, _ank), bend: -1),
        legF: Ik(Offset(0.12 - sink, _ank), bend: 1),
      );
  return _frontReps(
    p(const Offset(0.32, 1.04), 8, 0),
    p(const Offset(-0.26, 0.36), -10, 0.04),
    gear: const GearRig(anchorN: Offset(0.58, 1.14), shared: true),
  );
}

ExerciseMotion _pallofPress() {
  Pose p(double reach) => _front(
        hip: const Offset(0, _hipY - 0.02),
        arm: const Ik(Offset(-0.01, 0.72), bend: 1),
        armF: const Ik(Offset(0.01, 0.72), bend: -1),
        reach: reach,
        leg: _foot(-0.12, _ank, -1),
      );
  return _frontReps(
    p(1),
    p(0.38),
    gear: const GearRig(anchorN: Offset(0.62, 0.76), shared: true),
  );
}

ExerciseMotion _sideBend() {
  Pose p(double torso) => _front(torso: torso, arm: const Fk(-4, -4), armF: const Ik(Offset(-0.05, 0.03), bend: -1, rel: Rel.hip));
  return _frontReps(
    p(0),
    p(-18),
    gear: const GearRig(anchorN: Offset(-0.45, 0.08), oneHand: true),
  );
}

ExerciseMotion _landmineRotation() {
  Pose p(Offset hand, double torso) => _front(
        torso: torso,
        arm: Ik(hand, bend: 1),
        armF: Ik(hand + const Offset(0.02, 0), bend: -1),
        leg: _foot(-0.14, _ank, -1),
      );
  return ExerciseMotion(
    view: DemoView.front,
    seconds: 3.2,
    gear: const GearRig(anchorN: Offset(0, 0.02), shared: true),
    keys: <MotionKey>[
      MotionKey(0, p(const Offset(0, 1.02), 0)),
      MotionKey(0.25, p(const Offset(-0.3, 0.6), -8)),
      MotionKey(0.5, p(const Offset(0, 1.02), 0)),
      MotionKey(0.75, p(const Offset(0.3, 0.6), 8)),
    ],
  );
}

// ------------------------------------------------------------------ legs

enum _Hold { back, front, goblet, arms, belt }

ExerciseMotion _squat(_Hold hold, {bool box = false}) {
  final arms = switch (hold) {
    _Hold.back => (
        const Ik(Offset(-0.07, 0.02), bend: -1, rel: Rel.torso),
        const Ik(Offset(-0.07, 0.01), bend: -1, rel: Rel.torso),
      ),
    _Hold.front => (
        const Ik(Offset(0.09, 0.02), bend: -1, rel: Rel.torso),
        const Ik(Offset(0.09, 0.01), bend: -1, rel: Rel.torso),
      ),
    _Hold.goblet => (
        const Ik(Offset(0.12, -0.07), bend: -1, rel: Rel.torso),
        const Ik(Offset(0.12, -0.08), bend: -1, rel: Rel.torso),
      ),
    _Hold.arms => (const Fk(86, 88), const Fk(84, 86)),
    _Hold.belt => (
        const Ik(Offset(0.06, 0.06), bend: -1, rel: Rel.hip),
        const Ik(Offset(0.05, 0.05), bend: -1, rel: Rel.hip),
      ),
  };
  final lean = hold == _Hold.back ? 40.0 : hold == _Hold.arms ? 36.0 : 24.0;
  Pose p(double t) => _stand(
        hip: Offset(-0.15 * t, _hipY - 0.01 - 0.25 * t),
        torso: lean * t,
        armN: arms.$1,
        armF: arms.$2,
        legN: _foot(0.03),
        legF: _foot(-0.01),
      );
  return _side(
    p(0),
    p(1),
    seconds: 3,
    props: <Prop>[if (box) BoxProp(Rect.fromLTRB(-0.32, 0, -0.06, 0.2))],
    gear: GearRig(
      shared: hold == _Hold.goblet,
      at: hold == _Hold.belt ? GearAt.hip : GearAt.hands,
      offset: hold == _Hold.belt ? const Offset(0.04, -0.12) : Offset.zero,
      anchorN: const Offset(0.62, 0.03),
    ),
  );
}

ExerciseMotion _hackSquat() {
  Pose p(double t) => Pose(
        hip: Offset(0.0 - 0.13 * t, 0.56 - 0.24 * t),
        torso: -22,
        armN: const Ik(Offset(0.06, 0.0), bend: -1, rel: Rel.torso),
        armF: const Ik(Offset(0.05, -0.01), bend: -1, rel: Rel.torso),
        legN: const Ik(Offset(0.16, 0.1)),
        legF: const Ik(Offset(0.13, 0.1)),
        footN: 105,
        footF: 105,
      );
  return _side(
    p(0),
    p(1),
    seconds: 3,
    props: const <Prop>[
      PadProp(Offset(-0.3, 0.32), Offset(-0.02, 1.0), legs: false, post: true),
      PadProp(Offset(0.1, 0.05), Offset(0.3, 0.1), legs: false, post: true),
    ],
  );
}

ExerciseMotion _legPress({required bool calf}) {
  const hip = Offset(0, 0.36);
  Pose p(Offset ankle, double foot) => Pose(
        hip: hip,
        torso: -58,
        armN: const Ik(Offset(0.07, 0.29), bend: -1),
        armF: const Ik(Offset(0.06, 0.29), bend: -1),
        legN: Ik(ankle),
        legF: Ik(ankle + const Offset(-0.01, 0.01)),
        footN: foot,
        footF: foot,
      );
  final a = calf ? p(const Offset(0.29, 0.69), 220) : p(const Offset(0.16, 0.53), 232);
  final b = calf ? p(const Offset(0.31, 0.71), 196) : p(const Offset(0.3, 0.69), 232);
  return _side(
    a,
    b,
    seconds: calf ? 2.0 : 3.0,
    props: <Prop>[_backPad(a, extend: 0.1), const PadProp(Offset(-0.15, 0.3), Offset(0.06, 0.3), legs: false, post: true)],
    gear: const GearRig(at: GearAt.feet, anchorN: Offset(0.72, 1.06), padLength: 0.26),
  );
}

ExerciseMotion _legExtension() {
  Pose p(double shin) => _seated(
        hipY: 0.36,
        torso: -10,
        armN: const Ik(Offset(0.0, 0.3), bend: 1),
        armF: const Ik(Offset(-0.01, 0.3), bend: 1),
        legN: Fk(88, shin),
        legF: Fk(86, shin - 2),
      );
  final a = p(4);
  return _side(
    a,
    p(86),
    props: <Prop>[
      const PadProp(Offset(-0.12, 0.29), Offset(0.2, 0.29), legs: false, post: true),
      _backPad(a),
    ],
    gear: const GearRig(at: GearAt.ankles, anchorN: Offset(0.25, 0.37), padLength: 0.06, oneHand: true),
  );
}

ExerciseMotion _splitSquat({required bool bulgarian}) {
  final back = bulgarian ? const Offset(-0.4, 0.3) : const Offset(-0.3, 0.07);
  Pose p(double t) => _stand(
        hip: Offset(-0.04, _hipY - 0.04 - 0.21 * t),
        torso: bulgarian ? 10 * t : 3,
        legN: _foot(0.22),
        legF: Ik(back),
        footF: bulgarian ? -95 : 20,
      );
  return _side(
    p(0),
    p(1),
    seconds: 3,
    props: <Prop>[
      if (bulgarian) const PadProp(Offset(-0.62, 0.235), Offset(-0.34, 0.235)),
    ],
  );
}

ExerciseMotion _lunge({required bool forward}) {
  final rest = _stand();
  final down = forward
      ? _stand(
          hip: const Offset(0.08, 0.3),
          torso: 4,
          legN: _foot(0.32),
          legF: const Ik(Offset(-0.18, 0.07)),
          footF: 20,
        )
      : _stand(
          hip: const Offset(-0.06, 0.3),
          torso: 4,
          legN: _foot(0.02),
          legF: const Ik(Offset(-0.46, 0.07)),
          footF: 20,
        );
  return _side(rest, down, seconds: 3);
}

ExerciseMotion _stepUp() {
  final a = _stand(
    hip: const Offset(-0.06, 0.5),
    torso: 12,
    legN: const Ik(Offset(0.2, 0.26)),
    legF: _foot(-0.1),
  );
  final b = _stand(
    hip: const Offset(0.16, 0.74),
    legN: const Ik(Offset(0.2, 0.26)),
    legF: const Ik(Offset(0.14, 0.27)),
  );
  return _side(a, b, seconds: 3, props: <Prop>[BoxProp(Rect.fromLTRB(0.04, 0, 0.4, 0.22))]);
}

ExerciseMotion _pistol() {
  Pose p(double t) => _stand(
        hip: Offset(-0.13 * t, _hipY - 0.01 - 0.35 * t),
        torso: 40 * t,
        armN: const Fk(86, 88),
        armF: const Fk(84, 86),
        legN: _foot(0.03),
        legF: Fk(20 + 66 * t, 20 + 68 * t),
        footF: 110 + 60 * t,
      );
  return _side(p(0), p(1), seconds: 3.4);
}

ExerciseMotion _sissy() {
  Pose p(double t) => _stand(
        hip: Offset(0.12 * t, _hipY - 0.01 - 0.22 * t),
        torso: -38 * t,
        armN: const Fk(86, 88),
        armF: const Ik(Offset(0.42, 0.62), bend: -1),
        legN: Ik(Offset(0.02, _ank + 0.04 * t)),
        legF: Ik(Offset(-0.02, _ank + 0.04 * t)),
        footN: 90 + 50 * t,
        footF: 90 + 50 * t,
      );
  return _side(p(0), p(1), seconds: 3.2, props: const <Prop>[BarProp(Offset(0.44, 0.62))]);
}

ExerciseMotion _wallSit() => _hold(
      DemoView.side,
      _stand(
        hip: const Offset(-0.14, 0.29),
        armN: const Fk(10, 10),
        armF: const Fk(8, 8),
        legN: _foot(0.11),
        legF: _foot(0.08),
      ),
      props: const <Prop>[WallProp(-0.22)],
    );

ExerciseMotion _curtsy() {
  final rest = _front(arm: const Ik(Offset(0.02, -0.02), bend: 1, rel: Rel.hip), armF: const Ik(Offset(-0.02, -0.02), bend: -1, rel: Rel.hip));
  final down = _front(
    hip: const Offset(-0.03, 0.36),
    arm: const Ik(Offset(0.02, -0.02), bend: 1, rel: Rel.hip),
    armF: const Ik(Offset(-0.02, -0.02), bend: -1, rel: Rel.hip),
    leg: _foot(-0.1, _ank, -1),
    legF: const Ik(Offset(-0.22, 0.07), bend: -1),
  );
  return _frontReps(rest, down, seconds: 3, gear: const GearRig(oneHand: true));
}

ExerciseMotion _legCurlLying({required bool band}) {
  Pose p(double shin) => Pose(
        hip: const Offset(0, 0.5),
        torso: 90,
        neck: -15,
        armN: const Ik(Offset(0.4, 0.42), bend: -1),
        armF: const Ik(Offset(0.39, 0.42), bend: -1),
        legN: Fk(-90, shin),
        legF: Fk(-88, shin + 2),
        footN: shin + 60,
        footF: shin + 60,
      );
  return _side(
    p(-90),
    p(-172),
    props: <Prop>[
      if (band)
        const PadProp(Offset(-0.3, 0.42), Offset(0.4, 0.42), legs: false)
      else
        const PadProp(Offset(-0.3, 0.42), Offset(0.4, 0.42), legs: false, post: true),
    ],
    gear: GearRig(
      at: GearAt.ankles,
      anchorN: band ? const Offset(-0.9, 0.46) : const Offset(-0.26, 0.5),
      padLength: 0.06,
      oneHand: true,
    ),
  );
}

ExerciseMotion _legCurlSeated() {
  Pose p(double shin) => _seated(
        hipY: 0.36,
        torso: -14,
        armN: const Ik(Offset(0.0, 0.3), bend: 1),
        armF: const Ik(Offset(-0.01, 0.3), bend: 1),
        legN: Fk(88, shin),
        legF: Fk(86, shin - 2),
      );
  final a = p(88);
  return _side(
    a,
    p(-12),
    props: <Prop>[
      const PadProp(Offset(-0.12, 0.29), Offset(0.2, 0.29), legs: false, post: true),
      _backPad(a),
    ],
    gear: const GearRig(at: GearAt.ankles, anchorN: Offset(0.25, 0.37), padLength: 0.06, oneHand: true),
  );
}

ExerciseMotion _legCurlStanding() {
  Pose p(double shin) => _stand(
        torso: 14,
        armN: const Ik(Offset(0.28, 0.74), bend: -1),
        armF: const Ik(Offset(0.27, 0.74), bend: -1),
        legN: Fk(-4, shin),
        legF: _foot(0.0),
        footN: shin + 80,
      );
  return _side(
    p(-4),
    p(-150),
    gear: const GearRig(at: GearAt.ankles, anchorN: Offset(-0.03, 0.29), padLength: 0.06, oneHand: true),
  );
}

ExerciseMotion _gluteHam() {
  Pose p(double t) {
    const knee = Offset(0, 0.55);
    final thigh = -90 + 90 * t;
    final hip = knee - limbDirection(thigh) * Bone.thigh;
    return Pose(
      hip: hip,
      torso: 90 - 90 * t,
      armN: const Ik(Offset(0.07, -0.1), bend: -1, rel: Rel.torso),
      armF: const Ik(Offset(0.06, -0.11), bend: -1, rel: Rel.torso),
      legN: Fk(thigh, -90),
      legF: Fk(thigh + 2, -88),
      footN: -170,
      footF: -170,
    );
  }

  return _side(
    p(0),
    p(1),
    seconds: 3.2,
    props: const <Prop>[
      PadProp(Offset(0.02, 0.48), Offset(0.22, 0.48), legs: false, post: true),
      PadProp(Offset(-0.26, 0.61), Offset(-0.26, 0.61), legs: false, post: true),
    ],
  );
}

ExerciseMotion _nordic() {
  Pose p(double t) {
    const knee = Offset(0, 0.055);
    final thigh = -70 * t;
    final hip = knee - limbDirection(thigh) * Bone.thigh;
    return Pose(
      hip: hip,
      torso: 70 * t,
      armN: Fk(30 + 40 * t, 70 + 30 * t),
      armF: Fk(28 + 40 * t, 68 + 30 * t),
      legN: Fk(thigh, -90),
      legF: Fk(thigh + 2, -88),
      footN: -170,
      footF: -170,
    );
  }

  return _side(p(0), p(1), seconds: 3.6, down: 0.6, hold: 0.04);
}

ExerciseMotion _ballLegCurl() {
  Pose p(Offset hip, Offset ankle) {
    const shoulderY = 0.075;
    final dy = shoulderY - hip.dy;
    final cosT = dy / Bone.torso;
    final t = -math.acos(cosT.clamp(-1.0, 1.0)) * 180 / math.pi;
    return Pose(
      hip: hip,
      torso: t,
      armN: const Fk(88, 90),
      armF: const Fk(86, 88),
      legN: Ik(ankle),
      legF: Ik(ankle + const Offset(-0.01, 0)),
      footN: 160,
      footF: 160,
    );
  }

  return _side(
    p(const Offset(0, 0.2), const Offset(0.45, 0.245)),
    p(const Offset(0.0, 0.3), const Offset(0.25, 0.245)),
    gear: const GearRig(at: GearAt.ankles, offset: Offset(0.02, -0.125)),
  );
}

ExerciseMotion _hipThrust() {
  const shoulder = Offset(-0.22, 0.32);
  Pose p(double drop) {
    final r = math.asin(drop / Bone.torso);
    final hip = shoulder + Offset(math.cos(r), -math.sin(r)) * Bone.torso;
    final torso = math.atan2(shoulder.dx - hip.dx, shoulder.dy - hip.dy) * 180 / math.pi;
    return Pose(
      hip: hip,
      torso: torso,
      armN: const Ik(Offset(0.02, 0.1), bend: 1, rel: Rel.hip),
      armF: const Ik(Offset(0.01, 0.1), bend: 1, rel: Rel.hip),
      legN: _foot(0.3),
      legF: _foot(0.28),
    );
  }

  return _side(
    p(0.19),
    p(0.0),
    props: const <Prop>[PadProp(Offset(-0.62, 0.235), Offset(-0.2, 0.235))],
    gear: const GearRig(at: GearAt.hip, offset: Offset(0.0, 0.12), anchorN: Offset(-0.05, 0.6)),
  );
}

ExerciseMotion _bridge({required bool single}) {
  const shoulder = Offset(-0.26, 0.07);
  Pose p(double lift) {
    final hip = Offset(shoulder.dx + math.sqrt(Bone.torso * Bone.torso - lift * lift), shoulder.dy + lift);
    final torso = math.atan2(shoulder.dx - hip.dx, shoulder.dy - hip.dy) * 180 / math.pi;
    return Pose(
      hip: hip,
      torso: torso,
      armN: const Fk(88, 90),
      armF: const Fk(86, 88),
      legN: _foot(0.3),
      legF: single ? Fk(112 - lift * 60, 112 - lift * 60) : _foot(0.28),
      footF: single ? 170 : 90,
    );
  }

  return _side(p(0.0), p(0.2), seconds: 2.4);
}

ExerciseMotion _kickbackStanding() {
  Pose p(double leg) => _stand(
        torso: 24,
        armN: const Ik(Offset(0.3, 0.74), bend: -1),
        armF: const Ik(Offset(0.29, 0.74), bend: -1),
        legN: Fk(leg, leg + 4),
        legF: _foot(0.02),
        footN: 110,
      );
  return _side(
    p(-2),
    p(-48),
    gear: const GearRig(at: GearAt.ankles, anchorN: Offset(-0.55, 0.06), oneHand: true),
  );
}

ExerciseMotion _donkeyKick() {
  Pose p(double t) => Pose(
        hip: const Offset(0, 0.3),
        torso: 90,
        neck: -10,
        armN: const Fk(2, 2),
        armF: const Fk(0, 0),
        legN: Fk(-95 * t, -90 - 90 * t),
        legF: const Fk(2, -88),
        footN: -170 + 80 * t,
        footF: -170,
      );
  return _side(p(0), p(1), seconds: 2.4);
}

ExerciseMotion _fireHydrant() {
  Pose p(double t) => _front(
        hip: const Offset(0, 0.3),
        torsoLen: 0.25,
        arm: const Fk(-2, -2),
        leg: Fk(-75 * t, -10 * t),
        legF: const Fk(2, 2),
        stride: 0.55 + 0.1 * t,
        strideF: 0.55,
      );
  return _frontReps(p(0), p(1), seconds: 2.4);
}

ExerciseMotion _hipAbduction() {
  Pose p(double t) => _front(
        hip: const Offset(0, 0.36),
        arm: const Ik(Offset(-0.2, 0.36), bend: 1),
        leg: Fk(8 - 38 * t, -2 - 38 * t),
        stride: 0.62,
      );
  return _frontReps(
    p(0),
    p(1),
    props: const <Prop>[PadProp(Offset(-0.16, 0.3), Offset(0.16, 0.3), legs: false, post: true)],
  );
}

ExerciseMotion _lateralWalk() {
  Pose p(double n, double f, double x) => _front(
        hip: Offset(x, 0.47),
        torsoLen: 0.96,
        arm: const Fk(-10, 60),
        leg: Ik(Offset(n, _ank), bend: -1),
        legF: Ik(Offset(f, _ank), bend: 1),
      );
  return ExerciseMotion(
    view: DemoView.front,
    seconds: 2.2,
    peak: 1,
    gear: const GearRig(at: GearAt.ankles),
    keys: <MotionKey>[
      MotionKey(0, p(-0.1, 0.1, 0)),
      MotionKey(0.4, p(-0.24, 0.1, -0.07)),
      MotionKey(0.5, p(-0.24, 0.1, -0.07)),
      MotionKey(0.9, p(-0.1, 0.1, 0)),
    ],
  );
}

ExerciseMotion _calfRaise({required bool loaded, required bool single}) {
  final armsN = loaded ? const Ik(Offset(-0.07, 0.02), bend: -1, rel: Rel.torso) : const Fk(3, 3);
  final armsF = loaded ? const Ik(Offset(-0.07, 0.01), bend: -1, rel: Rel.torso) : const Fk(1, 1);
  Pose p(double t) => _stand(
        hip: Offset(0, _hipY + 0.05 * t),
        armN: armsN,
        armF: armsF,
        legN: Ik(Offset(0.02, _ank + 0.05 * t)),
        legF: single ? const Fk(-6, -80) : Ik(Offset(-0.02, _ank + 0.05 * t)),
        footN: 90 + 48 * t,
        footF: single ? 20 : 90 + 48 * t,
      );
  return _side(
    p(0),
    p(1),
    seconds: 2.2,
    gear: GearRig(
      at: loaded ? GearAt.hands : GearAt.hands,
      anchorN: const Offset(-0.3, 0.86),
    ),
  );
}

ExerciseMotion _donkeyCalf() {
  Pose p(double t) => _stand(
        hip: Offset(0.0, _hipY + 0.05 * t),
        torso: 84,
        neck: -20,
        armN: const Ik(Offset(0.45, 0.66), bend: -1),
        armF: const Ik(Offset(0.44, 0.66), bend: -1),
        legN: Ik(Offset(0.02, _ank + 0.05 * t)),
        legF: Ik(Offset(-0.02, _ank + 0.05 * t)),
        footN: 90 + 48 * t,
        footF: 90 + 48 * t,
      );
  return _side(
    p(0),
    p(1),
    seconds: 2.2,
    props: const <Prop>[PadProp(Offset(0.38, 0.62), Offset(0.56, 0.62), legs: false, post: true)],
    gear: const GearRig(at: GearAt.hip, anchorN: Offset(-0.3, 0.4), padLength: 0.08),
  );
}

ExerciseMotion _seatedCalf() {
  Pose p(double t) => _seated(
        hipY: 0.36,
        armN: const Ik(Offset(0.2, 0.42), bend: -1),
        armF: const Ik(Offset(0.19, 0.42), bend: -1),
        legN: Ik(Offset(0.25, _ank + 0.05 * t)),
        legF: Ik(Offset(0.22, _ank + 0.05 * t)),
      ).copyWith(footN: 90 + 48 * t, footF: 90 + 48 * t);
  return _side(
    p(0),
    p(1),
    seconds: 2.2,
    props: const <Prop>[PadProp(Offset(-0.12, 0.29), Offset(0.16, 0.29), legs: false, post: true)],
    gear: const GearRig(at: GearAt.knees, anchorN: Offset(0.5, 0.36), offset: Offset(0, 0.05), padLength: 0.1),
  );
}

ExerciseMotion _jumpRope() {
  Pose p(double up) => _front(
        hip: Offset(0, _hipY - 0.02 + up),
        arm: const Fk(-14, 30),
        leg: Ik(Offset(-0.06, _ank + up), bend: -1),
      ).copyWith(footN: 90, footF: 90);
  return ExerciseMotion(
    view: DemoView.front,
    seconds: 0.75,
    peak: 1,
    keys: <MotionKey>[MotionKey(0, p(0)), MotionKey(0.5, p(0.06))],
  );
}
