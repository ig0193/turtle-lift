import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';

/// The header must not move when the body scrolls -- on every screen, which is
/// why the rule is tested against the shell rather than any one screen.
void main() {
  Widget host(Widget screen) =>
      MaterialApp(theme: buildAppTheme(), home: screen);

  Widget longList() => ListView.builder(
        itemCount: 80,
        itemBuilder: (_, i) => SizedBox(height: 60, child: Text('row $i')),
      );

  Future<void> expectHeaderPinned(WidgetTester tester, String title) async {
    final header = find.text(title);
    final before = tester.getTopLeft(header);

    await tester.fling(find.byType(ListView), const Offset(0, -600), 1000);
    await tester.pumpAndSettle();

    expect(find.text('row 0'), findsNothing, reason: 'the body did scroll');
    expect(header, findsOneWidget, reason: 'the header scrolled away');
    expect(tester.getTopLeft(header), before, reason: 'the header moved');
  }

  testWidgets('root header stays put while the body scrolls', (tester) async {
    await tester.pumpWidget(
      host(AppScreen.root(title: 'Workout', body: longList())),
    );
    await expectHeaderPinned(tester, 'Workout');
  });

  testWidgets('pushed header stays put while the body scrolls', (tester) async {
    await tester.pumpWidget(
      host(AppScreen.pushed(title: 'Lower chest', body: longList())),
    );
    await expectHeaderPinned(tester, 'Lower chest');
  });

  testWidgets('the pinned bar does not tint when content scrolls under it',
      (tester) async {
    // Material 3 tints a scrolled-under app bar. With a permanently pinned
    // header that would mean a colour docs/00 §12 does not list.
    await tester.pumpWidget(
      host(AppScreen.root(title: 'Workout', body: longList())),
    );
    final theme = Theme.of(tester.element(find.byType(AppScreen))).appBarTheme;
    expect(theme.scrolledUnderElevation, 0);
    expect(theme.surfaceTintColor, Colors.transparent);
  });

  testWidgets('pushed screen pops via the back control', (tester) async {
    var popped = false;
    await tester.pumpWidget(
      host(AppScreen.pushed(
        title: 'Lower chest',
        body: longList(),
        onBack: () => popped = true,
      )),
    );

    await tester.tap(find.byIcon(Icons.chevron_left));
    expect(popped, isTrue);
  });

  // --- Characterization -----------------------------------------------
  // The header's measurements, spacing and type are load-bearing: the shell
  // and every screen are laid out against them. Pinned down here so a change
  // to AppScreen has to be a deliberate one.

  AppBar barOf(WidgetTester tester) => tester.widget<AppBar>(find.byType(AppBar));

  Finder headerSemanticsFor(String label) => find.descendant(
        of: find.byType(AppBar),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == label,
        ),
      );

  testWidgets('root header is 64 tall, pushed is 56', (tester) async {
    await tester.pumpWidget(
      host(AppScreen.root(title: 'Workout', body: longList())),
    );
    expect(barOf(tester).toolbarHeight, 64,
        reason: 'a tab root wears the tall 64pt header');

    await tester.pumpWidget(
      host(AppScreen.pushed(title: 'Lower chest', body: longList())),
    );
    expect(barOf(tester).toolbarHeight, 56,
        reason: 'a pushed screen wears the compact 56pt header');
  });

  testWidgets('root title clears the gutter, a pushed title sits against the '
      'back arrow', (tester) async {
    await tester.pumpWidget(
      host(AppScreen.root(title: 'Workout', body: longList())),
    );
    expect(barOf(tester).titleSpacing, kScreenGutter,
        reason: 'with no leading, the root title supplies its own gutter');

    await tester.pumpWidget(
      host(AppScreen.pushed(title: 'Lower chest', body: longList())),
    );
    expect(barOf(tester).titleSpacing, 0,
        reason: 'the back arrow already carries the gutter, so the title adds none');
  });

  testWidgets('the header reserves the gutter after its actions',
      (tester) async {
    await tester.pumpWidget(
      host(AppScreen.root(
        title: 'Workout',
        body: longList(),
        actions: const [Icon(Icons.add)],
      )),
    );

    final actions = barOf(tester).actions!;
    expect(actions.length, 2,
        reason: 'the caller action plus the trailing gutter spacer');
    expect(actions.last, isA<SizedBox>(),
        reason: 'the last action is the gutter spacer, not a control');
    expect((actions.last as SizedBox).width, kScreenGutter - 8,
        reason: 'an action already carries 8 of the 18pt gutter itself');
  });

  testWidgets('root and pushed titles use the two header type styles',
      (tester) async {
    await tester.pumpWidget(
      host(AppScreen.root(title: 'Workout', body: longList())),
    );
    final root = tester.widget<Text>(find.text('Workout')).style!;
    expect(root.fontSize, 24, reason: 'root title size');
    expect(root.fontWeight, FontWeight.w600, reason: 'root title weight');
    expect(root.letterSpacing, -0.48, reason: 'root title tracking');

    await tester.pumpWidget(
      host(AppScreen.pushed(title: 'Lower chest', body: longList())),
    );
    final pushed = tester.widget<Text>(find.text('Lower chest')).style!;
    expect(pushed.fontSize, 16, reason: 'pushed title size');
    expect(pushed.fontWeight, FontWeight.w600, reason: 'pushed title weight');
    expect(pushed.letterSpacing, -0.16, reason: 'pushed title tracking');
  });

  testWidgets('the title is announced as a header', (tester) async {
    await tester.pumpWidget(
      host(AppScreen.root(title: 'Workout', body: longList())),
    );

    final semantics = tester.widget<Semantics>(headerSemanticsFor('Workout'));
    expect(semantics.properties.header, isTrue,
        reason: 'the pinned title is the screen header for assistive tech');
  });

  testWidgets('titleWidget replaces the header text but not its label',
      (tester) async {
    await tester.pumpWidget(
      host(AppScreen.root(
        title: 'Push day',
        body: longList(),
        titleWidget: const Icon(Icons.edit, key: Key('title-widget')),
      )),
    );

    expect(find.byKey(const Key('title-widget')), findsOneWidget,
        reason: 'titleWidget renders in place of the title text');
    expect(find.text('Push day'), findsNothing,
        reason: 'the plain title must not render alongside titleWidget');

    final semantics = tester.widget<Semantics>(headerSemanticsFor('Push day'));
    expect(semantics.properties.label, 'Push day',
        reason: 'title stays the semantics label when titleWidget takes over');
    expect(semantics.properties.header, isTrue,
        reason: 'a custom title widget is still the screen header');
  });

  // --- extendBody and the one safe-area rule ---------------------------

  testWidgets('extendBody is off unless a screen asks for it', (tester) async {
    await tester.pumpWidget(
      host(AppScreen.root(title: 'Workout', body: longList())),
    );
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBody, isFalse,
        reason: 'only the tab shell floats its bottom bar over the content');
  });

  testWidgets('extendBody hands the bottom bar height to the body',
      (tester) async {
    // The direct guard on the missing SafeArea: SafeArea(top: false) consumes
    // the inset the Scaffold injects and strips it from the descendant
    // MediaQuery, so the screen can never pad its own scrollable for the bar.
    double? bottomInset;
    await tester.pumpWidget(
      host(AppScreen.root(
        title: 'Workout',
        extendBody: true,
        bottomBar: const SizedBox(height: 72, width: double.infinity),
        body: Builder(builder: (context) {
          bottomInset = MediaQuery.paddingOf(context).bottom;
          return longList();
        }),
      )),
    );

    expect(bottomInset, 72,
        reason: 'the body must read the floating bar height as a bottom inset');
  });

  testWidgets('screenScrollPadding adds the gutter to every safe-area edge',
      (tester) async {
    late EdgeInsets padding;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.fromLTRB(11, 47, 13, 34)),
          child: Builder(builder: (context) {
            padding = screenScrollPadding(context);
            return const SizedBox.shrink();
          }),
        ),
      ),
    );

    expect(padding.left, kScreenGutter + 11,
        reason: 'landscape notch on the left is the gutter plus the inset');
    expect(padding.right, kScreenGutter + 13,
        reason: 'landscape notch on the right is the gutter plus the inset');
    expect(padding.bottom, kScreenGutter + 34,
        reason: 'the home indicator or floating bar is added to the gutter');
    expect(padding.top, 0,
        reason: 'the pinned app bar already covers the top edge');
  });
}
