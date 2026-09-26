import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../theme/app_palette.dart';
import 'l0_tab_chrome.dart';
import 'log_workout_screen.dart';
import 'session_header.dart';
import 'template_list_screen.dart';

/// What the Workout tab puts in the pinned header.
///
/// With no workout open it contributes nothing and the header is the word
/// "Workout". With one open it becomes the editable session title plus a way to
/// start a different workout.
///
/// **Watched by the shell, so it stays deliberately coarse.** It depends on
/// whether a workout is open and on nothing else — not on the sets, not on the
/// title text — because the shell's build rebuilds the tab bar and the whole
/// tab stack.
final workoutTabChromeProvider = Provider<L0TabChrome>((ref) {
  final isOpen =
      ref.watch(activeSessionProvider.select((session) => session != null));
  if (!isOpen) return const L0TabChrome();

  return const L0TabChrome(
    title: 'Workout in progress',
    titleWidget: SessionTitleField(),
    // **Three controls, not five.** The header carried a browse-templates
    // glyph, Finish, the word "Profile" and an avatar, over a title that
    // truncated at a dozen characters. Finish is the only one a user reaches
    // for mid-workout; the rest moved into the overflow, and the profile
    // avatar is suppressed for the duration.
    actions: <Widget>[_FinishButton(), _WorkoutOverflow()],
    hideProfile: true,
  );
});

/// The key a test taps to reach the template list mid-workout.
///
/// It is the overflow menu now, not a header glyph of its own.
const Key startAnotherWorkoutKey = _WorkoutOverflow.menuKey;


/// Finishes the open workout, by way of the Save workout screen.
class _FinishButton extends StatelessWidget {
  const _FinishButton();

  @override
  Widget build(BuildContext context) => const FinishAction();
}

/// Everything else a workout can do: browse templates, or throw it away.
///
/// **Discard lives here rather than at the foot of the scroll.** It sat one
/// thumb-width under Add exercise — the control pressed most often on the
/// screen — painted in the one colour reserved for destruction. A menu costs a
/// tap and removes a whole class of accident.
class _WorkoutOverflow extends ConsumerWidget {
  const _WorkoutOverflow();

  static const Key menuKey = ValueKey<String>('workout-overflow');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: menuKey,
      icon: const Icon(Icons.more_horiz, color: AppPalette.textSecondary),
      color: AppPalette.surface,
      tooltip: 'Workout options',
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'templates',
          child: Text('Browse templates'),
        ),
        const PopupMenuItem<String>(
          value: 'discard',
          child: Text('Discard workout',
              style: TextStyle(color: AppPalette.danger)),
        ),
      ],
      onSelected: (value) async {
        switch (value) {
          case 'templates':
            await pushTemplateList(context);
          case 'discard':
            await LogWorkoutBody.discardWorkout(context, ref);
        }
      },
    );
  }
}
