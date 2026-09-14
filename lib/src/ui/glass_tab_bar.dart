import 'package:flutter/material.dart';
// ImageFilterConfig and SemanticsRole are not re-exported by material.dart --
// `widgets.dart` re-exports only `TextSelectionHandleType` from rendering. Drop
// this import and the blur silently falls back to `dart:ui`'s unbounded
// `ImageFilter.blur`, which is exactly the thing the Glass direction rules out.
import 'package:flutter/rendering.dart' show ImageFilterConfig, SemanticsRole;

import '../theme/app_palette.dart';
import 'tab_glyph.dart';

/// The floating L0 tab bar: a translucent capsule that content scrolls *under*.
///
/// **The layer order in [build] is load-bearing, not stylistic.** Read it
/// outermost-in:
///
/// ```
/// Padding          -- insets the capsule from the screen edge
/// DecoratedBox     -- the drop shadow, and ONLY the drop shadow
/// ClipRRect        -- the capsule silhouette
/// BackdropFilter   -- the blur, sampling what is behind the bar
/// DecoratedBox     -- the translucent fill and the inset ring
/// _GlassTabBarBody -- the hairline, the capsule, the items, and the drag
/// ```
///
/// Two of those are easy to "simplify" into a bug:
///
/// * **The shadow sits above the clip.** A [BoxShadow] paints *outside* its own
///   box, so folding it into the inner [DecoratedBox] -- the obvious tidy-up,
///   since that is where the fill already lives -- puts it inside the
///   [ClipRRect] and the clip erases every pixel of it. The bar then floats
///   over nothing.
/// * **The clip is required, not decorative.** `bounded: true` on the blur
///   restricts what the kernel *samples* to the capsule's own bounds so no
///   colour bleeds in from the content beside it. It does not clip the blur's
///   *output*. Without the [ClipRRect] you get a soft rectangular smear
///   escaping the capsule's rounded corners.
///
/// The bar is stateless about which tab is current: [selectedIndex] and
/// [onSelected] come from the shell. Keeping the selection out of here is what
/// lets the shell own navigation and lets this widget be tested in isolation.
/// The one piece of state the bar does own lives in [_GlassTabBarBody] and is
/// not the selection: it is where a finger currently is mid-drag, which no
/// caller can be told about because it does not outlive the gesture.
///
/// **Two gestures reach the same place.** Tapping a tab selects it, and
/// dragging along the bar slides the capsule under the finger and selects
/// whatever it crosses -- the iOS 26 tab bar's behaviour, and the reason the
/// drag is absolute rather than a swipe that steps. See [_GlassTabBarBody].
///
/// Geometry and colour are transcribed from the Glass variant of
/// `prototypes/l0-tabbar-prototype.html`, chosen over Solid and Ember.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  /// Which tab is current. Out of range is not defended against: the shell
  /// owns this value and three tabs is the whole app.
  final int selectedIndex;

  /// Called on every tap, **including a tap on the already-selected tab.**
  /// Re-reporting the current tab is not a no-op higher up -- it is how
  /// "scroll to top" / "pop to root" gestures are wired -- and the semantics
  /// tree requires a live tap action on every tab regardless.
  ///
  /// A drag along the bar reports through here too, but **only when the slot
  /// under the finger changes.** The repeat report is the tap's contract, not
  /// the drag's: a drag that re-sent the current tab every frame would fire
  /// pop-to-root dozens of times in one gesture.
  final ValueChanged<int> onSelected;

  /// The three tabs, in order. Profile is a header avatar, not a tab
  /// (`prototypes/l0-navigation-prototype.html`, variant A).
  static const List<String> labels = <String>['Workout', 'Muscles', 'History'];

  static const List<TabGlyph> glyphs = <TabGlyph>[
    TabGlyph.workout,
    TabGlyph.muscles,
    TabGlyph.history,
  ];

  // --- Geometry (prototype: `.barwrap`, `.bar`, `.cap`, `.bar button`) ------

  /// `.barwrap { padding: 0 16px ... }`.
  static const double horizontalInset = 16;

  /// `.barwrap { padding-bottom: max(14px, env(safe-area-inset-bottom)) }`.
  static const double minimumBottomInset = 14;

  /// `.bar { padding: 5px }` -- the track the highlight rides in.
  static const double barPadding = 5;

  /// `border-radius: 999px`. A number large enough to always resolve to a
  /// stadium at this height, kept literal to match the prototype.
  static const double barRadius = 999;

  /// The highlight's corner radius, derived rather than literal.
  ///
  /// The prototype says `.cap { border-radius: 20px }`, and that is wrong here
  /// for a reason the prototype could not have seen: its bar has no
  /// `overflow: hidden`, so the capsule may spill past the pill's curve
  /// unnoticed. This bar must clip -- the blur requires it -- so a 20px corner
  /// gets visibly sliced. At the far-left and far-right slots the bar's pill
  /// has already curved inward by ~15pt at the capsule's top edge, while the
  /// capsule sits only [barPadding] in, putting its corners outside the clip.
  ///
  /// So the radius follows the concentric-corner rule instead: an inner corner
  /// nests inside an outer one when its radius is the outer radius minus the
  /// gap between them. Both are stadiums here, so that falls out for free --
  /// an oversized radius is clamped to half the box, giving the capsule
  /// (barHeight/2 - barPadding) exactly, at any bar height, with no measuring.
  static const double highlightRadius = barRadius;

  /// `box-shadow: 0 0 0 .5px ... inset`. Flutter has no inset [BoxShadow], so
  /// this ships as a [BoxDecoration.border] instead.
  static const double ringWidth = 0.5;

  /// `box-shadow: 0 1px 0 ... inset`. Also not expressible as a shadow, and
  /// not expressible as a border either (a border would ring all four edges),
  /// so it ships as a 1px-tall child pinned to the top inside the clip.
  static const double topHighlightHeight = 1;

  /// `backdrop-filter: blur(22px)`.
  static const double blurSigma = 22;

  /// `.bar button { padding: 8px 0 7px }`.
  static const EdgeInsets itemPadding = EdgeInsets.only(top: 8, bottom: 7);

  /// `.bar button { gap: 3px }`.
  static const double iconLabelGap = 3;

  /// `.bar span { font-size: 10.5px; font-weight: 600; letter-spacing: .005em }`.
  /// CSS `em` is relative to the font size; Flutter's [TextStyle.letterSpacing]
  /// is absolute, so the multiplication is done here rather than fudged.
  static const double labelSize = 10.5;
  static const double labelLetterSpacing = labelSize * 0.005;

  /// `.bar button:active { transform: scale(.96) }`.
  static const double pressedScale = 0.96;

  // --- Motion --------------------------------------------------------------

  /// `.cap { transition: transform 260ms var(--ease) }`.
  static const Duration highlightDuration = Duration(milliseconds: 260);

  /// `--ease: cubic-bezier(0.23,1,0.32,1)`.
  static const Curve highlightCurve = Cubic(0.23, 1, 0.32, 1);

  /// `transition: color 160ms ease-out` and `stroke-width 160ms ease-out`.
  static const Duration tintDuration = Duration(milliseconds: 160);

  /// The press rebound. Not in the prototype (CSS `:active` is instant); a
  /// frame-or-two ramp is what keeps it from reading as a glitch on device.
  static const Duration pressDuration = Duration(milliseconds: 90);

  /// How far the capsule stretches along its travel, at full drag speed.
  ///
  /// **First pass, pending the App Store reference.** The magnitude is the part
  /// a video settles and reading the spec cannot; the *shape* below is the part
  /// that is structural, and that one is not a guess -- see
  /// [stretchAnchorsToTrailingEdge].
  static const double maxDragStretch = 0.18;

  /// How far the capsule must fall behind its target, in slots, to reach
  /// [maxDragStretch]. Beyond it the stretch saturates rather than growing
  /// without bound.
  ///
  /// **The stretch is read from the capsule's lag, not from the finger's
  /// speed**, and that is what makes it settle correctly. A speed-driven
  /// stretch has nothing to decay it when the finger stops *without* lifting:
  /// no more move events arrive, so the last speed stands and the capsule sits
  /// there stretched under a stationary thumb until it is released. Lag is
  /// self-correcting -- it is zero exactly when the capsule has caught up,
  /// which is the definition of "no longer being pulled" -- and it needs no
  /// ticker to notice.
  static const double lagAtFullStretch = 0.5;

  /// Volume preservation: the share of its horizontal stretch the capsule gives
  /// back in height. A blob pulled longer gets thinner, and a capsule that
  /// stretches without thinning reads as a rectangle being scaled.
  static const double stretchSquash = 0.35;

  /// **The stretch grows from the trailing edge, never from the centre**, and
  /// that is a clip constraint as much as a motion one.
  ///
  /// Growing about the centre pushes the capsule's outer edge past
  /// [barPadding] at the first and last slots, back outside the `ClipRRect` --
  /// the exact bug [highlightRadius] exists to fix, reintroduced through paint
  /// instead of layout. Anchoring at the trailing edge means the capsule only
  /// ever grows in the direction it is travelling, and at an end slot the only
  /// direction it can travel is inward. So the shape that is correct for a
  /// liquid is also the one that cannot escape the clip.
  static const bool stretchAnchorsToTrailingEdge = true;

  /// How quickly the stretch itself eases in and out. Shorter than
  /// [dragFollowDuration]: the stretch is a response to the follow, so a
  /// slower one would still be growing after the capsule had stopped.
  static const Duration stretchDuration = Duration(milliseconds: 70);

  /// How hard the capsule chases the finger during a drag.
  ///
  /// Not zero, and not [highlightDuration]. Zero pins the capsule rigidly to
  /// the touch point, which reads as a sprite being dragged rather than a
  /// liquid the finger is pulling; 260ms is the settle curve and lags so far
  /// behind a moving finger that the bar feels disconnected. At 90ms the
  /// capsule trails by a couple of frames and catches up when the finger
  /// stops -- which is the whole of the effect.
  static const Duration dragFollowDuration = Duration(milliseconds: 90);

  // --- Colour --------------------------------------------------------------
  //
  // Every colour is named, and every one is derived from AppPalette (or black,
  // which docs/00 §12 treats as an overlay rather than a palette entry -- it
  // darkens what is behind it instead of introducing a hue). Naming them is
  // what makes "no other colours" an assertion rather than a hope.
  //
  // These are `static final`, not `static const`: `Color.withValues` is an
  // instance method and cannot appear in a const expression. The alternative --
  // re-typing each palette hex into a `const Color.fromARGB` -- would compile,
  // and would silently keep the old value the day the palette moves.
  // `withOpacity` is deprecated in this SDK; `withValues` is the replacement.

  /// `.v-glass .bar { background: rgba(33,29,24,0.72) }` -- [AppPalette.surface].
  static final Color fillColor = AppPalette.surface.withValues(alpha: 0.72);

  /// `0 0 0 .5px rgba(245,239,232,0.10) inset`.
  static final Color ringColor = AppPalette.textPrimary.withValues(alpha: 0.10);

  /// `0 1px 0 rgba(245,239,232,0.06) inset`.
  static final Color topHighlightColor =
      AppPalette.textPrimary.withValues(alpha: 0.06);

  /// `0 10px 28px rgba(0,0,0,0.42)`.
  static final Color shadowColor =
      const Color(0xFF000000).withValues(alpha: 0.42);

  /// `.v-glass .cap { background: rgba(245,239,232,0.09) }` -- neutral, one
  /// step lighter than the glass. Glass tints with accent; it does not fill
  /// with it (that was Ember, and it lost).
  static final Color highlightColor =
      AppPalette.textPrimary.withValues(alpha: 0.09);

  /// The same capsule while a finger is on it, one step more present.
  ///
  /// The iOS bubble grows when you press it. Growing this one is the obvious
  /// transcription and it is the wrong one here: the capsule already sits only
  /// [barPadding] inside a bar that must clip, so scaling it up pushes its
  /// outer corners back outside the clip at the first and last slots -- the
  /// exact bug the concentric-corner radius above exists to fix. Brightening
  /// costs no geometry and says the same thing.
  static final Color draggingHighlightColor =
      AppPalette.textPrimary.withValues(alpha: 0.14);

  /// `.v-glass .bar button[aria-current=page] { color: var(--acc) }`.
  static const Color activeItemColor = AppPalette.accentStrong;

  /// `.bar button { color: var(--t2) }`.
  static const Color inactiveItemColor = AppPalette.textSecondary;

  /// Every colour this widget paints with, by name, so a test can walk them
  /// all instead of naming them one at a time and missing the next one added.
  @visibleForTesting
  static final Map<String, Color> debugNamedColors = <String, Color>{
    'fillColor': fillColor,
    'ringColor': ringColor,
    'topHighlightColor': topHighlightColor,
    'shadowColor': shadowColor,
    'highlightColor': highlightColor,
    'draggingHighlightColor': draggingHighlightColor,
    'activeItemColor': activeItemColor,
    'inactiveItemColor': inactiveItemColor,
  };

  /// The travelling highlight capsule. Public so a test can measure where it
  /// actually landed -- an indicator that never moves still renders perfectly.
  @visibleForTesting
  static const Key highlightKey = ValueKey<String>('glass-tab-bar-highlight');

  /// The node carrying [SemanticsRole.tabBar].
  @visibleForTesting
  static const Key tabBarKey = ValueKey<String>('glass-tab-bar-semantics');

  /// The tappable box for tab [index]. Its *size* is the accessibility
  /// contract; the glyph and label inside it are much smaller than the target.
  @visibleForTesting
  static Key itemKey(int index) => ValueKey<String>('glass-tab-bar-item-$index');

  /// The blur, plus the saturation lift that stops a translucent dark surface
  /// from washing the content behind it to grey (`saturate(1.6)`).
  ///
  /// `bounded: true` is the iOS-style frosted sample: the kernel reads only
  /// from inside the capsule's own bounds, so the bright content scrolling past
  /// on either side cannot bleed into the chrome. See the class doc for why it
  /// still needs a clip.
  static const ImageFilterConfig glassFilter = ImageFilterConfig.compose(
    outer: ImageFilterConfig(ColorFilter.matrix(saturationMatrix)),
    inner: ImageFilterConfig.blur(
      sigmaX: blurSigma,
      sigmaY: blurSigma,
      bounded: true,
    ),
  );

  /// CSS `saturate(1.6)` as a colour matrix, using the same luminance
  /// coefficients the filter spec does (0.213 / 0.715 / 0.072).
  static const List<double> saturationMatrix = <double>[
    1.4722, -0.4290, -0.0432, 0, 0, //
    -0.1278, 1.1710, -0.0432, 0, 0, //
    -0.1278, -0.4290, 1.5568, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// True when the device is asking for less movement.
  ///
  /// **Both platforms have to be read, and neither is on [MediaQueryData].**
  /// Android reports `disableAnimations`; iOS reports `reduceMotion` as a
  /// separate feature and leaves `disableAnimations` false. `MediaQueryData`
  /// has no `reduceMotion` field at all, and its `disableAnimations` cannot be
  /// overridden by wrapping in a [MediaQuery] -- so the platform dispatcher is
  /// the only place both answers exist.
  static bool prefersReducedMotion(BuildContext context) {
    final features = View.of(context).platformDispatcher.accessibilityFeatures;
    return features.disableAnimations || features.reduceMotion;
  }

  @override
  Widget build(BuildContext context) {
    // The keyboard is up: a floating capsule pinned above a text field is in
    // the way of the thing being typed into. Nothing else in the bar changes,
    // so it simply is not there.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }

    // viewPadding, not padding: padding is zeroed once something up the tree
    // has consumed the inset (a SafeArea, a Scaffold), and the bar would then
    // sit on the home indicator with nothing failing. viewPadding survives that.
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final reducedMotion = prefersReducedMotion(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalInset + viewPadding.left,
        0,
        horizontalInset + viewPadding.right,
        // `max(14px, env(safe-area-inset-bottom))` -- the home indicator when
        // there is one, a deliberate float off the edge when there is not.
        viewPadding.bottom > minimumBottomInset
            ? viewPadding.bottom
            : minimumBottomInset,
      ),
      // The shadow, and only the shadow. See the class doc: below the clip it
      // would be erased entirely.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(barRadius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: shadowColor,
              offset: const Offset(0, 10),
              blurRadius: 28,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(barRadius),
          // Not antiAliasWithSaveLayer: that allocates an offscreen layer every
          // frame for an edge quality difference nobody can see at this radius,
          // and the bar repaints on every scroll frame underneath it.
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filterConfig: glassFilter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(barRadius),
                border: Border.all(color: ringColor, width: ringWidth),
              ),
              child: _GlassTabBarBody(
                selectedIndex: selectedIndex,
                onSelected: onSelected,
                reducedMotion: reducedMotion,
              ),
            ),
          ),
        ),
      ),
    );
  }

}

/// The bar's interior -- the lit top edge, the travelling capsule and the three
/// items -- plus the drag that moves between them.
///
/// **The capsule tracks the finger; it does not wait for the release.** iOS 26's
/// tab bar puts a glass selection bubble under your finger and slides it along
/// the bar as you move, updating the selection live as it crosses each tab.
/// This bar's first version committed on release instead: nothing moved until
/// you lifted, and then it stepped exactly one tab. That is a different
/// interaction wearing the same name -- there is no feedback during the
/// gesture, so there is nothing to aim, and a gesture you cannot aim is one you
/// stop using.
///
/// **The mapping is absolute, not relative**, which is what makes a tap and a
/// drag the same gesture rather than two that must be kept in agreement:
/// the capsule goes to the slot under the finger, so pressing the third tab and
/// lifting selects it, and pressing the third tab and sliding to the first
/// selects the first. Under a relative mapping the same finger position means
/// different tabs depending on where the drag began, and the capsule stops
/// being a thing the user is touching.
///
/// **Crossing two slots in one gesture lands two tabs over.** The old
/// one-step-per-gesture clamp was right for a deferred gesture -- nothing had
/// travelled, so a jump read as a glitch -- and is wrong for this one, where
/// the capsule travelled the whole way under the finger and the "jump" is what
/// the user just watched happen.
///
/// Stateful because the slot under the finger only exists mid-drag.
class _GlassTabBarBody extends StatefulWidget {
  const _GlassTabBarBody({
    required this.selectedIndex,
    required this.onSelected,
    required this.reducedMotion,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool reducedMotion;

  @override
  State<_GlassTabBarBody> createState() => _GlassTabBarBodyState();
}

class _GlassTabBarBodyState extends State<_GlassTabBarBody> {
  /// Which slot the finger is over, fractionally, while a drag is in progress.
  ///
  /// Null when there is no drag, and that null -- rather than a separate bool
  /// -- is what makes the capsule fall back to the selected tab on release.
  double? _dragSlot;

  bool get _dragging => _dragSlot != null;

  /// The last index this drag handed to [_GlassTabBarBody.onSelected].
  ///
  /// **Not `widget.selectedIndex`.** Comparing against the parent's value
  /// assumes the parent echoes every report straight back, synchronously, and
  /// a parent is entitled to do neither -- it may rebuild a frame later, or
  /// refuse the change outright. When it does, the comparison stays true and
  /// the drag re-reports the same tab on every frame it moves. That is how the
  /// first version of this shipped, and the damage is not the duplicate
  /// reports: it is that `onSelected` also carries pop-to-root, so one drag
  /// would fire it ten times.
  int? _lastReported;

  /// The padded box the three items share. One slot is its width over three,
  /// so the drag needs neither [GlassTabBar.barPadding] arithmetic nor a
  /// `LayoutBuilder`: it measures the track that is actually on screen instead
  /// of reconstructing where the track ought to be.
  final GlobalKey _trackKey = GlobalKey(debugLabel: 'glass-tab-bar-track');

  /// The fractional slot under [globalPosition], or null before the track has
  /// been laid out.
  ///
  /// Clamped, not wrapped: dragging past the last tab holds the capsule there
  /// rather than teleporting it back to the first.
  double? _slotAt(Offset globalPosition) {
    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.width <= 0) return null;
    final slotWidth = box.size.width / GlassTabBar.labels.length;
    // -0.5 because slot *centres* are what the capsule aligns to: the centre
    // of slot 0 sits half a slot in from the track's left edge.
    final slot = box.globalToLocal(globalPosition).dx / slotWidth - 0.5;
    return slot.clamp(0.0, GlassTabBar.labels.length - 1.0);
  }

  void _track(Offset globalPosition) {
    final slot = _slotAt(globalPosition);
    if (slot == null) return;

    setState(() => _dragSlot = slot);

    // Seeded at the tab the drag began on, so a gesture that wanders inside
    // one slot reports nothing at all -- see GlassTabBar.onSelected for why a
    // repeat report belongs to the tap and not to this.
    final index = slot.round();
    _lastReported ??= widget.selectedIndex;
    if (index == _lastReported) return;
    _lastReported = index;
    widget.onSelected(index);
  }

  void _endDrag() {
    if (!_dragging) return;
    setState(() {
      _dragSlot = null;
      _lastReported = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Only the drag callbacks are wired, and the recognizer therefore does
      // not claim the arena until the pointer has moved past the touch slop.
      // Claiming any earlier would beat the items' taps on every finger that
      // moves a pixel, and a tap that moves a pixel is still a tap.
      behavior: HitTestBehavior.translucent,
      // The drag starts where the finger already is, so the capsule travels to
      // meet it. There is no separate long-press to arm it: on this bar the
      // press *is* the tap, and arming behind a hold would hide the gesture
      // behind a timer for no gain.
      onHorizontalDragStart: (d) => _track(d.globalPosition),
      onHorizontalDragUpdate: (d) => _track(d.globalPosition),
      onHorizontalDragEnd: (_) => _endDrag(),
      onHorizontalDragCancel: _endDrag,
      child: Stack(
        children: <Widget>[
          _buildTopHighlight(),
          _buildHighlight(),
          _buildItems(),
        ],
      ),
    );
  }

  /// The 1px lit top edge. A [Border] cannot express it (it would ring all four
  /// sides) and a [BoxShadow] cannot be inset, so it is a real child, clipped
  /// to the capsule by the `ClipRRect` above it.
  Widget _buildTopHighlight() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: GlassTabBar.topHighlightHeight,
        child: ColoredBox(color: GlassTabBar.topHighlightColor),
      ),
    );
  }

  /// The capsule riding behind the active tab, or under the finger.
  ///
  /// `.cap { width: calc((100% - 10px)/3); transform: translateX(--i * 100%) }`
  /// becomes a [FractionallySizedBox] a third as wide inside an [AnimatedAlign]
  /// -- for a child of exactly one-third width, `Alignment.x` of -1 / 0 / +1
  /// lands it on slot 0 / 1 / 2 with no arithmetic against the bar's measured
  /// width, so it is correct at every screen size without a [LayoutBuilder].
  /// That the mapping is *linear* is what lets the drag reuse it: a fractional
  /// slot of 1.5 is `Alignment.x` 0.5 and lands exactly halfway between.
  Widget _buildHighlight() {
    final target = _dragSlot ?? widget.selectedIndex.toDouble();

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(GlassTabBar.barPadding),
        // The SDK asserts in debug that every child of a tab-bar node is a
        // tab. This is decoration with no tap and no label; excluding it keeps
        // that assertion honest instead of muted.
        child: ExcludeSemantics(
          // A TweenAnimationBuilder rather than the AnimatedAlign this used to
          // be, for one reason: the builder hands back the capsule's *current*
          // interpolated slot, and the gap between that and the target is the
          // stretch. An AnimatedAlign animates the same number but keeps it to
          // itself, so the stretch would have to be reconstructed from the
          // finger's speed -- see GlassTabBar.lagAtFullStretch for why that
          // version cannot settle.
          //
          // `begin` is left null on purpose: the tween then seeds itself at
          // `end`, so the capsule does not slide in from slot 0 on first build.
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: target),
            duration: widget.reducedMotion
                ? Duration.zero
                : _dragging
                    ? GlassTabBar.dragFollowDuration
                    : GlassTabBar.highlightDuration,
            // The settle curve decelerates hard, which is right for a tap and
            // wrong while a finger is still moving: under a drag it reads as
            // the capsule repeatedly braking. easeOut is the follow.
            curve: _dragging ? Curves.easeOut : GlassTabBar.highlightCurve,
            builder: (context, slot, child) {
              // How far the capsule still has to go. Zero when it has caught
              // up, and signed, which is also the direction of travel.
              final lag = target - slot;
              final pull = widget.reducedMotion
                  ? 0.0
                  : (lag.abs() / GlassTabBar.lagAtFullStretch).clamp(0.0, 1.0);
              final stretch = pull * GlassTabBar.maxDragStretch;

              return Align(
                alignment: Alignment(slot - 1.0, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / 3,
                  heightFactor: 1,
                  child: Transform(
                    // Anchored at the trailing edge, so the capsule only ever
                    // grows the way it is going -- and at an end slot the only
                    // way it can go is inward, which is what keeps the stretch
                    // inside the clip. See
                    // GlassTabBar.stretchAnchorsToTrailingEdge.
                    alignment: lag >= 0
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    transform: Matrix4.diagonal3Values(
                      1 + stretch,
                      1 - stretch * GlassTabBar.stretchSquash,
                      1,
                    ),
                    // Paint-only: the capsule's layout size is untouched, so
                    // the slot it occupies and the geometry the tests measure
                    // stay exactly what they were.
                    transformHitTests: false,
                    child: child,
                  ),
                ),
              );
            },
            // Built once and reused across every frame of the travel -- the
            // capsule's decoration does not depend on where it is.
            child: AnimatedContainer(
              key: GlassTabBar.highlightKey,
              duration:
                  widget.reducedMotion ? Duration.zero : GlassTabBar.tintDuration,
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: _dragging
                    ? GlassTabBar.draggingHighlightColor
                    : GlassTabBar.highlightColor,
                borderRadius: BorderRadius.circular(GlassTabBar.highlightRadius),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItems() {
    return Padding(
      // The drag measures this box. Same geometry as the highlight's padding
      // above, deliberately: the capsule and the slots have to agree about
      // where a slot is, and they agree by sharing one track.
      key: _trackKey,
      padding: const EdgeInsets.all(GlassTabBar.barPadding),
      // container + explicitChildNodes: the three tabs must surface as three
      // distinct children of this node, or the debug tab-bar validator (and
      // every screen reader) sees one merged blob.
      child: Semantics(
        key: GlassTabBar.tabBarKey,
        role: SemanticsRole.tabBar,
        container: true,
        explicitChildNodes: true,
        child: Row(
          children: <Widget>[
            for (var i = 0; i < GlassTabBar.labels.length; i++)
              Expanded(
                child: _GlassTabItem(
                  key: GlassTabBar.itemKey(i),
                  glyph: GlassTabBar.glyphs[i],
                  label: GlassTabBar.labels[i],
                  // Set on all three, never just the active one: a tab whose
                  // `selected` is absent rather than false fails the SDK's
                  // "a tab needs selected states" assertion.
                  selected: i == widget.selectedIndex,
                  reducedMotion: widget.reducedMotion,
                  onTap: () => widget.onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One tab: glyph over label, tinted and thickened together.
///
/// The tint and the stroke weight are driven by a single 0 → 1 value rather
/// than two animations, because the prototype gives both the same 160ms
/// `ease-out` and a colour that arrives before or after the weight reads as a
/// wobble.
class _GlassTabItem extends StatefulWidget {
  const _GlassTabItem({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.reducedMotion,
    required this.onTap,
    super.key,
  });

  final TabGlyph glyph;
  final String label;
  final bool selected;
  final bool reducedMotion;
  final VoidCallback onTap;

  @override
  State<_GlassTabItem> createState() => _GlassTabItemState();
}

class _GlassTabItemState extends State<_GlassTabItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final tint =
        widget.reducedMotion ? Duration.zero : GlassTabBar.tintDuration;

    return MergeSemantics(
      child: Semantics(
        role: SemanticsRole.tab,
        selected: widget.selected,
        child: GestureDetector(
          // Opaque, so the whole column-width slot is the target rather than
          // the ~22pt glyph and the ~45pt label inside it.
          behavior: HitTestBehavior.opaque,
          // Wired even when this tab is already selected: see
          // GlassTabBar.onSelected.
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: AnimatedScale(
            scale: _pressed ? GlassTabBar.pressedScale : 1.0,
            duration: widget.reducedMotion
                ? Duration.zero
                : GlassTabBar.pressDuration,
            curve: Curves.easeOut,
            child: TweenAnimationBuilder<double>(
              // begin is left null on purpose: TweenAnimationBuilder then seeds
              // itself at `end`, so the bar does not play a tint-in for the
              // already-selected tab the first time it is built.
              tween: Tween<double>(end: widget.selected ? 1.0 : 0.0),
              duration: tint,
              curve: Curves.easeOut,
              builder: (context, t, _) {
                final color = Color.lerp(
                  GlassTabBar.inactiveItemColor,
                  GlassTabBar.activeItemColor,
                  t,
                )!;
                return Padding(
                  padding: GlassTabBar.itemPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TabGlyphIcon(
                        widget.glyph,
                        strokeWidth: kTabGlyphStrokeWidth +
                            (kTabGlyphSelectedStrokeWidth -
                                    kTabGlyphStrokeWidth) *
                                t,
                        color: color,
                      ),
                      const SizedBox(height: GlassTabBar.iconLabelGap),
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: GlassTabBar.labelSize,
                          fontWeight: FontWeight.w600,
                          letterSpacing: GlassTabBar.labelLetterSpacing,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
