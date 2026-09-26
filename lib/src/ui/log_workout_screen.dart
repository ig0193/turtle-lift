import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/load_type.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import 'adhoc_overview_body.dart';
import 'app_screen.dart';
import 'destructive_confirmation.dart';
import 'exercise_picker_screen.dart';
import 'log_exercise_block.dart';
import 'rest_timer.dart';
import 'save_workout_screen.dart';
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
        const SizedBox(height: AppMetrics.gapSection),
        if (session.exercises.isEmpty)
          const _EmptyState()
        else
          for (final exercise in session.exercises)
            LogExerciseBlock(exercise: exercise, session: session),
        // **Outlined, not filled.** A full-bleed accent slab is the loudest
        // thing on the screen and it scrolls under a blurred tab bar, where it
        // smears and reads as a collision. Accent stays on the border and the
        // label, which is legible under glass and still unmistakably the
        // primary action.
        OutlinedButton.icon(
          key: LogWorkoutScreen.addExerciseKey,
          onPressed: () => _addExercises(context, ref, session),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppPalette.accentLight,
            backgroundColor: AppPalette.surface,
            // **No accent border.** A 1.5px orange outline read *through* the
            // blurred tab bar as it scrolled past, which looks like a
            // collision rather than a control passing under glass. Accent
            // stays on the label, which survives the blur legibly.
            side: const BorderSide(color: AppPalette.border),
            minimumSize: const Size.fromHeight(AppMetrics.controlHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppMetrics.radiusControl),
            ),
            textStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600),
          ),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Add exercise'),
        ),
        // Discard moved into the header's overflow menu. A destructive action
        // does not belong at the foot of a scroll, one thumb-width under the
        // control the user reaches for most.
        const SizedBox(height: AppMetrics.gapBlock),
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

  static Future<void> discardWorkout(
      BuildContext context, WidgetRef ref) async {
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
/// **One figure leads.** Three equal-weight stats in a row is a table, and a
/// table makes the reader do the ranking. Duration is the one that moves and the
/// one a user glances at mid-set, so it is the large one; volume and sets are
/// facts to check, not to watch.
///
/// **Set count is still the headline of the app**, per `00` §3 — volume cannot
/// include bodyweight or timed work. Size here ranks *glanceability*, not
/// importance, which is why volume never gets the large treatment either.
class _SummaryBar extends ConsumerWidget {
  const _SummaryBar({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(top: AppMetrics.gapSnug),
      padding: const EdgeInsets.symmetric(
          horizontal: AppMetrics.gapCard, vertical: AppMetrics.gap),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(AppMetrics.radiusCard),
      ),
      // **Every region flexes.** The bar holds a hero numeral, two stats and a
      // control on a 360pt phone; laying any of them out at intrinsic width
      // overflows the moment a volume reaches four digits.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const Flexible(flex: 4, child: _DurationStat()),
          const SizedBox(width: AppMetrics.gap),
          Container(width: 1, height: 34, color: AppPalette.border),
          const SizedBox(width: AppMetrics.gap),
          Expanded(
            flex: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                  child: _MiniStat(
                    label: 'Volume',
                    valueKey: LogWorkoutScreen.volumeKey,
                    value: '${formatWeight(volumeOf(session))} kg',
                  ),
                ),
                Flexible(
                  child: _MiniStat(
                    label: 'Sets',
                    valueKey: LogWorkoutScreen.setCountKey,
                    value: '${setCountOf(session)}',
                  ),
                ),
                // **A count and a chevron, not two 40pt figures.** The body
                // diagrams are 42 traced segments rendered into a 40pt box:
                // at that size they are brown smudges that name nothing and
                // invite no tap. The muscle overview they lead to is worth
                // reaching; the thumbnail was not the way to say so.
                Semantics(
                  button: true,
                  label: 'Muscles worked this session',
                  excludeSemantics: true,
                  child: SizedBox(
                    height: AppMetrics.touchTarget,
                    child: InkWell(
                      key: LogWorkoutScreen.bodyMapKey,
                      borderRadius:
                          BorderRadius.circular(AppMetrics.radiusControl),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _OverviewRoute(session: session),
                        ),
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppMetrics.gapSnug),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.accessibility_new,
                                size: 18, color: AppPalette.textSecondary),
                            Icon(Icons.chevron_right,
                                size: 16, color: AppPalette.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A stat that is checked, not watched.
class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label,
            style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 11,
                letterSpacing: 0.3)),
        const SizedBox(height: 1),
        Text(
          value,
          key: valueKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
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
    return Semantics(
      button: true,
      label: 'Workout duration. Tap to adjust',
      excludeSemantics: true,
      child: InkWell(
        key: LogWorkoutScreen.durationControlKey,
        borderRadius: BorderRadius.circular(AppMetrics.radiusControl),
        onTap: session == null ? null : _adjust,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppMetrics.gapTight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Duration',
                  style: TextStyle(
                      color: AppPalette.textMuted,
                      fontSize: 11,
                      letterSpacing: 0.3)),
              Text(
                // An em dash, not `0:00`. A session logged before `adr/0004`
                // has no start time, and a zero would claim it took none.
                elapsed == null ? '—' : formatDuration(elapsed.inSeconds),
                key: LogWorkoutScreen.durationKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppPalette.accentLight,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  letterSpacing: -0.5,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 56, bottom: AppMetrics.gapSection),
      child: Column(
        children: <Widget>[
          Icon(Icons.fitness_center, size: 30, color: AppPalette.textMuted),
          SizedBox(height: AppMetrics.gapCard),
          Text('Nothing logged yet',
              style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: AppMetrics.gapTight + 2),
          Text('Add your first exercise below',
              style:
                  TextStyle(color: AppPalette.textSecondary, fontSize: 14)),
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
