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

/// The Schedule pane of the Profile tab: the training-day chips and the
/// reminder row -- the plan the user types, and nothing derived.
///
/// Rules and reasons: `docs/adr/0005-schedule-and-opt-in-notifications.md`;
/// layout: `prototypes/schedule-options.html` (P1, compact).
///
/// **The week itself is not here.** How this week is going against the plan
/// is derived, so it lives on the Workout landing beside Start (`WeekStrip`,
/// `docs/adr/0008-the-week-lives-on-the-workout-landing.md`), which leaves
/// Profile holding only what the user typed.
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

  static const String daysLabel = 'Training days';
  static const String remindersLabel = 'Reminders';

  static const String daysNote =
      'Days you aim for. You can train on any day. These just set what the '
      'week on the Workout tab compares against.';

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
    final days = ref.watch(todayPlanWeekdaysProvider);
    final supported = ref.watch(reminderSchedulerProvider).isSupported;
    final prefs = ref.watch(reminderPrefsProvider);
    final revoked = prefs.scheduleOn && _permitted == false;
    final remindOn = prefs.scheduleOn && !revoked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
