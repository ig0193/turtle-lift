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
    // Finish sits in the header, as Hevy's does (`adr/0004`), and the
    // Discard beside it stays at the foot of the body — ending a workout and
    // throwing it away must not be neighbours.
    actions: <Widget>[_StartAnotherButton(), _FinishButton()],
  );
});

/// Opens the template list so another workout can be started.
///
/// **A list glyph, never a plus.** It sits inches from the ad-hoc path's
/// "+ Add exercise" and means something far more consequential: choosing a
/// workout here saves or drops the one in progress. A plus would read as "add
/// something to this workout", which is the opposite of what it does.
class _StartAnotherButton extends StatelessWidget {
  const _StartAnotherButton();

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Browse templates',
        excludeSemantics: true,
        child: GestureDetector(
          key: startAnotherWorkoutKey,
          behavior: HitTestBehavior.opaque,
          onTap: () => pushTemplateList(context),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.list_alt_outlined,
                size: 20, color: AppPalette.textSecondary),
          ),
        ),
      );
}

/// The key a test taps to reach the template list mid-workout.
const Key startAnotherWorkoutKey = ValueKey<String>('start-another-workout');


/// Finishes the open workout, by way of the Save workout screen.
class _FinishButton extends StatelessWidget {
  const _FinishButton();

  @override
  Widget build(BuildContext context) => const FinishAction();
}
