import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/diet_derived.dart';
import '../data/diet_log.dart';
import '../data/food_index.dart';
import '../data/meal_slot.dart';
import '../data/local_date.dart';
import '../data/notification_permission.dart';
import '../data/reminder_prefs.dart';
import '../data/reminder_scheduler.dart' show reminderSchedulerProvider;
import '../data/today.dart' show planTodayProvider, startOfWeek;
import '../theme/app_palette.dart';
import '../theme/app_typography.dart' show kLandingSectionLabelStyle;
import 'diet_day_card.dart';
import 'diet_reminders_screen.dart';
import 'diet_slot_card.dart';
import 'empty_state.dart' show kEmptyStateBodyStyle;
import 'protein_target_screen.dart';
import 'reminder_controls.dart' show formatReminderMinute;
import 'week_day_meter.dart' show WeekDayMeter, kWeekdayLong;

/// The day the Diet pane shows. **In memory, never stored**, and today by
/// default.
///
/// It is rebuilt from [planTodayProvider], so when a resume finds a new date
/// (KTD13) the selection snaps to the new today rather than leaving the user
/// on a day that is now "yesterday". A resume on the same date changes
/// nothing downstream ([LocalDate] compares by value), so a picked day
/// survives it. A diet reminder tap selects today through [showDietDay].
class DietSelectedDay extends Notifier<LocalDate> {
  @override
  LocalDate build() => ref.watch(planTodayProvider);

  void select(LocalDate date) => state = date;
}

final dietSelectedDayProvider =
    NotifierProvider<DietSelectedDay, LocalDate>(DietSelectedDay.new);

/// How far back the strip can be slid, in days. Ten years, as the date
/// picker's own swipe range (`DietCalendarSheet.pastMonths`).
const int kDietStripLookbackDays = 3650;

/// The first of the seven days the week strip shows. **In memory, never
/// stored.**
///
/// It opens on the Monday of this week and moves two ways: the user slides it
/// one day at a time ([shift]), and picking a date jumps it to that date's
/// Monday-to-Sunday week ([showWeekOf]). Like [DietSelectedDay] it rebuilds
/// from [planTodayProvider], so a resume on a new date snaps back to this week.
///
/// **It never slides past this week's Monday.** The strip can show days that
/// have not happened (they are inert), but sliding on into an empty future
/// would be a way to get lost with nothing to find.
class DietStripStart extends Notifier<LocalDate> {
  @override
  LocalDate build() => startOfWeek(ref.watch(planTodayProvider));

  /// Moves the window by [days] (negative is earlier), inside its bounds.
  void shift(int days) {
    final today = ref.read(planTodayProvider);
    final latest = startOfWeek(today);
    final earliest = today.addDays(-kDietStripLookbackDays);
    var next = state.addDays(days);
    if (next > latest) next = latest;
    if (next < earliest) next = earliest;
    state = next;
  }

  /// Shows the Monday-to-Sunday week that contains [date].
  void showWeekOf(LocalDate date) => state = startOfWeek(date);
}

final dietStripStartProvider =
    NotifierProvider<DietStripStart, LocalDate>(DietStripStart.new);

/// Selects [day] and brings its week into the strip. The one way to jump to a
/// day: the date picker and a diet reminder tap both go through it.
void showDietDay(WidgetRef ref, LocalDate day) {
  ref.read(dietSelectedDayProvider.notifier).select(day);
  ref.read(dietStripStartProvider.notifier).showWeekOf(day);
}

/// The Diet tab's pane: a protein log
/// (`docs/adr/0015-diet-is-a-log.md`, layout `prototypes/diet.html`).
///
/// **A pane, not a screen.** [DietRoot] owns the one scroll view and the
/// pinned "Diet" header; this is a child of that `ListView`. Diet's controls
/// live in the pane, never the header (KTD4).
///
/// Two states, checked in order:
///
/// 1. **Food list unavailable** (R26): plain copy, no button. Nothing a user
///    taps can bring a missing asset back, and every other tab keeps working.
/// 2. **The day**, always, however empty the log is: the week strip (today
///    selected, a meter per day once a target is set), the selected day's
///    card, its four slot cards, and the "Settings" rows. There is no
///    first-time state to get past: the empty day already says what to do.
///    Every figure comes from [dietDayProvider], computed on read (R24).
class DietPane extends ConsumerWidget {
  const DietPane({super.key});

  static const String unavailableCopy =
      'Food list unavailable. Reinstall the app to restore it.';

  static const String setTargetLabel = 'Set a daily target';

  static const String settingsLabel = 'Settings';

  static const String targetRowTitle = 'Target';

  static const String targetRowSubtitle =
      'Daily protein, measured against what you log';

  static const String targetNotSet = 'Not set';

  /// "120 g a day".
  static String targetValue(int grams) => '$grams g a day';

  static const String remindersRowTitle = 'Reminders';

  static const String remindersRowSubtitle = 'A nudge to log each meal';

  /// "Off", "On" (master on, nothing chosen) or "4 a day".
  ///
  /// Never "on" when nothing will fire (profile audit B7, ADR 0014): "None
  /// chosen" with the master on but no reminder picked, and "Off in Settings"
  /// when the OS refuses notifications. [permitted] null (not read yet)
  /// counts as allowed, so the row does not flash a warning on open.
  static String remindersValue(ReminderPreferences prefs, {bool? permitted}) {
    if (!prefs.dietOn) return 'Off';
    if (permitted == false) return 'Off in Settings';
    final count = MealSlot.values.where((s) => prefs.slot(s).on).length;
    return count == 0 ? 'None chosen' : '$count a day';
  }

  /// "Nothing logged for Thursday", above four empty slots.
  static String nothingLoggedFor(int weekday) =>
      'Nothing logged for ${kWeekdayLong[weekday]}';

  @visibleForTesting
  static const Key unavailableKey = ValueKey<String>('diet-unavailable');

  @visibleForTesting
  static const Key dayViewKey = ValueKey<String>('diet-day-view');

  /// The in-pane Target row (KTD4).
  @visibleForTesting
  static const Key targetRowKey = ValueKey<String>('diet-target-row');

  /// The in-pane Reminders row, under Target (U17). Absent where
  /// notifications are unsupported (R23).
  @visibleForTesting
  static const Key remindersRowKey = ValueKey<String>('diet-reminders-row');

  /// A day on the week strip: the [position]th of its seven, 0 = the first.
  /// On the strip's opening week that is the weekday, 0 = Monday.
  @visibleForTesting
  static Key weekDayKey(int position) => DietWeekStrip.dayKey(position);


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

    return const _DietDayView();
  }
}

/// The selected day: this week's strip, its [DietDayCard], its four
/// [DietSlotCard]s and the settings. Every figure comes from
/// [dietDayProvider], computed on read (R24); a write through the serving
/// sheet or a new target moves them with no refresh.
class _DietDayView extends ConsumerWidget {
  const _DietDayView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(planTodayProvider);
    final selected = ref.watch(dietSelectedDayProvider);
    final stripStart = ref.watch(dietStripStartProvider);
    final day = ref.watch(dietDayProvider(selected));
    final strip = ref.watch(dietStripProvider(stripStart));
    final weekday = selected.weekday - 1;
    final hasTarget = day.targetG != null;

    return Column(
      key: DietPane.dayViewKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 4),
        DietWeekStrip(
          start: stripStart,
          today: today,
          selected: selected,
          onSelected: ref.read(dietSelectedDayProvider.notifier).select,
          onShift: ref.read(dietStripStartProvider.notifier).shift,
          meters: hasTarget
              ? <Widget>[
                  for (final d in strip) WeekDayMeter(fraction: d.meter ?? 0),
                ]
              : null,
        ),
        DietDayCard(
          day: day,
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
              DietPane.nothingLoggedFor(weekday),
              style: _metaStyle,
            ),
          ),
        for (final slot in day.slots)
          DietSlotCard(
            slotDay: slot,
            date: day.date,
            headerSubtitle: _reminderTime(context, ref, slot.slot),
          ),
        const _DietSettings(),
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
  // No time on the card when the OS will not deliver it (B7).
  if (ref.watch(notificationPermissionProvider) == false) return null;
  return formatReminderMinute(context, reminder.minute);
}

/// "Settings": Diet's controls, in the pane rather than the header (KTD4):
/// the Target row, and Reminders under it.
class _DietSettings extends ConsumerWidget {
  const _DietSettings();

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
            value: DietPane.remindersValue(
              ref.watch(reminderPrefsProvider),
              permitted: ref.watch(notificationPermissionProvider),
            ),
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
