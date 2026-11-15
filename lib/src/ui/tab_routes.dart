import 'diet_root.dart';
import 'l0_shell.dart';
import 'workout_root.dart';
import 'you_root.dart';

/// The Workout tab's index, read off the shell's own tab list so a reordered
/// bar cannot send a reminder or a tap to the wrong tab.
final int kWorkoutTabIndex =
    L0Shell.tabs.indexWhere((tab) => tab.body is WorkoutRoot);

/// The Diet tab's index, found the same way.
final int kDietTabIndex =
    L0Shell.tabs.indexWhere((tab) => tab.body is DietRoot);

/// The You tab's index, found the same way.
final int kYouTabIndex =
    L0Shell.tabs.indexWhere((tab) => tab.body is YouRoot);
