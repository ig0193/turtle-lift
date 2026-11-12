import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/diet_reminders.dart';
import '../data/notification_permission.dart';
import '../data/meal_slot.dart';
import '../data/reminder_prefs.dart';
import '../data/reminder_scheduler.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart' show kLandingSectionLabelStyle;
import 'app_screen.dart';
import 'reminder_controls.dart';

/// Pushes the [DietRemindersScreen] onto the stack.
Future<void> pushDietRemindersScreen(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DietRemindersScreen()),
    );

/// "Meal reminders": Diet's opt-in notifications (U17, R21, ADR 0007).
///
/// * **A master switch, a morning summary and one row per meal slot**, each
///   with a time (A7 defaults from [ReminderPreferences.defaults]). The
///   master switch silences the others without forgetting them; while it is
///   off they are disabled and say why.
/// * **Opt-in through [optInToReminders]**: the explain-first sheet before
///   any system prompt (A9). A refusal leaves the master off with
///   [kNotificationsOffCopy]; so does permission revoked later in system
///   Settings, re-read on mount and on resume, as Schedule does.
/// * **The screen schedules nothing itself.** It stores preferences;
///   `dietReminderSyncProvider` rebuilds the pending notifications from the
///   plan and these switches.
class DietRemindersScreen extends ConsumerStatefulWidget {
  const DietRemindersScreen({super.key});

  static const String title = 'Meal reminders';

  static const String masterTitle = 'Remind me';

  static const String masterSubtitle = 'Notifications built from your plan';

  static const String summaryTitle = 'Morning summary';

  static const String summarySubtitle = "Today's plan in one notification";

  static const String slotSubtitle = 'Only on days with food planned';

  /// Beside every child row while the master switch is off.
  static const String disabledReason = 'Turn on reminders to set times';

  static const String timesLabel = 'Times';

  static const String explainTitle = 'Remind you about your plan?';

  /// The explain-first sheet's body: what will be sent, and what never will.
  static const String explainBody =
      "TurtleLift will send a morning summary of the day's plan and a note at "
      'each meal time you turn on, only for meals with food planned. Nothing '
      'about what you ate. You can turn them off any time.';

  @visibleForTesting
  static const Key masterKey = ValueKey<String>('diet-reminders-master');

  @visibleForTesting
  static const Key summarySwitchKey =
      ValueKey<String>('diet-reminders-summary');

  @visibleForTesting
  static const Key summaryTimeKey =
      ValueKey<String>('diet-reminders-summary-time');

  @visibleForTesting
  static Key slotSwitchKey(MealSlot slot) =>
      ValueKey<String>('diet-reminders-${slot.name}');

  @visibleForTesting
  static Key slotTimeKey(MealSlot slot) =>
      ValueKey<String>('diet-reminders-${slot.name}-time');

  @visibleForTesting
  static const Key allowKey = ValueKey<String>('diet-reminders-allow');

  @visibleForTesting
  static const Key notNowKey = ValueKey<String>('diet-reminders-not-now');

  @override
  ConsumerState<DietRemindersScreen> createState() =>
      _DietRemindersScreenState();
}

class _DietRemindersScreenState extends ConsumerState<DietRemindersScreen> {
  /// What the OS last said about permission; null until first read.
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
    ref.read(notificationPermissionProvider.notifier).set(permitted);
  }

  Future<void> _save(ReminderPreferences next) =>
      ref.read(reminderPrefsProvider.notifier).save(next);

  /// On: the explain-first sheet (unless already permitted), the OS prompt,
  /// then store. Off: store, and the sync cancels both diet ranges.
  Future<void> _toggleMaster(bool showingOn) async {
    final prefs = ref.read(reminderPrefsProvider);
    if (showingOn) {
      await _save(prefs.copyWith(dietOn: false));
      return;
    }
    final result = await optInToReminders(
      context,
      scheduler: ref.read(reminderSchedulerProvider),
      title: DietRemindersScreen.explainTitle,
      body: DietRemindersScreen.explainBody,
      allowKey: DietRemindersScreen.allowKey,
      notNowKey: DietRemindersScreen.notNowKey,
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
        if (prefs.dietOn) {
          // Stored on all along (permission was revoked, now back): nothing
          // changes in the preferences, so ask for the reschedule directly.
          ref.invalidate(dietRemindersProvider);
        } else {
          await _save(prefs.copyWith(dietOn: true));
        }
    }
  }

  Future<void> _pickTime(
      int current, ReminderPreferences Function(int minute) apply) async {
    final minute = await pickReminderMinute(context, current);
    if (minute == null || !mounted) return;
    await _save(apply(minute));
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(reminderPrefsProvider);
    final revoked = prefs.dietOn && _permitted == false;
    final masterOn = prefs.dietOn && !revoked;
    // The disabled reason is said once, under the heading, not on every row
    // (profile audit B8).
    String subtitle(String own) => own;

    return AppScreen.pushed(
      title: DietRemindersScreen.title,
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 4),
          SwitchRow(
            switchKey: DietRemindersScreen.masterKey,
            title: DietRemindersScreen.masterTitle,
            subtitle: DietRemindersScreen.masterSubtitle,
            value: masterOn,
            onTap: () => _toggleMaster(masterOn),
          ),
          if (_refused || revoked) const NotificationsOffNote(),
          const _Label(DietRemindersScreen.timesLabel),
          if (!masterOn)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
              child: Semantics(
                container: true,
                child: const Text(
                  DietRemindersScreen.disabledReason,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppPalette.textSecondary,
                  ),
                ),
              ),
            ),
          SwitchRow(
            switchKey: DietRemindersScreen.summarySwitchKey,
            title: DietRemindersScreen.summaryTitle,
            subtitle: subtitle(DietRemindersScreen.summarySubtitle),
            value: prefs.summaryOn,
            onTap: masterOn
                ? () => _save(prefs.copyWith(summaryOn: !prefs.summaryOn))
                : null,
          ),
          TimeRow(
            key: DietRemindersScreen.summaryTimeKey,
            label: '${DietRemindersScreen.summaryTitle} time',
            time: formatReminderMinute(context, prefs.summaryMinute),
            onTap: masterOn
                ? () => _pickTime(prefs.summaryMinute,
                    (m) => ref.read(reminderPrefsProvider).copyWith(
                          summaryMinute: m,
                        ))
                : null,
          ),
          for (final slot in MealSlot.values) ...<Widget>[
            const SizedBox(height: 12),
            SwitchRow(
              switchKey: DietRemindersScreen.slotSwitchKey(slot),
              title: slot.label,
              subtitle: subtitle(DietRemindersScreen.slotSubtitle),
              value: prefs.slot(slot).on,
              onTap: masterOn
                  ? () => _save(prefs.withSlot(
                      slot, prefs.slot(slot).copyWith(on: !prefs.slot(slot).on)))
                  : null,
            ),
            TimeRow(
              key: DietRemindersScreen.slotTimeKey(slot),
              label: '${slot.label} time',
              time: formatReminderMinute(context, prefs.slot(slot).minute),
              onTap: masterOn
                  ? () => _pickTime(prefs.slot(slot).minute, (m) {
                        final now = ref.read(reminderPrefsProvider);
                        return now.withSlot(
                            slot, now.slot(slot).copyWith(minute: m));
                      })
                  : null,
            ),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 16, 2, 0),
            child: Text(
              "Reminders follow this week's plan and repeat every week. A "
              'meal with nothing planned sends nothing.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppPalette.textMuted,
              ),
            ),
          ),
        ],
      ),
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
