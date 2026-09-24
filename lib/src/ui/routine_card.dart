import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/local_date.dart';
import '../data/routine_store.dart';
import '../data/routines.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import 'destructive_confirmation.dart';
import 'routine_screen.dart';

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
    final setCount = routine.exercises
        .fold<int>(0, (total, e) => total + e.sets.length);
    final lastDone = lastPerformedRoutine(
      routine.id,
      ref.watch(savedSessionsProvider),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppMetrics.gap),
      child: Material(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(AppMetrics.radiusCard),
        child: InkWell(
          key: cardKey(routine.id),
          borderRadius: BorderRadius.circular(AppMetrics.radiusCard),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RoutineScreen(routineId: routine.id),
            ),
          ),
          child: Padding(
            padding: AppMetrics.cardPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        routine.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppPalette.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: AppMetrics.gapTight),
                      // **A count, then the names.** The count is the fact a
                      // user scanning six routines actually wants; the names
                      // are the reminder of which one this is. Names alone,
                      // wrapped to two lines, made every card the same height
                      // and none of them scannable.
                      // **Two lines, not one.** Everything on one line lost
                      // its tail to an ellipsis beside the Start pill — and
                      // the tail is the recency, which is the half a user
                      // scanning six routines actually reads.
                      Text(
                        _size(routine, setCount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppPalette.textSecondary,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      if (!routine.isEmpty)
                        Text(
                          _recency(lastDone),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppMetrics.gap),
                _StartButton(
                  buttonKey: startKey(routine.id),
                  onPressed: routine.isEmpty ? null : () => _start(context, ref),
                ),
                _RoutineMenu(routine: routine),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `4 exercises · 12 sets` — how big the routine is.
  ///
  /// **The exercise names came out.** Listed after the counts they truncated
  /// two words in — `21s bar…` — which is not recall, it is noise with an
  /// ellipsis. The routine's own name is what identifies it.
  static String _size(Routine routine, int setCount) {
    if (routine.isEmpty) return 'No exercises yet';
    final exercises =
        '${routine.exercises.length} exercise${routine.exercises.length == 1 ? '' : 's'}';
    final sets =
        setCount == 0 ? '' : ' · $setCount set${setCount == 1 ? '' : 's'}';
    return '$exercises$sets';
  }

  /// When it was last done. **Recall, never recommendation**: when, never
  /// "due", never "time for".
  static String _recency(LocalDate? date) {
    if (date == null) return 'Never done';
    final days = LocalDate.today().daysAfter(date);
    if (days <= 0) return 'Last done today';
    if (days == 1) return 'Last done yesterday';
    if (days < 7) return 'Last done $days days ago';
    if (days < 14) return 'Last done 1 week ago';
    if (days < 31) return 'Last done ${days ~/ 7} weeks ago';
    if (days < 62) return 'Last done 1 month ago';
    return 'Last done ${days ~/ 30} months ago';
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
        const PopupMenuItem<String>(
            value: 'duplicate', child: Text('Duplicate')),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: AppPalette.danger)),
        ),
      ],
      onSelected: (value) async {
        switch (value) {
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


/// The one accent on a routine card, and it is a pill rather than a slab.
///
/// **Two full-width accent buttons made the landing unreadable.** The palette
/// gives `#D85A30` one job — it marks the control that starts a workout — and
/// a list of six routines would have spent it six times, at full bleed, which
/// is the same as spending it nowhere. A pill keeps the meaning and gives it
/// back its weight; the card itself stays tappable for reading the routine.
class _StartButton extends StatelessWidget {
  const _StartButton({required this.buttonKey, required this.onPressed});

  final Key buttonKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Start routine',
      excludeSemantics: true,
      child: SizedBox(
        height: AppMetrics.touchTarget,
        child: Material(
          color: enabled ? AppPalette.accentStrong : AppPalette.mutedSurface,
          borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
          child: InkWell(
            key: buttonKey,
            borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: Text(
                  'Start',
                  style: TextStyle(
                    color:
                        enabled ? AppPalette.onAccent : AppPalette.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
