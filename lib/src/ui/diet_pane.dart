import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/diet_derived.dart';
import '../data/diet_plan.dart';
import '../data/food_index.dart';
import '../data/meal_slot.dart';
import '../data/local_date.dart';
import '../data/reminder_prefs.dart';
import '../data/reminder_scheduler.dart' show reminderSchedulerProvider;
import '../data/training_plan.dart' show planTodayProvider, startOfWeek;
import '../theme/app_palette.dart';
import '../theme/app_typography.dart' show kLandingSectionLabelStyle;
import 'diet_day_card.dart';
import 'diet_reminders_screen.dart';
import 'diet_slot_card.dart';
import 'empty_state.dart';
import 'food_picker_screen.dart';
import 'ghost_button.dart';
import 'protein_target_screen.dart';
import 'reminder_controls.dart' show formatReminderMinute;
import 'week_day_chip.dart' show WeekDayMeter, kWeekdayLong;

/// The day the Diet pane shows. **In memory, never stored**, and today by
/// default.
///
/// It is rebuilt from [planTodayProvider], so when a resume finds a new date
/// (KTD13) the selection snaps to the new today rather than leaving the user
/// on a day that is now "yesterday". A resume on the same date changes
/// nothing downstream ([LocalDate] compares by value), so a picked day
/// survives it. A diet reminder tap selects today through [select] (U17).
class DietSelectedDay extends Notifier<LocalDate> {
  @override
  LocalDate build() => ref.watch(planTodayProvider);

  void select(LocalDate date) => state = date;
}

final dietSelectedDayProvider =
    NotifierProvider<DietSelectedDay, LocalDate>(DietSelectedDay.new);

/// The Diet pane of the Profile tab: one weekly protein plan
/// (`docs/adr/0007-diet-in-profile.md`, layout `prototypes/diet.html`).
///
/// **A pane, not a screen.** [ProfileRoot] owns the one scroll view and the
/// pinned "Profile" header; this is a child of that `ListView`, like
/// `ProfilePersonalPane` and `SchedulePane`. Diet's controls live in the pane,
/// never the header (KTD4): header actions are per tab, so a Diet button there
/// would show on Personal and Schedule too.
///
/// Three states, checked in order:
///
/// 1. **Food list unavailable** (R26): plain copy, no button. Nothing a user
///    taps can bring a missing asset back, and every other tab keeps working.
/// 2. **First time**: nothing planned in any week and no target. The bowl,
///    one line, "Plan Monday", which opens the picker for Monday, Breakfast,
///    and a ghost "Set a daily target" under it.
/// 3. **The day**: the week strip (today selected, a meter per day once a
///    target is set), the selected day's card, its four slot cards with an
///    eaten tick where one is allowed (R18), and the "Plan settings" rows
///    (the Target row, KTD4). Every figure comes from [dietDayProvider],
///    computed on read (R24).
class DietPane extends ConsumerWidget {
  const DietPane({super.key});

  static const String unavailableCopy =
      'Food list unavailable. Reinstall the app to restore it.';

  static const String emptyHeading = "Plan your week's protein";

  static const String emptyBody =
      'Pick protein foods for each meal once, and the plan repeats every week.';

  static const String planMondayLabel = 'Plan Monday';

  static const String setTargetLabel = 'Set a daily target';

  static const String settingsLabel = 'Plan settings';

  static const String targetRowTitle = 'Target';

  static const String targetRowSubtitle =
      "Daily protein, measured against every day's plan";

  static const String targetNotSet = 'Not set';

  /// "120 g a day".
  static String targetValue(int grams) => '$grams g a day';

  static const String remindersRowTitle = 'Reminders';

  static const String remindersRowSubtitle =
      'A morning summary and meal times from your plan';

  /// "Off", "On" (master on, nothing chosen) or "4 a day".
  static String remindersValue(ReminderPreferences prefs) {
    if (!prefs.dietOn) return 'Off';
    final count = (prefs.summaryOn ? 1 : 0) +
        MealSlot.values.where((s) => prefs.slot(s).on).length;
    return count == 0 ? 'On' : '$count a day';
  }

  /// "Nothing planned for Thursday", above four empty slots.
  static String nothingPlannedFor(int weekday) =>
      'Nothing planned for ${kWeekdayLong[weekday]}';

  @visibleForTesting
  static const Key unavailableKey = ValueKey<String>('diet-unavailable');

  @visibleForTesting
  static const Key emptyStateKey = ValueKey<String>('diet-empty-state');

  @visibleForTesting
  static const Key planMondayKey = ValueKey<String>('diet-plan-monday');

  @visibleForTesting
  static const Key dayViewKey = ValueKey<String>('diet-day-view');

  /// The empty state's ghost "Set a daily target".
  @visibleForTesting
  static const Key setTargetKey = ValueKey<String>('diet-set-target');

  /// The in-pane Target row (KTD4).
  @visibleForTesting
  static const Key targetRowKey = ValueKey<String>('diet-target-row');

  /// The in-pane Reminders row, under Target (U17). Absent where
  /// notifications are unsupported (R23).
  @visibleForTesting
  static const Key remindersRowKey = ValueKey<String>('diet-reminders-row');

  /// A day on the week strip, 0 = Monday.
  @visibleForTesting
  static Key weekDayKey(int weekday) => DietWeekStrip.dayKey(weekday);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(foodIndexProvider).isAvailable) {
      return const Padding(
        key: unavailableKey,
        padding: EdgeInsets.symmetric(vertical: 34, horizontal: 16),
        child: Text(
          unavailableCopy,
          textAlign: TextAlign.center,
          style: kEmptyStateBodyStyle,
        ),
      );
    }

    final versions = ref.watch(dietPlanLogProvider);
    final target = ref.watch(proteinTargetProvider);
    final nothingPlanned = versions.every((v) => v.items.isEmpty);
    if (nothingPlanned && target == null) return const _DietEmptyState();

    return const _DietDayView();
  }
}

class _DietEmptyState extends StatelessWidget {
  const _DietEmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: DietPane.emptyStateKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const EmptyState(
          glyph: EmptyStateGlyph.bowl,
          heading: DietPane.emptyHeading,
          body: DietPane.emptyBody,
        ),
        FilledButton(
          key: DietPane.planMondayKey,
          onPressed: () => pushFoodPicker(
            context,
            weekday: 0,
            slot: MealSlot.breakfast,
          ),
          child: const Text(DietPane.planMondayLabel),
        ),
        const SizedBox(height: 8),
        GhostButton(
          buttonKey: DietPane.setTargetKey,
          label: DietPane.setTargetLabel,
          onTap: () => pushProteinTargetScreen(context),
        ),
      ],
    );
  }
}

/// The selected day: this week's strip, its [DietDayCard], its four
/// [DietSlotCard]s and the plan settings. Every figure comes from
/// [dietDayProvider], computed on read (R24); a write through the serving
/// sheet, a tick or a new target moves them with no refresh.
class _DietDayView extends ConsumerWidget {
  const _DietDayView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(planTodayProvider);
    final selected = ref.watch(dietSelectedDayProvider);
    final day = ref.watch(dietDayProvider(selected));
    final week = ref.watch(dietWeekProvider);
    final weekday = selected.weekday - 1;
    final hasTarget = day.targetG != null;

    return Column(
      key: DietPane.dayViewKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 4),
        DietWeekStrip(
          monday: startOfWeek(today),
          today: today,
          selected: selected,
          onSelected: ref.read(dietSelectedDayProvider.notifier).select,
          meters: hasTarget
              ? <Widget>[
                  for (final d in week) WeekDayMeter(fraction: d.meter ?? 0),
                ]
              : null,
        ),
        DietDayCard(
          day: day,
          // A future day has nothing eaten to count (R18, R19).
          subLines: <String>[
            if (day.tickable && day.eatenG > 0)
              DietDayCard.eatenLine(day.eatenG),
          ],
          footer: hasTarget
              ? DietTargetBar(day: day)
              : DietTextLink(
                  key: DietDayCard.setTargetKey,
                  label: DietPane.setTargetLabel,
                  onTap: () => pushProteinTargetScreen(context),
                ),
        ),
        if (day.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
            child: Text(
              DietPane.nothingPlannedFor(weekday),
              style: _metaStyle,
            ),
          ),
        for (final slot in day.slots)
          DietSlotCard(
            slotDay: slot,
            weekday: weekday,
            headerTrailing: slot.canTick
                ? DietEatenTick(
                    key: DietSlotCard.tickKey(slot.slot),
                    slot: slot.slot,
                    ticked: slot.ticked,
                    onTap: () => ref
                        .read(mealTicksProvider.notifier)
                        .toggle(day.date, slot.slot),
                  )
                : null,
            headerSubtitle: _reminderTime(context, ref, slot.slot),
          ),
        const _PlanSettings(),
      ],
    );
  }
}

/// The slot header's reminder time, only while the master switch and that
/// slot's reminder are on (A7), and only where notifications work.
String? _reminderTime(BuildContext context, WidgetRef ref, MealSlot slot) {
  if (!ref.watch(reminderSchedulerProvider).isSupported) return null;
  final prefs = ref.watch(reminderPrefsProvider);
  final reminder = prefs.slot(slot);
  if (!prefs.dietOn || !reminder.on) return null;
  return formatReminderMinute(context, reminder.minute);
}

/// "Plan settings": Diet's controls, in the pane rather than the header
/// (KTD4): the Target row, and Reminders under it (U17).
class _PlanSettings extends ConsumerWidget {
  const _PlanSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(proteinTargetProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Semantics(
            header: true,
            child: const Text(
              DietPane.settingsLabel,
              style: kLandingSectionLabelStyle,
            ),
          ),
        ),
        DietSettingsRow(
          key: DietPane.targetRowKey,
          title: DietPane.targetRowTitle,
          subtitle: DietPane.targetRowSubtitle,
          value: target == null
              ? DietPane.targetNotSet
              : DietPane.targetValue(target),
          onTap: () => pushProteinTargetScreen(context),
        ),
        // No row at all where notifications cannot work (R23).
        if (ref.watch(reminderSchedulerProvider).isSupported)
          DietSettingsRow(
            key: DietPane.remindersRowKey,
            title: DietPane.remindersRowTitle,
            subtitle: DietPane.remindersRowSubtitle,
            value: DietPane.remindersValue(ref.watch(reminderPrefsProvider)),
            onTap: () => pushDietRemindersScreen(context),
          ),
      ],
    );
  }
}

/// `.prow`: a title over a line, the current value, and a chevron. One row
/// per Diet setting (KTD4); U17's Reminders row reuses it.
class DietSettingsRow extends StatelessWidget {
  const DietSettingsRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: '$title, $value. $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
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
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title, style: _rowTitleStyle),
                    const SizedBox(height: 2),
                    Text(subtitle, style: _rowSubtitleStyle),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(value, style: _metaStyle),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppPalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const TextStyle _metaStyle = TextStyle(
  fontSize: 13,
  color: AppPalette.textSecondary,
);

const TextStyle _rowTitleStyle = TextStyle(
  fontSize: 15,
  color: AppPalette.textPrimary,
);

const TextStyle _rowSubtitleStyle = TextStyle(
  fontSize: 12,
  color: AppPalette.textMuted,
);
