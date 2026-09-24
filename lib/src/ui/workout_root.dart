import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/derived.dart';
import '../data/local_date.dart';
import '../data/routine_store.dart';
import '../data/routines.dart';
import '../data/session_store.dart';
import '../theme/app_palette.dart';
import '../data/active_session.dart';
import '../data/exercise_index.dart';
import 'app_screen.dart';
import 'destructive_confirmation.dart';
import 'routine_screen.dart';
import 'routine_card.dart';
import '../theme/app_metrics.dart';
import 'template_list_screen.dart';
import 'log_workout_screen.dart';
import 'template_row.dart';

/// The Workout tab's body: the templates you can start, filtered by split.
///
/// **There is no empty state here, by construction.** Eleven templates ship
/// with the app, so this screen has content on the very first launch — which is
/// the whole reason the landing lists them rather than hiding them behind a
/// picker. Day one is the app's fullest screen, not its emptiest.
///
/// **A body, never a `Scaffold`.** The shell owns the Scaffold and the pinned
/// header (`AppScreen`); a root that grew its own would nest two of each and
/// swallow the floating tab bar's inset on the way.
///
/// **The scrollable is this widget's, and so is its padding.** A `ListView`
/// with no `padding` quietly absorbs the bottom inset for you; the moment it
/// passes any padding of its own that automatic behaviour is skipped and the
/// last row slides under the tab bar with nothing failing. So every root passes
/// [screenScrollPadding] — the one rule, applied at the scrollable.
///
/// **Nothing here suggests a workout.** The filter says which templates are
/// listed; it never says which one to do, never advances, and does not know
/// what day it is. That is the line `docs/02-workout-tab-userflow.md` draws,
/// and the reason the split control is a view filter rather than a declared
/// programme.
///
/// This is the one root that grows a second *structural* body: build-order
/// step 4 replaces the landing entirely while a session is open. That is why
/// [build] branches first and lays out second.
class WorkoutRoot extends ConsumerWidget {
  const WorkoutRoot({super.key});

  /// The group heading over the user's own templates.
  @visibleForTesting
  static const String customGroupLabel = 'YOUR TEMPLATES';

  /// The row that opens the template library from the Workout tab.
  @visibleForTesting
  static const Key manageTemplatesKey = ValueKey<String>('manage-templates');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session != null) {
      // An open workout replaces the landing entirely, at stack depth zero.
      //
      // **One screen for both paths now** (`adr/0004`). The two overview
      // bodies used to branch here — a template run answering "which muscles
      // have I trained", an ad-hoc one "which exercises have I done". Both
      // questions still have their screen, reached from the summary bar's body
      // figures; what changed is that neither is the surface a set is logged
      // on any more.
      return const LogWorkoutBody();
    }

    return const WorkoutLandingBody();
  }

}

/// The templates you can start, filtered by split.
///
/// **Its own widget because it has two homes.** It is the Workout tab's landing
/// when nothing is open, and it is also what the open workout's header pushes
/// when the user wants to start a different one. Two copies would drift on the
/// filter, the groups and the ad-hoc entry alike.
class WorkoutLandingBody extends ConsumerWidget {
  const WorkoutLandingBody({super.key, this.isPushed = false});

  /// Whether this is the pushed list reached from an open workout, in which
  /// case choosing something has to close the workout that is already running
  /// and then return to the root.
  final bool isPushed;

  /// The keys a test reaches the landing's routine controls by.
  static const Key newRoutineKey = ValueKey<String>('new-routine');
  static const Key templatesKey = ValueKey<String>('open-templates');

  /// The card at the top of the landing, when there is one.
  static const Key heroKey = ValueKey<String>('routine-hero');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesProvider);
    final saved = ref.watch(savedSessionsProvider);
    final hero = _mostRecentlyTrained(routines, saved);
    final rest = routines.where((r) => r.id != hero?.id).toList();

    return ListView(
      padding: screenScrollPadding(context),
      children: <Widget>[
        const SizedBox(height: AppMetrics.gapSnug),
        if (hero != null) ...<Widget>[
          RoutineHeroCard(routine: hero, lastDone: lastPerformedRoutine(hero.id, saved)),
          const SizedBox(height: AppMetrics.gapSection),
        ],
        if (rest.isNotEmpty) ...<Widget>[
          Semantics(
            header: true,
            child: Text(
              hero == null
                  ? 'MY ROUTINES (${rest.length})'
                  : 'OTHER ROUTINES',
              style: kLandingSectionLabelStyle,
            ),
          ),
          const SizedBox(height: AppMetrics.gapTight),
          // Long-press to drag. The list is quiet now, but the order is still
          // the user's, and a routine they never train would otherwise sink
          // below one they do with no way back up.
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (oldIndex, newIndex) {
              final ids = rest.map((r) => r.id).toList();
              ids.insert(newIndex, ids.removeAt(oldIndex));
              // The hero keeps its own place: it is chosen by history, not by
              // position, so it is not part of what the drag reorders.
              ref.read(routineListProvider.notifier).reorder(ids);
            },
            children: <Widget>[
              for (final (i, routine) in rest.indexed)
                ReorderableDelayedDragStartListener(
                  key: ValueKey<String>('reorder-${routine.id}'),
                  index: i,
                  child: RoutineListRow(
                    routine: routine,
                    lastDone: lastPerformedRoutine(routine.id, saved),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppMetrics.gapSection),
        ],
        if (routines.isEmpty) ...<Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppMetrics.gapSection),
            child: Column(
              children: <Widget>[
                Icon(Icons.assignment_outlined,
                    size: 28, color: AppPalette.textSecondary),
                SizedBox(height: AppMetrics.gap),
                Text('No routines yet',
                    style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: AppMetrics.gapTight + 2),
                Text('Build one, or just start and add as you go',
                    style: TextStyle(
                        color: AppPalette.textSecondary, fontSize: 14)),
              ],
            ),
          ),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: _SecondaryAction(
                actionKey: newRoutineKey,
                icon: Icons.assignment_outlined,
                label: 'New routine',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RoutineScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppMetrics.gap),
            Expanded(
              child: _SecondaryAction(
                // **Where Hevy puts "Explore Routines".** That one reaches a
                // cloud library; this app has no network, so the local
                // equivalent is the eleven shipped templates — muscle-group
                // starting points, not routines. See `CONTEXT.md`.
                actionKey: templatesKey,
                icon: Icons.grid_view_outlined,
                label: 'Templates',
                onTap: () => pushTemplateList(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppMetrics.gap),
        _StartEmptyWorkout(onTap: () => _startEmpty(context, ref)),
        const SizedBox(height: AppMetrics.gapSection),
      ],
    );
  }

  /// The routine whose last completed workout is the most recent.
  ///
  /// **A fact about the past, never a pick for the future.** `docs/02` forbids
  /// this tab from suggesting, rotating or surfacing a "today's workout", and a
  /// card at the top of a screen is the loudest kind of surfacing there is — so
  /// what earns the position is the one thing the app can say without an
  /// opinion: *this is the one you last trained*. A routine never run is never
  /// the hero, and nothing here ranks, scores or rotates.
  ///
  /// Null when nothing has been run yet, and then the landing is a plain list
  /// rather than promoting an arbitrary routine to a place it has not earned.
  static Routine? _mostRecentlyTrained(
    List<Routine> routines,
    List<WorkoutSession> saved,
  ) {
    Routine? best;
    LocalDate? bestDate;
    for (final routine in routines) {
      final date = lastPerformedRoutine(routine.id, saved);
      if (date == null) continue;
      if (bestDate == null || date > bestDate) {
        best = routine;
        bestDate = date;
      }
    }
    return best;
  }

  /// Starts a workout with nothing in it.
  ///
  /// **The session is created here, unlike the old ad-hoc entry.** That one
  /// deferred creation to the first exercise added, because it opened a search
  /// screen and backing out of a search must not cost the user the workout they
  /// already had. This control says "start a workout" and nothing else, so
  /// deferring would leave the duration unstarted and the empty log screen with
  /// nothing to render.
  Future<void> _startEmpty(BuildContext context, WidgetRef ref) async {
    if (!await _closeOpenWorkout(context, ref)) return;
    await ref.read(activeSessionProvider.notifier).startAdHoc();
  }


  /// Saves or drops the workout already running. Returns false when the user
  /// backed out, in which case nothing else should happen.
  Future<bool> _closeOpenWorkout(BuildContext context, WidgetRef ref) async {
    final open = ref.read(activeSessionProvider);
    if (open == null) return true;

    final notifier = ref.read(activeSessionProvider.notifier);
    final index = ref.read(exerciseIndexProvider);

    if (setCountOf(open) > 0) {
      final name = resolvedTitle(open, index);
      await notifier.finish();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$name saved')));
      }
      return true;
    }

    if (open.hasAnyWrittenSets) {
      final confirmed = await confirmDestructive(
        context,
        title: 'Discard the workout in progress?',
        message: 'It has values typed but no sets ticked, so there is nothing '
            'to save.',
        confirmLabel: 'Discard',
      );
      if (!confirmed) return false;
    }
    await notifier.discard();
    return true;
  }

}

/// `+ Start empty workout` — the way past the routine list.
///
/// **Neutral, not accent-filled, and that is a change.** The landing's one
/// accent used to live here because nothing else on the screen read as an
/// action. Routine cards now each carry their own `Start routine`, which is the
/// primary action *of that card*; a second accent-filled control above them
/// would compete with every one of them at once. The meaning of `#D85A30` is
/// unchanged — it still marks the control that starts a workout.
class _StartEmptyWorkout extends StatelessWidget {
  const _StartEmptyWorkout({required this.onTap});

  final VoidCallback onTap;

  /// Unchanged from when this was the sixth row: it is the same destination,
  /// and the tests that reach the ad-hoc path reach it by this key.
  static const Key entryKey = ValueKey<String>('ad-hoc-entry');

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Start empty workout. Add exercises as you go',
        excludeSemantics: true,
        child: GestureDetector(
          key: entryKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppPalette.border),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.add_rounded,
                    size: 22, color: AppPalette.textPrimary),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const <Widget>[
                      Text('Start empty workout', style: _kCtaTitleStyle),
                      SizedBox(height: 2),
                      Text(
                        'Add exercises as you go',
                        style: _kCtaSubtitleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppPalette.textSecondary),
              ],
            ),
          ),
        ),
      );
}

/// The quiet route to template authoring, at the foot of the list.
// **Both colours followed the surface.** These read `onAccent` and a faded
// `onAccent` while this control was accent-filled; on the neutral surface it
// wears now, near-black text on a near-black card is invisible rather than
// merely low-contrast. A palette entry named for the ground it sits on has to
// move when that ground does.
const TextStyle _kCtaTitleStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  color: AppPalette.textPrimary,
);

/// The same colour as the title at two-thirds the size. The palette has one
/// colour for text on accent (§12, "No other colours"), so the second line is
/// made secondary by scale rather than by tint.
const TextStyle _kCtaSubtitleStyle = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w500,
  color: AppPalette.textSecondary,
);



/// `New routine` and `Templates` — the pair under the Routines heading.
///
/// Neutral surfaces: both are navigation, and neither starts a workout.
class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: actionKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 18, color: AppPalette.textSecondary),
              const SizedBox(width: 8),
              // Flexible, because two of these share a 360pt row with a gutter
              // either side — and a label that overflows is a red-striped box
              // on the narrowest phone rather than a layout that merely looks
              // tight.
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
}
