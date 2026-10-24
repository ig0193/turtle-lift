import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/history_preview_data.dart';
import '../theme/app_typography.dart';
import 'all_sessions_screen.dart';
import 'app_screen.dart';
import 'empty_state.dart';
import 'ghost_button.dart';
import 'history_calendar_card.dart';
import 'history_session_row.dart';

/// The History tab's body: a calendar, then the recent trail.
///
/// **Two complementary views over the same sessions, not two features.** The
/// calendar ([HistoryCalendarCard]) answers "did I train on a given day" and
/// "how spread out was last month" at a glance; the Recent list answers "what
/// did I just do" without any navigation at all. Both are read straight off
/// [historySessionsNewestFirstProvider] -- there is nothing calendar-specific
/// stored anywhere, so editing or deleting a session updates both for free.
///
/// **This replaces the root's previous shape**, which rendered every session,
/// newest first, grouped by month, with no bound. That full list still exists
/// -- it moved to [AllSessionsScreen], reached from the "See all" button below
/// Recent -- rather than disappearing, because an unbounded trail and a
/// calendar both competing for the root's scroll was the thing actually worth
/// fixing, not the trail itself.
///
/// **Still no stats block.** `docs/adr/0003-l0-navigation-variant-a.md`'s split
/// -- derived lives on the tab, authored lives behind the avatar -- is
/// unaffected by this change: a calendar is still a view over session rows,
/// not a new figure.
///
/// **A body, never a `Scaffold`** -- the shell supplies that and the pinned
/// header. The scrollable's padding is [screenScrollPadding], always.
class HistoryRoot extends ConsumerWidget {
  const HistoryRoot({super.key});

  /// How many of the newest sessions the Recent list shows before handing off
  /// to [AllSessionsScreen]. Short enough to read without scrolling past the
  /// calendar every time; long enough to cover a typical week at the app's own
  /// Push/Pull/Legs cadence without immediately hitting "See all".
  static const int recentCount = 6;

  /// Finds one row in the Recent list.
  @visibleForTesting
  static Key recentRowKey(String sessionId) =>
      ValueKey<String>('history-recent-$sessionId');

  /// Finds the "See all N sessions" button.
  @visibleForTesting
  static const Key seeAllKey = ValueKey<String>('history-see-all');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historySessionsNewestFirstProvider);

    if (sessions.isEmpty) {
      return ListView(
        padding: screenScrollPadding(context),
        children: const <Widget>[
          EmptyState(
            glyph: EmptyStateGlyph.logbook,
            heading: 'No workouts yet',
            body: "Finish your first session and it'll show up here.",
          ),
        ],
      );
    }

    final figures = ref.watch(historyProjectionProvider);
    final recent = sessions.take(recentCount).toList(growable: false);

    return ListView(
      padding: screenScrollPadding(context),
      children: <Widget>[
        const HistoryCalendarCard(),
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
        const SizedBox(height: 14),
        GhostButton(
          buttonKey: seeAllKey,
          label: 'See all ${sessions.length} '
              '${sessions.length == 1 ? 'session' : 'sessions'} ›',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AllSessionsScreen()),
          ),
        ),
      ],
    );
  }
}
