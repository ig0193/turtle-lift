// Walks every screen the app reaches and screenshots each one, for the
// `turtle-taste` design audit (`.claude/skills/turtle-taste/SKILL.md`).
//
// Not a correctness test: `sweep_test.dart` owns "nothing throws". This one
// exists so an audit looks at the real app on a real screen size instead of
// guessing from widget code. Run it through `tool/taste_shots.sh`, which saves
// the PNGs under `build/taste_shots/<device>/`.
//
// Each section is independent: one that cannot reach its screen (data changed,
// a key moved) is logged and skipped, and the walk goes home and carries on,
// so one broken step never costs the rest of the shots.
//
// It leaves no data behind: the workouts it opens are discarded, and the one
// it finishes (to reach the summary) is deleted from the summary. The food the
// Diet section adds is removed again (that is the undo shot). The very last
// section runs Delete all data, to reach Diet's first-time state; a debug
// build re-seeds its sample data on the next cold start.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:turtle_lift/main.dart' as app;
import 'package:turtle_lift/src/ui/data_screens.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/ui/destructive_confirmation.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/diet_reminders_screen.dart';
import 'package:turtle_lift/src/ui/diet_slot_card.dart';
import 'package:turtle_lift/src/ui/exercise_picker_sheet.dart';
import 'package:turtle_lift/src/ui/food_picker_screen.dart';
import 'package:turtle_lift/src/ui/food_serving_sheet.dart';
import 'package:turtle_lift/src/ui/glass_tab_bar.dart';
import 'package:turtle_lift/src/ui/history_root.dart';
import 'package:turtle_lift/src/ui/history_session_row.dart';
import 'package:turtle_lift/src/ui/l0_shell.dart';
import 'package:turtle_lift/src/ui/muscle_exercise_list_screen.dart';
import 'package:turtle_lift/src/ui/muscle_search_field.dart';
import 'package:turtle_lift/src/ui/profile_root.dart';
import 'package:turtle_lift/src/ui/session_actions.dart';
import 'package:turtle_lift/src/ui/session_overview_body.dart';
import 'package:turtle_lift/src/ui/session_summary_screen.dart';
import 'package:turtle_lift/src/ui/set_logging_screen.dart';
import 'package:turtle_lift/src/ui/set_row.dart';
import 'package:turtle_lift/src/ui/sub_group_row.dart';
import 'package:turtle_lift/src/ui/template_preview_sheet.dart';
import 'package:turtle_lift/src/ui/workout_root.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  var shot = 0;
  Future<void> snap(WidgetTester tester, String name) async {
    await settle(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    shot++;
    await binding.takeScreenshot('${shot.toString().padLeft(2, '0')}-$name');
  }

  Finder scrollable() => find.byType(Scrollable).first;

  Future<void> tapIfPresent(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) return;
    await tester.tap(finder.first);
    await settle(tester);
  }

  Future<void> scrollToAndTap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300, scrollable: scrollable());
    await settle(tester);
    await tester.tap(finder.first);
    await settle(tester);
  }

  /// Pops every pushed route and closes any sheet, back to a tab root.
  Future<void> home(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      if (!nav.canPop()) break;
      nav.pop();
      await settle(tester);
    }
  }

  Future<void> discardOpenWorkout(WidgetTester tester) async {
    await tester.tap(find.byKey(GlassTabBar.itemKey(0)));
    await settle(tester);
    if (find.byType(SessionOverviewBody).evaluate().isEmpty) return;
    await scrollToAndTap(tester, find.byKey(SessionActions.discardKey));
    await tapIfPresent(tester, find.byKey(confirmDestructiveKey));
  }

  Future<void> section(
    WidgetTester tester,
    String name,
    Future<void> Function() body,
  ) async {
    try {
      await body();
    } catch (e) {
      debugPrint('taste_shots: skipped "$name": $e');
    }
    await home(tester);
  }

  Finder pickerField() => find.descendant(
        of: find.byType(ExercisePickerSheet),
        matching: find.byType(TextField),
      );

  testWidgets('screenshot every screen', (tester) async {
    app.main();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(L0Shell).evaluate().isNotEmpty) break;
    }
    await settle(tester);
    await binding.convertFlutterSurfaceToImage();
    await settle(tester);
    await discardOpenWorkout(tester);

    // --- Workout tab.
    await section(tester, 'workout', () async {
      await snap(tester, 'workout-landing');
      await tester.drag(scrollable(), const Offset(0, -2000));
      await snap(tester, 'workout-landing-bottom');
    });

    await section(tester, 'template', () async {
      await scrollToAndTap(
          tester, find.byKey(WorkoutLandingBody.templateKey('push')));
      await snap(tester, 'template-preview');
      await tester.tap(find.byKey(TemplatePreviewSheet.startKey));
      await snap(tester, 'session-ready');
      await tester.tap(find.byKey(SessionOverviewBody.startLoggingKey));
      await settle(tester);
      await tester.tapAt(const Offset(10, 10));
      await snap(tester, 'session-template-list');
    });
    await discardOpenWorkout(tester);

    // An empty workout through to its summary: picker, logging, detail,
    // exercise history, the list, finish, summary. Deleted at the end.
    await section(tester, 'logging', () async {
      await tester.tap(find.byKey(WorkoutLandingBody.startWorkoutKey));
      await settle(tester);
      await tester.tap(find.byKey(SessionOverviewBody.startLoggingKey));
      await snap(tester, 'exercise-picker');
      await tester.enterText(pickerField(), 'bench');
      await snap(tester, 'exercise-picker-search');
      await tester.enterText(pickerField(), 'zzzz');
      await snap(tester, 'exercise-picker-empty');
      await tester.enterText(pickerField(), 'bench');
      await settle(tester);
      await tester
          .tap(find.byKey(ExercisePickerSheet.rowKey('barbell-bench-press')));
      await settle(tester);
      await snap(tester, 'exercise-first-time');
      await tapIfPresent(tester, find.text('Start logging'));
      await snap(tester, 'set-logging');
      await tester.tap(find.byKey(SetRow.checkKey(0)));
      await snap(tester, 'set-logging-one-done');

      await tester.tap(find.byKey(const ValueKey<String>('exercise-info')));
      await snap(tester, 'exercise-detail');
      await tester.drag(scrollable(), const Offset(0, -1200));
      await snap(tester, 'exercise-detail-bottom');
      await tester.pageBack();
      await settle(tester);

      await scrollToAndTap(tester, find.byKey(SetLoggingScreen.seeAllKey));
      await snap(tester, 'exercise-history');
      await tester.pageBack();
      await settle(tester);
      await tester.pageBack();
      await snap(tester, 'session-adhoc-list');

      // Plank, for the timed variant.
      await tester.tap(find.byKey(SessionOverviewBody.addExerciseKey));
      await settle(tester);
      await tester.enterText(pickerField(), 'plank');
      await settle(tester);
      await tester.tap(find.byKey(ExercisePickerSheet.rowKey('plank')));
      await settle(tester);
      await tapIfPresent(tester, find.text('Start logging'));
      await snap(tester, 'set-logging-timed');
      await tester.pageBack();
      await settle(tester);

      await scrollToAndTap(tester, find.byKey(SessionActions.finishKey));
      await snap(tester, 'summary');
      await tester.drag(scrollable(), const Offset(0, -1500));
      await snap(tester, 'summary-bottom');
      await scrollToAndTap(tester, find.byKey(SessionSummaryScreen.deleteKey));
      await snap(tester, 'confirm-delete');
      await tapIfPresent(tester, find.byKey(confirmDestructiveKey));
    });
    await discardOpenWorkout(tester);

    // --- Muscles tab.
    await section(tester, 'muscles', () async {
      await tester.tap(find.byKey(GlassTabBar.itemKey(1)));
      await snap(tester, 'muscles');
      // The middle of the map is the abdominals on both diagrams.
      final size = tester.getSize(find.byType(L0Shell));
      await tester.tapAt(Offset(size.width / 2, size.height * 0.48));
      await snap(tester, 'muscle-segment');
    });
    await section(tester, 'muscle-list', () async {
      await tester.tap(find.byKey(GlassTabBar.itemKey(1)));
      await settle(tester);
      await tester.drag(scrollable(), const Offset(0, -900));
      await snap(tester, 'muscles-list');
      await tester.tap(find.byType(SubGroupRow).first);
      await snap(tester, 'muscle-exercise-list');
      await tester.tap(find.byType(ExerciseRow).first);
      await snap(tester, 'exercise-detail-browse');
    });
    await section(tester, 'muscle-search', () async {
      await tester.tap(find.byKey(GlassTabBar.itemKey(1)));
      await settle(tester);
      // The tab keeps its scroll offset from the list section above.
      await tester.drag(scrollable(), const Offset(0, 3000));
      await settle(tester);
      await tester.tap(find.byType(MuscleSearchField));
      await snap(tester, 'search');
      await tester.enterText(find.byType(TextField).first, 'cable');
      await snap(tester, 'search-results');
      await tester.enterText(find.byType(TextField).first, 'qqqq');
      await snap(tester, 'search-empty');
    });

    // --- History tab.
    await section(tester, 'history', () async {
      await tester.tap(find.byKey(GlassTabBar.itemKey(2)));
      await snap(tester, 'history');
      await tester.tap(find.byType(HistorySessionRow).first);
      await snap(tester, 'history-session');
      await tester.drag(scrollable(), const Offset(0, -1500));
      await snap(tester, 'history-session-bottom');
      await tester.pageBack();
      await settle(tester);
      await scrollToAndTap(tester, find.byKey(HistoryRoot.seeAllKey));
      await snap(tester, 'all-sessions');
    });

    // --- Profile tab.
    await section(tester, 'profile', () async {
      await tester.tap(find.byKey(GlassTabBar.itemKey(3)));
      await snap(tester, 'profile');
      await tester.tap(find.text('My workout templates'));
      await snap(tester, 'template-library');
      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.text('Personal details'));
      await snap(tester, 'personal-details');
      await tester.drag(scrollable(), const Offset(0, -1500));
      await snap(tester, 'personal-details-bottom');
      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.text('Export everything'));
      await snap(tester, 'export');
      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.text('Delete all data'));
      await snap(tester, 'delete-all');
      await tester.tap(find.byKey(DeleteAllDataScreen.deleteKey));
      await snap(tester, 'delete-all-confirm');
      await tapIfPresent(tester, find.byKey(confirmCancelKey));
    });
    await section(tester, 'schedule', () async {
      await tester.tap(find.byKey(GlassTabBar.itemKey(3)));
      await settle(tester);
      await tester.tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.schedule)));
      await snap(tester, 'schedule');
      await tester.drag(scrollable(), const Offset(0, -1500));
      await snap(tester, 'schedule-bottom');
      await tester.tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.personal)));
      await settle(tester);
    });

    // --- Profile, Diet. The debug seed gives it a target, a planned week and
    // one tick today; the first-time state is shot last, after a wipe.
    Future<void> openDiet() async {
      await tester.tap(find.byKey(GlassTabBar.itemKey(3)));
      await settle(tester);
      // Profile keeps its scroll offset, and the segments scroll with it.
      await tester.drag(scrollable(), const Offset(0, 3000));
      await settle(tester);
      await tester.tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.diet)));
      await settle(tester);
    }

    await section(tester, 'diet', () async {
      await openDiet();
      await snap(tester, 'diet-today');
      // Another day of the week: Wednesday, or Thursday when today is
      // Wednesday, so the shot is never of the day already shown.
      final today = DateTime.now().weekday - 1;
      await tester.tap(find.byKey(DietPane.weekDayKey(today == 2 ? 3 : 2)));
      await snap(tester, 'diet-other-day');
      await tester.tap(find.byKey(DietPane.weekDayKey(today)));
      await settle(tester);

      // The picker for today's snack, a search with no match, then the add
      // sheet with today preselected under Repeat on.
      await scrollToAndTap(
          tester, find.byKey(DietSlotCard.addFoodKey(MealSlot.snack)));
      await snap(tester, 'diet-picker');
      await tester.enterText(find.byKey(FoodPickerScreen.searchKey), 'zzzz');
      await snap(tester, 'diet-picker-no-match');
      // Clear search, then scroll to the food: once `snap` has unfocused
      // the field, a second `enterText` does not reach it on a device.
      await tester.tap(find.byKey(FoodPickerScreen.clearSearchKey));
      await settle(tester);
      await scrollToAndTap(tester, find.byKey(FoodPickerScreen.rowKey('paneer')));
      await snap(tester, 'diet-add-sheet');
      await tester.tap(find.byKey(FoodServingSheet.commitKey));
      await settle(tester);

      // The row just added: its edit sheet, then Remove and the undo window.
      await scrollToAndTap(
          tester, find.byKey(DietSlotCard.rowKey(MealSlot.snack, 'paneer')));
      await snap(tester, 'diet-edit-sheet');
      await tester.tap(find.byKey(FoodServingSheet.removeKey));
      await snap(tester, 'diet-undo');
      await tester.pump(FoodServingSheet.undoDuration);
      await settle(tester);

      // Target, with the suggestion the seeded bodyweight gives.
      await scrollToAndTap(tester, find.byKey(DietPane.targetRowKey));
      await snap(tester, 'diet-target');
      await tester.pageBack();
      await settle(tester);

      // Reminders: the row exists only where notifications work.
      await scrollToAndTap(tester, find.byKey(DietPane.remindersRowKey));
      await snap(tester, 'diet-reminders');
      await tester.tap(find.byKey(DietRemindersScreen.masterKey));
      await settle(tester);
      if (find.byKey(DietRemindersScreen.notNowKey).evaluate().isNotEmpty) {
        await snap(tester, 'diet-reminders-explain');
        await tester.tap(find.byKey(DietRemindersScreen.notNowKey));
        await settle(tester);
      } else {
        // Permission was already granted, so the tap turned them on; put the
        // switch back as it was.
        await snap(tester, 'diet-reminders-on');
        await tester.tap(find.byKey(DietRemindersScreen.masterKey));
        await settle(tester);
      }
      await tester.pageBack();
      await settle(tester);

      await tester.drag(scrollable(), const Offset(0, -3000));
      await snap(tester, 'diet-bottom');
    });

    // Last, because it wipes everything: Diet's first-time state, and the
    // target screen with no bodyweight to suggest from.
    await section(tester, 'diet-empty', () async {
      await tester.tap(find.byKey(GlassTabBar.itemKey(3)));
      await settle(tester);
      await tester.drag(scrollable(), const Offset(0, 3000));
      await settle(tester);
      await tester.tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.personal)));
      await settle(tester);
      await scrollToAndTap(tester, find.text('Delete all data'));
      await tester.tap(find.byKey(DeleteAllDataScreen.deleteKey));
      await settle(tester);
      await tester.tap(find.byKey(confirmDestructiveKey));
      // The wipe reboots the app (`appRestartProvider`).
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await settle(tester);
      await openDiet();
      await snap(tester, 'diet-empty');
      await tester.tap(find.byKey(DietPane.setTargetKey));
      await snap(tester, 'diet-target-no-bodyweight');
      await tester.pageBack();
      await settle(tester);
    });

    await tester.tap(find.byKey(GlassTabBar.itemKey(0)));
    await settle(tester);
  });
}
