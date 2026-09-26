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
import '../theme/app_typography.dart';
import 'routine_screen.dart';
import 'workout_root.dart';

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


/// The landing's hero: the routine you last trained.
///
/// **One big thing, then quiet ones.** Three equal cards make the reader do the
/// ranking; a screen with a lead and a list has already done it. What earns the
/// lead here is history, not a recommendation — see
/// `WorkoutLandingBody._mostRecentlyTrained`.
class RoutineHeroCard extends ConsumerWidget {
  const RoutineHeroCard({required this.routine, required this.lastDone, super.key});

  final Routine routine;
  final LocalDate? lastDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setCount =
        routine.exercises.fold<int>(0, (total, e) => total + e.sets.length);

    return Material(
      color: AppPalette.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        key: WorkoutLandingBody.heroKey,
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RoutineScreen(routineId: routine.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text('LAST TRAINED',
                        style: kLandingSectionLabelStyle),
                  ),
                  _RoutineMenu(routine: routine),
                ],
              ),
              const SizedBox(height: AppMetrics.gapSnug),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  // The one display numeral on the screen. Opal's move: a
                  // single figure leads, and everything else is checked.
                  Text(
                    '${routine.exercises.length}',
                    style: const TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      height: 0.9,
                      letterSpacing: -2.4,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: AppMetrics.gap),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            routine.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            // The numeral beside this is the exercise count,
                            // so the word after it has to agree with it.
                            '${routine.exercises.length == 1 ? 'exercise' : 'exercises'}'
                            ' · $setCount ${setCount == 1 ? 'set' : 'sets'}'
                            ' · ${recencyLabel(lastDone)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppPalette.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                key: RoutineCard.startKey(routine.id),
                onPressed: routine.isEmpty
                    ? null
                    : () => ref
                        .read(activeSessionProvider.notifier)
                        .startFromRoutine(
                            routine, ref.read(exerciseIndexProvider)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.accentStrong,
                  foregroundColor: AppPalette.onAccent,
                  disabledBackgroundColor: AppPalette.mutedSurface,
                  disabledForegroundColor: AppPalette.textMuted,
                  minimumSize: const Size.fromHeight(AppMetrics.controlHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppMetrics.radiusControl),
                  ),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                child: const Text('Start routine'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A routine below the hero: one line, no accent.
///
/// **The list carries no colour at all.** Six rows each with their own accent
/// pill is six primary actions, which is none. Starting one of these is two
/// taps — open, then Start — and that is the correct cost for a routine you did
/// not last train.
class RoutineListRow extends ConsumerWidget {
  const RoutineListRow({required this.routine, required this.lastDone, super.key});

  final Routine routine;
  final LocalDate? lastDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      key: RoutineCard.cardKey(routine.id),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RoutineScreen(routineId: routine.id),
        ),
      ),
      child: Container(
        constraints:
            const BoxConstraints(minHeight: AppMetrics.touchTarget + 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppPalette.border)),
        ),
        padding: const EdgeInsets.symmetric(vertical: AppMetrics.gap),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    routine.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    routine.isEmpty
                        ? 'No exercises yet'
                        : '${routine.exercises.length}'
                            ' ${routine.exercises.length == 1 ? 'exercise' : 'exercises'}'
                            ' · ${recencyLabel(lastDone)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppPalette.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: AppPalette.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// When a routine was last run. **Recall, never recommendation**: when, never
/// "due", never "time for".
String recencyLabel(LocalDate? date) {
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
