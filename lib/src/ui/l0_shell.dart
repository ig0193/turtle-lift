import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_screen.dart';
import 'l0_tab_chrome.dart';
import 'glass_tab_bar.dart';
import 'history_root.dart';
import 'muscles_root.dart';
import 'profile_root.dart';
import 'tab_index.dart';
import 'workout_root.dart';
import 'workout_tab_chrome.dart';

/// What one L0 tab contributes to the shell's chrome.
///
/// The shell could switch on the index instead, and today that would be shorter
/// by six lines. It would also be the wrong seam: the Workout header stops
/// being the word "Workout" the moment a session is open — it becomes the
/// editable session title, which is the case [AppScreen.titleWidget]'s own doc
/// comment is written for — and Muscles grows a search affordance. Both of
/// those arrive as a different [L0TabSpec], not as another arm of a `switch`
/// that by then also has to reach for a provider and a controller.
///
/// [title] is not optional even when [titleWidget] is set. It is the header's
/// semantics label: a screen reader has to hear the tab change even when the
/// header is rendering a text field.
@immutable
class L0TabSpec {
  const L0TabSpec({
    required this.title,
    required this.body,
    this.titleWidget,
    this.actions,
  });

  /// The header text, and the header's semantics label.
  final String title;

  /// The tab root. **A body, never a `Scaffold`** — see the three roots.
  final Widget body;

  /// Replaces the header text when the title is not a plain string.
  final Widget? titleWidget;

  /// Header controls this tab adds.
  final List<Widget>? actions;
}

/// The app's one navigation surface: four tab roots under a floating bar.
///
/// **There is exactly one `Scaffold` in the app, and it is this one.** The
/// shell is an [AppScreen.root] rather than a second hand-rolled `Scaffold`, so
/// the pinned-header contract, the gutter and the bottom-inset rule keep a
/// single owner — and the screen users look at most stays inside the net
/// `test/app_screen_test.dart` already casts.
///
/// **The body is not wrapped in a `SafeArea`, and adding one is the tempting
/// bug.** [AppScreen] deliberately has no `SafeArea` either: with
/// `extendBody: true` the `Scaffold` hands the floating bar's height down as a
/// bottom `MediaQuery` padding, which every root then spends on its own
/// scrollable via [screenScrollPadding]. A `SafeArea` here would consume that
/// inset and strip it from the descendant `MediaQuery`, so all three roots
/// would read zero, render perfectly, and hide their last row behind the bar.
/// Nothing throws. Nothing looks wrong until you scroll to the very bottom.
///
/// **Bar visibility is a property of route opacity, not of state.** There is no
/// `RouteObserver`, no `barVisible` provider and no `Navigator.canPop` check
/// here, and adding one would be a misreading rather than an improvement: an
/// opaque page route covers the shell, so the bar goes with it for free, while
/// a modal route — dialog, bottom sheet, date picker — deliberately does not
/// cover it and deliberately leaves the bar on screen. `canPop` cannot tell
/// those two apart, which is exactly the distinction that matters.
///
/// **[IndexedStack] mounts all three roots and keeps them mounted.** That is
/// what preserves each tab's scroll offset and widget state across a switch;
/// "simplifying" it into a `switch` that returns one child looks identical on
/// screen and silently throws that away. With three empty roots the cost is
/// nil — revisit when they hold live queries, not before.
class L0Shell extends ConsumerWidget {
  const L0Shell({super.key});

  /// The four tabs, in bar order. **Add a tab here and in [kL0TabCount].**
  ///
  /// The structural list stays constant; only the Workout tab's *chrome*
  /// varies, and it varies through [workoutTabChromeProvider], which the
  /// Workout feature owns. The shell reads a small value and never learns what
  /// a workout session is.
  static const List<L0TabSpec> tabs = <L0TabSpec>[
    L0TabSpec(title: 'Workout', body: WorkoutRoot()),
    L0TabSpec(title: 'Muscles', body: MusclesRoot()),
    L0TabSpec(title: 'History', body: HistoryRoot()),
    L0TabSpec(title: 'Profile', body: ProfileRoot()),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(
      tabs.length == kL0TabCount &&
          tabs.length == GlassTabBar.labels.length &&
          tabs.length == GlassTabBar.glyphs.length,
      'the tab specs, the tab-index range, the bar labels and the bar glyphs '
      'must agree -- every one of them is indexed by the same tab index',
    );

    // Watched *here*, in the shell's own build, and not inside a Consumer
    // wrapped around the title. `AppScreen.root` takes `title` as a String and
    // feeds it to the header's Semantics label, so a Consumer confined to
    // `titleWidget` would leave a screen reader announcing "Workout" on all
    // three roots while sighted users watch the header change. The extra
    // Scaffold rebuild costs nothing worth having: three tabs, a discrete tap,
    // and the state that must survive is held by IndexedStack keeping its
    // children mounted, not by this widget not rebuilding.
    final index = ref.watch(tabIndexProvider);
    final tab = tabs[index];

    // A coarse selector, deliberately: this build rebuilds the header, the tab
    // stack and the animated bar, so watching the whole session would repaint
    // all of it on every logged set and every keystroke in the title field,
    // from whichever tab the user happens to be on.
    // Index 0 is the Workout tab, which is the only one whose header varies.
    final chrome = index == 0
        ? ref.watch(workoutTabChromeProvider)
        : const L0TabChrome();

    return AppScreen.root(
      title: chrome.title ?? tab.title,
      titleWidget: chrome.titleWidget ?? tab.titleWidget,
      actions: <Widget>[...?tab.actions, ...?chrome.actions],
      // What makes the bar float and what makes every root's bottom clearance
      // real. See the class doc before touching either of these two lines.
      extendBody: true,
      bottomBar: GlassTabBar(
        selectedIndex: index,
        // Fires on every tap, including one on the current tab. Storing the
        // same index again is a no-op in Riverpod; when pop-to-root lands
        // (build-order step 4) it hangs off this callback, which is why the
        // bar reports the repeat rather than swallowing it.
        onSelected: (i) => ref.read(tabIndexProvider.notifier).select(i),
      ),
      body: IndexedStack(
        index: index,
        // Expand, not the default loose fit: each root is a scrollable that has
        // to fill the viewport, because its scroll extent — and therefore
        // whether its last row clears the floating bar — is measured against
        // that height.
        sizing: StackFit.expand,
        children: <Widget>[for (final spec in tabs) spec.body],
      ),
    );
  }
}
