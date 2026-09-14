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
/// Stack            -- the top hairline, the highlight, the three items
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

  /// `.cap { border-radius: 20px }`.
  static const double highlightRadius = 20;

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
              child: Stack(
                children: <Widget>[
                  _buildTopHighlight(),
                  _buildHighlight(reducedMotion),
                  _buildItems(reducedMotion),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The 1px lit top edge. A [Border] cannot express it (it would ring all four
  /// sides) and a [BoxShadow] cannot be inset, so it is a real child, clipped
  /// to the capsule by the [ClipRRect] above it.
  Widget _buildTopHighlight() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: topHighlightHeight,
        child: ColoredBox(color: topHighlightColor),
      ),
    );
  }

  /// The capsule riding behind the active tab.
  ///
  /// `.cap { width: calc((100% - 10px)/3); transform: translateX(--i * 100%) }`
  /// becomes a [FractionallySizedBox] a third as wide inside an [AnimatedAlign]
  /// -- for a child of exactly one-third width, `Alignment.x` of -1 / 0 / +1
  /// lands it on slot 0 / 1 / 2 with no arithmetic against the bar's measured
  /// width, so it is correct at every screen size without a [LayoutBuilder].
  Widget _buildHighlight(bool reducedMotion) {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(barPadding),
        // The SDK asserts in debug that every child of a tab-bar node is a
        // tab. This is decoration with no tap and no label; excluding it keeps
        // that assertion honest instead of muted.
        child: ExcludeSemantics(
          child: AnimatedAlign(
            alignment: Alignment(selectedIndex - 1.0, 0),
            duration: reducedMotion ? Duration.zero : highlightDuration,
            curve: highlightCurve,
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              heightFactor: 1,
              child: DecoratedBox(
                key: highlightKey,
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(highlightRadius),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItems(bool reducedMotion) {
    return Padding(
      padding: const EdgeInsets.all(barPadding),
      // container + explicitChildNodes: the three tabs must surface as three
      // distinct children of this node, or the debug tab-bar validator (and
      // every screen reader) sees one merged blob.
      child: Semantics(
        key: tabBarKey,
        role: SemanticsRole.tabBar,
        container: true,
        explicitChildNodes: true,
        child: Row(
          children: <Widget>[
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: _GlassTabItem(
                  key: itemKey(i),
                  glyph: glyphs[i],
                  label: labels[i],
                  // Set on all three, never just the active one: a tab whose
                  // `selected` is absent rather than false fails the SDK's
                  // "a tab needs selected states" assertion.
                  selected: i == selectedIndex,
                  reducedMotion: reducedMotion,
                  onTap: () => onSelected(i),
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
