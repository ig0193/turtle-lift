import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/training_plan.dart' show PlanDayState;
import '../theme/app_palette.dart';

/// One-letter weekday initials, 0 = Monday (KTD5's weekday numbering).
const List<String> kWeekdayInitials = <String>[
  'M',
  'T',
  'W',
  'T',
  'F',
  'S',
  'S',
];

/// Full weekday names, 0 = Monday. What a screen reader hears for a chip.
const List<String> kWeekdayLong = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// A round weekday toggle: Schedule's training days and the serving sheet's
/// Repeat on.
///
/// **Promoted from `schedule_pane.dart`'s private `_DayChip`** so Schedule and
/// Diet pick days with one control. **Outlined when selected, never filled**
/// (`prototypes/diet.html` `.days`, and the taste rule that only the primary
/// action is filled): the accent ring and accent letter say "on", and the
/// filled shape stays reserved for the one button that commits.
class WeekDayChip extends StatelessWidget {
  const WeekDayChip({
    required this.weekday,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// 0 = Monday to 6 = Sunday.
  final int weekday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: kWeekdayLong[weekday],
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 44pt hit box around a 38pt disc, so seven fit a 320pt phone.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppPalette.mutedSurface : AppPalette.surface,
                border: Border.all(
                  color: selected ? AppPalette.accentStrong : AppPalette.border,
                ),
              ),
              child: Text(
                kWeekdayInitials[weekday],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? AppPalette.accentStrong
                      : AppPalette.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One plan day: filled when trained, a quiet dashed ring when the day passed
/// with no session, a solid accent ring while it is still ahead. **No red and
/// no failure wording** -- an empty day is just empty.
class PlanDot extends StatelessWidget {
  const PlanDot({required this.state, required this.size, super.key});

  final PlanDayState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _PlanDotPainter(state)),
    );
  }
}

class _PlanDotPainter extends CustomPainter {
  const _PlanDotPainter(this.state);

  final PlanDayState state;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    switch (state) {
      case PlanDayState.hit:
        canvas.drawCircle(
          center,
          size.width / 2,
          Paint()..color = AppPalette.accentStrong,
        );
      case PlanDayState.ahead:
        canvas.drawCircle(
          center,
          size.width / 2 - 0.75,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppPalette.accentStrong,
        );
      case PlanDayState.empty:
        final radius = size.width / 2 - 0.75;
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppPalette.textMuted;
        const dashes = 8;
        const sweep = 2 * math.pi / dashes;
        for (var i = 0; i < dashes; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            i * sweep,
            sweep * 0.55,
            false,
            paint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_PlanDotPainter old) => old.state != state;
}

/// A day's planned-against-target meter under its date on Diet's week strip
/// (`.wd .meter` in `prototypes/diet.html`).
///
/// **Neutral, never the accent** (KTD20): a [AppPalette.textMuted] fill on a
/// [AppPalette.mutedSurface] track. On Diet the accent means eaten, and the
/// meter measures planned. It stops at full; there is no shape for "past".
class WeekDayMeter extends StatelessWidget {
  const WeekDayMeter({required this.fraction, super.key});

  /// Planned over target, 0 to 1.
  final double fraction;

  @visibleForTesting
  static const Key fillKey = ValueKey<String>('week-day-meter-fill');

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 18,
        height: 3,
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppPalette.mutedSurface,
          borderRadius: BorderRadius.circular(2),
        ),
        child: FractionallySizedBox(
          key: fillKey,
          widthFactor: fraction.clamp(0.0, 1.0),
          heightFactor: 1,
          child: const ColoredBox(color: AppPalette.textMuted),
        ),
      ),
    );
  }
}
