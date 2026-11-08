import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reminder_prefs.dart';
import '../data/reminder_scheduler.dart';
import '../data/training_plan.dart';
import '../data/training_reminders.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'reminder_controls.dart';
import 'week_day_chip.dart';

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
/// **The reminder row is real** (U16, ADR 0005 §3). The switch and time are
/// stored in `ReminderPrefs` (`reminderPrefsProvider`); turning it on shows
/// the explain-first sheet and then the OS prompt (`optInToReminders`). The
/// pane schedules nothing itself: `trainingReminderSyncProvider` reschedules
/// from the plan and the stored switch after every change, at boot and on
/// resume. When the OS refuses, or permission is revoked later, the switch
/// reads off with [kNotificationsOffCopy]; the week summary never depends on
/// it. The row is absent where notifications are unsupported.
class SchedulePane extends ConsumerStatefulWidget {
  const SchedulePane({super.key});

  static const String weekLabel = 'Your week';
  static const String daysLabel = 'Training days';
  static const String remindersLabel = 'Reminders';

  /// Shown instead of the summary when no training days are in force.
  static const String emptySummary =
      'Pick your training days below and this space will show how each week '
      'is going.';

  static const String daysNote =
      'Days you aim for. You can train on any day. These just set what the '
      'summary compares against.';

  static const String explainTitle = 'Remind you on training days?';

  /// The explain-first sheet's body: what will be sent, and what never will.
  static String explainBody({required String time, required Set<int> days}) {
    final names = (days.toList()..sort()).map((d) => _dayShort[d]).join(', ');
    return 'TurtleLift will send one notification at $time on '
        '${names.isEmpty ? 'your training days' : names}. Nothing else: '
        'no streak alerts, no "you missed a day". You can turn it off any '
        'time.';
  }

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

const List<String> _dayShort = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];
const List<String> _dayLong = kWeekdayLong;

/// The line under the this-week count.
///
/// **States a count, never a verdict.** No "missed", no "behind". "N more to
/// go" appears only while plan days remain, and today counts as remaining until
/// it has a session. After the week is over it reads as a plain count.
String weekCaption(WeekSummary week) {
  final extra = week.extra == 0 ? '' : ' · +${week.extra} extra';
  final days = week.planned == 1 ? 'day' : 'days';
  if (week.hit == week.planned) {
    return 'All ${week.planned} plan $days done$extra';
  }
  final left = week.remaining;
  if (left.isEmpty) return '${week.hit} of ${week.planned} plan $days$extra';
  return '${left.length} more to go. Next is ${_dayLong[left.first.weekday]}'
      '$extra';
}

class _SchedulePaneState extends ConsumerState<SchedulePane> {
  /// What the OS last said about permission; null until first read. Re-read
  /// on resume, so a switch turned off in system Settings shows here.
  bool? _permitted;

  /// The user allowed in the sheet and the OS refused, this visit.
  bool _refused = false;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _readPermission();
    _lifecycle = AppLifecycleListener(onResume: _readPermission);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _readPermission() async {
    final scheduler = ref.read(reminderSchedulerProvider);
    if (!scheduler.isSupported) return;
    final permitted = await scheduler.hasPermission();
    if (!mounted) return;
    setState(() {
      _permitted = permitted;
      if (permitted) _refused = false;
    });
  }

  /// On: the explain-first sheet (unless permission is already granted),
  /// then the OS prompt, then store and let the sync schedule. Off: store,
  /// and the sync cancels. The switch never reads on while the OS would
  /// drop what it schedules.
  Future<void> _toggleRemind(bool showingOn) async {
    final prefs = ref.read(reminderPrefsProvider);
    final log = ref.read(reminderPrefsProvider.notifier);
    if (showingOn) {
      await log.save(prefs.copyWith(scheduleOn: false));
      return;
    }
    final result = await optInToReminders(
      context,
      scheduler: ref.read(reminderSchedulerProvider),
      title: SchedulePane.explainTitle,
      body: SchedulePane.explainBody(
        time: formatReminderMinute(context, prefs.scheduleMinute),
        days: ref.read(todayPlanWeekdaysProvider),
      ),
      allowKey: SchedulePane.allowKey,
      notNowKey: SchedulePane.notNowKey,
    );
    if (!mounted) return;
    switch (result) {
      case ReminderOptIn.declined:
        return;
      case ReminderOptIn.denied:
        setState(() {
          _permitted = false;
          _refused = true;
        });
      case ReminderOptIn.granted:
        setState(() {
          _permitted = true;
          _refused = false;
        });
        if (prefs.scheduleOn) {
          // Stored on all along (permission was revoked, now back): the
          // preferences do not change, so ask for the reschedule directly.
          ref.invalidate(trainingRemindersProvider);
        } else {
          await log.save(prefs.copyWith(scheduleOn: true));
        }
    }
  }

  Future<void> _pickTime() async {
    final prefs = ref.read(reminderPrefsProvider);
    final minute = await pickReminderMinute(context, prefs.scheduleMinute);
    if (minute == null || !mounted) return;
    await ref
        .read(reminderPrefsProvider.notifier)
        .save(ref.read(reminderPrefsProvider).copyWith(scheduleMinute: minute));
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
    final supported = ref.watch(reminderSchedulerProvider).isSupported;
    final prefs = ref.watch(reminderPrefsProvider);
    final revoked = prefs.scheduleOn && _permitted == false;
    final remindOn = prefs.scheduleOn && !revoked;

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
                fontSize: 13,
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
              WeekDayChip(
                key: SchedulePane.dayChipKey(d),
                weekday: d,
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
              fontSize: 12,
              height: 1.5,
              color: AppPalette.textMuted,
            ),
          ),
        ),
        // No row at all where notifications cannot work (R23): an inert
        // switch would promise something the app cannot do.
        if (supported) ...<Widget>[
          const _Label(SchedulePane.remindersLabel),
          SwitchRow(
            switchKey: SchedulePane.remindSwitchKey,
            title: 'Remind me',
            subtitle: 'Notification on training days',
            value: remindOn,
            onTap: () => _toggleRemind(remindOn),
          ),
          TimeRow(
            key: SchedulePane.timeRowKey,
            time: formatReminderMinute(context, prefs.scheduleMinute),
            onTap: _pickTime,
          ),
          if (_refused || revoked) const NotificationsOffNote(),
        ],
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
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
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
    this.padding = const EdgeInsets.all(12),
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
        borderRadius: BorderRadius.circular(16),
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
      label: 'This week: ${week.hit} of ${week.planned} plan '
          '${week.planned == 1 ? 'day' : 'days'}. $caption',
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
                          fontSize: 24,
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
                          fontSize: 12,
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
                        padding: const EdgeInsets.only(left: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            PlanDot(state: day.state, size: 15),
                            const SizedBox(height: 4),
                            Text(
                              _dayShort[day.weekday],
                              style: const TextStyle(
                                fontSize: 12,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          border: Border.all(color: AppPalette.border),
          borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.only(right: 4),
                child: PlanDot(state: day.state, size: 9),
              ),
            const SizedBox(width: 4),
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

