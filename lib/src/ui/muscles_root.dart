import 'package:flutter/material.dart';

import 'app_screen.dart';
import 'empty_state.dart';

/// The Muscles tab's body. Screen 3 in `prototypes/screens.html`.
///
/// **This tab has no empty state, and adding one would be a bug.** Its landing
/// is static reference content — a search field and the body map — so there is
/// no "you have not done anything yet" condition for it to be in. A user with
/// zero sessions sees the same screen as a user with three hundred; only the
/// diagram's fills differ. The heading and line below are the reference
/// landing's own copy, held in the same voice as the two roots either side so
/// the three tabs do not read as three different products.
///
/// **A body, never a `Scaffold`**, and the scrollable carries
/// [screenScrollPadding] — a `ListView` that passes its own padding stops
/// absorbing the safe-area inset automatically, and the last row would then
/// hide under the floating tab bar with nothing failing.
class MusclesRoot extends StatelessWidget {
  const MusclesRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: screenScrollPadding(context),
      children: [
        // Left-aligned, unlike an EmptyState: this is the top of a reference
        // screen, not a centred block standing in for missing content. It
        // borrows the empty-state type only so the voice matches.
        Semantics(
          header: true,
          child: const Text(
            'Browse by muscle',
            style: kEmptyStateHeadingStyle,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Search and the body map arrive with the exercise library.',
          style: kEmptyStateBodyStyle,
        ),
      ],
    );
  }
}
