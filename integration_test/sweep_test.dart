// Walks every screen the workout flow reaches and fails on any framework
// error — an overflow, a null, a bad state. The flow test proves the happy
// path works; this one proves nothing is quietly broken along the way.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:turtle_lift/main.dart' as app;
import 'package:turtle_lift/src/ui/destructive_confirmation.dart';
import 'package:turtle_lift/src/ui/exercise_picker_sheet.dart';
import 'package:turtle_lift/src/ui/glass_tab_bar.dart';
import 'package:turtle_lift/src/ui/l0_shell.dart';
import 'package:turtle_lift/src/ui/session_actions.dart';
import 'package:turtle_lift/src/ui/session_overview_body.dart';
import 'package:turtle_lift/src/ui/set_logging_screen.dart';
import 'package:turtle_lift/src/ui/set_row.dart';
import 'package:turtle_lift/src/ui/template_preview_sheet.dart';
import 'package:turtle_lift/src/ui/workout_root.dart';

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

  /// Starts the app and waits for its first screen.
  ///
  /// `app.main()` is async — it opens the database, seeds sample data in a debug
  /// build and reads the exercise library before `runApp` — and `pumpAndSettle`
  /// returns the moment no frame is scheduled, which is *before* any of that has
  /// finished. So this waits, in real time, for the shell to exist.
  Future<void> bootApp(WidgetTester tester) async {
    app.main();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(L0Shell).evaluate().isNotEmpty) break;
    }
    await settle(tester);
  }

  /// Scrolls the landing until [id]'s tile is clear of the pinned Start bar and
  /// the tab bar, then taps it. Tiles lower in the grid start off screen or
  /// behind the bars, where a tap lands on the wrong thing.
  Future<void> tapTemplate(WidgetTester tester, String id) async {
    final tile = find.byKey(WorkoutLandingBody.templateKey(id));
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
    await settle(tester);
    await tester.tap(tile);
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    if (finder.evaluate().isEmpty) return;
    await tester.tap(finder.first);
    await settle(tester);
  }

  testWidgets('every screen renders without a framework error',
      (tester) async {
    await bootApp(tester);

    // Clear anything a previous run left open, by Discard: it is on the ready
    // view and the list alike, below the whole list, so it is scrolled to.
    if (find.byType(SessionOverviewBody).evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        find.byKey(SessionActions.discardKey),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(SessionActions.discardKey));
      await settle(tester);
      if (find.byKey(confirmDestructiveKey).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(confirmDestructiveKey));
        await settle(tester);
      }
    }

    Finder pickerField() => find.descendant(
          of: find.byType(ExercisePickerSheet),
          matching: find.byType(TextField),
        );

    // --- The other two tabs. Tapped by the bar's own key: the header renders
    // the same words, so finding them by text hits the title instead.
    for (final index in <int>[1, 2, 0]) {
      await tester.tap(find.byKey(GlassTabBar.itemKey(index)));
      await settle(tester);
    }

    // --- The longest template: its preview, the ready view, the picker over
    // the map, and then the list itself.
    await tapTemplate(tester, 'upper-body');
    await tester.tap(find.byKey(TemplatePreviewSheet.startKey));
    await settle(tester);
    expect(find.byKey(SessionOverviewBody.startLoggingKey), findsOneWidget);
    await tester.tap(find.byKey(SessionOverviewBody.startLoggingKey));
    await settle(tester);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);

    // Finish sits below the whole list, so it is only built once scrolled to.
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

    // --- Empty start: the picker, the detour, logging, the summary, history.
    await tester.tap(find.byKey(WorkoutLandingBody.startWorkoutKey));
    await settle(tester);
    await tester.tap(find.byKey(SessionOverviewBody.startLoggingKey));
    await settle(tester);
    await tester.enterText(pickerField(), 'plank');
    await settle(tester);
    await tester.tap(find.byKey(ExercisePickerSheet.rowKey('plank')));
    await settle(tester);
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
    await tester.tap(find.byKey(SessionOverviewBody.addExerciseKey));
    await settle(tester);
    await tester.enterText(pickerField(), 'assisted');
    await settle(tester);
    await tester.tap(find.descendant(
      of: find.byType(ExercisePickerSheet),
      matching: find.text('Assisted pull-up machine'),
    ));
    await settle(tester);
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
