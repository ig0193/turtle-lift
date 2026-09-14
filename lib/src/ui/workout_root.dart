import 'package:flutter/material.dart';

import 'app_screen.dart';
import 'empty_state.dart';

/// The Workout tab's body. Screen 2 in `prototypes/screens.html`.
///
/// **A body, never a `Scaffold`.** The shell owns the Scaffold and the pinned
/// header (`AppScreen`), so a root that grew its own would nest two of each and
/// swallow the floating tab bar's inset on the way.
///
/// **The scrollable is this widget's, and so is its padding.** A `ListView`
/// with no `padding` quietly absorbs the bottom inset for you; the moment it
/// passes any padding of its own, that automatic behaviour is skipped and the
/// last row slides under the tab bar with nothing failing. So every root passes
/// [screenScrollPadding] — the one rule, applied at the scrollable.
///
/// This is the one root that will grow a second *structural* body: build-order
/// step 4 replaces the landing entirely while a session is open. That is why
/// [build] branches first and lays out second — step 4 fills the other arm
/// instead of unpicking this one.
class WorkoutRoot extends StatelessWidget {
  const WorkoutRoot({super.key, this.hasSession = false});

  /// Placeholder for "a session is open right now".
  ///
  /// A parameter rather than a `const false` so the branch below is real code
  /// rather than something the analyzer folds away. Build-order step 4 swaps it
  /// for a read of the active-session provider; nothing else about this file
  /// has to move.
  final bool hasSession;

  @override
  Widget build(BuildContext context) {
    if (hasSession) {
      // TODO(build order step 4 — workout flow): an in-progress session
      // replaces the landing entirely, with its own header. Add that body
      // here.
      return const SizedBox.shrink();
    }

    return ListView(
      padding: screenScrollPadding(context),
      children: const [
        EmptyState(
          glyph: EmptyStateGlyph.barbell,
          heading: 'Ready when you are',
          body: 'Pick a template for a planned session, or go ad-hoc and add '
              'exercises as you find them.',
        ),
      ],
    );
  }
}
