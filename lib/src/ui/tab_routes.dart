import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l0_shell.dart';
import 'profile_root.dart';
import 'tab_index.dart';
import 'workout_root.dart';

/// The Workout tab's index, read off the shell's own tab list so a reordered
/// bar cannot send a reminder or a tap to the wrong tab.
final int kWorkoutTabIndex =
    L0Shell.tabs.indexWhere((tab) => tab.body is WorkoutRoot);

/// The Profile tab's index, found the same way.
final int kProfileTabIndex =
    L0Shell.tabs.indexWhere((tab) => tab.body is ProfileRoot);

/// Switches to Profile and to [segment] inside it.
///
/// **Only from L0** (ADR 0003): a tab switch is legal only with an empty
/// stack. The callers are the Workout landing's week strip, which is itself an
/// L0 root, and the reminder listener, which pops to the shell first.
void showProfileSegment(WidgetRef ref, ProfileSegment segment) {
  ref.read(tabIndexProvider.notifier).select(kProfileTabIndex);
  ref.read(profileSegmentProvider.notifier).select(segment);
}
