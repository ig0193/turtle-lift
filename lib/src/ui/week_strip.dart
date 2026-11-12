import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/history_preview_data.dart';
import '../data/local_date.dart';
import '../data/training_plan.dart';
import '../theme/app_palette.dart';
import 'history_session_detail_screen.dart';
import 'history_session_row.dart' show historyDateLabel;
import 'profile_root.dart';
import 'tab_routes.dart';
import 'week_day_chip.dart';

/// This week against the training plan, on the Workout landing
/// (`docs/adr/0008-the-week-lives-on-the-workout-landing.md`).
///
/// **The week is derived and lives beside Start; the plan is typed and lives
/// on Profile.** The strip only reads: tapping it opens Profile › Schedule,
/// where the days and the reminder are edited.
///
/// **It states counts and days, never a verdict and never a workout** (ADR
/// 0005 rules 1 and 5): no "missed", no "behind", no exercise or template name,
/// nothing about what to train. An empty plan day is an empty marker.
class WeekStrip extends ConsumerWidget {
  const WeekStrip({super.key});

  /// The strip, or the quiet line standing in for it.
  static const Key stripKey = ValueKey<String>('week-strip');

  /// The line shown when no training days are set.
  static const String pickDaysLabel = 'Pick training days';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(thisWeekSummaryProvider);
    void open() => showProfileSegment(ref, ProfileSegment.schedule);

    if (week == null) {
      final days = ref.watch(todayPlanWeekdaysProvider);
      final label = days.isEmpty ? pickDaysLabel : planStartsLater(ref);
      return _QuietLine(label: label, onTap: open);
    }

    final caption = weekCaption(week);
    final days = week.planned == 1 ? 'day' : 'days';
    return Semantics(
      container: true,
      button: true,
      label: 'This week: ${week.hit} of ${week.planned} plan $days. $caption. '
          'Edit training days',
      onTap: open,
      excludeSemantics: true,
      child: GestureDetector(
        key: stripKey,
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            border: Border.all(color: AppPalette.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${week.hit} of ${week.planned} this week',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.textPrimary,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              for (final day in week.days)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PlanDot(state: day.state, size: 12),
                      const SizedBox(height: 4),
                      Text(
                        kWeekdayShort[day.weekday],
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppPalette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Short weekday names, Monday first.
const List<String> kWeekdayShort = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

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
  return '${left.length} more to go. Next is ${kWeekdayLong[left.first.weekday]}'
      '$extra';
}

/// Shown when a plan exists but has no day left in this week -- saved on a
/// Saturday for Mondays, say. Saying "pick your training days" there would be
/// wrong: they just did.
String planStartsLater(WidgetRef ref) => planStartsLaterText(
      ref.watch(planTodayProvider),
      ref.watch(trainingPlanLogProvider),
    );

/// [planStartsLater] over plain values, for the home-screen widget's copy.
String planStartsLaterText(LocalDate today, List<TrainingPlanEntry> plan) {
  for (var i = 1; i <= kWeekdayCount; i++) {
    final date = today.addDays(i);
    if (weekdaysInEffectOn(plan, date).contains(date.weekday - 1)) {
      return 'Your first plan day is ${kWeekdayLong[date.weekday - 1]}.';
    }
  }
  return WeekStrip.pickDaysLabel;
}

/// One quiet, tappable line: the strip's stand-in when there is no week to
/// show.
class _QuietLine extends StatelessWidget {
  const _QuietLine({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          key: WeekStrip.stripKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppPalette.textSecondary,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppPalette.textMuted),
              ],
            ),
          ),
        ),
      );
}

/// The newest saved workout as one line, which opens it in History.
///
/// **A pointer to History, not a second stat.** It repeats exactly what that
/// workout's History row says (day, name, sets) and opens the same detail
/// screen, so there is no figure here that History does not own. It never
/// suggests repeating it.
class LastWorkoutLine extends ConsumerWidget {
  const LastWorkoutLine({super.key});

  static const Key lineKey = ValueKey<String>('last-workout');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastWorkoutProvider);
    if (last == null) return const SizedBox.shrink();
    final line = last.line;
    void open() => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: RouteSettings(
              name: HistorySessionDetailScreen.routeNameFor(last.id),
            ),
            builder: (_) => HistorySessionDetailScreen(sessionId: last.id),
          ),
        );

    return Semantics(
      container: true,
      button: true,
      label: 'Last workout: $line',
      onTap: open,
      excludeSemantics: true,
      child: GestureDetector(
        key: lineKey,
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: <Widget>[
              const Text(
                'Last workout',
                style: TextStyle(fontSize: 13, color: AppPalette.textMuted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppPalette.textSecondary,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppPalette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The newest saved workout as "Yesterday · Push day · 14 sets", with its id,
/// or null with no history. Shared by [LastWorkoutLine] and the home-screen
/// widget, so the two can never word it differently.
final lastWorkoutProvider = Provider<({String id, String line})?>((ref) {
  final sessions = ref.watch(historySessionsNewestFirstProvider);
  if (sessions.isEmpty) return null;
  final session = sessions.first;
  final figures = ref.watch(historyProjectionProvider)[session.id];
  if (figures == null) return null;
  final sets = '${figures.setCount} set${figures.setCount == 1 ? '' : 's'}';
  return (
    id: session.id,
    line: '${historyDateLabel(session.performedOn)} · '
        '${resolvedTitle(session, figures)} · $sets',
  );
});

