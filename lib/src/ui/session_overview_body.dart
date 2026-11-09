import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/load_type.dart';
import '../data/session_progress.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'destructive_confirmation.dart';
import 'divider_row.dart';
import 'exercise_picker_sheet.dart' show showExercisePicker;
import 'ghost_button.dart';
import 'motion.dart';
import 'session_actions.dart';
import 'session_body_map.dart';
import 'session_date_control.dart';
import 'session_entry.dart';
import 'template_editor_screen.dart' show RowIconAction;
import 'template_row.dart' show kLandingSectionLabelStyle;

/// The workout in progress: the map, and the exercises still to log.
///
/// **One screen for both paths.** A template run is a session that started with
/// a list and an ad-hoc one is a session that starts with none, so there is
/// nothing left for two overviews to disagree about
/// (`docs/adr/0006-workout-tab-is-exercise-first.md`).
///
/// **It has two views, and the switch is the start of logging.** Until the user
/// taps Start logging (or writes anything) the screen is a *ready* view: the map
/// at full size and one button. After it, the live strip appears and the list
/// takes over under a smaller map. The ready view exists so that starting a
/// workout is a moment you can feel, rather than one list replacing another —
/// and so the list, which is the reference the user returns to between sets,
/// never competes with the button that begins the workout.
///
/// **The map is the hero and the list sits under it.** Which exercise is next is
/// the first thing under the map, so the one action a user wants between sets is
/// where their thumb already is.
class SessionOverviewBody extends ConsumerStatefulWidget {
  const SessionOverviewBody({required this.onFinished, super.key});

  final void Function(String sessionId) onFinished;

  /// The key a test taps to add another exercise.
  static const Key addExerciseKey = ValueKey<String>('add-exercise');

  /// The key a test taps to begin logging from the ready view.
  static const Key startLoggingKey = ValueKey<String>('start-logging');

  /// The ready view's list of planned exercises.
  static const Key plannedListKey = ValueKey<String>('planned-list');

  /// The label over the list.
  @visibleForTesting
  static const String keepLoggingLabel = 'Keep logging';

  /// The toggle that turns the list into its reorder / remove mode.
  static const Key editListKey = ValueKey<String>('session-edit-list');

  @override
  ConsumerState<SessionOverviewBody> createState() =>
      _SessionOverviewBodyState();
}

class _SessionOverviewBodyState extends ConsumerState<SessionOverviewBody> {
  /// Whether the list shows move and remove controls. In memory only.
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final onFinished = widget.onFinished;
    final session = ref.watch(activeSessionProvider);
    final started = ref.watch(loggingStartedProvider);
    final index = ref.watch(exerciseIndexProvider);
    if (session == null) return const SizedBox.shrink();

    final isStarted = hasLoggingStarted(session, started);
    final done =
        session.exercises.where((e) => progressOf(e) == ExerciseProgress.done);

    return ListView(
      padding: screenScrollPadding(context),
      children: <Widget>[
        if (isStarted) const LiveStrip(),
        Row(
          children: <Widget>[
            const Expanded(child: SessionDateControl()),
            if (isStarted)
              Text(
                '${done.length} of ${session.exercises.length} done',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppPalette.textMuted,
                ),
              ),
          ],
        ),
        // Keyed, so the strip appearing above it on the first logged set does
        // not rebuild the map from scratch and lose the ease into its fill.
        SessionBodyMap(
          key: const ValueKey<String>('session-body-map'),
          height: isStarted ? null : kReadyDiagramHeight,
        ),
        const SizedBox(height: 6),
        if (!isStarted)
          _ReadyBlock(
            exerciseCount: session.exercises.length,
            // Run from this state, not from the ready block: on a planned
            // workout the block is gone the moment logging starts (the list
            // replaces it), and a pick handed back to its dead context and
            // ref was silently dropped (workout-gaps audit).
            onStartLogging: () {
              ref.read(loggingStartedProvider.notifier).start(session.id);
              pickAndOpenExercise(
                context,
                ref,
                title: 'What are you starting with?',
              );
            },
          )
        else ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: const Text(
                    SessionOverviewBody.keepLoggingLabel,
                    style: kLandingSectionLabelStyle,
                  ),
                ),
              ),
              // Reorder and remove, in one mode with arrows and a remove
              // button per row: a swipe or a long-press was the only way to
              // remove, invisible and unreachable for VoiceOver, and there
              // was no way to reorder at all (workout-gaps audit).
              if (session.exercises.length > 1 || _editing)
                TextButton(
                  key: SessionOverviewBody.editListKey,
                  onPressed: () => setState(() => _editing = !_editing),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: AppPalette.textSecondary,
                  ),
                  child: Text(_editing ? 'Done' : 'Edit list'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (final (i, exercise) in session.exercises.indexed)
            if (_editing)
              _EditableSessionRow(
                key: ValueKey<String>('session-edit-${exercise.id}'),
                exercise: exercise,
                name:
                    index.byId(exercise.exerciseId)?.name ?? 'Unknown exercise',
                index: i,
                count: session.exercises.length,
              )
            else
              SessionExerciseRow(
                exercise: exercise,
                name:
                    index.byId(exercise.exerciseId)?.name ?? 'Unknown exercise',
                isNext: i == _nextIndex(session),
              ),
          const SizedBox(height: 12),
          _AddExerciseButton(
            onTap: () => pickAndOpenExercise(
              context,
              ref,
              title: 'Add an exercise',
            ),
          ),
        ],
        const SizedBox(height: 20),
        SessionActions(onFinished: onFinished, showFinish: isStarted),
      ],
    );
  }

}

/// The first exercise that is not done: the one to do next.
int _nextIndex(WorkoutSession session) =>
    session.exercises.indexWhere((e) => progressOf(e) != ExerciseProgress.done);

/// What the screen says before logging has begun.
class _ReadyBlock extends ConsumerWidget {
  const _ReadyBlock({
    required this.exerciseCount,
    required this.onStartLogging,
  });

  final int exerciseCount;

  /// Records that logging started and opens the picker. Owned by the screen's
  /// state, which outlives this block.
  final VoidCallback onStartLogging;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          // Its own node: without the boundary, assistive tech (and Maestro)
          // read the count and every planned name as one run-on label.
          child: Semantics(
            container: true,
            child: Text(
            exerciseCount == 0
                ? 'Nothing logged yet'
                : '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'} planned',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppPalette.textSecondary,
            ),
          ),
          ),
        ),
        if (session != null && session.exercises.isNotEmpty)
          _PlannedList(session: session),
        FilledButton(
          key: SessionOverviewBody.startLoggingKey,
          onPressed: session == null ? null : onStartLogging,
          child: const Text('Start logging'),
        ),
      ],
    );
  }
}

/// The exercises the workout starts with, by name, in order.
///
/// **The plan is what makes the start concrete** (research item 8): "6
/// exercises planned" with no names left the lower half of the screen empty
/// and the workout abstract. Up to six names, then a count of the rest; a
/// longer list belongs to the live screen.
class _PlannedList extends ConsumerWidget {
  const _PlannedList({required this.session});

  final WorkoutSession session;

  static const int _shown = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(exerciseIndexProvider);
    final names = <String>[
      for (final e in session.exercises)
        index.byId(e.exerciseId)?.name ?? 'Unknown exercise',
    ];
    final rest = names.length - _shown;
    return Padding(
      key: SessionOverviewBody.plannedListKey,
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        container: true,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (i, name) in names.take(_shown).indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(top: BorderSide(color: AppPalette.border)),
              ),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppPalette.textPrimary,
                ),
              ),
            ),
          if (rest > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+$rest more',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppPalette.textMuted,
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

/// "Workout in progress", with the clock.
///
/// **It appears only once logging has started.** Before that the workout is
/// being set up, and a strip claiming it is in progress — with a clock running —
/// would be claiming something that has not happened yet.
class LiveStrip extends StatelessWidget {
  const LiveStrip({super.key});

  /// The key a test finds the strip by.
  static const Key stripKey = ValueKey<String>('live-strip');

  @override
  Widget build(BuildContext context) => Padding(
        key: stripKey,
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: <Widget>[
            const _PulseDot(),
            const SizedBox(width: 8),
            // The dot carries the amber; the words do not need to repeat it.
            const Text(
              'Workout in progress',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppPalette.textSecondary,
              ),
            ),
            const Spacer(),
            const SessionClock(),
          ],
        ),
      );
}

/// The accent dot, with one ring that expands and fades as it appears.
///
/// **One pulse, not a loop.** A repeating animation never lets the frame
/// scheduler go idle, which makes every widget test that waits for the screen to
/// settle wait forever — and a dot that pulses for the whole workout is chrome
/// the user stops seeing in a minute anyway. The single pulse is what says
/// "this just started". With reduced motion asked for, the dot is simply there.
class _PulseDot extends StatelessWidget {
  const _PulseDot();

  static const Widget _dot = SizedBox(
    width: 8,
    height: 8,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.accentStrong,
        shape: BoxShape.circle,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 18,
        height: 18,
        child: prefersReducedMotion(context)
            ? const Center(child: _dot)
            : TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOut,
          builder: (context, t, _) => Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Opacity(
                opacity: (1 - t) * 0.6,
                child: Container(
                  width: 8 + 10 * t,
                  height: 8 + 10 * t,
                  decoration: const BoxDecoration(
                    color: AppPalette.accentStrong,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppPalette.accentStrong,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      );
}

/// What "now" is, so a test can hold the clock still.
final clockNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The workout's elapsed time, ticking once a second.
///
/// **Display-only** — see [sessionClockElapsed] for what it shows and when it
/// does not. It rebuilds on its own timer rather than on the session, so a
/// logged set or a keystroke in the title does not move it and it does not move
/// them.
class SessionClock extends ConsumerStatefulWidget {
  const SessionClock({super.key});

  /// The key a test finds the reading by.
  static const Key clockKey = ValueKey<String>('session-clock');

  @override
  ConsumerState<SessionClock> createState() => _SessionClockState();
}

class _SessionClockState extends ConsumerState<SessionClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const SizedBox.shrink();
    final elapsed = sessionClockElapsed(session, ref.read(clockNowProvider)());
    if (elapsed == null) return const SizedBox.shrink();

    return Semantics(
      label: 'Elapsed time',
      value: formatClock(elapsed),
      excludeSemantics: true,
      child: Text(
        formatClock(elapsed),
        key: SessionClock.clockKey,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppPalette.textPrimary,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// One exercise on the workout's list, its logged sets, and where it is up to.
class SessionExerciseRow extends ConsumerWidget {
  const SessionExerciseRow({
    required this.exercise,
    required this.name,
    required this.isNext,
    super.key,
  });

  final SessionExercise exercise;
  final String name;

  /// Whether this is the exercise to do next. It is tagged, so the one row
  /// that matters between sets is the one the eye lands on.
  final bool isNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = progressOf(exercise);
    final sets = formatSetList(exercise);
    final library = ref.watch(exerciseIndexProvider).byId(exercise.exerciseId);

    return Dismissible(
      key: ValueKey<String>('session-dismiss-${exercise.id}'),
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
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(16),
            // A hairline even on Up next: the amber label already marks it,
            // and an amber border as well put the accent on screen twice for
            // one fact.
            border: Border.all(color: AppPalette.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DividerRow(
            key: sessionExerciseRowKey(exercise.exerciseId),
            semanticsLabel:
                '$name. ${progress.label}${isNext ? '. Up next' : ''}',
            onTap: library == null
                ? () {}
                : () => openExerciseForLogging(context, ref, library),
            children: <Widget>[
              if (isNext)
                const Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Text(
                    'Up next',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.accentStrong,
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: progress == ExerciseProgress.done
                            ? AppPalette.textSecondary
                            : AppPalette.textPrimary,
                      ),
                    ),
                  ),
                  _ProgressTag(progress: progress),
                ],
              ),
              if (sets.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  sets,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppPalette.textMuted,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
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

/// The row for [exerciseId], so a test can reach one by name.
Key sessionExerciseRowKey(String exerciseId) =>
    ValueKey<String>('session-row-$exerciseId');

/// A row in the list's edit mode: move up, move down, remove.
class _EditableSessionRow extends ConsumerWidget {
  const _EditableSessionRow({
    required this.exercise,
    required this.name,
    required this.index,
    required this.count,
    super.key,
  });

  final SessionExercise exercise;
  final String name;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(activeSessionProvider.notifier);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 16, right: 4),
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppPalette.textPrimary,
              ),
            ),
          ),
          RowIconAction(
            key: sessionMoveUpKey(exercise.exerciseId),
            icon: Icons.arrow_upward_rounded,
            semanticsLabel: 'Move $name up',
            onTap: index == 0
                ? null
                : () => notifier.moveExercise(index, index - 1),
          ),
          RowIconAction(
            key: sessionMoveDownKey(exercise.exerciseId),
            icon: Icons.arrow_downward_rounded,
            semanticsLabel: 'Move $name down',
            onTap: index == count - 1
                ? null
                : () => notifier.moveExercise(index, index + 1),
          ),
          RowIconAction(
            key: sessionSwapKey(exercise.exerciseId),
            icon: Icons.swap_horiz_rounded,
            semanticsLabel: 'Swap $name for another exercise',
            onTap: () => _swap(context, ref),
          ),
          RowIconAction(
            key: sessionRemoveKey(exercise.exerciseId),
            icon: Icons.close_rounded,
            semanticsLabel: 'Remove $name',
            destructive: true,
            onTap: () async {
              if (exercise.completedSets.isNotEmpty) {
                final confirmed = await confirmDestructive(
                  context,
                  title: 'Remove $name?',
                  message: 'This drops the sets you have logged for it.',
                  confirmLabel: 'Remove',
                );
                if (!confirmed) return;
              }
              await notifier.removeExercise(exercise.id);
            },
          ),
        ],
      ),
    );
  }

  /// Swap in place (`docs/adr/0011-combined-build-decisions.md`): same
  /// position, another exercise. **Only before any set is completed** — a
  /// completed set is a record of this lift, and relabelling it would put its
  /// numbers in another exercise's history. Then the honest offer is Add.
  Future<void> _swap(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    if (exercise.completedSets.isNotEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
        content: const Text(kSwapRefusedMessage),
        // A reason, not a question: it times out rather than sitting over
        // Discard workout until dismissed (an action snackbar persists by
        // default).
        persist: false,
        action: SnackBarAction(
          label: 'Add instead',
          // Inverse (light) surface: amber would fail contrast here.
          textColor: AppPalette.pageBackground,
          onPressed: () {
            if (context.mounted) {
              pickAndOpenExercise(context, ref, title: 'Add an exercise');
            }
          },
        ),
      ));
      return;
    }
    final chosen =
        await showExercisePicker(context, title: 'Swap $name for');
    if (chosen == null || !context.mounted) return;
    final loadType = LoadType.fromName(chosen.loadType);
    if (loadType == null) return;
    final result =
        await ref.read(activeSessionProvider.notifier).swapExercise(
              sessionExerciseId: exercise.id,
              exerciseId: chosen.id,
              loadType: loadType,
            );
    final message = switch (result) {
      SwapResult.alreadyInWorkout => '${chosen.name} is already in this workout.',
      SwapResult.hasCompletedSets => kSwapRefusedMessage,
      SwapResult.swapped || SwapResult.notFound => null,
    };
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Why an exercise with logged sets cannot be swapped, in one line.
const String kSwapRefusedMessage =
    'It has logged sets, so it stays. Add the other exercise instead.';

Key sessionSwapKey(String exerciseId) =>
    ValueKey<String>('session-swap-$exerciseId');
Key sessionMoveUpKey(String exerciseId) =>
    ValueKey<String>('session-up-$exerciseId');
Key sessionMoveDownKey(String exerciseId) =>
    ValueKey<String>('session-down-$exerciseId');
Key sessionRemoveKey(String exerciseId) =>
    ValueKey<String>('session-remove-$exerciseId');

/// Where an exercise is up to, as a quiet word -- not a pill.
///
/// Six identical "To do" pills down a list were the loudest thing on the live
/// screen while saying the least. Done takes the amber ("worked"); the other
/// two stay grey. The word is always there, so status is never colour alone.
class _ProgressTag extends StatelessWidget {
  const _ProgressTag({required this.progress});

  final ExerciseProgress progress;

  @override
  Widget build(BuildContext context) {
    final colour = switch (progress) {
      ExerciseProgress.done => AppPalette.accentStrong,
      ExerciseProgress.inProgress => AppPalette.textSecondary,
      ExerciseProgress.notStarted => AppPalette.textMuted,
    };

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        progress.label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: progress == ExerciseProgress.done
              ? FontWeight.w600
              : FontWeight.w400,
          color: colour,
        ),
      ),
    );
  }
}

class _AddExerciseButton extends StatelessWidget {
  const _AddExerciseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GhostButton(
        buttonKey: SessionOverviewBody.addExerciseKey,
        label: 'Add exercise',
        leadingIcon: Icons.add_rounded,
        onTap: onTap,
      );
}
