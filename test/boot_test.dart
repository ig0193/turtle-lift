import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/main.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/ui/l0_shell.dart';

/// What the app opens on. Cheap to break and expensive to notice: `main.dart`
/// is edited rarely and by hand, and a wrong `home:` still compiles, still
/// renders and still passes every widget test that pumps its own screen.
void main() {
  testWidgets('the app boots into the L0 shell on the page background',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TurtleLiftApp()));
    await tester.pump();

    expect(find.byType(L0Shell), findsOneWidget,
        reason: 'the app must open on the tab shell, not on any other screen');

    // Which tab it opens on is part of the boot contract, and only this file
    // exercises the real TurtleLiftApp path -- the shell's own tests host
    // L0Shell directly and would not notice main.dart handing it a different
    // starting index.
    expect(find.text('Ready when you are').hitTestable(), findsOneWidget,
        reason: 'the app opens on the Workout tab');

    final context = tester.element(find.byType(L0Shell));
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      AppPalette.pageBackground,
      reason: 'the shell must sit on the palette page background',
    );
  });
}
