// Walks every screen the workout flow reaches and fails on any framework
// error — an overflow, a null, a bad state. The flow test proves the happy
// path works; this one proves nothing is quietly broken along the way.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:turtle_lift/main.dart' as app;
import 'package:turtle_lift/src/ui/destructive_confirmation.dart';
import 'package:turtle_lift/src/ui/glass_tab_bar.dart';
import 'package:turtle_lift/src/ui/session_actions.dart';
import 'package:turtle_lift/src/ui/set_logging_screen.dart';
import 'package:turtle_lift/src/ui/set_row.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final problems = <String>[];

  setUpAll(() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      problems.add(details.exceptionAsString());
      previous?.call(details);
    };
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    if (finder.evaluate().isEmpty) return;
    await tester.tap(finder.first);
    await settle(tester);
  }

  testWidgets('every screen renders without a framework error',
      (tester) async {
    app.main();
    await settle(tester);

    // Clear anything a previous run left open.
    if (find.byKey(SessionActions.finishKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(SessionActions.finishKey));
      await settle(tester);
      if (find.byKey(confirmDestructiveKey).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(confirmDestructiveKey));
        await settle(tester);
      }
    }

    // --- The other two tabs. Tapped by the bar's own key: the header renders
    // the same words, so finding them by text hits the title instead.
    for (final index in <int>[1, 2, 0]) {
      await tester.tap(find.byKey(GlassTabBar.itemKey(index)));
      await settle(tester);
    }

    // --- The widest template: every parent group, every accordion.
    await tapText(tester, 'Full body day');
    expect(find.text('Upper chest'), findsOneWidget,
        reason: 'the widest template — every parent group, every accordion');

    // The whole muscle list, which is the longest in the app. Finish sits past
    // twelve parent groups, so it is only built once scrolled to.
    await tester.scrollUntilVisible(
      find.byKey(SessionActions.finishKey),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);

    // --- Into a lift, through the first-time gate, and log every load type
    // the template reaches.
    // --- Discard, which is the destructive confirmation.
    await tester.tap(find.byKey(SessionActions.discardKey));
    await settle(tester);
    await tester.tap(find.byKey(confirmDestructiveKey));
    await settle(tester);

    // --- Ad-hoc: search, the detour, logging, the summary, history.
    await tapText(tester, 'Ad-hoc workout');
    await tester.enterText(find.byType(TextField).first, 'plank');
    await settle(tester);
    await tapText(tester, 'Plank');
    await tapText(tester, 'Start logging');

    if (find.byType(SetLoggingScreen).evaluate().isNotEmpty) {
      await tester.enterText(find.byType(TextField).first, '45');
      await settle(tester);
      await tester.tap(find.byKey(SetRow.checkKey(0)));
      await settle(tester);
      // A second set, and the optional weight chip.
      await tester.tap(find.byKey(SetLoggingScreen.addSetKey));
      await settle(tester);
      await tapText(tester, '+ weight');
      await tester.tap(find.byKey(SetLoggingScreen.markDoneKey));
      await settle(tester);
    }

    // Add an assisted lift too, so the inverted record and its banner render.
    await tapText(tester, '+ Add exercise');
    await tester.enterText(find.byType(TextField).first, 'assisted');
    await settle(tester);
    await tapText(tester, 'Assisted pull-up machine');
    await tapText(tester, 'Start logging');
    if (find.byType(SetLoggingScreen).evaluate().isNotEmpty) {
      await tester.enterText(find.byType(TextField).first, '25');
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(1), '8');
      await settle(tester);
      await tester.tap(find.byKey(SetRow.checkKey(0)));
      await settle(tester);
      await tester.tap(find.byKey(SetLoggingScreen.markDoneKey));
      await settle(tester);
    }

    // --- Finish, the celebration, the card, and its log.
    await tester.scrollUntilVisible(
      find.byKey(SessionActions.finishKey),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(SessionActions.finishKey));
    await settle(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);

    // --- History, which now reads the workout just finished.
    await tester.tap(find.byKey(GlassTabBar.itemKey(2)));
    await settle(tester);

    expect(
      problems,
      isEmpty,
      reason: 'the app threw while being walked:\n${problems.join("\n---\n")}',
    );
  });
}
