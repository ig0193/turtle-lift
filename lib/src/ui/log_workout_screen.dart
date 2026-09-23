import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/load_type.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import 'adhoc_overview_body.dart';
import 'app_screen.dart';
import 'destructive_confirmation.dart';
import 'exercise_picker_screen.dart';
import 'log_exercise_block.dart';
import 'rest_timer.dart';
import 'save_workout_screen.dart';
import 'session_body_map.dart';
import 'template_overview_body.dart';

/// The screen a workout is run on.
///
/// **One scrolling screen, and that is the whole point** (`adr/0004`). Every
/// exercise and every set is inline: adding a set, correcting a weight and
/// ticking a rep never leave this route. The flow it replaces pushed a screen
/// per exercise and popped back to a list, which cost two navigations for every
/// lift in a session where the user is holding a phone between sets.
///
/// The header is still the pinned `Scaffold.appBar` through [AppScreen], so the
/// rule in `app_screen.dart` holds here as everywhere: the body is the
/// scrollable, and the header does not move.
class LogWorkoutScreen extends ConsumerWidget {
  const LogWorkoutScreen({super.key});

  static const Key addExerciseKey = ValueKey<String>('log-add-exercise');
  static const Key discardKey = ValueKey<String>('log-discard');
  static const Key finishKey = ValueKey<String>('log-finish');
  static const Key setCountKey = ValueKey<String>('log-set-count');
  static const Key volumeKey = ValueKey<String>('log-volume');
  static const Key durationKey = ValueKey<String>('log-duration');
  static const Key bodyMapKey = ValueKey<String>('log-body-map');
  static const Key durationControlKey =
      ValueKey<String>('log-duration-control');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScreen.pushed(
      title: 'Log workout',
      actions: <Widget>[const FinishAction()],
      bottomBar: const RestTimerBar(),
      body: const LogWorkoutBody(),
    );
  }
}

/// The Log Workout screen's content, without a shell of its own.
///
/// **Separate from [LogWorkoutScreen] because an open session *is* the Workout
/// tab**, and the tab root cannot bring its own `Scaffold` — `l0_shell.dart`
/// owns the only one. `docs/02` Step 2b is unchanged by the rebuild: a running
/// workout replaces the landing rather than sitting behind a Resume card. So
/// this body renders at stack depth zero under the shell's pinned header, and
/// [LogWorkoutScreen] wraps the same body for the pushed case.
///
/// **Which is why there is no collapse chevron.** Hevy's screen is a modal you
/// pull down out of; here the tab bar is already the way out, and the mini bar
/// in the shell is what you get when you take it.
class LogWorkoutBody extends ConsumerWidget {
  const LogWorkoutBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const SizedBox.shrink();

    return ListView(
      padding: screenScrollPadding(context),
      children: <Widget>[
        _SummaryBar(session: session),
        const SizedBox(height: 16),
        if (session.exercises.isEmpty)
          const _EmptyState()
        else
          for (final exercise in session.exercises)
            LogExerciseBlock(exercise: exercise, session: session),
        FilledButton.icon(
          key: LogWorkoutScreen.addExerciseKey,
          onPressed: () => _addExercises(context, ref, session),
          style: FilledButton.styleFrom(
            backgroundColor: AppPalette.accentStrong,
            foregroundColor: AppPalette.onAccent,
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add exercise'),
        ),
        const SizedBox(height: 10),
        TextButton(
          key: LogWorkoutScreen.discardKey,
          onPressed: () => _discard(context, ref),
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Discard workout',
              style: TextStyle(color: AppPalette.danger)),
        ),
      ],
    );
  }

  /// Adds everything picked in one go, in the order they were ticked.
  Future<void> _addExercises(
    BuildContext context,
    WidgetRef ref,
    WorkoutSession session,
  ) async {
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        // Filtered to the session's groups when it came from a template, which
        // is all a template does now — it narrows the picker, it does not lock
        // the session (`adr/0004`).
        builder: (_) => ExercisePickerScreen(
          preselectedGroupIds:
              session.groupIds.isEmpty ? null : session.groupIds,
        ),
      ),
    );
    if (picked == null) return;
    final index = ref.read(exerciseIndexProvider);
    for (final exerciseId in picked) {
      final library = index.byId(exerciseId);
      if (library == null) continue;
      await ref.read(activeSessionProvider.notifier).addExercise(
            exerciseId: exerciseId,
            loadType: LoadType.fromName(library.loadType) ?? LoadType.weighted,
          );
    }
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Discard workout?',
      message: 'Everything logged in this session is permanently deleted.',
      confirmLabel: 'Discard',
    );
    if (!confirmed) return;
    await ref.read(activeSessionProvider.notifier).discard();
  }
}

/// The header's Finish button.
///
/// **It opens the Save workout screen rather than saving outright** — Hevy's
/// order, and the reason the title and the date get one last look before a
/// session becomes history. `00` §9 is unchanged underneath it: Finish is
/// available at any time, and a session with zero completed sets is dropped
/// silently rather than filed as an empty workout that would count toward the
/// streak.
class FinishAction extends ConsumerWidget {
  const FinishAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const SizedBox.shrink();
    return TextButton(
      key: LogWorkoutScreen.finishKey,
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SaveWorkoutScreen()),
      ),
      child: const Text('Finish',
          style: TextStyle(
              color: AppPalette.accentLight, fontWeight: FontWeight.w600)),
    );
  }
}

/// `Duration · Volume · Sets`, plus the front and back figures.
///
/// **Set count is the headline of the three**, per `00` §3: volume cannot
/// include bodyweight or timed work, so it is the partial figure of the row and
/// must never out-rank the one that covers every load type.
class _SummaryBar extends ConsumerWidget {
  const _SummaryBar({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppPalette.border)),
      ),
      child: Row(
        children: <Widget>[
          const Expanded(child: _DurationStat()),
          Expanded(
            child: _Stat(
              label: 'Volume',
              valueKey: LogWorkoutScreen.volumeKey,
              value: '${formatWeight(volumeOf(session))} kg',
            ),
          ),
          Expanded(
            child: _Stat(
              label: 'Sets',
              valueKey: LogWorkoutScreen.setCountKey,
              value: '${setCountOf(session)}',
            ),
          ),
          // The two figures are the way back to the muscle overview, which
          // Hevy has no equivalent of and which this app kept (`adr/0004`).
          GestureDetector(
            key: LogWorkoutScreen.bodyMapKey,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _OverviewRoute(session: session),
              ),
            ),
            child: SizedBox(
              width: 64,
              child: SessionBodyMap(compact: true),
            ),
          ),
        ],
      ),
    );
  }
}

/// The only stat here that moves on its own, so the only one that needs a tick.
class _DurationStat extends ConsumerStatefulWidget {
  const _DurationStat();

  @override
  ConsumerState<_DurationStat> createState() => _DurationStatState();
}

class _DurationStatState extends ConsumerState<_DurationStat> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final elapsed = session == null ? null : elapsedOf(session, _now);
    return GestureDetector(
      key: LogWorkoutScreen.durationControlKey,
      behavior: HitTestBehavior.opaque,
      onTap: session == null ? null : _adjust,
      child: _Stat(
        label: 'Duration',
        valueKey: LogWorkoutScreen.durationKey,
        // An em dash, not `0:00`. A session logged before `adr/0004` has no
        // start time, and a zero would claim it took no time at all.
        value: elapsed == null ? '—' : formatDuration(elapsed.inSeconds),
        accent: true,
      ),
    );
  }

  /// Corrects the duration — for the walk to the gym that got counted, or the
  /// workout that was started twenty minutes late.
  ///
  /// It moves the *start* backwards from the end, so a running session keeps
  /// ticking from the corrected value. `performedOn` is untouched: pushing a
  /// start across midnight must not refile the workout onto the previous day.
  Future<void> _adjust() async {
    final chosen = await showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: AppPalette.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Set duration',
                  style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
            for (final minutes in <int>[15, 30, 45, 60, 75, 90])
              ListTile(
                title: Text('$minutes min',
                    style: const TextStyle(color: AppPalette.textPrimary)),
                onTap: () => Navigator.of(context).pop(<int>[minutes]),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    await ref
        .read(activeSessionProvider.notifier)
        .setDuration(Duration(minutes: chosen.first));
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.valueKey,
    this.accent = false,
  });

  final String label;
  final String value;
  final Key valueKey;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label,
            style: const TextStyle(color: AppPalette.textMuted, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          value,
          key: valueKey,
          style: TextStyle(
            color: accent ? AppPalette.accentLight : AppPalette.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: <Widget>[
          Text('Get started',
              style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Add an exercise to start your workout',
              style: TextStyle(color: AppPalette.textSecondary)),
        ],
      ),
    );
  }
}

/// The muscle overview, kept reachable from the summary bar's body figures.
class _OverviewRoute extends StatelessWidget {
  const _OverviewRoute({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    return AppScreen.pushed(
      title: 'Muscles this session',
      // Finishing is the Log Workout screen's job; this route is a read of the
      // muscle map, so its Finish is a no-op that simply returns.
      body: session.isTemplateSession
          ? TemplateOverviewBody(onFinished: (_) => Navigator.of(context).pop())
          : AdHocOverviewBody(onFinished: (_) => Navigator.of(context).pop()),
    );
  }
}
