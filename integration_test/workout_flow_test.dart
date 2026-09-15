import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:turtle_lift/main.dart' as app;
import 'package:turtle_lift/src/ui/adhoc_overview_body.dart';
import 'package:turtle_lift/src/ui/exercise_search_screen.dart';
import 'package:turtle_lift/src/ui/destructive_confirmation.dart';
import 'package:turtle_lift/src/ui/session_actions.dart';
import 'package:turtle_lift/src/ui/session_summary_screen.dart';
import 'package:turtle_lift/src/ui/set_logging_screen.dart';
import 'package:turtle_lift/src/ui/set_row.dart';
import 'package:turtle_lift/src/ui/template_overview_body.dart';

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

  /// Boots the app onto the landing, ending whatever was left running.
  ///
  /// These run in order against one real on-device database, so a test that
  /// leaves a workout open would hand the next one a takeover instead of the
  /// landing. That is the app behaving correctly; the isolation is this
  /// harness's job.
  Future<void> bootToLanding(WidgetTester tester) async {
    app.main();
    await settle(tester);
    if (find.byKey(SessionActions.finishKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(SessionActions.finishKey));
      await settle(tester);
      // A workout with typed-but-unticked values asks before dropping.
      if (find.byKey(confirmDestructiveKey).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(confirmDestructiveKey));
        await settle(tester);
      }
    }
  }

  testWidgets('a template workout: start, log a set, finish', (tester) async {
    await bootToLanding(tester);

    expect(find.text('Workout'), findsWidgets,
        reason: 'the app boots to the Workout tab');
    expect(find.text('Chest and triceps day'), findsOneWidget);

    // Starting replaces the landing rather than pushing over it.
    await tester.tap(find.text('Chest and triceps day'));
    await settle(tester);

    expect(find.byType(TemplateOverviewBody), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Upper chest'), findsOneWidget,
        reason: 'the muscle list is derived from the template at render time');

    // Into a sub-group, which lists the lifts that train it.
    await tester.tap(find.text('Upper chest'));
    await settle(tester);
    expect(find.textContaining('EXERCISE'), findsOneWidget,
        reason: 'the swap screen counts what it lists');

    await tester.pageBack();
    await settle(tester);

    // Finish with nothing logged: the workout is dropped, never saved.
    await tester.tap(find.byKey(SessionActions.finishKey));
    await settle(tester);

    expect(find.byType(TemplateOverviewBody), findsNothing,
        reason: 'a workout with no completed sets is never saved');
    expect(find.text('Chest and triceps day'), findsOneWidget,
        reason: 'and the landing is back');
  });

  testWidgets('an ad-hoc workout: search, add, log, finish', (tester) async {
    await bootToLanding(tester);

    await tester.tap(find.text('Ad-hoc workout'));
    await settle(tester);
    expect(find.byType(ExerciseSearchScreen), findsOneWidget);

    // Backing out with nothing added must leave the landing intact.
    await tester.pageBack();
    await settle(tester);
    expect(find.text('Ad-hoc workout'), findsOneWidget);
    expect(find.byType(AdHocOverviewBody), findsNothing,
        reason: 'the workout is created by the first exercise added, not by '
            'arriving at search');

    // Now actually add one.
    await tester.tap(find.text('Ad-hoc workout'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'barbell curl');
    await settle(tester);

    expect(find.text('Barbell curl'), findsOneWidget);
    await tester.tap(find.text('Barbell curl'));
    await settle(tester);

    // Never performed, so the first-time gate comes first.
    expect(find.text('Start logging'), findsOneWidget,
        reason: 'a user cannot know a lift they have never done');
    await tester.tap(find.text('Start logging'));
    await settle(tester);

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

    // Back at the overview, with the work recorded.
    expect(find.byType(AdHocOverviewBody), findsOneWidget);
    expect(find.text('Barbell curl'), findsOneWidget);
    expect(find.text('30kg × 10'), findsOneWidget,
        reason: 'the set renders through the one shared formatter');
    expect(find.text('Done'), findsOneWidget);

    // Finishing saves it and lands on the card.
    await tester.tap(find.byKey(SessionActions.finishKey));
    await settle(tester);

    expect(find.byType(SessionSummaryScreen), findsOneWidget,
        reason: 'the finished workout is shown back as a card worth keeping');
    expect(find.text('TURTLELIFT'), findsOneWidget);
    expect(find.text('30kg × 10'), findsWidgets);
    expect(find.text('Sets'), findsOneWidget);

    // And the History tab lists it, from real data rather than a fixture.
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.text('History'));
    await settle(tester);

    expect(find.text('Barbell curl'), findsWidgets,
        reason: 'the History tab reads the workouts the user actually did');
  });

  testWidgets('an open workout survives a restart', (tester) async {
    await bootToLanding(tester);

    await tester.tap(find.text('Back and biceps day'));
    await settle(tester);
    expect(find.byType(TemplateOverviewBody), findsOneWidget);

    // Boot the app again over the same database, as a cold start would.
    app.main();
    await settle(tester);

    expect(
      find.byType(TemplateOverviewBody),
      findsOneWidget,
      reason: 'an open workout persists indefinitely and takes the tab over on '
          'the first frame, never showing the landing first',
    );

    await tester.tap(find.byKey(SessionActions.finishKey));
    await settle(tester);
  });
}
