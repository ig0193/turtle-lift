import 'dart:ui' as ui show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/glass_tab_bar.dart';
import 'package:turtle_lift/src/ui/tab_glyph.dart';

/// The tab bar is the one widget on screen the whole time, so the things it can
/// get wrong are the things nobody notices and everybody feels:
///
/// * a highlight that never travels -- the bar still looks perfect,
/// * a tap on the current tab that reports nothing, killing pop-to-root,
/// * an off-palette colour, invisible at 0.09 alpha,
/// * three tabs a screen reader hears as one blob,
/// * 260ms of motion played to someone who asked the OS for none,
/// * a capsule floating on top of the keyboard.
///
/// None of those throw. Each is asserted directly below.
void main() {
  /// Hosts the bar pinned to the bottom of a screen.
  ///
  /// The [MediaQuery] override sits *immediately* around the bar rather than
  /// above the [MaterialApp]: an app-level one is replaced by
  /// `MediaQuery.fromView`, and a Scaffold-level one can be rewritten by the
  /// Scaffold on its way down. This way the bar reads exactly what is set here.
  Widget host(
    Widget bar, {
    EdgeInsets viewPadding = EdgeInsets.zero,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) {
    return MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Stack(
          children: <Widget>[
            const SizedBox.expand(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    viewPadding: viewPadding,
                    viewInsets: viewInsets,
                  ),
                  child: bar,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The bar's own subtree, so a finder can never pick up a Scaffold's or a
  /// Material's identically-typed internals.
  Finder inBar(Finder matching) =>
      find.descendant(of: find.byType(GlassTabBar), matching: matching);

  /// Narrows the window to the smallest phone the app has to survive.
  void useNarrowScreen(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 780);
    addTearDown(tester.view.reset);
  }

  group('rendering and taps', () {
    testWidgets('renders the three tabs, in order', (tester) async {
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 0, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'the bar must lay out clean');
      for (final label in const <String>['Workout', 'Muscles', 'History']) {
        expect(find.text(label), findsOneWidget,
            reason: 'the $label tab is missing');
      }
      expect(find.byType(TabGlyphIcon), findsNWidgets(3),
          reason: 'each tab carries exactly one stroked glyph');
    });

    testWidgets('tapping a tab reports its index', (tester) async {
      final reported = <int>[];
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 0, onSelected: reported.add)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(GlassTabBar.itemKey(1)));
      await tester.pumpAndSettle();

      expect(reported, <int>[1], reason: 'the second tab must report index 1');
    });

    testWidgets('tapping the already-selected tab still reports it',
        (tester) async {
      // Not a no-op higher up: this is the gesture that pops a tab to its root
      // or scrolls it to the top, and swallowing it here kills both silently.
      final reported = <int>[];
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 2, onSelected: reported.add)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(GlassTabBar.itemKey(2)));
      await tester.pumpAndSettle();

      expect(reported, <int>[2],
          reason: 'a tap on the current tab must still be reported');
    });

    testWidgets('every tab is at least a 48x48 target on a 320pt screen',
        (tester) async {
      useNarrowScreen(tester);
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 0, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < GlassTabBar.labels.length; i++) {
        final size = tester.getSize(find.byKey(GlassTabBar.itemKey(i)));
        expect(size.width, greaterThanOrEqualTo(48),
            reason: 'tab $i is narrower than the minimum touch target');
        expect(size.height, greaterThanOrEqualTo(48),
            reason: 'tab $i is shorter than the minimum touch target');
      }
    });

    testWidgets('the three labels fit at 320pt without overflowing',
        (tester) async {
      useNarrowScreen(tester);
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 0, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'a RenderFlex overflow at the narrowest supported width');
      for (final label in GlassTabBar.labels) {
        expect(find.text(label), findsOneWidget,
            reason: '$label must still render at 320pt');
      }
    });

    testWidgets('the bar is not shown while the keyboard is up',
        (tester) async {
      await tester.pumpWidget(
        host(
          GlassTabBar(selectedIndex: 0, onSelected: (_) {}),
          viewInsets: const EdgeInsets.only(bottom: 336),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workout'), findsNothing,
          reason: 'a floating capsule above the keyboard sits on top of the '
              'field being typed into');
      expect(tester.getSize(find.byType(GlassTabBar)).height, 0,
          reason: 'the hidden bar must reserve no height either');
    });
  });

  group('tint', () {
    testWidgets('only the selected tab is accented', (tester) async {
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 0, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      // Packed ARGB, not Color identity: the tint is interpolated, so the
      // settled value is the same colour rebuilt from floats and `==` fails on
      // it even when it is exactly right.
      for (var i = 0; i < GlassTabBar.labels.length; i++) {
        final expected =
            i == 0 ? AppPalette.accentStrong : AppPalette.textSecondary;

        final glyph =
            tester.widget<TabGlyphIcon>(find.byType(TabGlyphIcon).at(i));
        expect(glyph.color.toARGB32(), expected.toARGB32(),
            reason: 'tab $i glyph colour');

        final label =
            tester.widget<Text>(find.text(GlassTabBar.labels[i])).style!;
        expect(label.color!.toARGB32(), expected.toARGB32(),
            reason: 'tab $i label colour');
      }
    });

    testWidgets('the selected glyph carries the heavier stroke',
        (tester) async {
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 1, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      final widths = <double>[
        for (var i = 0; i < GlassTabBar.labels.length; i++)
          tester
              .widget<TabGlyphIcon>(find.byType(TabGlyphIcon).at(i))
              .strokeWidth,
      ];

      expect(widths[1], moreOrLessEquals(kTabGlyphSelectedStrokeWidth),
          reason: 'the selected glyph is drawn at 2.2');
      expect(widths[0], moreOrLessEquals(kTabGlyphStrokeWidth),
          reason: 'an unselected glyph stays at 1.7');
      expect(widths[2], moreOrLessEquals(kTabGlyphStrokeWidth),
          reason: 'an unselected glyph stays at 1.7');
    });
  });

  group('the travelling highlight', () {
    testWidgets('moves from the first slot to the third', (tester) async {
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 0, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      final capsule = find.byKey(GlassTabBar.highlightKey);
      final before = tester.getTopLeft(capsule).dx;
      final slotWidth = tester.getSize(capsule).width;

      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 2, onSelected: (_) {})),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final midTravel = tester.getTopLeft(capsule).dx;
      expect(midTravel, greaterThan(before),
          reason: 'the highlight must travel, not cut');

      await tester.pumpAndSettle();

      // Derived from the capsule's own measured width rather than a literal,
      // so the assertion holds at every screen size.
      expect(tester.getTopLeft(capsule).dx,
          moreOrLessEquals(before + 2 * slotWidth, epsilon: 0.5),
          reason: 'the highlight must settle over the third tab');
      expect(tester.getTopLeft(capsule).dx, greaterThan(midTravel),
          reason: 'it stopped short of the third slot');
    });

    testWidgets('sits over the selected tab from the very first frame',
        (tester) async {
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 1, onSelected: (_) {})),
      );
      await tester.pump();

      final centre = tester.getCenter(find.byKey(GlassTabBar.highlightKey)).dx;
      final tabCentre = tester.getCenter(find.byKey(GlassTabBar.itemKey(1))).dx;

      expect(centre, moreOrLessEquals(tabCentre, epsilon: 0.5),
          reason: 'the bar must not animate the highlight in on first build');
    });
  });

  group('drag along the bar', () {
    /// The capsule follows the finger and the selection commits as it crosses
    /// each slot -- the iOS 26 tab bar's gesture, not a swipe that steps on
    /// release. The tests below cover the tracking, the live commit, crossing
    /// more than one slot, both ends, and -- most importantly -- that a tap
    /// still taps.

    /// Hosts a bar whose selection actually updates, the way the shell does.
    ///
    /// The drag is a feedback loop -- the bar reports, the parent rebuilds, the
    /// tints and the capsule's resting place follow -- and a host that recorded
    /// the report without applying it would test only half of that. Every
    /// index the bar reports lands in [reported], in order.
    Widget liveHost(int initialIndex, List<int> reported) {
      var index = initialIndex;
      return StatefulBuilder(
        builder: (context, setState) => host(
          GlassTabBar(
            selectedIndex: index,
            onSelected: (i) {
              reported.add(i);
              setState(() => index = i);
            },
          ),
        ),
      );
    }

    /// Centre of tab [index], in global coordinates.
    Offset tabCentre(WidgetTester tester, int index) =>
        tester.getCenter(find.byKey(GlassTabBar.itemKey(index)));

    /// Presses at [from] and slides to [to] in steps, so the gesture produces
    /// real intermediate positions rather than one teleport. Returns the
    /// still-open gesture: the caller decides when the finger lifts, because
    /// what the capsule does *during* the drag is half of what is being tested.
    Future<TestGesture> dragAcross(
      WidgetTester tester,
      Offset from,
      Offset to, {
      int steps = 12,
    }) async {
      final gesture = await tester.startGesture(from);
      final step = (to - from) / steps.toDouble();
      for (var i = 0; i < steps; i++) {
        await gesture.moveBy(step);
        await tester.pump(const Duration(milliseconds: 16));
      }
      return gesture;
    }

    testWidgets('the capsule follows the finger before it is lifted',
        (tester) async {
      // The regression this guards is the whole point of the rework: a gesture
      // that only commits on release leaves the bar looking frozen while the
      // user drags, so there is nothing to aim and no reason to trust it.
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 0, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      final capsule = find.byKey(GlassTabBar.highlightKey);
      final atRest = tester.getCenter(capsule).dx;

      final gesture = await dragAcross(
        tester,
        tabCentre(tester, 0),
        tabCentre(tester, 2),
      );

      expect(tester.getCenter(capsule).dx, greaterThan(atRest + 1),
          reason: 'the capsule must have travelled while the finger is still '
              'down, not waited for the release');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the selection commits as the finger crosses each slot',
        (tester) async {
      final reported = <int>[];
      await tester.pumpWidget(liveHost(0, reported));
      await tester.pumpAndSettle();

      final gesture = await dragAcross(
        tester,
        tabCentre(tester, 0),
        tabCentre(tester, 2),
      );

      expect(reported, <int>[1, 2],
          reason: 'each slot the finger crosses is reported, in order, while '
              'the finger is still down -- one report per slot, not one per '
              'frame');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('crossing two slots in one gesture lands two tabs over',
        (tester) async {
      // Deliberately the opposite of the old one-step-per-gesture rule. That
      // clamp was right when nothing moved until release -- a jump read as a
      // glitch. Here the capsule travelled the whole way under the finger, so
      // stopping it a slot short would be the glitch.
      final reported = <int>[];
      await tester.pumpWidget(liveHost(0, reported));
      await tester.pumpAndSettle();

      final gesture = await dragAcross(
        tester,
        tabCentre(tester, 0),
        tabCentre(tester, 2),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(reported.last, 2, reason: 'the finger ended over the third tab');
    });

    testWidgets('dragging back before lifting lands where the finger stopped',
        (tester) async {
      // The capsule is absolute: it is wherever the finger is. A drag out to
      // the last tab and back must therefore end on the first, and must not
      // remember the furthest slot it touched.
      final reported = <int>[];
      await tester.pumpWidget(liveHost(0, reported));
      await tester.pumpAndSettle();

      final gesture = await dragAcross(
        tester,
        tabCentre(tester, 0),
        tabCentre(tester, 2),
      );
      // Same gesture, dragged back. moveBy is relative, so this walks home.
      final back = tabCentre(tester, 0) - tabCentre(tester, 2);
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(back / 12);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(reported.last, 0,
          reason: 'the selection follows the finger rather than latching on '
              'the furthest tab the gesture reached');
    });

    testWidgets('dragging past the last tab holds there instead of wrapping',
        (tester) async {
      final reported = <int>[];
      await tester.pumpWidget(liveHost(1, reported));
      await tester.pumpAndSettle();

      final capsule = find.byKey(GlassTabBar.highlightKey);
      final gesture = await dragAcross(
        tester,
        tabCentre(tester, 1),
        // Well past the right edge of the bar.
        tabCentre(tester, 2) + const Offset(400, 0),
      );

      expect(reported, <int>[2],
          reason: 'it must stop at the last tab, and report it once however '
              'far past the edge the finger goes');
      expect(
        tester.getCenter(capsule).dx,
        moreOrLessEquals(tabCentre(tester, 2).dx, epsilon: 1),
        reason: 'the capsule clamps to the last slot rather than sliding out '
            'of the bar',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a drag that crosses no slot reports nothing', (tester) async {
      // Load-bearing: a repeat report is the *tap's* contract -- it is how
      // pop-to-root is wired -- so a drag that re-sent the current tab on
      // every frame would fire it dozens of times in one gesture.
      final reported = <int>[];
      await tester.pumpWidget(liveHost(1, reported));
      await tester.pumpAndSettle();

      final centre = tabCentre(tester, 1);
      final gesture = await dragAcross(
        tester,
        centre,
        // Past the touch slop, so a drag really starts, but nowhere near the
        // neighbouring slot centres.
        centre + const Offset(30, 0),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(reported, isEmpty,
          reason: 'the slot under the finger never changed');
    });

    /// The capsule's horizontal scale, as actually painted. The stretch is a
    /// Transform, so it never reaches `getSize` -- a test that measured the
    /// layout box would pass on a bar that does not stretch at all.
    double paintedScaleX(WidgetTester tester) {
      final transform = tester.widget<Transform>(find.ancestor(
        of: find.byKey(GlassTabBar.highlightKey),
        matching: find.byType(Transform),
      ));
      return transform.transform.storage[0];
    }

    testWidgets('the capsule stretches while it is chasing the finger',
        (tester) async {
      final reported = <int>[];
      await tester.pumpWidget(liveHost(0, reported));
      await tester.pumpAndSettle();

      expect(paintedScaleX(tester), moreOrLessEquals(1, epsilon: 0.001),
          reason: 'at rest the capsule is exactly one slot wide');

      final gesture = await dragAcross(
        tester,
        tabCentre(tester, 0),
        tabCentre(tester, 2),
        steps: 4, // Few, large steps: a fast drag, so the capsule falls behind.
      );

      expect(paintedScaleX(tester), greaterThan(1.02),
          reason: 'the capsule must stretch along its travel while it is '
              'still catching up with the finger');

      await gesture.up();
      await tester.pumpAndSettle();

      expect(paintedScaleX(tester), moreOrLessEquals(1, epsilon: 0.001),
          reason: 'and must come back to one slot once it has settled');
    });

    testWidgets('a finger that stops without lifting settles the capsule',
        (tester) async {
      // The regression a speed-driven stretch cannot avoid: when the finger
      // stops moving but stays down, no further move events arrive, so a
      // stretch read from the last speed stays frozen at full extension under
      // a stationary thumb. Read from the capsule's lag it decays on its own.
      final reported = <int>[];
      await tester.pumpWidget(liveHost(0, reported));
      await tester.pumpAndSettle();

      final gesture = await dragAcross(
        tester,
        tabCentre(tester, 0),
        tabCentre(tester, 2),
        steps: 4,
      );
      expect(paintedScaleX(tester), greaterThan(1.02),
          reason: 'precondition: it is stretched mid-drag');

      // Finger still down, simply not moving. Long enough for the follow to
      // finish, and not one frame of it is a new pointer event.
      await tester.pump(const Duration(milliseconds: 400));

      expect(paintedScaleX(tester), moreOrLessEquals(1, epsilon: 0.01),
          reason: 'the capsule caught up, so nothing is pulling it any more');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the stretch grows inward at the last slot', (tester) async {
      // Anchoring the stretch at the capsule's centre would push its outer
      // edge past the bar padding and back outside the ClipRRect at the end
      // slots -- the clipped-corner bug, reintroduced through paint. Anchored
      // at the trailing edge it can only grow the way it is travelling.
      final reported = <int>[];
      await tester.pumpWidget(liveHost(0, reported));
      await tester.pumpAndSettle();

      final barRight = tester.getRect(find.byType(ClipRRect).first).right;
      final gesture = await dragAcross(
        tester,
        tabCentre(tester, 0),
        tabCentre(tester, 2),
        steps: 4,
      );

      final painted = tester.getRect(find.byKey(GlassTabBar.highlightKey));
      // getRect is the layout box; the stretch is painted from the left edge
      // outward by (scaleX - 1) of that width.
      final paintedRight =
          painted.left + painted.width * paintedScaleX(tester);

      expect(paintedRight, lessThanOrEqualTo(barRight),
          reason: 'the stretched capsule must stay inside the bar it is '
              'clipped by');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the drag gesture does not swallow taps', (tester) async {
      // The regression that matters: a drag recognizer that claims the arena
      // early beats the items' taps on any finger that moves a pixel.
      final reported = <int>[];
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 0, onSelected: reported.add)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(GlassTabBar.itemKey(2)));
      await tester.pumpAndSettle();

      expect(reported, <int>[2], reason: 'tapping a tab still selects it');
    });

    testWidgets('a movement inside the touch slop stays a tap', (tester) async {
      // A thumb drifting a few pixels on its way to a tab must not become a
      // drag -- below the slop no drag is recognized at all, so the tap wins.
      final reported = <int>[];
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 0, onSelected: reported.add)),
      );
      await tester.pumpAndSettle();

      await tester.drag(
          find.byKey(GlassTabBar.itemKey(0)), const Offset(-10, 0));
      await tester.pumpAndSettle();

      expect(reported, <int>[0],
          reason: 'it stays a tap on the tab under the finger');
    });
  });

  group('reduced motion', () {
    /// Both platforms assert the same thing. 20ms is a margin, not a
    /// discriminator: the bar sets the duration to zero outright, and the
    /// framework's own `disableAnimations` scaling would give 260 x 0.05 =
    /// 13ms, so either implementation has settled by 20ms. What the threshold
    /// does catch is the failure that matters -- a bar that ignores reduced
    /// motion entirely and plays the full 260ms travel.
    Future<void> expectHighlightSnaps(WidgetTester tester) async {
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 0, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      final capsule = find.byKey(GlassTabBar.highlightKey);
      final before = tester.getTopLeft(capsule).dx;
      final slotWidth = tester.getSize(capsule).width;

      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 2, onSelected: (_) {})),
      );
      await tester.pump(const Duration(milliseconds: 20));

      expect(tester.getTopLeft(capsule).dx,
          moreOrLessEquals(before + 2 * slotWidth, epsilon: 0.5),
          reason: 'the highlight must already be at the third tab rather '
              'than still travelling');
      expect(tester.hasRunningAnimations, isFalse,
          reason: 'nothing may still be animating under reduced motion');
    }

    testWidgets('Android: disableAnimations snaps the highlight',
        (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await expectHighlightSnaps(tester);
    });

    testWidgets('iOS: reduceMotion snaps the highlight', (tester) async {
      // iOS reports this flag and leaves `disableAnimations` false, so a bar
      // that checked only `disableAnimations` -- or only MediaQuery, which has
      // no `reduceMotion` field at all -- would animate anyway.
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await expectHighlightSnaps(tester);
    });

    testWidgets('motion is on by default', (tester) async {
      // The control. Without it, both tests above would pass on a bar that
      // never animates at all.
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 0, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      final capsule = find.byKey(GlassTabBar.highlightKey);
      final before = tester.getTopLeft(capsule).dx;
      final slotWidth = tester.getSize(capsule).width;

      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 2, onSelected: (_) {})),
      );
      await tester.pump(const Duration(milliseconds: 20));

      expect(tester.getTopLeft(capsule).dx, lessThan(before + 2 * slotWidth - 1),
          reason: '20ms into a 260ms travel the highlight is still on its way');
      await tester.pumpAndSettle();
    });
  });

  group('palette', () {
    testWidgets('every colour the bar names comes from the palette',
        (tester) async {
      // docs/00 §12: "No other colours." The bar is the one widget that layers
      // alpha over the palette, which is exactly where an invented `rgba()`
      // hides -- at 0.09 opacity nobody can see the difference.
      final allowed = <int>{
        for (final colour in const <Color>[
          AppPalette.pageBackground,
          AppPalette.surface,
          AppPalette.border,
          AppPalette.mutedSurface,
          AppPalette.textPrimary,
          AppPalette.textSecondary,
          AppPalette.textMuted,
          AppPalette.accentStrong,
          AppPalette.accentLight,
          AppPalette.onAccent,
          AppPalette.danger,
        ])
          colour.toARGB32(),
        // Black is an overlay, not a hue: the drop shadow darkens whatever is
        // behind the bar rather than introducing a colour.
        0xFF000000,
      };

      expect(GlassTabBar.debugNamedColors, isNotEmpty,
          reason: 'the bar must name its colours for this test to mean '
              'anything');
      GlassTabBar.debugNamedColors.forEach((name, colour) {
        expect(allowed.contains(colour.withValues(alpha: 1).toARGB32()), isTrue,
            reason:
                'GlassTabBar.$name is not a palette colour at full opacity');
      });
    });
  });

  group('capsule geometry', () {
    testWidgets('the highlight nests inside the bar instead of being clipped',
        (tester) async {
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 0, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      final cap = tester.getRect(find.byKey(GlassTabBar.highlightKey));
      final bar = tester.getRect(find.byType(ClipRRect).first);

      // Concentric corners: an inner corner nests inside an outer one when its
      // radius is the outer radius minus the gap. Both are stadiums, so the
      // capsule's effective radius is half its height, and that must equal the
      // bar's half-height minus the padding between them. Get this wrong -- as
      // the prototype's literal 20 does -- and the capsule's outer corners
      // fall outside the bar's curve at the first and last slots, where the
      // ClipRRect the blur requires slices them off.
      expect(cap.height / 2, bar.height / 2 - GlassTabBar.barPadding,
          reason: 'the capsule must be exactly concentric with the bar');

      // And the gap is the same on every side it touches.
      expect(cap.left - bar.left, GlassTabBar.barPadding);
      expect(cap.top - bar.top, GlassTabBar.barPadding);
      expect(bar.bottom - cap.bottom, GlassTabBar.barPadding);
    });

    testWidgets('the highlight is exactly one tab slot', (tester) async {
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 1, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      final cap = tester.getRect(find.byKey(GlassTabBar.highlightKey));
      final slot = tester.getRect(find.byKey(GlassTabBar.itemKey(1)));

      // Edge by edge with a tolerance, not Rect equality: a third of the track
      // is not exact in binary, so the two rects differ in the last bits while
      // being the same rectangle on screen.
      const tolerance = 0.01;
      expect(cap.left, moreOrLessEquals(slot.left, epsilon: tolerance),
          reason: 'the capsule sits on the selected tab');
      expect(cap.right, moreOrLessEquals(slot.right, epsilon: tolerance),
          reason: 'neither wider nor narrower than the slot it marks');
      expect(cap.top, moreOrLessEquals(slot.top, epsilon: tolerance));
      expect(cap.bottom, moreOrLessEquals(slot.bottom, epsilon: tolerance));
    });
  });

  group('semantics', () {
    testWidgets('three tabs under one tab bar, exactly one selected',
        (tester) async {
      // Disposed at the end of the body, not via addTearDown: the framework
      // verifies no SemanticsHandle is outstanding before tearDowns run, so a
      // deferred dispose fails the test it was meant to clean up after.
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 1, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      final barNode = tester.getSemantics(find.byKey(GlassTabBar.tabBarKey));
      expect(barNode.getSemanticsData().role, SemanticsRole.tabBar,
          reason: 'the row of tabs must announce itself as a tab bar');

      final tabs = <SemanticsNode>[];
      barNode.visitChildren((node) {
        tabs.add(node);
        return true;
      });

      expect(tabs, hasLength(3),
          reason: 'the highlight capsule must not surface as a fourth child, '
              'and the three tabs must not merge into one');

      for (var i = 0; i < tabs.length; i++) {
        final data = tabs[i].getSemanticsData();
        expect(data.role, SemanticsRole.tab, reason: 'child $i is not a tab');
        expect(data.hasAction(SemanticsAction.tap), isTrue,
            reason: 'tab $i has no tap action -- the SDK requires one even on '
                'the selected tab');
        expect(data.flagsCollection.isSelected, isNot(ui.Tristate.none),
            reason: 'tab $i has no selected state at all; it must be set on '
                'every tab, not only the active one');
      }

      final selected = tabs
          .where((node) =>
              node.getSemanticsData().flagsCollection.isSelected ==
              ui.Tristate.isTrue)
          .toList();
      expect(selected, hasLength(1),
          reason: 'exactly one tab may be marked selected');
      expect(selected.single.getSemanticsData().label, contains('Muscles'),
          reason: 'the selected tab must be the one at selectedIndex');

      handle.dispose();
    });
  });

  // --- Characterization -------------------------------------------------
  // Glass was chosen over Solid and Ember. These pin the three things that
  // decision actually bought, so drifting off it has to be deliberate.

  group('the glass material', () {
    testWidgets('blurs a bounded sample behind a real clip', (tester) async {
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 0, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      final blur = tester.widget<BackdropFilter>(inBar(find.byType(BackdropFilter)));
      expect(blur.filterConfig, isNotNull,
          reason: 'filterConfig, not filter: a plain ImageFilter.blur samples '
              'the whole canvas, which is what Glass rules out');
      expect(blur.filter, isNull,
          reason: 'BackdropFilter asserts if both are provided');

      final clip = tester.widget<ClipRRect>(inBar(find.byType(ClipRRect)));
      expect(clip.clipBehavior, Clip.antiAlias,
          reason: 'bounded sampling does not clip output, so the clip is '
              'load-bearing -- and antiAliasWithSaveLayer would allocate an '
              'offscreen layer on every frame the bar repaints');
    });

    testWidgets('the shadow is painted outside the clip', (tester) async {
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 0, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      // A BoxShadow paints outside its own box, so folding the shadow into the
      // clipped fill -- the obvious tidy-up -- erases it entirely, silently.
      final shadowBox =
          tester.widget<DecoratedBox>(inBar(find.byType(DecoratedBox)).first);
      final decoration = shadowBox.decoration as BoxDecoration;

      expect(decoration.boxShadow, hasLength(1),
          reason: 'the outermost decorated box carries the drop shadow');
      expect(decoration.color, isNull,
          reason: 'it carries only the shadow; the fill belongs inside the '
              'clip, under the blur');
      expect(decoration.boxShadow!.single.offset, const Offset(0, 10),
          reason: 'prototype: 0 10px 28px');
      expect(decoration.boxShadow!.single.blurRadius, 28,
          reason: 'prototype: 0 10px 28px');
    });

    testWidgets('floats off the bottom edge, and clears the home indicator',
        (tester) async {
      await tester.pumpWidget(
        host(GlassTabBar(selectedIndex: 0, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      final flatGap = tester.getRect(find.byType(GlassTabBar)).bottom -
          tester.getRect(inBar(find.byType(ClipRRect))).bottom;
      expect(flatGap, GlassTabBar.minimumBottomInset,
          reason: 'with no inset the bar still floats 14pt off the edge');

      await tester.pumpWidget(
        host(
          GlassTabBar(selectedIndex: 0, onSelected: (_) {}),
          viewPadding: const EdgeInsets.only(bottom: 34),
        ),
      );
      await tester.pumpAndSettle();

      final insetGap = tester.getRect(find.byType(GlassTabBar)).bottom -
          tester.getRect(inBar(find.byType(ClipRRect))).bottom;
      expect(insetGap, 34,
          reason: 'the home indicator inset wins once it exceeds 14pt');
    });
  });
}
