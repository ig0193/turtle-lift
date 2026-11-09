import 'package:flutter/material.dart';

import '../data/exercise.dart';
import '../demo/demo_catalogue.dart';
import '../demo/demo_painter.dart';
import '../demo/exercise_motion.dart';
import '../theme/app_palette.dart';
import 'motion.dart';

/// The animated demonstration at the top of an exercise's page.
///
/// **Drawn, not bundled** (`docs/adr/0010-exercise-demonstrations-are-drawn-
/// not-bundled.md`): a keyframed figure in the app's own palette, so all 260
/// exercises have one in a single style, offline, with no third-party
/// artwork and no licence to carry.
///
/// **It plays a few reps and then rests**, on the two-position still: the
/// start pose ghosted under the peak. A loop that never ends is motion the
/// reader did not ask for while they read the cues below it (WCAG 2.2.2);
/// the play button brings it back.
///
/// **Reduce Motion shows the still and does not start on its own.** Pressing
/// play is an explicit request, so it still plays.
class ExerciseDemo extends StatefulWidget {
  const ExerciseDemo({required this.exercise, required this.motion, super.key});

  final Exercise exercise;
  final ExerciseMotion motion;

  /// The demonstration for [exercise], or `null` when it names none this
  /// build can draw — the page then simply has no demonstration.
  static Widget? forExercise(Exercise exercise, {Key? key}) {
    final motion = demoMotionFor(exercise.animation);
    if (motion == null) return null;
    return ExerciseDemo(key: key, exercise: exercise, motion: motion);
  }

  /// The play/pause control, for tests.
  static const Key toggleKey = ValueKey<String>('exercise-demo-toggle');

  /// How many cycles play before it rests on the still.
  static const int cycles = 3;

  @override
  State<ExerciseDemo> createState() => _ExerciseDemoState();
}

class _ExerciseDemoState extends State<ExerciseDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds:
          (widget.motion.seconds * 1000 * ExerciseDemo.cycles).round(),
    ),
  )..addStatusListener((_) {
      if (mounted) setState(() {});
    });

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!prefersReducedMotion(context)) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _playing => _controller.isAnimating;

  void _toggle() {
    setState(() {
      if (_playing) {
        _controller.stop();
      } else if (_controller.isCompleted || _controller.value == 0) {
        _controller.forward(from: 0);
      } else {
        _controller.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.exercise.primary.toSet();
    final gear = widget.exercise.animationGear ?? 'none';
    // At rest — never started, or finished its reps — it shows the still.
    final resting = !_playing &&
        (_controller.value == 0 || _controller.isCompleted);
    final label = 'Demonstration of ${widget.exercise.name}'
        '${_playing ? '' : ', paused'}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            (constraints.maxWidth / kExerciseDemoAspect).clamp(160.0, 260.0);
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Semantics(
                  image: true,
                  label: label,
                  excludeSemantics: true,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final v = _controller.value * ExerciseDemo.cycles;
                        return CustomPaint(
                          painter: ExerciseDemoPainter(
                            motion: widget.motion,
                            gear: gear,
                            primary: primary,
                            phase: v - v.floorToDouble(),
                            still: resting,
                            holdProgress:
                                resting ? 1 : v - v.floorToDouble(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: IconButton(
                  key: ExerciseDemo.toggleKey,
                  onPressed: _toggle,
                  tooltip:
                      _playing ? 'Pause demonstration' : 'Play demonstration',
                  icon: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppPalette.textSecondary,
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    shape: const CircleBorder(
                      side: BorderSide(color: AppPalette.border),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Width over height of the demonstration card: wide enough for a lying
/// figure, short enough that the muscle map is still on the first screen.
const double kExerciseDemoAspect = 1.7;
