import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/exercise_index.dart';
import '../data/load_type.dart';
import '../data/routine_store.dart';
import '../data/routines.dart';
import '../data/set_format.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'routine_builder_screen.dart';

/// One routine, read before it is run.
///
/// **No chart.** Hevy's equivalent leads with a volume/reps/duration graph over
/// past runs of the routine; V1 has no charts anywhere, and a "No data yet"
/// placeholder occupying the top third of the screen would be worse than the
/// honest absence of one. The exercise list is what the screen is for.
class RoutineDetailScreen extends ConsumerWidget {
  const RoutineDetailScreen({required this.routineId, super.key});

  final String routineId;

  static const Key startKey = ValueKey<String>('routine-detail-start');
  static const Key editKey = ValueKey<String>('routine-detail-edit');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesProvider);
    final routine =
        routines.where((r) => r.id == routineId).firstOrNull;
    if (routine == null) {
      // Deleted from under this screen — pop rather than render a husk.
      return const AppScreen.pushed(title: 'Routine', body: SizedBox.shrink());
    }
    final index = ref.watch(exerciseIndexProvider);

    return AppScreen.pushed(
      title: routine.name,
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: AppMetrics.gapSnug),
          Text(
            _meta(routine),
            style: const TextStyle(
                color: AppPalette.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: AppMetrics.gapCard),
          FilledButton(
            key: startKey,
            onPressed: routine.isEmpty
                ? null
                : () async {
                    await ref
                        .read(activeSessionProvider.notifier)
                        .startFromRoutine(routine, index);
                    if (context.mounted) Navigator.of(context).pop();
                  },
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.accentStrong,
              foregroundColor: AppPalette.onAccent,
              disabledBackgroundColor: AppPalette.mutedSurface,
              disabledForegroundColor: AppPalette.textMuted,
              minimumSize:
                  const Size.fromHeight(AppMetrics.controlHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppMetrics.radiusControl),
              ),
              textStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            // The one accent on the screen, and the one thing this screen is
            // for. Everything below it is reference.
            child: const Text('Start routine'),
          ),
          const SizedBox(height: AppMetrics.gapSection),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('EXERCISES',
                  style: TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  )),
              TextButton(
                key: editKey,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RoutineBuilderScreen(routineId: routine.id),
                  ),
                ),
                child: const Text('Edit routine',
                    style: TextStyle(color: AppPalette.accentLight)),
              ),
            ],
          ),
          for (final exercise in routine.exercises)
            _ExerciseSummary(exercise: exercise),
          const SizedBox(height: AppMetrics.gapSection),
          if (routine.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'This routine has no exercises yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppPalette.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExerciseSummary extends ConsumerWidget {
  const _ExerciseSummary({required this.exercise});

  final RoutineExercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(exerciseIndexProvider).byId(exercise.exerciseId);
    final type = LoadType.fromName(library?.loadType ?? '') ?? LoadType.weighted;
    final targets = exercise.sets.map((s) => _target(type, s)).toList();
    final named = targets.where((t) => t != '—').toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppMetrics.gap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  library?.name ?? exercise.exerciseId,
                  // Not accent: a name is not a state. See `00` §12.
                  style: const TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2),
                ),
                const SizedBox(height: AppMetrics.gapTight),
                Text(
                  // **One line, not a column of `1  —` rows.** A plan with no
                  // numbers yet says "3 sets"; one with numbers says them.
                  // Numbering rows that hold nothing was a table of nothing.
                  named.isEmpty
                      ? '${targets.length} set${targets.length == 1 ? '' : 's'}'
                      : named.join('  ·  '),
                  style: const TextStyle(
                      color: AppPalette.textSecondary, fontSize: 14),
                ),
                if (exercise.notes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppMetrics.gapTight),
                    child: Text(exercise.notes!,
                        style: const TextStyle(
                            color: AppPalette.textMuted, fontSize: 13)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A planned set with no numbers reads as `—`, not as `0kg × 0`: the routine
  /// is saying "do a set here", not "lift nothing".
  static String _target(LoadType type, RoutineSet set) {
    switch (type) {
      case LoadType.timed:
        return set.targetDurationSec == null
            ? '—'
            : formatDuration(set.targetDurationSec!);
      case LoadType.bodyweight:
        return set.targetReps == null ? '—' : '${set.targetReps} reps';
      case LoadType.weighted:
      case LoadType.assisted:
        if (set.targetWeightKg == null && set.targetReps == null) return '—';
        final weight = set.targetWeightKg == null
            ? ''
            : '${formatWeight(set.targetWeightKg)}kg';
        final reps = set.targetReps == null ? '' : ' × ${set.targetReps}';
        return '$weight$reps'.trim();
    }
  }
}


/// `4 exercises · 12 sets`, under the routine's name.
String _meta(Routine routine) {
  if (routine.isEmpty) return 'No exercises yet';
  final exercises = routine.exercises.length;
  final sets =
      routine.exercises.fold<int>(0, (total, e) => total + e.sets.length);
  return '$exercises exercise${exercises == 1 ? '' : 's'}'
      ' · $sets set${sets == 1 ? '' : 's'}';
}
