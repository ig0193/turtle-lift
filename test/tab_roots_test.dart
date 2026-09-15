import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/ui/body_diagram.dart';
import 'package:turtle_lift/src/ui/empty_state.dart';
import 'package:turtle_lift/src/ui/history_root.dart';
import 'package:turtle_lift/src/ui/muscle_search_field.dart';
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
  // `exerciseLibraryProvider` reaches `rootBundle` for the shipped exercises,
  // which needs the services binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The floating bar's height, as the Scaffold would report it.
  const barInset = 63.0;

  /// The real shipped library, folded into the index the Muscles root reads.
  ///
  /// **The shipped data rather than fixtures.** The counts this root renders
  /// are the library's own, so a fixture would let the row copy drift from the
  /// 260 exercises the app actually ships and still pass. `main()` builds the
  /// index exactly this way.
  late ExerciseIndex index;

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    index = ExerciseIndex.fromJson(
      await container.read(exerciseLibraryProvider.future),
    );
  });

  /// Every L0 tab root. **Add a root here when you add a root.** The clearance
  /// and scroll contracts below iterate this map; a root missing from it is a
  /// root with no proof that its last item is reachable.
  /// [clearanceHeight] is the viewport the clearance check hosts that root in.
  /// It has to sit in a narrow band: tall enough that the root's last item is
  /// still on screen once the bottom padding is spent, short enough that the
  /// root still overflows and there is a bottom of the scroll to inspect at
  /// all. The two empty-state roots hold a screenful of copy; the Workout
  /// landing holds a list of rows and needs a taller window to satisfy both
  /// ends of that band.
  final roots = <String, ({Widget Function() build, double clearanceHeight})>{
    'WorkoutRoot': (build: () => const WorkoutRoot(), clearanceHeight: 300),
    // The Muscles landing is the tallest root by far -- a search field, a
    // front/back control, a full-height body map and 19 rows -- so it needs
    // the same taller window the Workout landing does. At 120 the map alone
    // overflows the viewport and no row is ever reached.
    'MusclesRoot': (build: () => const MusclesRoot(), clearanceHeight: 300),
    'HistoryRoot': (build: () => const HistoryRoot(), clearanceHeight: 120),
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
    // The Workout root reads providers (the split filter, the user's own
    // templates), so every root in this registry now needs a scope around it --
    // including the geometry tests below, which never look at that content but
    // do mount the widget. No database is needed to *render*: the filter is
    // seeded synchronously and the store is only touched when one is selected.
    //
    // The index override is not optional: `exerciseIndexProvider` throws
    // without one by design, so the Muscles root would not mount at all.
    return ProviderScope(
      overrides: [
        exerciseIndexProvider.overrideWithValue(index),
        // These roots are hosted to check geometry and the empty state, so
        // History starts with no sessions. Its populated form is
        // `test/history_root_test.dart`'s subject.
        historySessionsProvider.overrideWithValue(const <HistorySession>[]),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: height,
              child: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, height),
                  padding: padding,
                ),
                child: root,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A viewport tall enough that nothing is scrolled out of view, for the tests
  /// that are about content rather than geometry.
  Widget hostTall(Widget root) => host(root, height: 640);

  /// The root's own scrollable.
  ///
  /// **Not a bare `find.byType(Scrollable)` any more.** The Muscles landing
  /// carries the app's first text input, and an `EditableText` brings a
  /// scrollable of its own for the caret -- so a bare finder matches two and
  /// throws. The root's is the outer one, and therefore the first in
  /// depth-first order.
  Finder rootScrollable() => find.byType(Scrollable).first;

  ScrollPosition positionOf(WidgetTester tester) =>
      tester.state<ScrollableState>(rootScrollable()).position;

  // --- Content ---------------------------------------------------------

  testWidgets('Workout root lists templates rather than an empty state',
      (tester) async {
    await tester.pumpWidget(hostTall(const WorkoutRoot()));

    expect(find.text('TEMPLATES'), findsOneWidget,
        reason: 'the group label the filter control sits beside');
    expect(find.text('Ad-hoc workout'), findsOneWidget,
        reason: 'the ad-hoc entry sits below every template group');
    expect(find.byType(EmptyState), findsNothing,
        reason: 'eleven templates ship with the app, so this landing has '
            'content on day one -- it has no zero-data condition to be in, and '
            'an empty state here would be the bug');
    expect(find.byType(TabGlyphIcon), findsNothing,
        reason: 'tab-bar icons belong to the bar only');
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

  testWidgets('Muscles root renders the reference landing and has no empty '
      'state', (tester) async {
    await tester.pumpWidget(hostTall(const MusclesRoot()));

    expect(find.byType(MuscleSearchField), findsOneWidget,
        reason: 'the landing leads with the search field (R1)');
    expect(find.byType(BodyDiagram), findsOneWidget,
        reason: 'and carries the body map itself, not a picture of one');
    // The front/back control, not the list label: the map is taller than any
    // viewport, so everything below it is off-screen and unbuilt here. The 19
    // rows are `test/muscles_root_test.dart`'s subject.
    expect(find.text(bodyViewLabel(BodyView.front)), findsOneWidget,
        reason: 'the front/back control sits between the field and the map');
    expect(find.byType(EmptyState), findsNothing,
        reason: 'the Muscles landing is static reference content -- there is '
            'no zero-data condition for it to be empty of');
    expect(find.byType(TabGlyphIcon), findsNothing,
        reason: 'tab-bar icons belong to the bar only');
  });

  testWidgets('the empty-state block holds its mascot slot open above the disc',
      (tester) async {
    // Hosted on History: it is the root that still carries an EmptyState now
    // that the Workout landing lists templates instead.
    await tester.pumpWidget(hostTall(const HistoryRoot()));

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
          entry.value.build(),
          height: entry.value.clearanceHeight,
          padding: const EdgeInsets.only(bottom: barInset),
        ),
      );
      await tester.pump();

      final scrollable = rootScrollable();
      final position = positionOf(tester);
      expect(position.maxScrollExtent, greaterThan(0),
          reason: '${entry.key}: nothing scrolls, so the bottom of the scroll '
              'cannot be inspected -- either the harness viewport grew taller '
              'than the content, or this root stopped spending the bottom '
              'inset on its scrollable, which is most of what makes this '
              'content overflow in the first place');

      // The bottom of the scroll is the only place the failure shows, and
      // reaching it takes more than one jump. `SliverList` *estimates*
      // maxScrollExtent from the average extent of the children it has built
      // so far; the Muscles landing's children are wildly uneven -- a ~600pt
      // body map among 48pt rows -- so the first estimate overshoots the real
      // bottom by thousands of pixels and a single jump lands past the end of
      // the content with nothing laid out to measure. Each jump builds more
      // children and sharpens the estimate, so this settles in two passes and
      // is a no-op for the roots whose rows are all one height.
      for (var pass = 0; pass < 10; pass++) {
        if ((position.pixels - position.maxScrollExtent).abs() < 0.5) break;
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
      }
      expect(position.pixels, moreOrLessEquals(position.maxScrollExtent),
          reason: '${entry.key}: the scroll never settled at its own bottom, '
              'so whatever is measured below is not the last item');

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
        host(
          entry.value.build(),
          padding: const EdgeInsets.only(bottom: barInset),
        ),
      );
      await tester.pump();

      final position = positionOf(tester);
      expect(position.pixels, 0,
          reason: '${entry.key}: a root opens at the top of its content');

      // Well past the drag slop, and deliberately so. The Workout landing now
      // has a tap target (the filter control) sitting under the centre of this
      // viewport, and a movement barely over the slop leaves the tap and the
      // scroll contesting the gesture. A decisive drag is what this test
      // actually means to make.
      await tester.drag(rootScrollable(), const Offset(0, -60));
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
            return entry.value.build();
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
    // Also re-homed to History for the same reason as the mascot slot above.
    await tester.pumpWidget(hostTall(const HistoryRoot()));

    final heading = tester.widget<Text>(find.text('No workouts yet')).style!;
    expect(heading.fontSize, 15, reason: '.empty h3 font-size');
    expect(heading.fontWeight, FontWeight.w600, reason: '.empty h3 weight');

    final body = tester
        .widget<Text>(
          find.text("Finish your first session and it'll show up here."),
        )
        .style!;
    expect(body.fontSize, 12.5, reason: '.empty p font-size');
    expect(body.height, 1.55, reason: '.empty p line-height');
  });
}
