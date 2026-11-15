import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'meal_slot.dart';
import 'reminder_prefs.dart';
import 'reminder_scheduler.dart';
import 'today.dart' show kWeekdayCount;

/// Diet's reminders (ADR 0007, `docs/adr/0015-diet-is-a-log.md`): one weekly
/// nudge per meal slot the user switched on, to log that meal.
///
/// The rules, because each is the bug someone will otherwise write:
///
/// * **Built from the switches only.** Diet is a log, so there is no plan to
///   read a meal from, and what the log holds today never reaches
///   [dietRemindersFor]: a reminder cannot be dropped or reworded because a
///   meal was or was not logged (R20, AE7).
/// * **Fixed template copy**, periods and commas, never a dash.
/// * **Weekly.** The OS repeats a notification by weekday, so a slot's
///   reminder is seven of them at the same time.

/// A meal reminder's title: "Log your lunch".
String dietMealTitle(MealSlot slot) => 'Log your ${slot.label.toLowerCase()}';

/// A meal reminder's body. Neutral: it never says what was or was not eaten.
const String kDietMealBody = "Add what you ate to today's Diet log.";

/// What Diet wants pending: for every weekday, a reminder for each enabled
/// slot. Nothing while the master switch is off. Pure.
List<WeeklyReminder> dietRemindersFor(ReminderPreferences prefs) {
  if (!prefs.dietOn) return const <WeeklyReminder>[];
  return List<WeeklyReminder>.unmodifiable(<WeeklyReminder>[
    for (var weekday = 0; weekday < kWeekdayCount; weekday++)
      for (final slot in MealSlot.values)
        if (prefs.slot(slot).on)
          WeeklyReminder(
            id: dietMealReminderId(weekday, slot),
            weekday: weekday,
            minute: prefs.slot(slot).minute,
            title: dietMealTitle(slot),
            body: kDietMealBody,
            target: ReminderTarget.dietToday,
          ),
  ]);
}

/// The diet reminders for the stored switches. Derived, so it moves with every
/// preference save and the resume that rebuilds it.
final dietRemindersProvider = Provider<List<WeeklyReminder>>(
  (ref) => dietRemindersFor(ref.watch(reminderPrefsProvider)),
);

/// Keeps the OS's pending diet reminders equal to [dietRemindersProvider]
/// (KTD15).
///
/// Each change reschedules the meal range 300-363 and nothing else. **The
/// retired ranges are cancelled on every run** ([kRetiredReminderIds]): it is
/// cheap, and it makes an upgrade from a build that had training or summary
/// reminders leave none behind. Reschedules run one after another and a
/// failure is reported, not thrown.
final dietReminderSyncProvider = Provider<void>((ref) {
  var queue = Future<void>.value();
  ref.listen<List<WeeklyReminder>>(
    dietRemindersProvider,
    (_, reminders) {
      final scheduler = ref.read(reminderSchedulerProvider);
      queue = queue.then((_) async {
        try {
          for (final range in kRetiredReminderIds) {
            await scheduler.cancelRange(range);
          }
          await rescheduleRange(scheduler, kDietMealReminderIds, reminders);
        } on Object catch (error, stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'turtle_lift',
            context: ErrorDescription('while scheduling diet reminders'),
          ));
        }
      });
    },
    fireImmediately: true,
  );
});
