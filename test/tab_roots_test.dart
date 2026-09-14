import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/empty_state.dart';
import 'package:turtle_lift/src/ui/history_root.dart';
import 'package:turtle_lift/src/ui/muscles_root.dart';
import 'package:turtle_lift/src/ui/tab_glyph.dart';
import 'package:turtle_lift/src/ui/workout_root.dart';

/// Two invariants, and both fail silently in the app.
///
/// **Clearance.** The tab bar floats over the content, so the Scaffold hands
/// the bar's height down as a bottom `MediaQuery` padding and each root has to
/// spend it on its own scrollable. A root that forgets renders perfectly: the
/// only symptom is that its last row is unreachable, hidden behind the bar at
/// the very bottom of the scroll — which is exactly where nobody looks during
/// development. So the contract is tested against the `MediaQuery` rather than
/// against one assembled arrangement, and it is tested through a registry of
/// every root, so that a fourth root added without registering it is what
/// fails rather than the check quietly covering three of four screens.
///
/// **The right disc.** The empty-state discs are not the tab-bar icons —
/// History's tab is a clock and its disc is a logbook page. Swapping one for
/// the other compiles and renders a perfectly plausible screen, so these tests
/// assert the glyph itself, not the presence of a disc.
void main() {
  /// The floating bar's height, as the Scaffold would report it.
  const barInset = 63.0;

  /// Every L0 tab root. **Add a root here when you add a root.** The clearance
  /// and scroll contracts below iterate this map; a root missing from it is a
  /// root with no proof that its last item is reachable.
  final roots = <String, Widget Function()>{
    'WorkoutRoot': () => const WorkoutRoot(),
    'MusclesRoot': () => const MusclesRoot(),
    'HistoryRoot': () => const HistoryRoot(),
  };

  /// Hosts a root as the shell does: a bare body inside a fixed viewport, with
  /// [padding] standing in for the safe area plus the floating bar.
  ///
  /// The default height is deliberately tiny. Every root has to overflow it, or
  /// the clearance check would pass on content that never reaches the bottom
  /// edge in the first place.
  Widget host(
    Widget root, {
    double width = 360,
    double height = 80,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    return MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: height,
            child: MediaQuery(
              data: MediaQueryData(size: Size(width, height), padding: padding),
              child: root,
            ),
          ),
        ),
      ),
    );
  }

  /// A viewport tall enough that nothing is scrolled out of view, for the tests
  /// that are about content rather than geometry.
  Widget hostTall(Widget root) => host(root, height: 640);

  ScrollPosition positionOf(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable)).position;

  // --- Content ---------------------------------------------------------

  testWidgets('Workout root renders its empty state on the barbell disc',
      (tester) async {
    await tester.pumpWidget(hostTall(const WorkoutRoot()));

    expect(find.text('Ready when you are'), findsOneWidget,
        reason: 'the Workout empty-state heading, verbatim from the prototype');
    expect(
      find.text('Pick a template for a planned session, or go ad-hoc and add '
          'exercises as you find them.'),
      findsOneWidget,
      reason: 'the Workout empty-state body copy, verbatim from the prototype',
    );

    final glyph = tester.widget<EmptyStateGlyphIcon>(
      find.byType(EmptyStateGlyphIcon),
    );
    expect(glyph.glyph, EmptyStateGlyph.barbell,
        reason: 'the Workout disc is the barbell drawing');
    expect(find.byType(TabGlyphIcon), findsNothing,
        reason: 'the disc is an empty-state glyph, never a tab-bar icon');
  });

  testWidgets('History root renders its empty state on the logbook disc',
      (tester) async {
    await tester.pumpWidget(hostTall(const HistoryRoot()));

    expect(find.text('No workouts yet'), findsOneWidget,
        reason: 'the History empty-state heading, verbatim from the prototype');
    expect(
      find.text("Finish your first session and it'll show up here."),
      findsOneWidget,
      reason: 'the History empty-state body copy, verbatim from the prototype',
    );

    final glyph = tester.widget<EmptyStateGlyphIcon>(
      find.byType(EmptyStateGlyphIcon),
    );
    expect(glyph.glyph, EmptyStateGlyph.logbook,
        reason: "History's disc is a logbook page, not the clock its tab wears "
            '-- the wrong glyph here renders a plausible screen and says '
            'nothing, so the glyph is asserted rather than the disc');
    expect(find.byType(TabGlyphIcon), findsNothing,
        reason: 'TabGlyph.history is the clock and belongs to the bar only');
  });

  testWidgets('Muscles root renders reference copy and has no empty state',
      (tester) async {
    await tester.pumpWidget(hostTall(const MusclesRoot()));

    expect(find.text('Browse by muscle'), findsOneWidget,
        reason: 'the Muscles landing heading');
    expect(
      find.text('Search and the body map arrive with the exercise library.'),
      findsOneWidget,
      reason: 'the Muscles landing placeholder line',
    );
    expect(find.byType(EmptyState), findsNothing,
        reason: 'the Muscles landing is static reference content -- there is '
            'no zero-data condition for it to be empty of');
  });

  testWidgets('the empty-state block holds its mascot slot open above the disc',
      (tester) async {
    await tester.pumpWidget(hostTall(const WorkoutRoot()));

    final slot = find.byKey(EmptyState.mascotSlotKey);
    expect(slot, findsOneWidget,
        reason: 'the reserved mascot band must survive a refactor of the block');
    expect(tester.getSize(slot).height, kEmptyStateMascotSlot,
        reason: 'the band is the full reserved height, not a token gap');
    expect(
      tester.getRect(slot).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(EmptyStateGlyphIcon)).top),
      reason: 'docs/05-mascot-brief.md places the resting turtle above the '
          'empty-state copy, so the band sits above the disc',
    );
  });

  // --- Clearance and scrolling, over the registry -----------------------

  testWidgets("every root's last item clears the floating tab bar",
      (tester) async {
    for (final entry in roots.entries) {
      await tester.pumpWidget(
        // The height is squeezed between two failures. Below 81 -- the
        // bottom padding, kScreenGutter + barInset -- the whole visible band
        // at max scroll is padding and no last item is left on screen to
        // measure. Much above this, the shortest root (Muscles) stops
        // overflowing and maxScrollExtent goes to zero.
        host(
          entry.value(),
          height: 120,
          padding: const EdgeInsets.only(bottom: barInset),
        ),
      );
      await tester.pump();

      final scrollable = find.byType(Scrollable);
      final position = positionOf(tester);
      expect(position.maxScrollExtent, greaterThan(0),
          reason: '${entry.key}: nothing scrolls, so the bottom of the scroll '
              'cannot be inspected -- either the harness viewport grew taller '
              'than the content, or this root stopped spending the bottom '
              'inset on its scrollable, which is most of what makes this '
              'content overflow in the first place');

      // The bottom of the scroll is the only place the failure shows.
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();

      final viewportBottom = tester.getRect(scrollable).bottom;
      final lastItem =
          find.descendant(of: scrollable, matching: find.byType(Text)).last;
      final clearance = viewportBottom - tester.getRect(lastItem).bottom;

      expect(clearance, greaterThanOrEqualTo(barInset),
          reason: '${entry.key}: scrolled to the very end, the last item still '
              'has to sit clear of the floating bar. A root that drops '
              'screenScrollPadding lands it flush against the viewport edge '
              'and hides it behind the bar, with nothing else failing');
    }
  });

  testWidgets('every root scrolls', (tester) async {
    for (final entry in roots.entries) {
      await tester.pumpWidget(
        host(entry.value(), padding: const EdgeInsets.only(bottom: barInset)),
      );
      await tester.pump();

      final position = positionOf(tester);
      expect(position.pixels, 0,
          reason: '${entry.key}: a root opens at the top of its content');

      await tester.drag(find.byType(Scrollable), const Offset(0, -20));
      await tester.pump();

      expect(position.pixels, greaterThan(0),
          reason: '${entry.key}: the root owns a real scrollable, so content '
              'taller than the viewport can be reached');
    }
  });

  testWidgets('every root spends the safe-area inset on its own scrollable',
      (tester) async {
    // The direct guard on the trap in the roots' doc comments: a ListView with
    // no padding absorbs the inset for you, but one that passes any padding of
    // its own does not, so the padding has to carry the inset explicitly.
    for (final entry in roots.entries) {
      late EdgeInsets expected;
      await tester.pumpWidget(
        host(
          Builder(builder: (context) {
            expected = screenScrollPadding(context);
            return entry.value();
          }),
          padding: const EdgeInsets.fromLTRB(11, 47, 13, barInset),
        ),
      );

      final view = tester.widget<ListView>(find.byType(ListView));
      expect(view.padding, expected,
          reason: '${entry.key}: the scrollable pads itself with '
              'screenScrollPadding -- one rule, applied at the scrollable');
      expect((view.padding! as EdgeInsets).bottom, kScreenGutter + barInset,
          reason: '${entry.key}: the bottom edge carries the gutter plus the '
              'floating bar');
    }
  });

  // --- Characterization -------------------------------------------------
  // The block's measurements come straight from `.empty` in
  // prototypes/screens.html. Pinned so a change to them is a deliberate one.

  testWidgets('the disc and its glyph match the prototype', (tester) async {
    await tester.pumpWidget(hostTall(const HistoryRoot()));

    expect(
      tester.getSize(find.byKey(EmptyState.discKey)),
      const Size(kEmptyStateDiscSize, kEmptyStateDiscSize),
      reason: '.empty .ico is a 46px disc',
    );
    expect(tester.getSize(find.byType(EmptyStateGlyphIcon)),
        const Size(kEmptyStateGlyphSize, kEmptyStateGlyphSize),
        reason: '.empty .ico svg is 22px');

    final icon =
        tester.widget<EmptyStateGlyphIcon>(find.byType(EmptyStateGlyphIcon));
    expect(icon.strokeWidth, kEmptyStateGlyphStrokeWidth,
        reason: '.empty .ico svg strokes at 1.6, lighter than the tab bar');
  });

  testWidgets('heading and body use the two empty-state type styles',
      (tester) async {
    await tester.pumpWidget(hostTall(const WorkoutRoot()));

    final heading = tester.widget<Text>(find.text('Ready when you are')).style!;
    expect(heading.fontSize, 15, reason: '.empty h3 font-size');
    expect(heading.fontWeight, FontWeight.w600, reason: '.empty h3 weight');

    final body = tester
        .widget<Text>(find.text(
            'Pick a template for a planned session, or go ad-hoc and add '
            'exercises as you find them.'))
        .style!;
    expect(body.fontSize, 12.5, reason: '.empty p font-size');
    expect(body.height, 1.55, reason: '.empty p line-height');
  });
}
