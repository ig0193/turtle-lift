import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'glass_tab_bar.dart' show GlassTabBar;

/// The moment between finishing and the card.
///
/// **Small and fast, and not an award.** A checkmark and one radiating ring,
/// under a second. `CLAUDE.md` rules out achievements, badges and level-ups for
/// V1, and this screen is where that line is easiest to cross — so there is no
/// trophy, no streak milestone, no confetti and no sound. It marks that the
/// work was saved, nothing more.
///
/// **No overshoot, transforms only.** The check eases out without bouncing past
/// its size, and the ring grows by `Transform.scale` rather than by width and
/// height, so nothing is laid out again each frame. With reduced motion asked
/// for, the check simply appears and the ring is not drawn.
class FinishCelebration extends StatefulWidget {
  const FinishCelebration({required this.onDone, super.key});

  /// Called once the moment has played.
  final VoidCallback onDone;

  /// How long the whole thing lasts.
  static const Duration duration = Duration(milliseconds: 850);

  @override
  State<FinishCelebration> createState() => _FinishCelebrationState();
}

class _FinishCelebrationState extends State<FinishCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FinishCelebration.duration,
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A strong ease-out, settling without overshoot.
  static const Curve _ease = Cubic(0.22, 1, 0.36, 1);

  @override
  Widget build(BuildContext context) {
    // Both platforms' flags: iOS reports Reduce Motion as `reduceMotion` and
    // leaves MediaQuery's `disableAnimations` false (QA second pass).
    final reduceMotion = GlassTabBar.prefersReducedMotion(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: AppPalette.pageBackground,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                final pop =
                    reduceMotion ? 1.0 : _ease.transform(t.clamp(0, 0.4) / 0.4);
                final ring = _ease.transform(t);
                return Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    if (!reduceMotion)
                      Opacity(
                        opacity: (1 - ring).clamp(0, 1),
                        child: Transform.scale(
                          scale: 1 + 1.5 * ring,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppPalette.accentStrong,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Opacity(
                      opacity: pop.clamp(0, 1),
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * pop,
                        child: child,
                      ),
                    ),
                  ],
                );
              },
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.accentStrong,
                ),
                child: const Icon(Icons.check,
                    size: 32, color: AppPalette.onAccent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
