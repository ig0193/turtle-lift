import 'package:flutter/material.dart';

import 'app_screen.dart';
import 'empty_state.dart';

/// Where the ad-hoc entry lands: search the library, add what you want.
///
/// **A deliberate placeholder.** The real screen searches the 260 shipped
/// exercises and adds them to a session, which is build-order step 4 — and
/// `docs/02-workout-tab-userflow.md` is specific that tapping a result goes
/// straight to set logging rather than to a reference screen, because routing
/// every logging action through detail taxes the majority who already know the
/// lift. None of that is built yet.
///
/// What this commits to now is the one thing the landing depends on: the
/// ad-hoc path has somewhere real to push, on an opaque route so the floating
/// tab bar goes with it.
class ExerciseSearchScreen extends StatelessWidget {
  const ExerciseSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen.pushed(
      title: 'Add exercises',
      body: ListView(
        padding: screenScrollPadding(context),
        children: const <Widget>[
          SizedBox(height: 24),
          // TODO(build order step 4 — workout flow): replace this with the real
          // search over `exerciseLibraryProvider`, where tapping a result goes
          // straight to the set-logging screen.
          Text(
            'Search across the exercise library will live here.',
            style: kEmptyStateBodyStyle,
          ),
        ],
      ),
    );
  }
}
