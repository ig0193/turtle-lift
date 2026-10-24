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
import 'package:turtle_lift/src/ui/session_summary_screen.dart';
import 'package:turtle_lift/src/ui/set_logging_screen.dart';
import 'package:turtle_lift/src/ui/set_row.dart';
import 'package:turtle_lift/src/ui/template_preview_sheet.dart';
import 'package:turtle_lift/src/ui/workout_root.dart';

/// Drives the real app on a real device, against the real database.
///
/// **This is the proof the widget suite cannot give.** Those tests pump one
/// screen at a time with a fixture database; this one boots `main()`, walks the
/// flow the way a person does, and would catch a schema that never migrated, a
/// provider that was never seeded, or a screen that only renders under a test
/// harness — all of which are invisible to a widget test and obvious on a phone.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Lets real database work finish between taps.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
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

  /// Ends whatever workout is open, by Discard: it is on both the ready view
  /// and the list, so one path covers either. It sits below the whole list, so
  /// it is scrolled to rather than assumed on screen, and the confirmation is
  /// answered.
  Future<void> endOpenWorkout(WidgetTester tester) async {
    if (find.byType(SessionOverviewBody).evaluate().isEmpty) return;
    final discard = find.byKey(SessionActions.discardKey);
    await tester.scrollUntilVisible(
      discard,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await tester.tap(discard);
    await settle(tester);
    if (find.byKey(confirmDestructiveKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(confirmDestructiveKey));
      await settle(tester);
    }
  }

  /// Boots the app onto the landing, ending whatever was left running.
  ///
  /// These run in order against one real on-device database, so a test that
  /// leaves a workout open would hand the next one a takeover instead of the
  /// landing. That is the app behaving correctly; the isolation is this
  /// harness's job.
  Future<void> bootToLanding(WidgetTester tester) async {
    await bootApp(tester);
    await endOpenWorkout(tester);
  }

  Finder pickerField() => find.descendant(
        of: find.byType(ExercisePickerSheet),
        matching: find.byType(TextField),
      );

  testWidgets('a template workout: preview, start, ready view, list, finish',
      (tester) async {
    await bootToLanding(tester);

    expect(find.byKey(WorkoutLandingBody.startWorkoutKey), findsOneWidget,
        reason: 'the pinned Start workout bar is on the landing');
    expect(find.byKey(WorkoutLandingBody.templateKey('chest-triceps')),
        findsOneWidget);

    // A tile previews first; nothing starts until Start workout.
    await tapTemplate(tester, 'chest-triceps');
    expect(find.byKey(TemplatePreviewSheet.startKey), findsOneWidget);
    expect(find.text('Barbell bench press'), findsOneWidget);
    await tester.tap(find.byKey(TemplatePreviewSheet.startKey));
    await settle(tester);

    // Starting replaces the landing, and opens on the ready view.
    expect(find.byType(SessionOverviewBody), findsOneWidget);
    expect(find.byKey(SessionOverviewBody.startLoggingKey), findsOneWidget);
    expect(find.text('6 exercises planned'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('WORKOUT IN PROGRESS'), findsNothing,
        reason: 'nothing has started yet');

    // Start logging opens the picker over the map, planned exercises first.
    await tester.tap(find.byKey(SessionOverviewBody.startLoggingKey));
    await settle(tester);
    expect(find.text('What are you starting with?'), findsOneWidget);
    expect(find.text('IN THIS WORKOUT'), findsOneWidget);

    // Dismissing it leaves the list, with the live strip.
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);
    expect(find.text(SessionOverviewBody.keepLoggingLabel), findsOneWidget);
    expect(find.text('WORKOUT IN PROGRESS'), findsOneWidget);
    expect(find.text('UP NEXT'), findsOneWidget);

    // Finish with nothing logged: the workout is dropped, never saved.
    await tester.tap(find.byKey(SessionActions.finishKey));
    await settle(tester);
    expect(find.byType(SessionOverviewBody), findsNothing,
        reason: 'a workout with no completed sets is never saved');
    expect(find.byKey(WorkoutLandingBody.startWorkoutKey), findsOneWidget,
        reason: 'and the landing is back');
  });

  testWidgets('an empty workout: start, pick, log, finish, save as a template',
      (tester) async {
    await bootToLanding(tester);

    await tester.tap(find.byKey(WorkoutLandingBody.startWorkoutKey));
    await settle(tester);
    expect(find.text('Nothing logged yet'), findsOneWidget);

    await tester.tap(find.byKey(SessionOverviewBody.startLoggingKey));
    await settle(tester);
    await tester.enterText(pickerField(), 'barbell curl');
    await settle(tester);
    await tester.tap(find.byKey(ExercisePickerSheet.rowKey('barbell-curl')));
    await settle(tester);

    // A lift never performed meets its page first (the debug sample history
    // may already include this one, in which case logging opens directly).
    if (find.text('Start logging').evaluate().isNotEmpty) {
      await tester.tap(find.text('Start logging'));
      await settle(tester);
    }
    expect(find.byType(SetLoggingScreen), findsOneWidget);

    // Log one real set.
    await tester.enterText(find.byType(TextField).first, '30');
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(1), '10');
    await settle(tester);
    await tester.tap(find.byKey(SetRow.checkKey(0)));
    await settle(tester);
    await tester.tap(find.byKey(SetLoggingScreen.markDoneKey));
    await settle(tester);

    // Back at the list, with the work recorded and the live strip showing.
    expect(find.byType(SessionOverviewBody), findsOneWidget);
    expect(find.text('Barbell curl'), findsOneWidget);
    expect(find.text('30kg × 10'), findsOneWidget,
        reason: 'the set renders through the one shared formatter');
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('WORKOUT IN PROGRESS'), findsOneWidget);

    // Finishing saves it and lands on the card.
    await tester.tap(find.byKey(SessionActions.finishKey));
    await settle(tester);
    expect(find.byType(SessionSummaryScreen), findsOneWidget,
        reason: 'the finished workout is shown back as a card worth keeping');
    expect(find.text('TURTLELIFT'), findsOneWidget);
    expect(find.text('Sets'), findsOneWidget);

    // Save it as a template: that is how a user's own templates are made.
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await settle(tester);
    await tester.tap(find.byKey(SessionSummaryScreen.saveAsTemplateKey));
    await settle(tester);
    await tester.enterText(
      find.descendant(
          of: find.byType(Dialog), matching: find.byType(TextField)),
      'Curl day',
    );
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    // And the History tab lists the workout, from real data.
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.byKey(GlassTabBar.itemKey(2)));
    await settle(tester);
    expect(find.text('Barbell curl'), findsWidgets,
        reason: 'the History tab reads the workouts the user actually did');

    // Back on Workout, the new template is under My templates.
    await tester.tap(find.byKey(GlassTabBar.itemKey(0)));
    await settle(tester);
    expect(find.text(WorkoutLandingBody.customGroupLabel), findsOneWidget);
    expect(find.text('Curl day'), findsWidgets);
  });

  testWidgets('an open workout survives a restart', (tester) async {
    await bootToLanding(tester);

    await tapTemplate(tester, 'back-biceps');
    await tester.tap(find.byKey(TemplatePreviewSheet.startKey));
    await settle(tester);
    expect(find.byType(SessionOverviewBody), findsOneWidget);

    // Boot the app again over the same database, as a cold start would.
    await bootApp(tester);

    expect(
      find.byType(SessionOverviewBody),
      findsOneWidget,
      reason: 'an open workout persists indefinitely and takes the tab over on '
          'the first frame, never showing the landing first',
    );

    await endOpenWorkout(tester);
  });
}
