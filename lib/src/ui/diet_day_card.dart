import 'package:flutter/material.dart';

import '../data/diet_derived.dart';
import '../data/local_date.dart';
import '../theme/app_palette.dart';
import 'food_picker_screen.dart' show kDietWeekdayShort;
import 'week_day_chip.dart' show kWeekdayLong;

/// The selected day's planned protein (`.daycard` in `prototypes/diet.html`).
///
/// R17, states counts, never verdicts:
///
/// * No target: "86 g planned".
/// * A target: "86 of 120 g planned", with "34 g to go" only while planned is
///   under the target. At or past it there is no second line, and no word
///   for "past" either.
///
/// **Structure.** The top line is the planned count; [subLines] holds the
/// line under it ("28 g eaten", [eatenLine], on today and earlier days this
/// week); [footer] is the [DietTargetBar] with its legend when a target is
/// set, or the "Set a daily target" link ([setTargetKey]) when none is. The
/// Diet pane composes both, so the card stays a plain layout.
class DietDayCard extends StatelessWidget {
  const DietDayCard({
    required this.day,
    this.subLines = const <String>[],
    this.footer,
    super.key,
  });

  final DietDay day;

  /// Extra count lines joined after "N g to go" with " · ".
  final List<String> subLines;

  /// Below the lines: the bar and legend, or the target link (U13).
  final Widget? footer;

  @visibleForTesting
  static const Key cardKey = ValueKey<String>('diet-day-card');

  /// The "Set a daily target" link in the no-target card (AE2).
  static const Key setTargetKey = ValueKey<String>('diet-day-set-target');

  /// The planned-against-target bar: its track, its two layers, its legend.
  @visibleForTesting
  static const Key barKey = ValueKey<String>('diet-day-bar');

  @visibleForTesting
  static const Key plannedLayerKey = ValueKey<String>('diet-day-bar-planned');

  @visibleForTesting
  static const Key eatenLayerKey = ValueKey<String>('diet-day-bar-eaten');

  @visibleForTesting
  static const Key legendKey = ValueKey<String>('diet-day-legend');

  static const String plannedLegend = 'Planned';

  static const String eatenLegend = 'Eaten';

  /// "28 g eaten" (R19): a count beside planned, never a verdict.
  static String eatenLine(int grams) => '$grams g eaten';

  /// "34 g to go", or null without a target or once the target is planned.
  static String? toGoLine(DietDay day) {
    final toGo = day.toGoG;
    return toGo == null || toGo == 0 ? null : '$toGo g to go';
  }

  @override
  Widget build(BuildContext context) {
    final target = day.targetG;
    final lines = <String>[?toGoLine(day), ...subLines];
    return Container(
      key: cardKey,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border.all(color: AppPalette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: '${day.plannedG}', style: _bigStyle),
                TextSpan(
                  text: target == null
                      ? ' g planned'
                      : ' of $target g planned',
                  style: _ofStyle,
                ),
              ],
            ),
          ),
          if (lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(lines.join(' · '), style: _subStyle),
            ),
          ?footer,
        ],
      ),
    );
  }
}

/// The planned-against-target bar and its legend (`.pbar` and `.legend` in
/// `prototypes/diet.html`), shown only when a target is set (R17).
///
/// Two layers on a [AppPalette.mutedSurface] track (KTD20): planned in
/// [AppPalette.textMuted], and on a tickable day eaten in
/// [AppPalette.accentStrong] over it. Both stop at full; there is no shape for
/// "past the target". **Every layer has a word in the legend**, so nothing is
/// told by colour alone (R19). A future day has no eaten layer and no "Eaten"
/// entry, because nothing on it can be ticked yet.
class DietTargetBar extends StatelessWidget {
  const DietTargetBar({required this.day, super.key});

  final DietDay day;

  @override
  Widget build(BuildContext context) {
    final target = day.targetG!;
    final planned = day.meter ?? 0;
    final eaten = (day.eatenG / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(
          child: Container(
            key: DietDayCard.barKey,
            height: 7,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppPalette.mutedSurface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: <Widget>[
                _BarLayer(
                  layerKey: DietDayCard.plannedLayerKey,
                  fraction: planned,
                  color: AppPalette.textMuted,
                ),
                if (day.tickable)
                  _BarLayer(
                    layerKey: DietDayCard.eatenLayerKey,
                    fraction: eaten,
                    color: AppPalette.accentStrong,
                  ),
              ],
            ),
          ),
        ),
        Row(
          key: DietDayCard.legendKey,
          children: <Widget>[
            const _LegendEntry(
              label: DietDayCard.plannedLegend,
              color: AppPalette.textMuted,
            ),
            if (day.tickable) ...<Widget>[
              const SizedBox(width: 12),
              const _LegendEntry(
                label: DietDayCard.eatenLegend,
                color: AppPalette.accentStrong,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _BarLayer extends StatelessWidget {
  const _BarLayer({
    required this.layerKey,
    required this.fraction,
    required this.color,
  });

  /// On the painted box, so a test can measure the layer's width.
  final Key layerKey;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction,
        child: DecoratedBox(
          key: layerKey,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// A swatch and its word. The word carries the meaning; the swatch only
/// matches it to the layer.
class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: _subStyle),
      ],
    );
  }
}

/// This week, Monday to Sunday (`.week` in `prototypes/diet.html`). Today's
/// short name is in the accent; the selected day carries an accent outline,
/// never a fill. With a target, each day carries a `WeekDayMeter` under its
/// date ([meters]).
class DietWeekStrip extends StatelessWidget {
  const DietWeekStrip({
    required this.monday,
    required this.today,
    required this.selected,
    required this.onSelected,
    this.meters,
    super.key,
  });

  final LocalDate monday;
  final LocalDate today;
  final LocalDate selected;
  final ValueChanged<LocalDate> onSelected;

  /// One widget per day under the date (the meters); null for none.
  final List<Widget>? meters;

  /// A day of the strip, 0 = Monday.
  static Key dayKey(int weekday) => ValueKey<String>('diet-week-day-$weekday');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          for (var d = 0; d < kWeekdayLong.length; d++) ...<Widget>[
            if (d > 0) const SizedBox(width: 4),
            Expanded(
              child: _WeekDay(
                key: dayKey(d),
                weekday: d,
                date: monday.addDays(d),
                isToday: monday.addDays(d) == today,
                selected: monday.addDays(d) == selected,
                meter: meters?[d],
                onTap: () => onSelected(monday.addDays(d)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.weekday,
    required this.date,
    required this.isToday,
    required this.selected,
    required this.meter,
    required this.onTap,
    super.key,
  });

  final int weekday;
  final LocalDate date;
  final bool isToday;
  final bool selected;
  final Widget? meter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${kWeekdayLong[weekday]} ${date.day}${isToday ? ', today' : ''}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppPalette.accentStrong : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                kDietWeekdayShort[weekday],
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isToday ? AppPalette.accentStrong : AppPalette.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${date.day}',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppPalette.textPrimary
                      : AppPalette.textSecondary,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              if (meter != null) ...<Widget>[
                const SizedBox(height: 4),
                meter!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const TextStyle _bigStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.4,
  color: AppPalette.textPrimary,
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
);

const TextStyle _ofStyle = TextStyle(
  fontSize: 13,
  color: AppPalette.textSecondary,
);

const TextStyle _subStyle = TextStyle(
  fontSize: 12,
  color: AppPalette.textMuted,
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
);
