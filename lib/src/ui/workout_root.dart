import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/routines.dart';
import '../theme/app_palette.dart';
import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import 'app_screen.dart';
import 'destructive_confirmation.dart';
import 'name_prompt.dart';
import 'routine_builder_screen.dart';
import 'routine_card.dart';
import 'routine_folder_section.dart';
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

  /// The keys a test reaches the landing's three routine controls by.
  static const Key newFolderKey = ValueKey<String>('new-folder');
  static const Key newRoutineKey = ValueKey<String>('new-routine');
  static const Key templatesKey = ValueKey<String>('open-templates');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesProvider);
    final folders = ref.watch(routineFoldersProvider);
    final unfiled = routines.where((r) => r.folderId == null).toList();

    return ListView(
      padding: screenScrollPadding(context),
      children: <Widget>[
        const SizedBox(height: 2),
        _StartEmptyWorkout(onTap: () => _startEmpty(context, ref)),
        const SizedBox(height: 22),
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                header: true,
                child: const Text('ROUTINES', style: kLandingSectionLabelStyle),
              ),
            ),
            IconButton(
              key: newFolderKey,
              tooltip: 'New folder',
              icon: const Icon(Icons.create_new_folder_outlined,
                  size: 20, color: AppPalette.textSecondary),
              onPressed: () => _newFolder(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: _SecondaryAction(
                actionKey: newRoutineKey,
                icon: Icons.assignment_outlined,
                label: 'New routine',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RoutineBuilderScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
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
        const SizedBox(height: 18),
        for (final folder in folders)
          RoutineFolderSection(
            folder: folder,
            routines: routines.where((r) => r.folderId == folder.id).toList(),
          ),
        if (folders.isNotEmpty) const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text('MY ROUTINES (${unfiled.length})',
              style: kLandingSectionLabelStyle),
        ),
        const SizedBox(height: 10),
        if (unfiled.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Routines you build appear here. Start an empty workout any '
              'time without one.',
              style: TextStyle(color: AppPalette.textSecondary),
            ),
          )
        else
          // **Long-press to drag, inside the landing's own scrollable.**
          // `shrinkWrap` with no physics of its own, so this list measures its
          // children and hands scrolling back to the page — two competing
          // scrollables on one screen is how a drag near the edge starts
          // fighting the finger.
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            // `onReorderItem`, not the deprecated `onReorder`: it reports the
            // index the row actually lands on, rather than the one it would
            // have had before the row was taken out.
            onReorderItem: (oldIndex, newIndex) {
              final ids = unfiled.map((r) => r.id).toList();
              ids.insert(newIndex, ids.removeAt(oldIndex));
              ref.read(routineListProvider.notifier).reorder(ids);
            },
            children: <Widget>[
              for (final (i, routine) in unfiled.indexed)
                ReorderableDelayedDragStartListener(
                  key: ValueKey<String>('reorder-${routine.id}'),
                  index: i,
                  child: RoutineCard(routine: routine),
                ),
            ],
          ),
      ],
    );
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

  Future<void> _newFolder(BuildContext context, WidgetRef ref) async {
    final name = await promptForName(context, title: 'New folder');
    if (name == null || name.isEmpty) return;
    await ref.read(routineFolderListProvider.notifier).create(name);
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
