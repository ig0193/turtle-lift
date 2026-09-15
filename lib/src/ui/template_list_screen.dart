import 'package:flutter/material.dart';

import 'app_screen.dart';
import 'workout_root.dart';

/// The template list, reached from an open workout's header.
///
/// **The landing's own body on a pushed screen.** The list a user picks a
/// workout from should not be two different screens depending on whether one is
/// already running, and the filter and the groups belong to it either way.
class TemplateListScreen extends StatelessWidget {
  const TemplateListScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScreen.pushed(
        title: 'Templates',
        body: WorkoutLandingBody(isPushed: true),
      );
}

/// Pushes the template list.
Future<void> pushTemplateList(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const TemplateListScreen()));
