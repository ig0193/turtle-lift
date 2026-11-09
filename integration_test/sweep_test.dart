// Walks every screen the workout flow reaches and fails on any framework
// error — an overflow, a null, a bad state. The flow test proves the happy
// path works; this one proves nothing is quietly broken along the way.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:turtle_lift/main.dart' as app;
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/ui/destructive_confirmation.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/diet_slot_card.dart';
import 'package:turtle_lift/src/ui/exercise_picker_sheet.dart';
import 'package:turtle_lift/src/ui/food_picker_screen.dart';
import 'package:turtle_lift/src/ui/food_serving_sheet.dart';
import 'package:turtle_lift/src/ui/glass_tab_bar.dart';
import 'package:turtle_lift/src/ui/l0_shell.dart';
import 'package:turtle_lift/src/ui/profile_root.dart';
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

  /// A returning user (the debug seed has plenty of workouts) sees the
  /// ready-made grid folded behind one row (research item 11). Unfolds it.
  Future<void> unfoldReadyMade(WidgetTester tester) async {
    final toggle = find.byKey(WorkoutLandingBody.readyMadeToggleKey);
    if (toggle.evaluate().isEmpty) return;
    if (find.byKey(WorkoutLandingBody.templateKey('push')).evaluate().isNotEmpty) {
      return;
    }
    await tester.scrollUntilVisible(
      toggle,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await settle(tester);
    await tester.tap(toggle);
    await settle(tester);
  }

  /// Scrolls the landing until [id]'s tile is clear of the pinned Start bar and
  /// the tab bar, then taps it. Tiles lower in the grid start off screen or
  /// behind the bars, where a tap lands on the wrong thing.
  Future<void> tapTemplate(WidgetTester tester, String id) async {
    await unfoldReadyMade(tester);
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
      // The chip reads "weight" beside a plus icon (its semantics label is
      // "Add weight"); the old '+ weight' matched nothing, so tapText quietly
      // skipped the optional-weight path.
      final chips = find.text('weight').evaluate().length;
      expect(chips, greaterThan(0), reason: 'every timed row offers the chip');
      await tester.tap(find.text('weight').last);
      await settle(tester);
      expect(find.text('weight').evaluate().length, chips - 1,
          reason: 'the chip expands into the optional weight field');
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

    // --- Profile, Diet: every day, the picker and its filters, the add and
    // edit sheets, the undo, the target and reminders screens. The food it
    // adds it removes again.
    Future<void> scrollToAndTap(Finder finder) async {
      await tester.scrollUntilVisible(finder, 300,
          scrollable: find.byType(Scrollable).first);
      await settle(tester);
      await tester.tap(finder);
      await settle(tester);
    }

    await tester.tap(find.byKey(GlassTabBar.itemKey(3)));
    await settle(tester);
    await tester.tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.diet)));
    await settle(tester);
    expect(find.byType(DietPane), findsOneWidget);
    for (var weekday = 0; weekday < 7; weekday++) {
      await tester.tap(find.byKey(DietPane.weekDayKey(weekday)));
      await settle(tester);
    }
    await tester.tap(
        find.byKey(DietPane.weekDayKey(DateTime.now().weekday - 1)));
    await settle(tester);

    await scrollToAndTap(find.byKey(DietSlotCard.addFoodKey(MealSlot.snack)));
    // Every chip, then back to All: the choice lasts for the run (A15).
    for (final filter in <DietFilter>[...DietFilter.values, DietFilter.all]) {
      await tester.tap(find.byKey(FoodPickerScreen.chipKey(filter)));
      await settle(tester);
    }
    await tester.enterText(find.byKey(FoodPickerScreen.searchKey), 'zzzz');
    await settle(tester);
    await tester.enterText(find.byKey(FoodPickerScreen.searchKey), 'soya');
    await settle(tester);
    await tester.tap(find.byKey(FoodPickerScreen.rowKey('soya-bean')));
    await settle(tester);
    await tester.tap(find.byKey(FoodServingSheet.commitKey));
    await settle(tester);
    await scrollToAndTap(
        find.byKey(DietSlotCard.rowKey(MealSlot.snack, 'soya-bean')));
    await tester.tap(find.byKey(FoodServingSheet.removeKey));
    await settle(tester);
    await tester.pump(FoodServingSheet.undoDuration);
    await settle(tester);

    await scrollToAndTap(find.byKey(DietPane.targetRowKey));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    if (find.byKey(DietPane.remindersRowKey).evaluate().isNotEmpty) {
      await scrollToAndTap(find.byKey(DietPane.remindersRowKey));
      await tester.pageBack();
      await settle(tester);
    }
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await settle(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await settle(tester);
    await tester.tap(
        find.byKey(ProfileRoot.segmentKey(ProfileSegment.personal)));
    await settle(tester);

    expect(
      problems,
      isEmpty,
      reason: 'the app threw while being walked:\n${problems.join("\n---\n")}',
    );
  });
}
