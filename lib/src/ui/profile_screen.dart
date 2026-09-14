import 'package:flutter/material.dart';

import 'app_screen.dart';
import 'empty_state.dart';

/// The destination behind the L0 header avatar.
///
/// **A deliberate placeholder.** Profile is build-order step 7 in `CLAUDE.md`;
/// what it holds — units, body-diagram sex, the data export, the delete-all
/// escape hatch — is out of scope for the navigation shell. What this file
/// commits to now is only the two things the shell depends on: that the avatar
/// has somewhere real to push, and that the thing it pushes is an
/// [AppScreen.pushed] on an **opaque** route, which is the whole mechanism by
/// which the tab bar disappears (see `L0Shell`). Swapping it for a modal sheet
/// later would leave the bar sitting under it.
///
/// The body is a scrollable carrying [screenScrollPadding], like every other
/// screen, so the one bottom-inset rule holds here too — a pushed screen picks
/// up the home indicator on that edge even with no tab bar in sight.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen.pushed(
      title: 'Profile',
      body: ListView(
        padding: screenScrollPadding(context),
        children: const [
          SizedBox(height: 24),
          // TODO(build order step 7 — profile tab): replace this line with the
          // real profile content (units, diagram sex, export, delete all).
          // Screen 4 in `prototypes/screens.html`.
          Text(
            'Units, body diagram and your data will live here.',
            style: kEmptyStateBodyStyle,
          ),
        ],
      ),
    );
  }
}
