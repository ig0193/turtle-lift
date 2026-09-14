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

  group('reduced motion', () {
    /// Both platforms assert the same thing, and 20ms is not arbitrary: an
    /// `AnimationController` under `disableAnimations` scales its duration by
    /// 0.05 rather than to zero, so a bar that merely inherited that behaviour
    /// would still be moving one frame in. 20ms is past 260 x 0.05 = 13ms and
    /// far short of the full 260ms.
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
