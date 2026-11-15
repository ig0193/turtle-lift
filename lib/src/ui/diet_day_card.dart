import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import '../data/diet_derived.dart';
import '../data/local_date.dart';
import '../theme/app_palette.dart';
import 'food_picker_screen.dart' show kDietWeekdayShort;
import 'week_day_meter.dart' show kWeekdayLong;

/// The selected day's logged protein (`.daycard` in `prototypes/diet.html`).
///
/// R17, states counts, never verdicts:
///
/// * No target: "86 g logged".
/// * A target: "86 of 120 g logged", with "34 g to go" only while logged is
///   under the target. At or past it there is no second line, and no word
///   for "past" either.
///
/// **Structure.** The top line is the logged count; [footer] is the
/// [DietTargetBar] when a target is set, or the "Set a daily target" link
/// ([setTargetKey]) when none is. The Diet pane composes it, so the card
/// stays a plain layout.
class DietDayCard extends StatelessWidget {
  const DietDayCard({required this.day, this.footer, super.key});

  final DietDay day;

  /// Below the lines: the bar, or the target link.
  final Widget? footer;

  @visibleForTesting
  static const Key cardKey = ValueKey<String>('diet-day-card');

  /// The "Set a daily target" link in the no-target card (AE2).
  static const Key setTargetKey = ValueKey<String>('diet-day-set-target');

  /// The logged-against-target bar: its track and its one layer.
  @visibleForTesting
  static const Key barKey = ValueKey<String>('diet-day-bar');

  @visibleForTesting
  static const Key loggedLayerKey = ValueKey<String>('diet-day-bar-logged');

  /// "34 g to go", or null without a target or once the target is logged.
  static String? toGoLine(DietDay day) {
    final toGo = day.toGoG;
    return toGo == null || toGo == 0 ? null : '$toGo g to go';
  }

  @override
  Widget build(BuildContext context) {
    final target = day.targetG;
    final toGo = toGoLine(day);
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
                TextSpan(text: '${day.loggedG}', style: _bigStyle),
                TextSpan(
                  text: target == null
                      ? ' g logged'
                      : ' of $target g logged',
                  style: _ofStyle,
                ),
              ],
            ),
          ),
          if (toGo != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(toGo, style: _subStyle),
            ),
          ?footer,
        ],
      ),
    );
  }
}

/// The logged-against-target bar (`.pbar` in `prototypes/diet.html`), shown
/// only when a target is set (R17).
///
/// One layer on a [AppPalette.mutedSurface] track (KTD20), in
/// [AppPalette.accentStrong]. It stops at full; there is no shape for "past
/// the target". The count above it carries the meaning, so the bar needs no
/// legend and nothing is told by colour alone.
class DietTargetBar extends StatelessWidget {
  const DietTargetBar({required this.day, super.key});

  final DietDay day;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        key: DietDayCard.barKey,
        height: 7,
        margin: const EdgeInsets.only(top: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppPalette.mutedSurface,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: <Widget>[
            _BarLayer(
              layerKey: DietDayCard.loggedLayerKey,
              fraction: day.meter ?? 0,
              color: AppPalette.accentStrong,
            ),
          ],
        ),
      ),
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

/// Seven days in a row (`.week` in `prototypes/diet.html`), a window that
/// slides one day at a time.
///
/// **Always seven.** [start] is the first; dragging left reveals later days
/// and dragging right earlier ones, **one day per cell-width dragged**, so it
/// follows the finger instead of jumping a week. A quick fling that did not
/// travel a full cell still moves one day, so a flick is never a no-op. The
/// window's bounds are the notifier's ([onShift]), not this widget's.
///
/// Today's short name is in the accent; the selected day carries an accent
/// outline, never a fill. With a target, each day carries a `WeekDayMeter`
/// under its date ([meters]). **A day after [today] cannot be picked**: Diet
/// is a log, and a meal that has not been eaten has nothing to log.
///
/// Screen readers cannot drag, so the strip offers "Show earlier day" and
/// "Show later day" as custom actions.
class DietWeekStrip extends StatefulWidget {
  const DietWeekStrip({
    required this.start,
    required this.today,
    required this.selected,
    required this.onSelected,
    required this.onShift,
    this.meters,
    super.key,
  });

  /// The first of the seven days.
  final LocalDate start;
  final LocalDate today;
  final LocalDate selected;
  final ValueChanged<LocalDate> onSelected;

  /// Slide the window by this many days (negative is earlier).
  final ValueChanged<int> onShift;

  /// One widget per day under the date (the meters); null for none.
  final List<Widget>? meters;

  /// A day of the strip: the [position]th of its seven, 0 = the first.
  static Key dayKey(int position) =>
      ValueKey<String>('diet-week-day-$position');

  /// The draggable strip, for a test to swipe.
  @visibleForTesting
  static const Key stripKey = ValueKey<String>('diet-week-strip');

  /// A fling faster than this (logical pixels per second) moves one day even
  /// when the drag did not travel a full cell.
  static const double flingVelocity = 700;

  @override
  State<DietWeekStrip> createState() => _DietWeekStripState();
}

class _DietWeekStripState extends State<DietWeekStrip> {
  /// Drag distance not yet turned into a day.
  double _carry = 0;

  /// Whole days moved during the current drag.
  int _moved = 0;

  void _onDragUpdate(DragUpdateDetails details, double cell) {
    // Dragging left (negative dx) reveals later days: the window start moves
    // later. Each full cell of travel is one day.
    _carry -= details.delta.dx;
    while (_carry >= cell) {
      _carry -= cell;
      _moved++;
      widget.onShift(1);
    }
    while (_carry <= -cell) {
      _carry += cell;
      _moved--;
      widget.onShift(-1);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_moved == 0 && velocity.abs() > DietWeekStrip.flingVelocity) {
      widget.onShift(velocity < 0 ? 1 : -1);
    }
    _carry = 0;
    _moved = 0;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Semantics(
      container: true,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        const CustomSemanticsAction(label: 'Show earlier day'): () =>
            w.onShift(-1),
        const CustomSemanticsAction(label: 'Show later day'): () =>
            w.onShift(1),
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.maxWidth / kWeekdayLong.length;
          return GestureDetector(
            key: DietWeekStrip.stripKey,
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (d) => _onDragUpdate(d, cell),
            onHorizontalDragEnd: _onDragEnd,
            onHorizontalDragCancel: () {
              _carry = 0;
              _moved = 0;
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: <Widget>[
                  for (var i = 0; i < kWeekdayLong.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: _WeekDay(
                        key: DietWeekStrip.dayKey(i),
                        date: w.start.addDays(i),
                        isToday: w.start.addDays(i) == w.today,
                        selected: w.start.addDays(i) == w.selected,
                        meter: w.meters?[i],
                        onTap: w.start.addDays(i) > w.today
                            ? null
                            : () => w.onSelected(w.start.addDays(i)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.date,
    required this.isToday,
    required this.selected,
    required this.meter,
    required this.onTap,
    super.key,
  });

  final LocalDate date;
  final bool isToday;
  final bool selected;
  final Widget? meter;

  /// Null for a day that cannot be picked yet.
  final VoidCallback? onTap;

  /// 0 = Monday ... 6 = Sunday. **From the date**, not the column: the strip
  /// slides, so the first cell is any weekday.
  int get weekday => date.weekday - 1;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: onTap != null,
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
                  color: onTap == null
                      ? AppPalette.textMuted
                      : selected
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
