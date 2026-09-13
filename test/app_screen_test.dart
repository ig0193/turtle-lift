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
}
