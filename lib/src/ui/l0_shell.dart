import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'l0_tab_chrome.dart';
import 'stroke_glyph.dart';
import 'glass_tab_bar.dart';
import 'history_root.dart';
import 'muscles_root.dart';
import 'profile_screen.dart';
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

  /// Header controls this tab adds *before* the profile avatar, which is
  /// always the trailing-most control.
  final List<Widget>? actions;
}

/// The app's one navigation surface: three tab roots under a floating bar.
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

  /// The three tabs, in bar order. **Add a tab here and in [kL0TabCount].**
  ///
  /// The structural list stays constant; only the Workout tab's *chrome*
  /// varies, and it varies through [workoutTabChromeProvider], which the
  /// Workout feature owns. The shell reads a small value and never learns what
  /// a workout session is.
  static const List<L0TabSpec> tabs = <L0TabSpec>[
    L0TabSpec(title: 'Workout', body: WorkoutRoot()),
    L0TabSpec(title: 'Muscles', body: MusclesRoot()),
    L0TabSpec(title: 'History', body: HistoryRoot()),
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
      actions: <Widget>[
        ...?tab.actions,
        ...?chrome.actions,
        // Profile is a header control, not a fourth tab. AppScreen appends the
        // trailing gutter spacer after this, and the avatar carries the other
        // 8 itself — so it is wrapped in its own target rather than dropped in
        // as a bare IconButton.
        ProfileAvatarButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
          ),
        ),
      ],
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

/// The circular Profile control in the L0 header.
///
/// Transcribed from `.avatar` in `prototypes/l0-navigation-prototype.html`: a
/// 32pt disc on [AppPalette.surface] with a 1pt [AppPalette.border] ring and a
/// [AppPalette.textSecondary] head-and-shoulders glyph.
///
/// **Both the ring and the glyph flip to accent while pressed** (`.avatar:active
/// { border-color: var(--acc); color: var(--acc) }` — `color` is what the SVG's
/// `stroke: currentColor` resolves to). Tinting only the ring is the easy half
/// to ship, and at 32pt on a dark surface it reads as nothing happening at all.
///
/// **The disc is 32pt but the target is 48.** The visible circle is what the
/// prototype specifies; the padding around it is what makes the control
/// tappable. The 8pt on each side is also the 8 that [AppScreen] assumes an
/// action already carries out of the 18pt gutter, so the disc lands exactly on
/// the gutter line.
///
/// It takes an [onPressed] rather than pushing [ProfileScreen] itself: the
/// shell owns navigation, and a control that knows a route cannot be rendered
/// anywhere else or tested without one.
class ProfileAvatarButton extends StatefulWidget {
  const ProfileAvatarButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  /// `.avatar { width:32px; height:32px }`.
  static const double size = 32;

  /// The tap target: [size] plus 8 on each side. 48 is the accessibility floor.
  static const double tapTarget = 48;

  /// `.avatar { border:1px solid var(--line) }`.
  static const double borderWidth = 1;

  /// `.avatar svg { width:17px; height:17px }`.
  static const double glyphSize = 17;

  /// `.avatar svg { stroke-width:1.8 }`.
  static const double glyphStrokeWidth = 1.8;

  /// Ring and glyph at rest.
  static const Color restingGlyphColor = AppPalette.textSecondary;
  static const Color restingRingColor = AppPalette.border;

  /// Ring **and** glyph while pressed — one colour for both.
  static const Color pressedColor = AppPalette.accentStrong;

  /// What the avatar says it opens.
  ///
  /// **The label is the whole point of this control having one.** The rule that
  /// authored things live behind this avatar (KD1) puts the app's only
  /// template-authoring surface behind a 32pt disc with no words on it, which is
  /// poor discovery for something a new user may want in week one. A label is
  /// half of what pays that cost; the other half is the route from the Workout
  /// tab's template picker.
  ///
  /// **Beside the disc, not beneath it.** The header is a fixed-height
  /// `Scaffold.appBar`, so a second line would either grow it or clip; and the
  /// label sits *inside* the tap target rather than next to it, because a word
  /// that names the destination but does not open it is worse than no word.
  /// The disc keeps its own 32pt size and its own 48pt square inside the row —
  /// only the target's width grows.
  static const String label = 'Profile';

  /// The 32pt disc, so a test can measure it without guessing which box in the
  /// header it is.
  @visibleForTesting
  static const Key circleKey = ValueKey<String>('profile-avatar-circle');

  /// The tappable box around the disc. Its *size* is the accessibility
  /// contract; the disc inside it is smaller than the target on purpose.
  @visibleForTesting
  static const Key tapTargetKey = ValueKey<String>('profile-avatar');

  @override
  State<ProfileAvatarButton> createState() => _ProfileAvatarButtonState();
}

class _ProfileAvatarButtonState extends State<ProfileAvatarButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final tint = _pressed
        ? ProfileAvatarButton.pressedColor
        : ProfileAvatarButton.restingGlyphColor;
    final ring = _pressed
        ? ProfileAvatarButton.pressedColor
        : ProfileAvatarButton.restingRingColor;

    return MergeSemantics(
      child: Semantics(
        button: true,
        label: ProfileAvatarButton.label,
        child: GestureDetector(
          key: ProfileAvatarButton.tapTargetKey,
          // Opaque, so the whole 48pt box is the target rather than the 32pt
          // disc drawn inside it.
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: SizedBox(
            height: ProfileAvatarButton.tapTarget,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // The wrapping Semantics already announces this control as a
                // button named Profile; leaving the glyph's own label in would
                // have a screen reader say it twice.
                ExcludeSemantics(
                  child: Text(
                    ProfileAvatarButton.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.02,
                      color: tint,
                    ),
                  ),
                ),
                SizedBox.square(
                  dimension: ProfileAvatarButton.tapTarget,
                  child: Center(
                    child: Container(
                      key: ProfileAvatarButton.circleKey,
                      width: ProfileAvatarButton.size,
                      height: ProfileAvatarButton.size,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppPalette.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ring,
                          width: ProfileAvatarButton.borderWidth,
                        ),
                      ),
                      child: ProfileGlyphIcon(color: tint),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The head-and-shoulders glyph inside the avatar.
///
/// Hand-painted, like `tab_glyph.dart` and `empty_state.dart`: `CLAUDE.md`
/// rules out an SVG package, and no Material font glyph matches this drawing.
class ProfileGlyphIcon extends StatelessWidget {
  const ProfileGlyphIcon({
    this.size = ProfileAvatarButton.glyphSize,
    this.strokeWidth = ProfileAvatarButton.glyphStrokeWidth,
    this.color = ProfileAvatarButton.restingGlyphColor,
    super.key,
  });

  final double size;
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: ProfileGlyphPainter(strokeWidth: strokeWidth, color: color),
        size: Size.square(size),
      ),
    );
  }
}

/// The painter behind [ProfileGlyphIcon]. Public so a test can read the exact
/// colour it strokes with — the press state is only real if it reaches the
/// canvas.
class ProfileGlyphPainter extends CustomPainter {
  const ProfileGlyphPainter({required this.strokeWidth, required this.color});

  final double strokeWidth;
  final Color color;

  /// Round cap and join, matching `stroke-linecap:round; stroke-linejoin:round`
  /// on `.avatar svg`: the shoulders are an open curve whose ends would read as
  /// chiselled otherwise.
  Paint buildPaint() =>
      strokeGlyphPaint(color: color, strokeWidth: strokeWidth);

  /// The glyph in viewBox units, scaled to [size]. The stroke is applied after
  /// the scale, so [strokeWidth] is in rendered pixels either way.
  Path pathFor(Size size) => scaledGlyphPath(_basePath, size);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(pathFor(size), buildPaint());
  }

  @override
  bool shouldRepaint(ProfileGlyphPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth || oldDelegate.color != color;
}

/// `<circle cx="12" cy="8" r="3.5"/><path d="M5 20c0-3.5 3-6 7-6s7 2.5 7 6"/>`.
///
/// The shoulders are the one curve in the app's hand-painted glyphs. The SVG's
/// smooth-cubic `s` has no `Path` equivalent, so its first control point is
/// written out here as the reflection the spec defines: the previous curve's
/// second control (8,14) mirrored through the join at (12,14) is (16,14).
///
/// Built once and cached — the geometry never changes, and the avatar repaints
/// on every press.
final Path _basePath = Path()
  ..addOval(Rect.fromCircle(center: const Offset(12, 8), radius: 3.5))
  ..moveTo(5, 20)
  ..cubicTo(5, 16.5, 8, 14, 12, 14)
  ..cubicTo(16, 14, 19, 16.5, 19, 20);
