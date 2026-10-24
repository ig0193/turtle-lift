import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/history_preview_data.dart';
import 'app_screen.dart';
import 'empty_state.dart';
import 'history_session_row.dart';

/// The full chronological history, newest first, grouped by month.
///
/// **Reached from [HistoryRoot]'s "See all N sessions" button, never a tab
/// root.** The tab root used to render exactly this list; splitting it off a
/// calendar card and a short Recent section onto the root left a plain
/// unbounded trail with nowhere to live, so it became its own pushed screen
/// rather than an ever-growing `ListView` sitting below a calendar the user has
/// to scroll past every time.
///
/// **No stats block here either, for the same reason [HistoryRoot] carries
/// none.** `docs/adr/0003-l0-navigation-variant-a.md`'s split -- derived lives
/// on the tab, authored lives behind the avatar -- is about where a *figure*
/// lives, not about which screen under the tab renders it; this is still the
/// History tab's own territory, just one push deeper.
class AllSessionsScreen extends ConsumerWidget {
  const AllSessionsScreen({super.key});

  /// Finds one session's row.
  @visibleForTesting
  static Key rowKey(String sessionId) => ValueKey<String>('all-sessions-$sessionId');

  /// Finds a month heading.
  @visibleForTesting
  static Key monthKey(String label) => ValueKey<String>('all-sessions-month-$label');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historySessionsNewestFirstProvider);
    final figures = ref.watch(historyProjectionProvider);

    return AppScreen.pushed(
      title: 'All workouts',
      body: sessions.isEmpty
          ? ListView(
              padding: screenScrollPadding(context),
              children: const <Widget>[
                EmptyState(
                  glyph: EmptyStateGlyph.logbook,
                  heading: 'No workouts yet',
                  body: "Finish your first session and it'll show up here.",
                ),
              ],
            )
          : _buildList(context, sessions, figures),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<HistorySession> sessions,
    Map<String, HistoryRowFigures> figures,
  ) {
    // Month headings are computed while walking the list rather than by
    // grouping first: the list is already in the order it renders, and a
    // grouped map would have to be flattened back into it.
    final children = <Widget>[];
    String? lastMonth;

    for (final session in sessions) {
      final month = monthYearLabel(session.performedOn);
      if (month != lastMonth) {
        children.add(HistoryMonthLabel(
          key: monthKey(month),
          label: month,
          first: lastMonth == null,
        ));
        lastMonth = month;
      }
      children.add(
        HistorySessionRow(
          key: rowKey(session.id),
          session: session,
          figures: figures[session.id]!,
        ),
      );
    }

    return ListView(
      padding: screenScrollPadding(context),
      children: children,
    );
  }
}
