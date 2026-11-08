import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reminder_prefs.dart';
import 'reminder_scheduler.dart';
import 'training_plan.dart';

/// The training-day reminder's title. **Fixed text** (ADR 0005 §4): it never
/// changes with what was or was not logged, so it cannot read as a nudge
/// about a gap.
const String kTrainingReminderTitle = 'Training day';

/// The training-day reminder's body. Neutral, like the summary (ADR 0005 §5).
const String kTrainingReminderBody = 'Today is one of your training days.';

/// What the Schedule reminder wants pending: one weekly notification per
/// training weekday at the one chosen time (ADR 0005 §3), or nothing while
/// the switch is off.
///
/// **Takes the plan's weekdays and the switches, and nothing else.** No
/// session reaches it, so a reminder cannot be added, dropped or reworded
/// because of what was logged (ADR 0005 §4).
List<WeeklyReminder> trainingRemindersFor({
  required Set<int> weekdays,
  required ReminderPreferences prefs,
}) {
  if (!prefs.scheduleOn) return const <WeeklyReminder>[];
  return <WeeklyReminder>[
    for (final weekday in weekdays.toList()..sort())
      WeeklyReminder(
        id: trainingReminderId(weekday),
        weekday: weekday,
        minute: prefs.scheduleMinute,
        title: kTrainingReminderTitle,
        body: kTrainingReminderBody,
        target: ReminderTarget.schedule,
      ),
  ];
}

/// The training reminders for the plan in force today and the stored
/// switches. Derived, so it moves with every plan save, preference save and
/// resume (which re-reads today).
final trainingRemindersProvider = Provider<List<WeeklyReminder>>(
  (ref) => trainingRemindersFor(
    weekdays: ref.watch(todayPlanWeekdaysProvider),
    prefs: ref.watch(reminderPrefsProvider),
  ),
);

/// Keeps the OS's pending training reminders equal to
/// [trainingRemindersProvider] (KTD15).
///
/// Listening to it (not just reading it: an unlistened provider is paused)
/// reschedules immediately (boot) and then on every change: a plan save, a time change, the switch, and the resume
/// that re-reads today. `RefreshTodayOnResume` in `main.dart` holds it for
/// the life of the scope. Reschedules run one after another, so two quick
/// changes cannot interleave their cancel and schedule calls, and a failure
/// is reported rather than thrown: a plugin error costs the reminder, not
/// the app.
final trainingReminderSyncProvider = Provider<void>((ref) {
  var queue = Future<void>.value();
  ref.listen<List<WeeklyReminder>>(
    trainingRemindersProvider,
    (_, reminders) {
      final scheduler = ref.read(reminderSchedulerProvider);
      queue = queue.then((_) async {
        try {
          await rescheduleRange(scheduler, kTrainingReminderIds, reminders);
        } on Object catch (error, stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'turtle_lift',
            context: ErrorDescription('while scheduling training reminders'),
          ));
        }
      });
    },
    fireImmediately: true,
  );
});
