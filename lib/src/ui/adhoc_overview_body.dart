import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'destructive_confirmation.dart';
import 'divider_row.dart';
import 'exercise_search_screen.dart';
import 'session_actions.dart';
import 'session_body_map.dart';
import 'session_date_control.dart';
import 'set_logging_screen.dart';

/// The ad-hoc path's overview: the exercises you have added, in order.
///
/// **A flat list, not a muscle list.** There is no template to derive muscles
/// from, which is the whole difference between the two paths.
class AdHocOverviewBody extends ConsumerWidget {
  const AdHocOverviewBody({required this.onFinished, super.key});

  final void Function(String sessionId) onFinished;

  /// The key a test taps to add another exercise.
  static const Key addExerciseKey = ValueKey<String>('add-exercise');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final index = ref.watch(exerciseIndexProvider);
    if (session == null) return const SizedBox.shrink();

    return ListView(
      padding: screenScrollPadding(context),
      children: <Widget>[
        const SessionDateControl(),
        const SessionBodyMap(),
        const SizedBox(height: 6),
        for (final exercise in session.exercises)
          _AdHocExerciseRow(
            exercise: exercise,
            name: index.byId(exercise.exerciseId)?.name ?? 'Unknown exercise',
          ),
        const SizedBox(height: 12),
        _AddExerciseButton(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ExerciseSearchScreen(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SessionActions(onFinished: onFinished),
      ],
    );
  }
}

/// One added exercise, its logged sets, and where it is up to.
class _AdHocExerciseRow extends ConsumerWidget {
  const _AdHocExerciseRow({required this.exercise, required this.name});

  final SessionExercise exercise;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = progressOf(exercise);
    final sets = formatSetList(exercise);

    return Dismissible(
      key: ValueKey<String>('adhoc-dismiss-${exercise.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmRemoval(context),
      onDismissed: (_) =>
          ref.read(activeSessionProvider.notifier).removeExercise(exercise.id),
      background: const ColoredBox(color: AppPalette.danger),
      child: GestureDetector(
        // The second way to remove it, so the one action a user reaches for
        // one-handed mid-session does not depend on a swipe.
        onLongPress: () async {
          if (!await _confirmRemoval(context)) return;
          if (!context.mounted) return;
          await ref
              .read(activeSessionProvider.notifier)
              .removeExercise(exercise.id);
        },
        child: DividerRow(
          key: adHocRowKey(exercise.exerciseId),
          semanticsLabel: '$name. ${progress.label}',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SetLoggingScreen(sessionExerciseId: exercise.id),
            ),
          ),
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                ),
                _ProgressTag(progress: progress),
              ],
            ),
            if (sets.isNotEmpty) ...<Widget>[
              const SizedBox(height: 3),
              Text(
                sets,
                style: const TextStyle(
                    fontSize: 11.5, color: AppPalette.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Asked only when there is something to lose.
  Future<bool> _confirmRemoval(BuildContext context) async {
    if (exercise.completedSets.isEmpty) return true;
    return confirmDestructive(
      context,
      title: 'Remove $name?',
      message: 'This drops the sets you have logged for it.',
      confirmLabel: 'Remove',
    );
  }
}

class _ProgressTag extends StatelessWidget {
  const _ProgressTag({required this.progress});

  final ExerciseProgress progress;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (progress) {
      ExerciseProgress.done => (AppPalette.accentStrong, AppPalette.onAccent),
      ExerciseProgress.inProgress => (
          AppPalette.mutedSurface,
          AppPalette.accentLight
        ),
      ExerciseProgress.notStarted => (
          AppPalette.mutedSurface,
          AppPalette.textMuted
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        progress.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class _AddExerciseButton extends StatelessWidget {
  const _AddExerciseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Add exercise',
        excludeSemantics: true,
        child: GestureDetector(
          key: AdHocOverviewBody.addExerciseKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppPalette.surface,
              border: Border.all(color: AppPalette.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '+ Add exercise',
              style: TextStyle(fontSize: 14, color: AppPalette.textSecondary),
            ),
          ),
        ),
      );
}

/// The row for [exerciseId], so a test can reach one by name.
Key adHocRowKey(String exerciseId) => ValueKey<String>('adhoc-row-$exerciseId');
