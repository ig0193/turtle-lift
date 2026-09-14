import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/theme/app_theme.dart';
import 'src/ui/l0_shell.dart';

void main() {
  runApp(const ProviderScope(child: TurtleLiftApp()));
}

class TurtleLiftApp extends StatelessWidget {
  const TurtleLiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Placeholder name -- see CLAUDE.md "Still undecided".
      title: 'Turtle Lift',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Straight into the shell, with no splash route ahead of it. Anything
      // that later pops back to an L0 root should predicate on the shell route
      // rather than `isFirst`: a splash added in front would otherwise become
      // the pop target without a single test noticing.
      home: const L0Shell(),
    );
  }
}
