import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/glass_tab_bar.dart';
import 'package:turtle_lift/src/ui/history_root.dart';
import 'package:turtle_lift/src/ui/l0_shell.dart';
import 'package:turtle_lift/src/ui/muscles_root.dart';
import 'package:turtle_lift/src/ui/profile_screen.dart';
import 'package:turtle_lift/src/ui/tab_index.dart';
import 'package:turtle_lift/src/ui/workout_root.dart';

/// The shell is the app's only navigation surface, and almost everything it can
/// get wrong renders perfectly:
///
/// * an `IndexedStack` "simplified" into a `switch` — every tab still works,
///   and every tab silently forgets its scroll position,
/// * a title that changes for sighted users while a screen reader keeps
///   announcing the first tab,
/// * a `SafeArea` reintroduced around the body — three roots quietly lose the
///   clearance that keeps their last row out from under the floating bar,
/// * a bar hidden with `Navigator.canPop` instead of route opacity — it then
///   disappears behind dialogs, which it must not,
/// * system back that exits the app instead of returning to the shell.
///
/// None of those throw. Each is asserted directly below.
void main() {
  Widget host() => ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const L0Shell(),
        ),
      );

  /// The header's `Semantics` wrapper for [label] — the same net
  /// `test/app_screen_test.dart` casts, so the two files agree on what "the
  /// header" is.
  Finder headerSemanticsFor(String label) => find.descendant(
        of: find.byType(AppBar),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == label,
        ),
      );

  /// The active root's own scrollable, scoped by root type. **All three roots
  /// stay mounted**, so a bare `find.byType(ListView)` matches three of them.
  Finder scrollableIn(Type rootType) => find.descendant(
        of: find.byType(rootType),
        matching: find.byType(Scrollable),
      );

  double scrollOffsetIn(WidgetTester tester, Type rootType) =>
      tester.state<ScrollableState>(scrollableIn(rootType)).position.pixels;

  /// A window short enough that a root's empty state overflows it. The default
  /// 800x600 test window is taller than any root's content, so nothing would
  /// scroll and the scroll-preservation test would pass on a shell that threw
  /// its children away every switch.
  void useShortScreen(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 320);
    addTearDown(tester.view.reset);
  }

  /// The root Navigator, captured *before* anything is pushed: once an opaque
  /// route is up, `find.byType(L0Shell)` matches nothing and the shell's
  /// element is no longer reachable.
  NavigatorState navigatorOf(WidgetTester tester) =>
      Navigator.of(tester.element(find.byType(L0Shell)));

  /// The copy that identifies each root on screen, in tab order.
  const rootText = <String>[
    'Ready when you are', // WorkoutRoot
    'Browse by muscle', // MusclesRoot
    'No workouts yet', // HistoryRoot
  ];

  group('tabs', () {
    testWidgets('opens on Workout', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'the shell must lay out clean');
      expect(find.text(rootText[0]).hitTestable(), findsOneWidget,
          reason: 'the app opens on the tab you came to use');
      expect(tester.widget<GlassTabBar>(find.byType(GlassTabBar)).selectedIndex,
          0,
          reason: 'the bar must agree with the body about which tab is current');
    });

    testWidgets('tapping each tab shows that root and not the other two',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      for (var tab = 0; tab < GlassTabBar.labels.length; tab++) {
        await tester.tap(find.byKey(GlassTabBar.itemKey(tab)));
        await tester.pumpAndSettle();

        // Hit-testability, not presence: an IndexedStack keeps all three roots
        // mounted on purpose, so `findsOneWidget` on any of them is true at
        // every moment and proves nothing. Only the displayed child is
        // hit-tested (`RenderIndexedStack.hitTestChildren`).
        for (var other = 0; other < rootText.length; other++) {
          expect(
            find.text(rootText[other]).hitTestable(),
            other == tab ? findsOneWidget : findsNothing,
            reason: other == tab
                ? 'tab $tab must show its own root'
                : 'tab $tab must not leave root $other interactive on top of it',
          );
        }

        expect(
          tester.widget<GlassTabBar>(find.byType(GlassTabBar)).selectedIndex,
          tab,
          reason: 'the bar must mark tab $tab after a tap on tab $tab',
        );
      }
    });

    testWidgets("switching tabs keeps each root's scroll offset",
        (tester) async {
      // The regression this exists for: replacing the IndexedStack with a
      // `switch` that returns one child. Every tab still renders, every tab
      // still switches, and every tab silently restarts at the top.
      useShortScreen(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(GlassTabBar.itemKey(2)));
      await tester.pumpAndSettle();

      await tester.drag(scrollableIn(HistoryRoot), const Offset(0, -60));
      await tester.pumpAndSettle();

      final scrolled = scrollOffsetIn(tester, HistoryRoot);
      expect(scrolled, greaterThan(0),
          reason: 'the History root did not scroll, so the check below would '
              'pass on a shell that discards its children');

      await tester.tap(find.byKey(GlassTabBar.itemKey(1)));
      await tester.pumpAndSettle();
      expect(find.text(rootText[1]).hitTestable(), findsOneWidget,
          reason: 'the Muscles root must actually be showing in between');

      await tester.tap(find.byKey(GlassTabBar.itemKey(2)));
      await tester.pumpAndSettle();

      expect(scrollOffsetIn(tester, HistoryRoot), scrolled,
          reason: 'the History root came back scrolled to a different offset');
    });

    testWidgets('the header title and its semantics label follow the tab',
        (tester) async {
      // Disposed at the end of the body, not via addTearDown: the framework
      // checks for outstanding SemanticsHandles before tearDowns run, so a
      // deferred dispose fails the very test it was meant to clean up after.
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      for (var tab = 0; tab < L0Shell.tabs.length; tab++) {
        await tester.tap(find.byKey(GlassTabBar.itemKey(tab)));
        await tester.pumpAndSettle();

        final title = L0Shell.tabs[tab].title;
        expect(find.descendant(of: find.byType(AppBar), matching: find.text(title)),
            findsOneWidget,
            reason: 'the header must read "$title" on tab $tab');

        // The label, not only the rendered text. A Consumer confined to
        // `titleWidget` would keep the header text in step while leaving every
        // root announcing "Workout" — and nothing on screen would show it.
        final semantics =
            tester.widget<Semantics>(headerSemanticsFor(title));
        expect(semantics.properties.label, title,
            reason: 'the header semantics label must follow the tab too');
        expect(semantics.properties.header, isTrue,
            reason: 'the title is still the screen header on every tab');
        expect(tester.getSemantics(headerSemanticsFor(title)).label,
            contains(title),
            reason: 'the label must reach the semantics tree, not just the '
                'widget');
      }

      handle.dispose();
    });

    testWidgets('setting the index from outside the shell switches the tab',
        (tester) async {
      // How the celebration screen returns the user to a named tab from a
      // pushed route: it has no handle on the shell, only on the provider.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // listen: false -- this is a read from outside a build, and the default
      // would register a dependency on an element that is not building.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(L0Shell)),
        listen: false,
      );
      container.read(tabIndexProvider.notifier).select(1);
      await tester.pumpAndSettle();

      expect(find.text(rootText[1]).hitTestable(), findsOneWidget,
          reason: 'the Muscles root must be showing');
      expect(tester.widget<GlassTabBar>(find.byType(GlassTabBar)).selectedIndex,
          1,
          reason: 'the bar must follow a change it did not originate');
    });

    testWidgets('the shell declares one spec per bar label', (tester) async {
      // Cheap, and it is the assert in `L0Shell.build` made unconditional: a
      // fourth tab added to the bar but not to the specs would throw a range
      // error the first time anyone tapped it.
      expect(L0Shell.tabs, hasLength(GlassTabBar.labels.length),
          reason: 'every bar slot needs a root and a header behind it');
      expect(L0Shell.tabs, hasLength(kL0TabCount),
          reason: 'the index range and the specs must agree');
      expect(
        L0Shell.tabs.map((t) => t.title).toList(),
        GlassTabBar.labels,
        reason: 'the header and the bar label name the same tab today; the day '
            'one of them stops (the open-session title), change this '
            'deliberately rather than by accident',
      );
    });
  });

  group('layout', () {
    testWidgets('there is exactly one Scaffold in the app', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget,
          reason: 'the shell is an AppScreen.root, not a second Scaffold, and '
              'a root that grew its own would nest two');
    });

    testWidgets('the bar height reaches every root as a bottom inset',
        (tester) async {
      // The direct guard on the missing SafeArea. Wrapping the shell's body in
      // one consumes the padding `extendBody` injects and strips it from the
      // descendant MediaQuery: `screenScrollPadding` then reads zero in all
      // three roots, they render perfectly, and their last row hides behind
      // the bar.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final barHeight = tester.getSize(find.byType(GlassTabBar)).height;
      expect(barHeight, greaterThan(0), reason: 'the bar must have a height');

      for (final rootType in const <Type>[
        WorkoutRoot,
        MusclesRoot,
        HistoryRoot,
      ]) {
        // skipOffstage: false — IndexedStack keeps all three roots mounted but
        // only the selected one is onstage, and the inset has to reach the two
        // that are not being painted just as much as the one that is.
        final inset = MediaQuery.paddingOf(
          tester.element(find.byType(rootType, skipOffstage: false)),
        ).bottom;
        expect(inset, barHeight,
            reason: '$rootType must read the floating bar as a bottom inset');
      }
    });
  });

  group('bar visibility', () {
    testWidgets('an opaque route hides the bar; popping restores it with the '
        'same tab', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(GlassTabBar.itemKey(2)));
      await tester.pumpAndSettle();
      expect(find.byType(GlassTabBar).hitTestable(), findsOneWidget,
          reason: 'the bar is up at L0 before anything is pushed');

      final navigator = navigatorOf(tester);
      unawaited(navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('pushed'))),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('pushed'), findsOneWidget,
          reason: 'the pushed screen must be up');
      // hitTestable, not a bare findsNothing: the shell stays mounted beneath
      // an opaque route, and `findsNothing` would pass by accident of
      // skipOffstage's default rather than because the bar is gone.
      expect(find.byType(GlassTabBar).hitTestable(), findsNothing,
          reason: 'an opaque page route covers the shell, bar included');

      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(GlassTabBar).hitTestable(), findsOneWidget,
          reason: 'popping back to L0 brings the bar back');
      expect(tester.widget<GlassTabBar>(find.byType(GlassTabBar)).selectedIndex,
          2,
          reason: 'the tab selected before the push must still be selected');
      expect(find.text(rootText[2]).hitTestable(), findsOneWidget,
          reason: 'and its root must still be the one showing');
    });

    testWidgets('a dialog leaves the bar visible', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      unawaited(showDialog<void>(
        context: tester.element(find.byType(L0Shell)),
        builder: (_) => const AlertDialog(content: Text('are you sure')),
      ));
      await tester.pumpAndSettle();

      expect(find.text('are you sure'), findsOneWidget,
          reason: 'the dialog must be up');
      // Deliberately not `hitTestable()` here, and the difference is the point:
      // a modal route puts a barrier over everything, so nothing behind it is
      // tappable — by design. What R3 asks is that the bar is still *there* and
      // still drawn, which is what a modal route not covering the shell means.
      expect(find.byType(GlassTabBar), findsOneWidget,
          reason: 'a modal route does not cover the shell, so the bar stays');
      expect(tester.getSize(find.byType(GlassTabBar)).height, greaterThan(0),
          reason: 'the bar must still occupy its space under the barrier');
    });

    testWidgets('the avatar pushes Profile and the bar goes with the shell',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // Captured first: once Profile is up the shell is offstage and
      // `find.byType(L0Shell)` matches nothing.
      final navigator = navigatorOf(tester);

      await tester.tap(find.byKey(ProfileAvatarButton.tapTargetKey));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget,
          reason: 'the header avatar pushes the Profile destination');
      expect(find.byType(GlassTabBar).hitTestable(), findsNothing,
          reason: 'Profile is an opaque page route, so it hides the bar — a '
              'modal sheet here would leave the bar sitting under it');

      // And it comes back, so Profile is genuinely a push and not a replace.
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(GlassTabBar).hitTestable(), findsOneWidget,
          reason: 'popping Profile returns to the shell');
    });
  });

  group('system back', () {
    /// Records every `SystemNavigator.pop` — the platform call that asks the OS
    /// to close the app. Mock handlers are cleared after each test.
    List<String> recordPlatformCalls(WidgetTester tester) {
      final methods = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          methods.add(call.method);
          return null;
        },
      );
      return methods;
    }

    testWidgets('back on a pushed screen returns to the shell, not the home '
        'screen', (tester) async {
      final methods = recordPlatformCalls(tester);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      unawaited(navigatorOf(tester).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('pushed'))),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('pushed'), findsNothing,
          reason: 'system back must pop the pushed route');
      expect(find.byType(GlassTabBar).hitTestable(), findsOneWidget,
          reason: 'and land back on the shell with the bar restored');
      expect(methods, isNot(contains('SystemNavigator.pop')),
          reason: 'with a route to pop, back must never ask the OS to close '
              'the app');
    });

    testWidgets('back at the shell itself does not crash', (tester) async {
      // At the bottom of the stack there is nothing to pop, so the framework
      // asks the OS to close the app. That is correct behaviour, not a bug —
      // what is asserted here is only that the shell survives being asked.
      recordPlatformCalls(tester);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'system back at L0 must not throw');
      expect(find.byType(GlassTabBar).hitTestable(), findsOneWidget,
          reason: 'the shell is still up');
    });
  });

  group('the profile avatar', () {
    testWidgets('is a 32pt disc on surface with a 1pt border', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final circle = find.byKey(ProfileAvatarButton.circleKey);
      expect(tester.getSize(circle),
          const Size(ProfileAvatarButton.size, ProfileAvatarButton.size),
          reason: 'the prototype gives .avatar a 32px box');

      final decoration =
          tester.widget<Container>(circle).decoration! as BoxDecoration;
      // Packed ARGB, never Color identity — the repo's rule for colour checks.
      expect(decoration.color!.toARGB32(), AppPalette.surface.toARGB32(),
          reason: 'the disc is filled with the card surface');
      expect(decoration.shape, BoxShape.circle, reason: 'it is a circle');
      expect(decoration.border!.top.color.toARGB32(),
          AppPalette.border.toARGB32(),
          reason: 'the resting ring is the border colour');
      expect(decoration.border!.top.width, ProfileAvatarButton.borderWidth,
          reason: 'a 1pt ring, not a heavier one');

      expect(
        tester.widget<ProfileGlyphIcon>(find.byType(ProfileGlyphIcon)).color
            .toARGB32(),
        AppPalette.textSecondary.toARGB32(),
        reason: 'the resting glyph is the secondary text colour',
      );
    });

    testWidgets('flips both the ring and the glyph to accent while pressed',
        (tester) async {
      // Tinting only the ring is the easy half to ship, and at 32pt on a dark
      // surface it reads as nothing having happened.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ProfileAvatarButton.tapTargetKey)),
      );
      await tester.pump();

      final pressed = tester
          .widget<Container>(find.byKey(ProfileAvatarButton.circleKey))
          .decoration! as BoxDecoration;
      expect(pressed.border!.top.color.toARGB32(),
          AppPalette.accentStrong.toARGB32(),
          reason: 'the ring must accent while pressed');
      expect(
        tester.widget<ProfileGlyphIcon>(find.byType(ProfileGlyphIcon)).color
            .toARGB32(),
        AppPalette.accentStrong.toARGB32(),
        reason: 'the glyph must accent with it — `.avatar:active` sets both '
            'border-color and color, and the SVG strokes currentColor',
      );

      // cancel, not up: releasing on the button fires the tap and pushes the
      // Profile route over the shell, which takes the avatar offstage and
      // leaves nothing to measure. A cancelled press is the gesture that ends
      // without navigating, which is the one this assertion is about.
      await gesture.cancel();
      await tester.pumpAndSettle();

      final released = tester
          .widget<Container>(find.byKey(ProfileAvatarButton.circleKey))
          .decoration! as BoxDecoration;
      expect(released.border!.top.color.toARGB32(), AppPalette.border.toARGB32(),
          reason: 'the ring must return to rest when the press ends');
    });

    testWidgets('is at least a 48x48 target', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final size =
          tester.getSize(find.byKey(ProfileAvatarButton.tapTargetKey));
      expect(size.width, greaterThanOrEqualTo(48),
          reason: 'the 32pt disc is smaller than the minimum touch target, so '
              'the box around it has to make up the difference');
      expect(size.height, greaterThanOrEqualTo(48),
          reason: 'M3 centres app-bar actions rather than stretching them, so '
              'the height is the control\'s own');
    });

    testWidgets('announces itself as a button named Profile', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // isSemantics, not matchesSemantics: this asserts the three things that
      // matter and stays quiet about the flags the framework adds around them.
      // (containsSemantics is the same matcher, deprecated after v3.40.)
      expect(
        tester.getSemantics(find.byKey(ProfileAvatarButton.tapTargetKey)),
        isSemantics(label: 'Profile', isButton: true, hasTapAction: true),
        reason: 'an unlabelled icon control is unusable with a screen reader, '
            'and a labelled one with no tap action is worse',
      );

      handle.dispose();
    });
  });
}
