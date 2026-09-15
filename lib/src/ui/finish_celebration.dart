import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// The moment between finishing and the card.
///
/// **Small and fast, and not an award.** A checkmark and one radiating ring,
/// under a second. `CLAUDE.md` rules out achievements, badges and level-ups for
/// V1, and this screen is where that line is easiest to cross — so there is no
/// trophy, no streak milestone, no confetti and no sound. It marks that the
/// work was saved, nothing more.
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

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: AppPalette.pageBackground,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                final pop = Curves.easeOutBack.transform(t.clamp(0, 0.5) * 2);
                final ring = Curves.easeOut.transform(t);
                return Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Opacity(
                      opacity: (1 - ring).clamp(0, 1),
                      child: Container(
                        width: 60 + 90 * ring,
                        height: 60 + 90 * ring,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppPalette.accentStrong,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: pop,
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppPalette.accentStrong,
                        ),
                        child: const Icon(Icons.check,
                            size: 34, color: AppPalette.onAccent),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
