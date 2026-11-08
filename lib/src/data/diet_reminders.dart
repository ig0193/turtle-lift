import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diet_derived.dart';
import 'diet_plan.dart';
import 'diet_plan_store.dart';
import 'food_index.dart';
import 'local_date.dart';
import 'meal_slot.dart';
import 'reminder_prefs.dart';
import 'reminder_scheduler.dart';
import 'serving_phrase.dart';
import 'training_plan.dart' show kWeekdayCount, planTodayProvider, startOfWeek;

/// Diet's reminders (U17, ADR 0007): a morning summary of the day's plan and
/// one reminder per planned meal slot, each a weekly notification (KTD15).
///
/// The rules, because each is the bug someone will otherwise write:
///
/// * **Built from the plan only** (R22). No ticks reach [dietRemindersFor],
///   so a reminder cannot be dropped, added or reworded because a meal was or
///   was not ticked (R20, AE7). An empty slot has no reminder and a day with
///   nothing planned has no summary.
/// * **The plan in effect this week is the source.** The notifications repeat
///   weekly, and every plan edit applies from this week's Monday, so this
///   week's version is what each weekday will say until the next edit or
///   resume reschedules.
/// * **Figures round once, like the day view**: the slot and day totals come
///   from [dietDayFor]; each food keeps its one decimal.
/// * **Fixed template copy**, periods and commas, never a dash.

/// The summary's title: "Today, 112 g protein planned".
String dietSummaryTitle(int grams) => 'Today, $grams g protein planned';

/// A meal reminder's title: "Lunch, 28 g protein".
String dietMealTitle(MealSlot slot, int grams) =>
    '${slot.label}, $grams g protein';

/// The summary's body: "Breakfast: Paneer bhurji, Milk. Lunch: Rajma, Curd."
String dietSummaryBody(DietDay day) => <String>[
      for (final slot in day.slots)
        if (!slot.isEmpty)
          '${slot.slot.label}: ${slot.items.map((i) => i.name).join(', ')}.',
    ].join(' ');

/// A meal reminder's body, one sentence per food:
/// "Rajma, 1 katori (9 g). Curd, 1 katori (11 g)."
String dietMealBody(DietSlotDay slot) => <String>[
      for (final i in slot.items)
        i.food == null
            ? '${i.name} (0 g).'
            : '${i.name}, ${servingPhrase(i.food!, i.servings)} '
                '(${formatGramsShort(i.proteinG)} g).',
    ].join(' ');

/// What Diet wants pending: for each weekday of the plan in effect for
/// [today]'s week, a summary (when the summary is on and the day has food)
/// and a reminder per enabled, non-empty slot. Nothing while the master
/// switch is off. Pure.
List<WeeklyReminder> dietRemindersFor({
  required List<DietPlanVersion> versions,
  required FoodIndex foods,
  required ReminderPreferences prefs,
  required LocalDate today,
}) {
  if (!prefs.dietOn) return const <WeeklyReminder>[];
  final monday = startOfWeek(today);
  final reminders = <WeeklyReminder>[];
  for (var weekday = 0; weekday < kWeekdayCount; weekday++) {
    // No ticks and no target: neither may change what a reminder says.
    final day = dietDayFor(
      date: monday.addDays(weekday),
      today: today,
      versions: versions,
      ticks: const {},
      target: null,
      foods: foods,
    );
    if (day.isEmpty) continue;
    if (prefs.summaryOn) {
      reminders.add(WeeklyReminder(
        id: dietSummaryReminderId(weekday),
        weekday: weekday,
        minute: prefs.summaryMinute,
        title: dietSummaryTitle(day.plannedG),
        body: dietSummaryBody(day),
        target: ReminderTarget.dietToday,
      ));
    }
    for (final slot in day.slots) {
      final pref = prefs.slot(slot.slot);
      if (slot.isEmpty || !pref.on) continue;
      reminders.add(WeeklyReminder(
        id: dietMealReminderId(weekday, slot.slot),
        weekday: weekday,
        minute: pref.minute,
        title: dietMealTitle(slot.slot, slot.proteinG),
        body: dietMealBody(slot),
        target: ReminderTarget.dietToday,
      ));
    }
  }
  return List<WeeklyReminder>.unmodifiable(reminders);
}

/// The diet reminders for the plan in effect this week and the stored
/// switches. Derived, so it moves with every plan edit (whether or not a
/// target is set), every preference save, and the resume that re-reads today.
///
/// **The master switch is read first**: while it is off nothing else is
/// watched, so the food list and the plan are never read for a feature the
/// user has not turned on.
final dietRemindersProvider = Provider<List<WeeklyReminder>>((ref) {
  final prefs = ref.watch(reminderPrefsProvider);
  if (!prefs.dietOn) return const <WeeklyReminder>[];
  return dietRemindersFor(
    versions: ref.watch(dietPlanLogProvider),
    foods: ref.watch(foodIndexProvider),
    prefs: prefs,
    today: ref.watch(planTodayProvider),
  );
});

/// Keeps the OS's pending diet reminders equal to [dietRemindersProvider]
/// (KTD15), the way `trainingReminderSyncProvider` does for Schedule.
///
/// Each change reschedules both diet ranges, summaries 200-206 and meals
/// 300-363, and nothing else: the master switch off cancels those two ranges
/// and leaves training reminders alone. Reschedules run one after another and
/// a failure is reported, not thrown.
final dietReminderSyncProvider = Provider<void>((ref) {
  var queue = Future<void>.value();
  ref.listen<List<WeeklyReminder>>(
    dietRemindersProvider,
    (_, reminders) {
      final scheduler = ref.read(reminderSchedulerProvider);
      queue = queue.then((_) async {
        try {
          await rescheduleRange(
            scheduler,
            kDietSummaryReminderIds,
            <WeeklyReminder>[
              for (final r in reminders)
                if (kDietSummaryReminderIds.contains(r.id)) r,
            ],
          );
          await rescheduleRange(
            scheduler,
            kDietMealReminderIds,
            <WeeklyReminder>[
              for (final r in reminders)
                if (kDietMealReminderIds.contains(r.id)) r,
            ],
          );
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
