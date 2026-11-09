/// Paints one frame of an exercise demonstration.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../theme/app_palette.dart';
import 'exercise_motion.dart';
import 'figure_rig.dart';

/// Limb thickness, figure heights.
abstract final class _W {
  static const upperArm = 0.05;
  static const forearm = 0.042;
  static const hand = 0.034;
  static const thigh = 0.074;
  static const shin = 0.056;
  static const foot = 0.036;
  static const neck = 0.04;
  static const torsoSide = 0.125;
}

/// The colours a figure is drawn in. All from the closed palette (`00` §12).
class _Ink {
  const _Ink({
    required this.near,
    required this.far,
    required this.metal,
    required this.muscles,
  });

  final Color near;
  final Color far;
  final Color metal;
  final bool muscles;
}

final _solid = _Ink(
  near: AppPalette.textSecondary,
  far: AppPalette.textMuted.withValues(alpha: 0.5),
  metal: AppPalette.textMuted,
  muscles: true,
);

final _ghost = _Ink(
  near: AppPalette.textMuted.withValues(alpha: 0.26),
  far: AppPalette.textMuted.withValues(alpha: 0.16),
  metal: AppPalette.textMuted.withValues(alpha: 0.22),
  muscles: false,
);

/// The painter. Cheap to construct; [shouldRepaint] compares the phase.
class ExerciseDemoPainter extends CustomPainter {
  ExerciseDemoPainter({
    required this.motion,
    required this.gear,
    required this.primary,
    required this.phase,
    required this.still,
    this.holdProgress = 0,
  });

  final ExerciseMotion motion;

  /// The exercise's `animationGear`: what is in the hands.
  final String gear;

  /// The exercise's primary sub-muscle groups, painted in the primary-muscle
  /// colour on the figure — the same statement the body map makes below it.
  final Set<String> primary;

  /// Position in the cycle, 0 to 1.
  final double phase;

  /// Draw the two-position still: the first key ghosted under the peak.
  final bool still;

  /// For a timed hold, how far round the timer ring is.
  final double holdProgress;

  /// Gear that runs to a fixed anchor: only these widen the frame for it.
  static const Set<String> _anchored = <String>{'cable', 'band', 'machine', 'landmine'};

  static final Map<(ExerciseMotion, String), Rect> _bounds =
      <(ExerciseMotion, String), Rect>{};

  /// The world rectangle the whole cycle occupies, computed once per motion.
  static Rect worldBounds(ExerciseMotion motion, String gear) {
    return _bounds.putIfAbsent((motion, gear), () {
      var r = Rect.fromLTRB(-0.1, 0, 0.1, 0.02);
      for (var i = 0; i <= 24; i++) {
        final s = solvePose(motion.poseAt(i / 24), motion.view);
        for (final p in s.points) {
          r = r.expandToInclude(Rect.fromCircle(center: p, radius: 0.04));
        }
        for (final p in _gearPoints(motion, s)) {
          r = r.expandToInclude(Rect.fromCircle(center: p, radius: 0.06));
        }
      }
      for (final p in motion.props) {
        r = r.expandToInclude(p.bounds);
      }
      final a = motion.gear.anchorN;
      if (a != null && _anchored.contains(gear)) {
        r = r.expandToInclude(Rect.fromCircle(center: a, radius: 0.05));
      }
      final f = motion.gear.anchorF;
      if (f != null && _anchored.contains(gear)) {
        r = r.expandToInclude(Rect.fromCircle(center: f, radius: 0.05));
      }
      return r;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final world = worldBounds(motion, gear);
    // Fit the cycle's bounds into the card with breathing room, floor at the
    // bottom, centred across.
    const pad = 0.1;
    final w = world.width + pad * 2;
    final h = world.height + pad * 1.6;
    final scale = math.min(size.width / w, size.height / h);
    final cx = world.center.dx;
    final floorY = size.height / 2 + world.center.dy * scale;
    canvas.save();
    canvas.translate(size.width / 2 - cx * scale, floorY);
    canvas.scale(scale, -scale);

    _floor(canvas, world);
    for (final p in motion.props) {
      _prop(canvas, p);
    }
    _towers(canvas);

    if (still) {
      _figure(canvas, motion.keys.first.pose, _ghost, 0);
      _figure(canvas, motion.peakPose, _solid, motion.keys[motion.peak].t);
    } else {
      _figure(canvas, motion.poseAt(phase), _solid, phase);
    }
    canvas.restore();

    if (motion.hold) _timer(canvas, size);
  }

  void _floor(Canvas canvas, Rect world) {
    final p = Paint()
      ..color = AppPalette.border
      ..strokeWidth = 0.012
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(world.left - 0.08, -0.006),
      Offset(world.right + 0.08, -0.006),
      p,
    );
  }

  Paint _propFill() => Paint()..color = AppPalette.mutedSurface;
  Paint _propEdge([double width = 0.012]) => Paint()
    ..color = AppPalette.textMuted.withValues(alpha: 0.38)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _prop(Canvas canvas, Prop prop) {
    switch (prop) {
      case PadProp(:final a, :final b, :final legs, :final post):
        final edge = _propEdge();
        if (legs || post) {
          final supports = post
              ? <Offset>[Offset.lerp(a, b, 0.5)!]
              : <Offset>[Offset.lerp(a, b, 0.15)!, Offset.lerp(a, b, 0.85)!];
          for (final s in supports) {
            canvas.drawLine(s, Offset(s.dx, 0), edge);
          }
          if (!post) {
            canvas.drawLine(
              Offset(supports.first.dx - 0.03, 0.004),
              Offset(supports.last.dx + 0.03, 0.004),
              edge,
            );
          }
        }
        final pad = Paint()
          ..color = AppPalette.mutedSurface
          ..strokeWidth = 0.05
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(a, b, pad);
        canvas.drawLine(a, b, _propEdge(0.008)..strokeWidth = 0.008);
        final outline = Path()
          ..addRRect(_capsule(a, b, 0.025));
        canvas.drawPath(outline, _propEdge(0.008));
      case BarProp(:final at, :final width, :final uprights):
        final edge = _propEdge(0.014);
        if (uprights) {
          final xs = width == 0
              ? <double>[at.dx]
              : <double>[at.dx - width, at.dx + width];
          for (final x in xs) {
            canvas.drawLine(Offset(x, 0), Offset(x, at.dy), edge);
          }
        }
        if (width == 0) {
          canvas.drawCircle(at, 0.018, Paint()..color = AppPalette.textMuted);
        } else {
          canvas.drawLine(
            at - Offset(width, 0),
            at + Offset(width, 0),
            Paint()
              ..color = AppPalette.textMuted
              ..strokeWidth = 0.022
              ..strokeCap = StrokeCap.round,
          );
        }
      case BoxProp(:final rect):
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(0.015));
        canvas.drawRRect(rr, _propFill());
        canvas.drawRRect(rr, _propEdge());
      case WallProp(:final x, :final top):
        canvas.drawLine(Offset(x, 0), Offset(x, top), _propEdge(0.02));
      case BallProp(:final centre, :final radius):
        _ball(canvas, centre, radius);
    }
  }

  RRect _capsule(Offset a, Offset b, double r) {
    // An axis-aligned capsule is all a pad outline needs when the pad is
    // level; a tilted one is drawn by the thick stroke alone.
    if ((a.dy - b.dy).abs() > 0.001) {
      return RRect.fromRectAndRadius(Rect.zero, Radius.zero);
    }
    final rect = Rect.fromLTRB(
      math.min(a.dx, b.dx) - r,
      a.dy - r,
      math.max(a.dx, b.dx) + r,
      a.dy + r,
    );
    return RRect.fromRectAndRadius(rect, Radius.circular(r));
  }

  void _ball(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, _propFill());
    canvas.drawCircle(c, r, _propEdge());
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.7),
      0.4,
      1.2,
      false,
      _propEdge(0.008),
    );
  }

  /// A cable needs a stack to come from.
  void _towers(Canvas canvas) {
    if (gear != 'cable') return;
    final edge = _propEdge(0.02);
    final seen = <double>{};
    for (final a in <Offset?>[motion.gear.anchorN, motion.gear.anchorF]) {
      if (a == null || !seen.add(a.dx)) continue;
      final top = math.max(a.dy + 0.06, 0.95);
      final x = a.dx + (a.dx >= 0 ? 0.035 : -0.035);
      canvas.drawLine(Offset(x, 0), Offset(x, top), edge);
      canvas.drawCircle(a, 0.022, _propFill());
      canvas.drawCircle(a, 0.022, _propEdge(0.01));
    }
  }

  void _timer(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) * 0.07;
    final c = Offset(size.width - r - 14, r + 14);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = AppPalette.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * holdProgress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = AppPalette.textSecondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  // ----------------------------------------------------------------- figure

  void _figure(Canvas canvas, Pose pose, _Ink ink, double t) {
    final s = solvePose(pose, motion.view);
    if (motion.view == DemoView.side) {
      _gearBehind(canvas, s, ink, t);
      _limb(canvas, s.armF, s.handF, ink.far, arm: true);
      _leg(canvas, s.legF, s.toeF, s.heelF, ink.far);
      _gearFar(canvas, s, ink);
      _torsoSide(canvas, s, ink.near);
      _head(canvas, s, ink.near);
      _leg(canvas, s.legN, s.toeN, s.heelN, ink.near);
      if (ink.muscles) _muscles(canvas, s, near: true);
      _gearShared(canvas, s, ink, t);
      _limb(canvas, s.armN, s.handN, ink.near, arm: true);
      if (ink.muscles) _muscles(canvas, s, near: true, armsOnly: true);
      _gearNear(canvas, s, ink, t);
    } else {
      _gearBehind(canvas, s, ink, t);
      _leg(canvas, s.legN, s.toeN, s.heelN, ink.near);
      _leg(canvas, s.legF, s.toeF, s.heelF, ink.near);
      _torsoFront(canvas, s, ink.near);
      _head(canvas, s, ink.near);
      if (ink.muscles) _muscles(canvas, s, near: true);
      _limb(canvas, s.armN, s.handN, ink.near, arm: true);
      _limb(canvas, s.armF, s.handF, ink.near, arm: true);
      if (ink.muscles) _muscles(canvas, s, near: true, armsOnly: true);
      _gearShared(canvas, s, ink, t);
      _gearFar(canvas, s, ink);
      _gearNear(canvas, s, ink, t);
    }
  }

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  void _limb(
    Canvas canvas,
    LimbJoints l,
    Offset handTip,
    Color c, {
    required bool arm,
  }) {
    canvas.drawLine(l.root, l.mid, _stroke(c, _W.upperArm));
    canvas.drawLine(l.mid, l.end, _stroke(c, _W.forearm));
    canvas.drawLine(l.end, handTip, _stroke(c, _W.hand));
  }

  void _leg(Canvas canvas, LimbJoints l, Offset toe, Offset heel, Color c) {
    canvas.drawLine(l.root, l.mid, _stroke(c, _W.thigh));
    canvas.drawLine(l.mid, l.end, _stroke(c, _W.shin));
    canvas.drawLine(heel, toe, _stroke(c, _W.foot));
  }

  void _torsoSide(Canvas canvas, Skeleton s, Color c) {
    final dir = s.shoulder - s.hip;
    final unit = dir / dir.distance;
    // Stop short of the shoulder point so the capsule's round end sits at the
    // top of the shoulder rather than above it.
    canvas.drawLine(
      s.hip + unit * 0.01,
      s.shoulder - unit * 0.025,
      _stroke(c, _W.torsoSide),
    );
    canvas.drawLine(s.shoulder, s.neckTop, _stroke(c, _W.neck));
  }

  void _torsoFront(Canvas canvas, Skeleton s, Color c) {
    final dir = s.shoulder - s.hip;
    final unit = dir / dir.distance;
    final across = Offset(unit.dy, -unit.dx);
    final top = s.shoulder - unit * 0.02;
    final waist = Offset.lerp(s.hip, s.shoulder, 0.35)!;
    final path = Path()
      ..moveTo((top - across * 0.112).dx, (top - across * 0.112).dy)
      ..lineTo((top + across * 0.112).dx, (top + across * 0.112).dy)
      ..lineTo((waist + across * 0.068).dx, (waist + across * 0.068).dy)
      ..lineTo((s.hip + across * 0.08).dx, (s.hip + across * 0.08).dy)
      ..lineTo((s.hip - across * 0.08).dx, (s.hip - across * 0.08).dy)
      ..lineTo((waist - across * 0.068).dx, (waist - across * 0.068).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = c);
    canvas.drawPath(path, _stroke(c, 0.04));
    canvas.drawLine(s.shoulder, s.neckTop, _stroke(c, _W.neck));
  }

  void _head(Canvas canvas, Skeleton s, Color c) {
    canvas.drawCircle(s.headCentre, Bone.headRadius, Paint()..color = c);
  }

  // ---------------------------------------------------------------- muscles

  void _muscles(
    Canvas canvas,
    Skeleton s, {
    required bool near,
    bool armsOnly = false,
  }) {
    final paint = _stroke(AppPalette.accentStrong, 0.0);
    void mark(Offset a, Offset b, Offset normal, double side, double w) {
      final o = normal * side;
      canvas.drawLine(a + o, b + o, paint..strokeWidth = w);
    }

    Offset anterior(Offset from, Offset to) {
      final d = to - from;
      final u = d / d.distance;
      return Offset(-u.dy, u.dx);
    }

    final side = s.view == DemoView.side;
    final torsoDir = (s.shoulder - s.hip) / (s.shoulder - s.hip).distance;
    final torsoFront = Offset(torsoDir.dy, -torsoDir.dx);
    Offset tp(double f) => Offset.lerp(s.hip, s.shoulder, f)!;

    void torso(double from, double to, double offset, double w, {double lateral = 0}) {
      if (armsOnly) return;
      if (side) {
        mark(tp(from), tp(to), torsoFront, offset, w);
      } else if (lateral == 0) {
        mark(tp(from), tp(to), torsoFront, 0, w);
      } else {
        mark(tp(from), tp(to), torsoFront, -lateral, w);
        mark(tp(from), tp(to), torsoFront, lateral, w);
      }
    }

    void arms(bool upper, double offset, double w, [double from = 0.2, double to = 0.85]) {
      if (!armsOnly) return;
      for (final arm in side ? <LimbJoints>[s.armN] : <LimbJoints>[s.armN, s.armF]) {
        final a = upper ? arm.root : arm.mid;
        final b = upper ? arm.mid : arm.end;
        final n = anterior(a, b) * (side ? 1 : 0);
        mark(Offset.lerp(a, b, from)!, Offset.lerp(a, b, to)!, n, offset, w);
      }
    }

    void legs(bool upper, double offset, double w) {
      if (armsOnly) return;
      for (final leg in side ? <LimbJoints>[s.legN] : <LimbJoints>[s.legN, s.legF]) {
        final a = upper ? leg.root : leg.mid;
        final b = upper ? leg.mid : leg.end;
        final n = anterior(a, b) * (side ? 1 : 0);
        mark(Offset.lerp(a, b, 0.22)!, Offset.lerp(a, b, 0.78)!, n, offset, w);
      }
    }

    void delt() {
      if (!armsOnly) return;
      for (final arm in side ? <LimbJoints>[s.armN] : <LimbJoints>[s.armN, s.armF]) {
        canvas.drawCircle(
          Offset.lerp(arm.root, arm.mid, 0.12)!,
          0.033,
          Paint()..color = AppPalette.accentStrong,
        );
      }
    }

    for (final id in primary) {
      switch (id) {
        case 'chest/upper':
          torso(0.78, 0.88, 0.035, 0.05, lateral: 0.05);
        case 'chest/mid':
          torso(0.68, 0.84, 0.035, 0.055, lateral: 0.05);
        case 'chest/lower':
          torso(0.6, 0.74, 0.035, 0.05, lateral: 0.05);
        case 'back/lats':
          torso(0.42, 0.78, -0.035, 0.05, lateral: 0.07);
        case 'back/upper':
          if (side) {
            torso(0.78, 0.97, -0.035, 0.05);
          } else if (!armsOnly) {
            // Traps: the slope from neck to shoulder, both sides.
            final across = Offset(torsoDir.dy, -torsoDir.dx);
            for (final sign in <double>[-1, 1]) {
              canvas.drawLine(
                s.neckTop - torsoDir * 0.02,
                s.shoulder + across * (0.08 * sign) - torsoDir * 0.005,
                paint..strokeWidth = 0.035,
              );
            }
          }
        case 'back/lower':
          torso(0.1, 0.4, -0.035, 0.05, lateral: 0.035);
        case 'abs/upper':
          torso(0.4, 0.62, 0.035, 0.05);
        case 'abs/lower':
          torso(0.12, 0.4, 0.035, 0.05);
        case 'obliques/obliques':
          torso(0.15, 0.55, 0.0, 0.05, lateral: 0.06);
        case 'glutes/glutes':
          if (!armsOnly) {
            final n = side ? torsoFront * -0.045 : Offset.zero;
            canvas.drawCircle(s.hip + n, 0.045, Paint()..color = AppPalette.accentStrong);
          }
        case 'shoulders/front-delt' || 'shoulders/side-delt' || 'shoulders/rear-delt':
          delt();
        case 'biceps/biceps':
          arms(true, 0.01, 0.034);
        case 'triceps/triceps':
          arms(true, -0.01, 0.034);
        case 'forearms/forearms':
          arms(false, 0, 0.03, 0.12, 0.7);
        case 'quads/quads':
          legs(true, 0.012, 0.048);
        case 'hamstrings/hamstrings':
          legs(true, -0.012, 0.048);
        case 'calves/calves':
          legs(false, -0.01, 0.038);
      }
    }
  }

  // ------------------------------------------------------------------- gear

  static Iterable<Offset> _gearPoints(ExerciseMotion motion, Skeleton s) sync* {
    yield s.gripN();
    yield s.gripF();
    if (motion.gear.at == GearAt.hip) yield s.hip + const Offset(0, 0.08);
  }

  /// Where the implement sits for the near and far side.
  (Offset, Offset) _attach(Skeleton s) {
    final (n, f) = _attachRaw(s);
    final o = motion.gear.offset;
    return (n + o, f + o);
  }

  (Offset, Offset) _attachRaw(Skeleton s) {
    switch (motion.gear.at) {
      case GearAt.hands:
        return (s.gripN(), s.gripF());
      case GearAt.hip:
        return (s.hip, s.hip);
      case GearAt.shoulders:
        return (s.armN.root, s.armF.root);
      case GearAt.ankles:
        return (s.legN.end, s.legF.end);
      case GearAt.knees:
        return (s.legN.mid, s.legF.mid);
      case GearAt.feet:
        return (
          Offset.lerp(s.heelN, s.toeN, 0.55)!,
          Offset.lerp(s.heelF, s.toeF, 0.55)!,
        );
    }
  }

  bool get _bar =>
      gear == 'barbell' || gear == 'ezbar' || gear == 'trapbar' || gear == 'smith';

  /// Scenery that belongs to the gear and stands behind the figure: Smith
  /// rails, landmine sleeve, machine levers, cable lines.
  void _gearBehind(Canvas canvas, Skeleton s, _Ink ink, double t) {
    final (n, f) = _attach(s);
    final metal = _stroke(ink.metal, 0.014);
    switch (gear) {
      case 'smith':
        // Rails stay where the bar started; the bar slides on them.
        final first = solvePose(motion.keys.first.pose, motion.view);
        final (rail, _) = _attachFor(first);
        if (motion.view == DemoView.side) {
          canvas.drawLine(Offset(rail.dx - 0.07, 0), Offset(rail.dx - 0.07, 1.05), _propEdge(0.018));
        } else {
          for (final x in <double>[-0.42, 0.42]) {
            canvas.drawLine(Offset(x, 0), Offset(x, 1.05), _propEdge(0.018));
          }
        }
      case 'machine':
        final pivot = motion.gear.anchorN;
        if (pivot == null) break;
        final heavy = _stroke(ink.metal, 0.026);
        canvas.drawLine(pivot, Offset(pivot.dx, 0), _propEdge(0.02));
        if (motion.view == DemoView.side) {
          canvas.drawLine(pivot, n, heavy);
          _pad(canvas, pivot, n, ink);
        } else {
          final pf = motion.gear.anchorF ?? Offset(-pivot.dx, pivot.dy);
          canvas.drawLine(pf, Offset(pf.dx, 0), _propEdge(0.02));
          canvas.drawLine(pivot, n, heavy);
          canvas.drawLine(pf, f, heavy);
          _pad(canvas, pivot, n, ink);
          _pad(canvas, pf, f, ink);
        }
        canvas.drawCircle(pivot, 0.022, Paint()..color = ink.metal);
      case 'landmine':
        final base = motion.gear.anchorN ?? Offset(n.dx + 0.6, 0.02);
        final mid = motion.gear.shared || motion.view == DemoView.side
            ? Offset.lerp(n, f, 0.5)!
            : n;
        final d = (mid - base) / (mid - base).distance;
        final end = mid + d * 0.1;
        canvas.drawLine(base, end, _stroke(ink.metal, 0.022));
        canvas.drawCircle(base, 0.02, Paint()..color = ink.metal);
        _plate(canvas, end + d * 0.02, 0.085, ink);
      default:
        break;
    }
    if (gear == 'cable' || gear == 'band') {
      final band = gear == 'band';
      final line = _stroke(ink.metal.withValues(alpha: band ? 0.9 : 0.7), band ? 0.016 : 0.008);
      Offset anchorFor(bool isNear, Offset at) {
        final a = isNear ? motion.gear.anchorN : (motion.gear.anchorF ?? motion.gear.anchorN);
        if (a != null) return a;
        // A band with no anchor runs under the feet.
        return isNear
            ? Offset.lerp(s.heelN, s.toeN, 0.5)!
            : Offset.lerp(s.heelF, s.toeF, 0.5)!;
      }

      if (motion.gear.shared || motion.gear.oneHand) {
        final at = motion.gear.shared ? Offset.lerp(n, f, 0.5)! : n;
        canvas.drawLine(anchorFor(true, at), at, line);
      } else {
        canvas.drawLine(anchorFor(false, f), f, line);
        canvas.drawLine(anchorFor(true, n), n, line);
      }
    }
    if (gear == 'roller') {
      final mid = Offset.lerp(n, f, 0.5)!;
      // The string winds up over the cycle, then unwinds.
      final wound = 0.5 - 0.5 * math.cos(2 * math.pi * t);
      final drop = 0.42 - 0.3 * wound;
      canvas.drawLine(mid, mid - Offset(0, drop), _stroke(ink.metal, 0.006));
      _plate(canvas, mid - Offset(0, drop + 0.05), 0.05, ink);
    }
    if (_bar && motion.view == DemoView.side && gear == 'smith') {
      canvas.drawLine(n, n, metal);
    }
  }

  (Offset, Offset) _attachFor(Skeleton s) => _attach(s);

  void _pad(Canvas canvas, Offset pivot, Offset at, _Ink ink) {
    final d = at - pivot;
    if (d.distance == 0) return;
    final u = d / d.distance;
    final across = Offset(-u.dy, u.dx) * (motion.gear.padLength / 2);
    canvas.drawLine(
      at - across,
      at + across,
      Paint()
        ..color = ink.metal
        ..strokeWidth = 0.04
        ..strokeCap = StrokeCap.round,
    );
  }

  /// The far hand's own implement (side view: drawn behind the torso).
  void _gearFar(Canvas canvas, Skeleton s, _Ink ink) {
    if (motion.gear.oneHand || motion.gear.shared) return;
    final (_, f) = _attach(s);
    if (motion.view == DemoView.side) {
      if (gear == 'dumbbell') _dumbbellEnd(canvas, f, ink, dim: true);
      if (gear == 'kettlebell') _kettlebell(canvas, f, ink, dim: true);
    }
  }

  /// One implement shared between the hands, or a front-view barbell.
  void _gearShared(Canvas canvas, Skeleton s, _Ink ink, double t) {
    final (n, f) = _attach(s);
    if (motion.view == DemoView.front && _bar) {
      final across = f - n;
      final len = across.distance;
      final u = len == 0 ? const Offset(1, 0) : across / len;
      final a = n - u * 0.16;
      final b = f + u * 0.16;
      canvas.drawLine(a, b, _stroke(ink.metal, 0.018));
      for (final end in <Offset>[a + u * 0.03, b - u * 0.03]) {
        final perp = Offset(-u.dy, u.dx);
        final h = gear == 'ezbar' ? 0.06 : 0.09;
        canvas.drawLine(end - perp * h, end + perp * h, _stroke(ink.metal, 0.03));
      }
    }
    if (gear == 'jumprope') {
      // The rope's lowest point swings round the body once per cycle.
      final ang = 2 * math.pi * t;
      final mid = Offset.lerp(n, f, 0.5)!;
      final reach = 0.62;
      final ctrl = Offset(mid.dx, mid.dy - reach * math.cos(ang) - 0.05);
      final path = Path()
        ..moveTo(n.dx, n.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, f.dx, f.dy);
      canvas.drawPath(path, _stroke(ink.metal, 0.01));
    }
  }

  void _gearNear(Canvas canvas, Skeleton s, _Ink ink, double t) {
    final (n, f) = _attach(s);
    final side = motion.view == DemoView.side;
    final points = motion.gear.shared
        ? <Offset>[Offset.lerp(n, f, 0.5)!]
        : side || motion.gear.oneHand
            ? <Offset>[n]
            : <Offset>[n, f];
    switch (gear) {
      case 'barbell' || 'trapbar' || 'smith':
        if (side) _plate(canvas, Offset.lerp(n, f, 0.5)!, 0.11, ink);
      case 'ezbar':
        if (side) _plate(canvas, Offset.lerp(n, f, 0.5)!, 0.085, ink);
      case 'dumbbell':
        for (final p in points) {
          side ? _dumbbellEnd(canvas, p, ink) : _dumbbellAcross(canvas, p, ink);
        }
      case 'kettlebell':
        for (final p in points) {
          _kettlebell(canvas, p, ink);
        }
      case 'plate':
        for (final p in points) {
          _plate(canvas, p, 0.075, ink);
        }
      case 'wheel':
        final p = Offset.lerp(n, f, 0.5)!;
        canvas.drawCircle(p + const Offset(0, -0.02), 0.05, Paint()..color = ink.metal);
        canvas.drawCircle(
          p + const Offset(0, -0.02),
          0.018,
          Paint()..color = AppPalette.surface,
        );
      case 'ball':
        final (an, _) = _attach(s);
        _ball(canvas, an, 0.12);
      case 'cable' || 'band':
        for (final p in points) {
          canvas.drawCircle(p, 0.016, Paint()..color = ink.metal);
        }
      case 'gripper':
        final p = n;
        canvas.drawLine(p, p + const Offset(0.03, -0.05), _stroke(ink.metal, 0.012));
        canvas.drawLine(p, p + const Offset(-0.01, -0.055), _stroke(ink.metal, 0.012));
      case 'roller':
        canvas.drawLine(
          Offset.lerp(n, f, 0.5)! - const Offset(0.04, 0),
          Offset.lerp(n, f, 0.5)! + const Offset(0.04, 0),
          _stroke(ink.metal, 0.03),
        );
      default:
        break;
    }
  }

  void _plate(Canvas canvas, Offset c, double r, _Ink ink) {
    canvas.drawCircle(c, r, Paint()..color = ink.metal);
    canvas.drawCircle(
      c,
      r * 0.72,
      _stroke(AppPalette.surface.withValues(alpha: ink.muscles ? 0.55 : 0.2), 0.008),
    );
    canvas.drawCircle(c, r * 0.18, Paint()..color = AppPalette.surface);
  }

  void _dumbbellEnd(Canvas canvas, Offset c, _Ink ink, {bool dim = false}) {
    final color = dim ? ink.far : ink.metal;
    canvas.drawCircle(c, 0.05, Paint()..color = color);
    canvas.drawCircle(c, 0.012, Paint()..color = AppPalette.surface);
  }

  void _dumbbellAcross(Canvas canvas, Offset c, _Ink ink) {
    final bar = _stroke(ink.metal, 0.016);
    canvas.drawLine(c - const Offset(0.055, 0), c + const Offset(0.055, 0), bar);
    for (final x in <double>[-0.055, 0.055]) {
      canvas.drawLine(
        c + Offset(x, -0.04),
        c + Offset(x, 0.04),
        _stroke(ink.metal, 0.03),
      );
    }
  }

  void _kettlebell(Canvas canvas, Offset c, _Ink ink, {bool dim = false}) {
    final color = dim ? ink.far : ink.metal;
    final body = c - const Offset(0, 0.07);
    canvas.drawCircle(body, 0.05, Paint()..color = color);
    canvas.drawArc(
      Rect.fromCircle(center: c - const Offset(0, 0.03), radius: 0.03),
      0,
      math.pi,
      false,
      _stroke(color, 0.012),
    );
  }

  @override
  bool shouldRepaint(ExerciseDemoPainter old) =>
      old.phase != phase ||
      old.still != still ||
      old.motion != motion ||
      old.gear != gear ||
      old.holdProgress != holdProgress ||
      old.primary.length != primary.length;
}
