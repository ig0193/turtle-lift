import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Full weekday names, 0 = Monday. What a screen reader hears for a day.
const List<String> kWeekdayLong = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// A day's logged-against-target meter under its date on Diet's week strip
/// (`.wd .meter` in `prototypes/diet.html`).
///
/// **Neutral, never the accent** (KTD20): a [AppPalette.textMuted] fill on a
/// [AppPalette.mutedSurface] track, so the strip stays quieter than the day
/// card's accent bar. It stops at full; there is no shape for "past".
class WeekDayMeter extends StatelessWidget {
  const WeekDayMeter({required this.fraction, super.key});

  /// Logged over target, 0 to 1.
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
