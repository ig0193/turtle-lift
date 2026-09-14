import 'package:flutter/material.dart';

import '../data/workout_templates.dart';
import 'app_screen.dart';
import 'empty_state.dart';

/// Where tapping a template row lands.
///
/// **A deliberate placeholder, and deliberately not a session.** The real
/// overview is build-order step 4, and it is the thing that creates a session
/// — with a `performedOn` date, the auto-save-or-discard rule, and the template
/// lock. None of that exists yet, and building it here would drag in the whole
/// data layer behind a screen that only had to prove a tap goes somewhere.
///
/// So the landing's contract today is navigation: tap a template, arrive at
/// that template. [template] is carried and displayed precisely so that
/// contract is observable rather than assumed.
///
/// An [AppScreen.pushed] on an opaque route, like [ProfileScreen] — that is the
/// mechanism that makes the floating tab bar disappear behind it (see
/// `L0Shell`). A modal sheet here would leave the bar sitting on top.
class WorkoutOverviewScreen extends StatelessWidget {
  const WorkoutOverviewScreen({required this.template, super.key});

  /// The template this session would be started from.
  final WorkoutTemplate template;

  @override
  Widget build(BuildContext context) {
    return AppScreen.pushed(
      title: template.name,
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 24),
          Text(template.name, style: kEmptyStateHeadingStyle),
          const SizedBox(height: 5),
          Text(template.subtitle, style: kEmptyStateBodyStyle),
          const SizedBox(height: 18),
          // TODO(build order step 4 — workout flow): replace this with the real
          // overview — the muscle list, the session date control, and the
          // action that actually starts the session.
          const Text(
            'The muscle list and the rest of this session will live here.',
            style: kEmptyStateBodyStyle,
          ),
        ],
      ),
    );
  }
}
