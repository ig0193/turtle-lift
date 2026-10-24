import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/session_progress.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'destructive_confirmation.dart';
import 'divider_row.dart';
import 'session_actions.dart';
import 'session_body_map.dart';
import 'session_date_control.dart';
import 'session_entry.dart';
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
class SessionOverviewBody extends ConsumerWidget {
  const SessionOverviewBody({required this.onFinished, super.key});

  final void Function(String sessionId) onFinished;

  /// The key a test taps to add another exercise.
  static const Key addExerciseKey = ValueKey<String>('add-exercise');

  /// The key a test taps to begin logging from the ready view.
  static const Key startLoggingKey = ValueKey<String>('start-logging');

  /// The label over the list.
  @visibleForTesting
  static const String keepLoggingLabel = 'KEEP LOGGING';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  fontSize: 11.5,
                  color: AppPalette.textMuted,
                ),
              ),
          ],
        ),
        SessionBodyMap(height: isStarted ? null : kReadyDiagramHeight),
        const SizedBox(height: 6),
        if (!isStarted)
          _ReadyBlock(exerciseCount: session.exercises.length)
        else ...<Widget>[
          Semantics(
            header: true,
            child: const Text(keepLoggingLabel, style: kLandingSectionLabelStyle),
          ),
          const SizedBox(height: 4),
          for (final (i, exercise) in session.exercises.indexed)
            SessionExerciseRow(
              exercise: exercise,
              name: index.byId(exercise.exerciseId)?.name ?? 'Unknown exercise',
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

  /// The first exercise that is not done: the one to do next.
  static int _nextIndex(WorkoutSession session) =>
      session.exercises.indexWhere((e) => progressOf(e) != ExerciseProgress.done);
}

/// What the screen says before logging has begun.
class _ReadyBlock extends ConsumerWidget {
  const _ReadyBlock({required this.exerciseCount});

  final int exerciseCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            exerciseCount == 0
                ? 'Nothing logged yet'
                : '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'} planned',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppPalette.textSecondary,
            ),
          ),
        ),
        FilledButton(
          key: SessionOverviewBody.startLoggingKey,
          onPressed: session == null
              ? null
              : () {
                  // Recorded before the sheet opens, so dismissing it leaves
                  // the user on the list they asked for, not back on a button
                  // they have already pressed.
                  ref.read(loggingStartedProvider.notifier).start(session.id);
                  pickAndOpenExercise(
                    context,
                    ref,
                    title: 'What are you starting with?',
                  );
                },
          child: const Text('Start logging'),
        ),
      ],
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
            const Text(
              'WORKOUT IN PROGRESS',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: AppPalette.accentStrong,
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
/// "this just started".
class _PulseDot extends StatelessWidget {
  const _PulseDot();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 18,
        height: 18,
        child: TweenAnimationBuilder<double>(
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
          fontSize: 12.5,
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

  /// Whether this is the exercise to do next. It is tagged and outlined, so the
  /// one row that matters between sets is the one the eye lands on.
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isNext ? AppPalette.accentStrong : AppPalette.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13),
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
                    'UP NEXT',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
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
                        fontWeight: FontWeight.w600,
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
                const SizedBox(height: 3),
                Text(
                  sets,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppPalette.textMuted,
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
          key: SessionOverviewBody.addExerciseKey,
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
