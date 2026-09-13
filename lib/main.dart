import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/data/exercise_library.dart';
import 'src/data/shipped_data.dart';
import 'src/theme/app_palette.dart';
import 'src/theme/app_theme.dart';
import 'src/ui/app_screen.dart';

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
      home: const SetupCheckScreen(),
    );
  }
}

/// TEMPORARY. Proves the scaffold wiring: palette, bundled exercise library,
/// taxonomy and body-segment data all load. Delete once the workout tab lands
/// (build order step 4 in CLAUDE.md) -- nothing else imports it, and the data
/// layer it reads from lives in `src/data/`, so deleting this file takes
/// nothing with it.
class SetupCheckScreen extends ConsumerWidget {
  const SetupCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(exerciseLibraryProvider);

    return AppScreen.root(
      title: 'Turtle Lift',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            kScreenGutter, 4, kScreenGutter, kScreenGutter),
        children: [
          const Text(
            'Scaffold only. No screens built yet.',
            style: TextStyle(color: AppPalette.textSecondary),
          ),
          const SizedBox(height: 16),
          _StatCard('Muscle groups', '$kMuscleGroupCount'),
          _StatCard('Sub-muscle groups', '$kSubMuscleGroupCount'),
          _StatCard('Body assets', '$kBodyAssetCount'),
          _StatCard('Body segments', '$kBodySegmentCount'),
          _StatCard(
            'Exercises',
            exercises.when(
              data: (list) => '${list.length}',
              loading: () => '...',
              error: (e, _) => 'failed: $e',
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled count, rendered as a card.
class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: AppPalette.textSecondary)),
            Text(value,
                style: const TextStyle(
                  color: AppPalette.accentStrong,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}
