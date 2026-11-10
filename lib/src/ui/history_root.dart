import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/history_preview_data.dart';
import '../data/date_labels.dart';
import '../data/history_stats.dart';
import '../data/local_date.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'all_sessions_screen.dart';
import 'app_screen.dart';
import 'empty_state.dart';
import 'ghost_button.dart';
import 'history_calendar_card.dart';
import 'history_session_row.dart';
import 'session_entry.dart' show startBackfill;
import 'tab_index.dart';
import 'tab_routes.dart' show kWorkoutTabIndex;

/// The History tab's body: the stats line, a calendar, then the recent trail.
///
/// **The stats line is `docs/00` §11's**: streak, total workouts, total sets,
/// with the streak's explainer one tap away (`docs/04` copy). They are
/// derived, so they live on this tab (ADR 0003's split); `00` §11 wins over
/// the old "no stats block" note here, decided in ADR 0013. **Never the
/// current week**: that is the Workout landing's (ADR 0008). The calendar
/// totals the month it shows instead.
///
/// **Two complementary views over the same sessions.** The calendar
/// ([HistoryCalendarCard]) answers "did I train on a given day"; the Recent
/// list answers "what did I just do". Both read
/// [historySessionsNewestFirstProvider], so an edit or delete updates both.
///
/// **A body, never a `Scaffold`** -- the shell supplies that and the pinned
/// header. The scrollable's padding is [screenScrollPadding], always.
class HistoryRoot extends ConsumerWidget {
  const HistoryRoot({super.key});

  /// How many of the newest sessions the Recent list shows before handing off
  /// to [AllSessionsScreen].
  static const int recentCount = 6;

  /// Finds one row in the Recent list.
  @visibleForTesting
  static Key recentRowKey(String sessionId) =>
      ValueKey<String>('history-recent-$sessionId');

  /// Finds the "See all N workouts" button.
  @visibleForTesting
  static const Key seeAllKey = ValueKey<String>('history-see-all');

  /// The stats line.
  @visibleForTesting
  static const Key statsKey = ValueKey<String>('history-stats');

  /// Opens the streak explainer.
  @visibleForTesting
  static const Key streakInfoKey = ValueKey<String>('history-streak-info');

  /// The empty state's Start a workout.
  @visibleForTesting
  static const Key startWorkoutKey = ValueKey<String>('history-start-workout');

  /// The backfill offer's confirm button.
  @visibleForTesting
  static const Key backfillConfirmKey = ValueKey<String>('history-backfill');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historySessionsNewestFirstProvider);

    if (sessions.isEmpty) {
      return ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const EmptyState(
            glyph: EmptyStateGlyph.logbook,
            heading: 'No workouts yet',
            body: "Finish your first workout and it'll show up here.",
          ),
          // A way out of the dead end (audit #18): the place workouts start.
          GhostButton(
            buttonKey: startWorkoutKey,
            label: 'Start a workout',
            trailingIcon: Icons.chevron_right_rounded,
            onTap: () =>
                ref.read(tabIndexProvider.notifier).select(kWorkoutTabIndex),
          ),
        ],
      );
    }

    final figures = ref.watch(historyProjectionProvider);
    final stats = ref.watch(historyStatsProvider);
    final recent = sessions.take(recentCount).toList(growable: false);

    return ListView(
      padding: screenScrollPadding(context),
      children: <Widget>[
        _StatsLine(stats: stats),
        HistoryCalendarCard(
          onLogPastDay: (day) => _offerBackfill(context, ref, day),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Semantics(
            header: true,
            child: const Text('Recent', style: kLandingSectionLabelStyle),
          ),
        ),
        for (final session in recent)
          HistorySessionRow(
            key: recentRowKey(session.id),
            session: session,
            figures: figures[session.id]!,
          ),
        // Only when something is behind it (B14), and in the word the screen
        // it opens uses: "workouts", never "sessions" (B13).
        if (sessions.length > recentCount) ...<Widget>[
          const SizedBox(height: 14),
          GhostButton(
            buttonKey: seeAllKey,
            label: 'See all ${sessions.length} workouts',
            trailingIcon: Icons.chevron_right_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AllSessionsScreen()),
            ),
          ),
        ],
      ],
    );
  }
}

/// Streak, workouts, sets: three figures in one quiet row.
class _StatsLine extends StatelessWidget {
  const _StatsLine({required this.stats});

  final HistoryStats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Semantics(
      key: HistoryRoot.statsKey,
      container: true,
      label: '${s.streak} day streak, '
          '${s.workouts} workout${s.workouts == 1 ? '' : 's'}, '
          '${s.sets} set${s.sets == 1 ? '' : 's'}',
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ExcludeSemantics(
                child: _Figure(value: '${s.streak}', label: 'Day streak'),
              ),
            ),
            Expanded(
              child: ExcludeSemantics(
                child: _Figure(value: '${s.workouts}', label: 'Workouts'),
              ),
            ),
            Expanded(
              child: ExcludeSemantics(
                child: _Figure(value: '${s.sets}', label: 'Sets'),
              ),
            ),
            Semantics(
              container: true,
              button: true,
              label: 'How your streak works',
              onTap: () => _explainStreak(context),
              excludeSemantics: true,
              child: GestureDetector(
                key: HistoryRoot.streakInfoKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => _explainStreak(context),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.info_outline,
                      size: 18, color: AppPalette.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppPalette.textPrimary,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppPalette.textMuted),
          ),
        ],
      );
}

/// Backfill (audit #18, ADR 0013): an empty past day on the calendar offers to
/// log a workout for it, then starts the ordinary workout flow dated that
/// day. Asked first, because a tap on a calendar is easy to make by accident.
Future<void> _offerBackfill(
  BuildContext context,
  WidgetRef ref,
  LocalDate day,
) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.border),
      ),
      title: Text(
        'Log a workout for ${weekdayDateLabel(day)}?',
        style: const TextStyle(fontSize: 17, color: AppPalette.textPrimary),
      ),
      content: const Text(
        'It starts on the Workout tab, dated that day. Your streak and records '
        'count it as that day.',
        style: TextStyle(fontSize: 15, color: AppPalette.textSecondary),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel',
              style: TextStyle(color: AppPalette.textSecondary)),
        ),
        TextButton(
          key: HistoryRoot.backfillConfirmKey,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Log a workout',
            style: TextStyle(
              color: AppPalette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  await startBackfill(context, ref, day);
}

/// `docs/04` §Stats: a stat the user cannot predict is a stat that generates
/// angry reviews, so the streak says how it works.
void _explainStreak(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.border),
      ),
      title: const Text(
        'How your streak works',
        style: TextStyle(fontSize: 17, color: AppPalette.textPrimary),
      ),
      content: const Text(
        'Your streak counts the workout days in a row where you never went '
        'more than 3 days without training. Rest days are fine. Miss more '
        'than two in a row and it resets. Any logged workout counts, '
        'including a single quick log.\n\n'
        'Logged a workout for an earlier date? Your streak updates to match. '
        'The line under the calendar days shows where it held.',
        style: TextStyle(fontSize: 15, color: AppPalette.textSecondary),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it',
              style: TextStyle(color: AppPalette.textSecondary)),
        ),
      ],
    ),
  );
}
