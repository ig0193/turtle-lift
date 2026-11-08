import 'package:flutter/material.dart';

import '../data/reminder_scheduler.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// The reminder controls Schedule (ADR 0005) and Diet's Reminders screen
/// (ADR 0007) share: a row with a drawn switch, a time row, the explain-first
/// sheet, and [optInToReminders], which puts that sheet in front of the OS
/// prompt.
///
/// **Promoted from `schedule_pane.dart`** so both features read and behave
/// alike. Every string a feature owns (titles, sheet copy) is a parameter;
/// only the copy that must match across features lives here.

/// Shown when the OS will not deliver this app's notifications: after a
/// refused prompt, or when permission was revoked in system Settings.
const String kNotificationsOffCopy =
    'Notifications are off for TurtleLift. Turn them on in Settings.';

const TextStyle kProfileSwitchTitleStyle = TextStyle(
  fontSize: AppTypeScale.body,
  fontWeight: FontWeight.w600,
  color: AppPalette.textPrimary,
);

const TextStyle kProfileSwitchSubtitleStyle = TextStyle(
  fontSize: AppTypeScale.caption,
  color: AppPalette.textMuted,
);

/// A titled row with a [ReminderSwitch] on the right; the whole row is the
/// tap target.
///
/// [onTap] null disables it: dimmed, announced as disabled, and inert. Use
/// [subtitle] to say why ("Turn on reminders to set times").
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    required this.switchKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
    super.key,
  });

  /// Carried by the row's [Semantics], so tests find and tap the row by it.
  final Key switchKey;
  final String title;
  final String subtitle;
  final bool value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      key: switchKey,
      toggled: value,
      enabled: enabled,
      label: '$title. $subtitle',
      excludeSemantics: true,
      onTap: onTap,
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
          // Only the title and switch dim when disabled: the subtitle is the
          // reason, and dimmed it would fall under 4.5:1 (turtle-taste).
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Opacity(
                      opacity: enabled ? 1 : 0.5,
                      child: Text(title, style: kProfileSwitchTitleStyle),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: kProfileSwitchSubtitleStyle),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Opacity(
                opacity: enabled ? 1 : 0.5,
                child: ReminderSwitch(on: value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A drawn switch: Material's `Switch` brings a thumb, track and ripple that
/// exist nowhere in the palette. Visual only; [SwitchRow] owns the tap.
class ReminderSwitch extends StatelessWidget {
  const ReminderSwitch({required this.on, super.key});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      // On the 4pt grid: a 20pt thumb inset 4pt in a 44 x 28 track.
      width: 44,
      height: 28,
      padding: const EdgeInsets.all(4),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? AppPalette.accentStrong : AppPalette.border,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? AppPalette.onAccent : AppPalette.textSecondary,
        ),
      ),
    );
  }
}

/// A labelled reminder time that opens a picker. [onTap] null disables it.
class TimeRow extends StatelessWidget {
  const TimeRow({
    required this.time,
    required this.onTap,
    this.label = 'Time',
    super.key,
  });

  /// Already formatted, see [formatReminderMinute].
  final String time;
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label. $time',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppPalette.border)),
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Row(
              children: <Widget>[
                Expanded(child: Text(label, style: kProfileSwitchTitleStyle)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppPalette.surface,
                    border: Border.all(color: AppPalette.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    time,
                    style: const TextStyle(
                      fontSize: AppTypeScale.body,
                      color: AppPalette.textPrimary,
                      fontFeatures: <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The line under a reminder switch when the OS will not deliver
/// notifications ([kNotificationsOffCopy]).
class NotificationsOffNote extends StatelessWidget {
  const NotificationsOffNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(2, 8, 2, 0),
      child: Text(
        kNotificationsOffCopy,
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: AppPalette.textSecondary,
        ),
      ),
    );
  }
}

/// The explain-first sheet (ADR 0005 §3): what will be sent, before any
/// system prompt. Pops `true` for Allow and `false` for Not now.
class ExplainSheet extends StatelessWidget {
  const ExplainSheet({
    required this.title,
    required this.body,
    this.allowKey,
    this.notNowKey,
    this.allowLabel = 'Allow reminders',
    this.notNowLabel = 'Not now',
    super.key,
  });

  final String title;
  final String body;
  final Key? allowKey;
  final Key? notNowKey;
  final String allowLabel;
  final String notNowLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: AppTypeScale.title,
              fontWeight: FontWeight.w600,
              color: AppPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: allowKey,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(allowLabel),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: notNowKey,
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: AppPalette.textSecondary,
            ),
            child: Text(notNowLabel),
          ),
        ],
      ),
    );
  }
}

/// Shows [ExplainSheet] and returns true only for Allow. Dismissing it is
/// Not now.
Future<bool> showExplainSheet(
  BuildContext context, {
  required String title,
  required String body,
  Key? allowKey,
  Key? notNowKey,
}) async {
  final allowed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppPalette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ExplainSheet(
      title: title,
      body: body,
      allowKey: allowKey,
      notNowKey: notNowKey,
    ),
  );
  return allowed ?? false;
}

/// How [optInToReminders] ended.
enum ReminderOptIn {
  /// Notifications are allowed: store the switch on and schedule.
  granted,

  /// "Not now", or the sheet was dismissed. Nothing was requested; leave the
  /// switch off and say nothing.
  declined,

  /// The user allowed in the sheet but the OS refused (now or earlier).
  /// Leave the switch off and show [NotificationsOffNote].
  denied,
}

/// Turning a reminder on: the explain-first sheet, then the OS prompt
/// (ADR 0005 §3, A9).
///
/// **The sheet shows whenever permission is not already granted.** Nothing is
/// stored to remember that it was seen, so a user who chose Not now, or who
/// was refused, sees it again next time rather than a silent failure. With
/// permission already granted (say, by the other feature) there is nothing to
/// explain before, so no sheet and no prompt. The OS prompt itself appears
/// only while undetermined; the plugin handles that.
Future<ReminderOptIn> optInToReminders(
  BuildContext context, {
  required ReminderScheduler scheduler,
  required String title,
  required String body,
  Key? allowKey,
  Key? notNowKey,
}) async {
  if (await scheduler.hasPermission()) return ReminderOptIn.granted;
  if (!context.mounted) return ReminderOptIn.declined;
  final allowed = await showExplainSheet(
    context,
    title: title,
    body: body,
    allowKey: allowKey,
    notNowKey: notNowKey,
  );
  if (!allowed) return ReminderOptIn.declined;
  return await scheduler.requestPermission()
      ? ReminderOptIn.granted
      : ReminderOptIn.denied;
}

/// [minute] (after local midnight) as the platform shows a time of day.
String formatReminderMinute(BuildContext context, int minute) =>
    TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

/// Opens the time picker at [minute]; returns the chosen minute after local
/// midnight, or null if cancelled.
Future<int?> pickReminderMinute(BuildContext context, int minute) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
  );
  if (picked == null) return null;
  return picked.hour * 60 + picked.minute;
}
