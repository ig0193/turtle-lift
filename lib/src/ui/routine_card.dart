import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/exercise_index.dart';
import '../data/routine_store.dart';
import '../data/routines.dart';
import '../theme/app_palette.dart';
import 'destructive_confirmation.dart';
import 'routine_builder_screen.dart';
import 'routine_detail_screen.dart';

/// One routine on the Workout landing.
///
/// **The card is the start button, and the whole card is not the tap target.**
/// Starting a workout replaces the tab and can auto-save whatever is already
/// open, so it is a deliberate press on a named control rather than anything a
/// scrolling thumb can trigger. Tapping the card body opens the routine to
/// read; only `Start routine` starts one.
class RoutineCard extends ConsumerWidget {
  const RoutineCard({required this.routine, super.key});

  final Routine routine;

  static Key startKey(String routineId) =>
      ValueKey<String>('routine-start-$routineId');
  static Key menuKey(String routineId) =>
      ValueKey<String>('routine-menu-$routineId');
  static Key cardKey(String routineId) =>
      ValueKey<String>('routine-card-$routineId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(exerciseIndexProvider);
    final names = routine.exercises
        .map((e) => index.byId(e.exerciseId)?.name)
        .whereType<String>()
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: cardKey(routine.id),
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RoutineDetailScreen(routineId: routine.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        routine.name,
                        style: const TextStyle(
                          color: AppPalette.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _RoutineMenu(routine: routine),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  // An empty routine says so rather than rendering a blank
                  // line the user cannot interpret.
                  names.isEmpty ? 'No exercises yet' : names,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppPalette.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: startKey(routine.id),
                  onPressed: routine.isEmpty
                      ? null
                      : () => _start(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.accentStrong,
                    foregroundColor: AppPalette.onAccent,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Start routine'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    // Starting while another workout is open auto-saves it (≥1 completed set)
    // or drops it silently — `00` §9, unchanged by the rebuild.
    await ref
        .read(activeSessionProvider.notifier)
        .startFromRoutine(routine, ref.read(exerciseIndexProvider));
  }
}

class _RoutineMenu extends ConsumerWidget {
  const _RoutineMenu({required this.routine});

  final Routine routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: RoutineCard.menuKey(routine.id),
      icon: const Icon(Icons.more_horiz, color: AppPalette.textSecondary),
      color: AppPalette.surface,
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: 'edit', child: Text('Edit routine')),
        const PopupMenuItem<String>(
            value: 'duplicate', child: Text('Duplicate')),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: AppPalette.danger)),
        ),
      ],
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RoutineBuilderScreen(routineId: routine.id),
              ),
            );
          case 'duplicate':
            await ref.read(routineListProvider.notifier).duplicate(routine);
          case 'delete':
            final confirmed = await confirmDestructive(
              context,
              title: 'Delete ${routine.name}?',
              message: 'The routine and its planned sets are permanently '
                  'removed. Workouts you already logged from it are kept.',
              confirmLabel: 'Delete',
            );
            if (confirmed) {
              await ref.read(routineListProvider.notifier).delete(routine.id);
            }
        }
      },
    );
  }

}
