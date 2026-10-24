import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/training_plan.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// The Schedule pane of the Profile tab: this week against the plan, the
/// training-day chips, and the reminder row.
///
/// Rules and reasons: `docs/adr/0005-schedule-and-opt-in-notifications.md`;
/// layout: `prototypes/schedule-options.html` (P1, compact).
///
/// **The week summary is derived on read** from saved sessions and the dated
/// plan, so editing or deleting a session moves it with no refresh path.
/// It is the one computed figure that lives on Profile -- a named exception
/// recorded in ADR 0004 -- and it must not also appear on History.
///
/// **The reminder row is inert for now.** The switch and the explain-first
/// sheet work, but nothing is scheduled and no system permission is requested;
/// real notifications are ticket 04. The switch is local state and deliberately
/// not persisted: a stored "on" that fires nothing would be a lie on disk.
class SchedulePane extends ConsumerStatefulWidget {
  const SchedulePane({super.key});

  static const String weekLabel = 'YOUR WEEK';
  static const String daysLabel = 'TRAINING DAYS';
  static const String remindersLabel = 'REMINDERS';

  /// Shown instead of the summary when no training days are in force.
  static const String emptySummary =
      'Pick your training days below and this space will show how each week '
      'is going.';

  static const String daysNote =
      'Days you aim for. You can train on any day — these just set what the '
      'summary compares against.';

  @visibleForTesting
  static Key dayChipKey(int weekday) => ValueKey<String>('schedule-day-$weekday');

  @visibleForTesting
  static const Key remindSwitchKey = ValueKey<String>('schedule-remind-switch');

  @visibleForTesting
  static const Key timeRowKey = ValueKey<String>('schedule-time-row');

  @visibleForTesting
  static const Key allowKey = ValueKey<String>('schedule-allow');

  @visibleForTesting
  static const Key notNowKey = ValueKey<String>('schedule-not-now');

  @visibleForTesting
  static const Key heroKey = ValueKey<String>('schedule-week-hero');

  @visibleForTesting
  static const Key lastWeekKey = ValueKey<String>('schedule-last-week');

  @override
  ConsumerState<SchedulePane> createState() => _SchedulePaneState();
}

const List<String> _dayInitials = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const List<String> _dayShort = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];
const List<String> _dayLong = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// The line under the this-week count.
///
/// **States a count, never a verdict.** No "missed", no "behind". "N more to
/// go" appears only while plan days remain, and today counts as remaining until
/// it has a session. After the week is over it reads as a plain count.
String weekCaption(WeekSummary week) {
  final extra = week.extra == 0 ? '' : ' · +${week.extra} extra';
  if (week.hit == week.planned) {
    return 'All ${week.planned} plan days done$extra';
  }
  final left = week.remaining;
  if (left.isEmpty) return '${week.hit} of ${week.planned} plan days$extra';
  return '${left.length} more to go — next is ${_dayLong[left.first.weekday]}'
      '$extra';
}

class _SchedulePaneState extends ConsumerState<SchedulePane> {
  bool _remind = false;
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 30);

  Future<void> _toggleRemind() async {
    if (_remind) {
      setState(() => _remind = false);
      return;
    }
    final allowed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _ExplainSheet(
        time: _time.format(context),
        days: ref.read(todayPlanWeekdaysProvider),
      ),
    );
    if (allowed == true && mounted) setState(() => _remind = true);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  void _toggleDay(int weekday) {
    final current = ref.read(todayPlanWeekdaysProvider);
    final next = <int>{...current};
    if (!next.add(weekday)) next.remove(weekday);
    ref.read(trainingPlanLogProvider.notifier).save(next);
  }

  @override
  Widget build(BuildContext context) {
    final week = ref.watch(thisWeekSummaryProvider);
    final lastWeek = ref.watch(lastWeekSummaryProvider);
    final days = ref.watch(todayPlanWeekdaysProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _Label(SchedulePane.weekLabel),
        if (week == null)
          _Card(
            child: Text(
              days.isEmpty
                  ? SchedulePane.emptySummary
                  : _planStartsLater(ref),
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppPalette.textSecondary,
              ),
            ),
          )
        else ...<Widget>[
          _WeekHero(week: week),
          if (lastWeek != null) _LastWeekRow(week: lastWeek),
        ],
        const _Label(SchedulePane.daysLabel),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            for (var d = 0; d < kWeekdayCount; d++)
              _DayChip(
                key: SchedulePane.dayChipKey(d),
                initial: _dayInitials[d],
                label: _dayLong[d],
                selected: days.contains(d),
                onTap: () => _toggleDay(d),
              ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            SchedulePane.daysNote,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: AppPalette.textMuted,
            ),
          ),
        ),
        const _Label(SchedulePane.remindersLabel),
        _SwitchRow(
          switchKey: SchedulePane.remindSwitchKey,
          title: 'Remind me',
          subtitle: 'Notification on training days',
          value: _remind,
          onTap: _toggleRemind,
        ),
        _TimeRow(
          key: SchedulePane.timeRowKey,
          time: _time.format(context),
          onTap: _pickTime,
        ),
      ],
    );
  }
}

/// Shown when a plan exists but has no day left in this week -- saved on a
/// Saturday for Mondays, say. Saying "pick your training days" there would be
/// wrong: they just did.
String _planStartsLater(WidgetRef ref) {
  final today = ref.read(planTodayProvider);
  final plan = ref.read(trainingPlanLogProvider);
  for (var i = 1; i <= kWeekdayCount; i++) {
    final date = today.addDays(i);
    if (weekdaysInEffectOn(plan, date).contains(date.weekday - 1)) {
      return 'Your first plan day is ${_dayLong[date.weekday - 1]}.';
    }
  }
  return SchedulePane.emptySummary;
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Semantics(
        header: true,
        child: Text(text, style: kLandingSectionLabelStyle),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(13),
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border.all(color: AppPalette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

/// This week as the hero: the count and a dot per plan day on one row, with
/// one line saying what is left.
class _WeekHero extends StatelessWidget {
  const _WeekHero({required this.week});

  final WeekSummary week;

  @override
  Widget build(BuildContext context) {
    final caption = weekCaption(week);
    return Semantics(
      container: true,
      label: 'This week: ${week.hit} of ${week.planned} plan days. $caption',
      excludeSemantics: true,
      child: _Card(
        key: SchedulePane.heroKey,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '${week.hit} of ${week.planned}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                          color: AppPalette.textPrimary,
                          fontFeatures: <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      const TextSpan(
                        text: '  this week',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final day in week.days)
                      Padding(
                        padding: const EdgeInsets.only(left: 9),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            PlanDot(state: day.state, size: 15),
                            const SizedBox(height: 3),
                            Text(
                              _dayShort[day.weekday],
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppPalette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppPalette.border)),
              ),
              child: Text(
                caption,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppPalette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastWeekRow extends StatelessWidget {
  const _LastWeekRow({required this.week});

  final WeekSummary week;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Last week: ${week.hit} of ${week.planned} plan days',
      excludeSemantics: true,
      child: Container(
        key: SchedulePane.lastWeekKey,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          border: Border.all(color: AppPalette.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            const Text(
              'Last week',
              style: TextStyle(fontSize: 13, color: AppPalette.textSecondary),
            ),
            const Spacer(),
            for (final day in week.days)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: PlanDot(state: day.state, size: 9),
              ),
            const SizedBox(width: 5),
            Text(
              '${week.hit} of ${week.planned}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppPalette.textPrimary,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
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

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.initial,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String initial;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
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
                color: selected ? AppPalette.accentStrong : AppPalette.surface,
                border: Border.all(
                  color: selected ? AppPalette.accentStrong : AppPalette.border,
                ),
              ),
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? AppPalette.onAccent
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

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.switchKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  final Key switchKey;
  final String title;
  final String subtitle;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: switchKey,
      toggled: value,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppPalette.border),
              bottom: BorderSide(color: AppPalette.border),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: kProfileSwitchTitleStyle),
                    const SizedBox(height: 2),
                    Text(subtitle, style: kProfileSwitchSubtitleStyle),
                  ],
                ),
              ),
              _Switch(on: value),
            ],
          ),
        ),
      ),
    );
  }
}

/// A drawn switch: Material's `Switch` brings a thumb, track and ripple that
/// exist nowhere in the palette.
class _Switch extends StatelessWidget {
  const _Switch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 42,
      height: 25,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? AppPalette.accentStrong : AppPalette.border,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Container(
        width: 19,
        height: 19,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? AppPalette.onAccent : AppPalette.textSecondary,
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.time, required this.onTap, super.key});

  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Reminder time. $time',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppPalette.border)),
          ),
          child: Row(
            children: <Widget>[
              const Expanded(child: Text('Time', style: kProfileSwitchTitleStyle)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  border: Border.all(color: AppPalette.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  time,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppPalette.textPrimary,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The explain-first sheet. "Allow reminders" is the only thing that will
/// trigger the system permission once notifications exist; today it just turns
/// the inert switch on.
class _ExplainSheet extends StatelessWidget {
  const _ExplainSheet({required this.time, required this.days});

  final String time;
  final Set<int> days;

  @override
  Widget build(BuildContext context) {
    final names = (days.toList()..sort()).map((d) => _dayShort[d]).join(', ');
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        20,
        18,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Remind you on training days?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'TurtleLift will send one notification at $time on '
            '${names.isEmpty ? 'your training days' : names}. Nothing else — '
            'no streak alerts, no "you missed a day". You can turn it off any '
            'time.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            key: SchedulePane.allowKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(true),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppPalette.accentStrong,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Allow reminders',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.onAccent,
                ),
              ),
            ),
          ),
          GestureDetector(
            key: SchedulePane.notNowKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(false),
            child: const SizedBox(
              height: 48,
              child: Center(
                child: Text(
                  'Not now',
                  style: TextStyle(fontSize: 13, color: AppPalette.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle kProfileSwitchTitleStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.1,
  color: AppPalette.textPrimary,
);

const TextStyle kProfileSwitchSubtitleStyle = TextStyle(
  fontSize: 12,
  color: AppPalette.textMuted,
);
