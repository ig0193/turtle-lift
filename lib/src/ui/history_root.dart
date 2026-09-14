import 'package:flutter/material.dart';

import 'app_screen.dart';
import 'empty_state.dart';

/// The History tab's body. Its empty state is the one in screen 4 of
/// `prototypes/screens.html`.
///
/// **A body, never a `Scaffold`** — the shell supplies both that and the pinned
/// header, and a second one here would swallow the tab bar's bottom inset.
///
/// **The scrollable's padding is [screenScrollPadding], always.** A `ListView`
/// that passes any padding of its own no longer absorbs the safe-area inset
/// automatically, so the last row would sit under the floating bar and nothing
/// would fail to say so.
///
/// The disc glyph here is a logbook page, not the clock the History *tab* wears
/// (`TabGlyph.history`). Two different drawings for the same tab is the
/// prototype's decision, kept deliberately — see [EmptyStateGlyph].
class HistoryRoot extends StatelessWidget {
  const HistoryRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: screenScrollPadding(context),
      children: const [
        EmptyState(
          glyph: EmptyStateGlyph.logbook,
          heading: 'No workouts yet',
          body: "Finish your first session and it'll show up here.",
        ),
      ],
    );
  }
}
