import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How many L0 tabs there are.
///
/// Lives here rather than being read off `GlassTabBar.labels`, because this is
/// the *navigation* fact and that is the bar's *rendering* of it. The shell
/// asserts the two agree (`L0Shell.tabs`), so a fourth tab added to one and not
/// the other fails loudly instead of rendering a bar with an unreachable slot.
const int kL0TabCount = 3;

/// Which L0 tab is showing.
///
/// **A `Notifier`, not a `StateProvider`.** On `flutter_riverpod` 3
/// `StateProvider` is legacy and lives behind
/// `package:flutter_riverpod/legacy.dart` — it is the shape most tutorials
/// still reach for, and importing that file to get it is the tell. `Notifier`
/// needs no codegen either, which is what the repo's Riverpod decision
/// requires.
///
/// **A provider rather than the shell's own `State`.** The index has to be
/// settable from *outside* the shell: finishing a session sends the user to a
/// named tab from a pushed route, and that caller has no handle on the shell's
/// element. Keeping it here means that caller writes one line and the shell
/// rebuilds itself.
class TabIndex extends Notifier<int> {
  /// Workout. The app opens on the tab you came to use.
  @override
  int build() => 0;

  /// Show tab [index].
  ///
  /// Selecting the tab that is already current is deliberately **not** swallowed
  /// here: Riverpod skips the notification anyway when the value is unchanged,
  /// and the gesture itself is not a no-op — a second tap on the current tab is
  /// how "pop to root" / "scroll to top" get wired. That behaviour belongs to
  /// the shell's `onSelected`, which sees every tap; this only stores a number.
  void select(int index) {
    assert(
      index >= 0 && index < kL0TabCount,
      'tab index $index is outside the $kL0TabCount L0 tabs',
    );
    state = index;
  }
}

/// The tab index, named for the thing rather than for the word "provider" —
/// matching `exerciseLibraryProvider` in `lib/src/data/exercise_library.dart`.
final tabIndexProvider = NotifierProvider<TabIndex, int>(TabIndex.new);
