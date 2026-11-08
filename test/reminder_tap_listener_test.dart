import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/main.dart' as app;
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/l0_shell.dart';
import 'package:turtle_lift/src/ui/profile_root.dart';
import 'package:turtle_lift/src/ui/reminder_tap_listener.dart';
import 'package:turtle_lift/src/ui/schedule_pane.dart';
import 'package:turtle_lift/src/ui/tab_index.dart';

import 'support/fake_reminder_scheduler.dart';

/// A reminder tap while the app is running (KTD17, R11): pop to the shell
/// route, select Profile, select the target's segment. Driven through the
/// real `TurtleLiftApp`, so the listener's place in the tree is what is
/// tested, not a copy of it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseIndex index;

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    index = ExerciseIndex.fromJson(
      await container.read(exerciseLibraryProvider.future),
    );
  });

  late FakeReminderScheduler reminders;

  Future<ProviderContainer> pumpApp(WidgetTester tester,
      {List<Override> extra = const <Override>[]}) async {
    reminders = FakeReminderScheduler();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exerciseIndexProvider.overrideWithValue(index),
          foodIndexProvider.overrideWithValue(FoodIndex.fromJson(const [])),
          customTemplatesProvider.overrideWithValue(const <WorkoutTemplate>[]),
          historySessionsProvider.overrideWithValue(const <HistorySession>[]),
          planTodayProvider.overrideWithValue(LocalDate(2026, 11, 4)),
          reminderSchedulerProvider.overrideWithValue(reminders),
          ...extra,
        ],
        child: const app.TurtleLiftApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(L0Shell)));
  }

  test('the Profile tab index is found from the shell, not hard-coded', () {
    expect(kProfileTabIndex, 3);
    expect(L0Shell.tabs[kProfileTabIndex].body, isA<ProfileRoot>());
  });

  testWidgets('a diet tap over a pushed route pops to the shell and shows '
      'Profile, Diet', (tester) async {
    final container = await pumpApp(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('pushed screen')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('pushed screen'), findsOneWidget);

    reminders.tap(ReminderTarget.dietToday);
    await tester.pumpAndSettle();

    expect(find.text('pushed screen'), findsNothing,
        reason: 'the pushed route is popped first (ADR 0003: tab switches '
            'happen with an empty stack)');
    expect(navigator.canPop(), isFalse);
    expect(container.read(tabIndexProvider), 3);
    expect(container.read(profileSegmentProvider), ProfileSegment.diet);
    expect(find.byType(DietPane), findsOneWidget);
  });

  testWidgets('a diet tap selects today on Diet, even after another day was '
      'picked (KTD17)', (tester) async {
    final container = await pumpApp(tester);
    container.read(dietSelectedDayProvider.notifier).select(LocalDate(2026, 11, 7));
    expect(container.read(dietSelectedDayProvider), LocalDate(2026, 11, 7));

    reminders.tap(ReminderTarget.dietToday);
    await tester.pumpAndSettle();

    expect(container.read(dietSelectedDayProvider), LocalDate(2026, 11, 4));
  });

  testWidgets('a schedule tap leaves the Diet day alone', (tester) async {
    final container = await pumpApp(tester);
    container.read(dietSelectedDayProvider.notifier).select(LocalDate(2026, 11, 7));

    reminders.tap(ReminderTarget.schedule);
    await tester.pumpAndSettle();

    expect(container.read(dietSelectedDayProvider), LocalDate(2026, 11, 7));
  });

  testWidgets('a diet tap over an open bottom sheet closes it too',
      (tester) async {
    final container = await pumpApp(tester);
    showModalBottomSheet<void>(
      context: tester.element(find.byType(L0Shell)),
      builder: (_) => const SizedBox(height: 200, child: Text('a sheet')),
    );
    await tester.pumpAndSettle();
    expect(find.text('a sheet'), findsOneWidget);

    reminders.tap(ReminderTarget.dietToday);
    await tester.pumpAndSettle();

    expect(find.text('a sheet'), findsNothing);
    expect(container.read(tabIndexProvider), 3);
    expect(container.read(profileSegmentProvider), ProfileSegment.diet);
  });

  testWidgets('a schedule tap shows Profile, Schedule', (tester) async {
    final container = await pumpApp(tester);

    reminders.tap(ReminderTarget.schedule);
    await tester.pumpAndSettle();

    expect(container.read(tabIndexProvider), 3);
    expect(container.read(profileSegmentProvider), ProfileSegment.schedule);
    expect(find.byType(SchedulePane), findsOneWidget);
  });

  testWidgets('a tap from another Profile segment switches to Diet',
      (tester) async {
    final container = await pumpApp(tester);
    container.read(tabIndexProvider.notifier).select(3);
    container
        .read(profileSegmentProvider.notifier)
        .select(ProfileSegment.schedule);
    await tester.pumpAndSettle();

    reminders.tap(ReminderTarget.dietToday);
    await tester.pumpAndSettle();

    expect(container.read(profileSegmentProvider), ProfileSegment.diet);
  });

  group('launch overrides (cold start)', () {
    testWidgets('a diet launch target opens on Profile, Diet on the first '
        'frame (AE6)', (tester) async {
      reminders = FakeReminderScheduler();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exerciseIndexProvider.overrideWithValue(index),
            foodIndexProvider.overrideWithValue(FoodIndex.fromJson(const [])),
            customTemplatesProvider
                .overrideWithValue(const <WorkoutTemplate>[]),
            historySessionsProvider
                .overrideWithValue(const <HistorySession>[]),
            planTodayProvider.overrideWithValue(LocalDate(2026, 11, 4)),
            reminderSchedulerProvider.overrideWithValue(reminders),
            ...reminderLaunchOverrides(ReminderTarget.dietToday),
          ],
          child: const app.TurtleLiftApp(),
        ),
      );
      // One frame, no settle: the first frame must already be Diet.
      await tester.pump();

      expect(find.byType(DietPane), findsOneWidget);
      final container =
          ProviderScope.containerOf(tester.element(find.byType(L0Shell)));
      expect(container.read(tabIndexProvider), 3);
      expect(container.read(profileSegmentProvider), ProfileSegment.diet);
    });

    test('no launch target overrides nothing', () {
      expect(reminderLaunchOverrides(null), isEmpty);
    });

    test('a launch override only sets where the app opens; the user can still '
        'move', () {
      final container = ProviderContainer(
          overrides: reminderLaunchOverrides(ReminderTarget.dietToday));
      addTearDown(container.dispose);

      expect(container.read(tabIndexProvider), 3);
      container.read(tabIndexProvider.notifier).select(0);
      expect(container.read(tabIndexProvider), 0);
      container
          .read(profileSegmentProvider.notifier)
          .select(ProfileSegment.personal);
      expect(container.read(profileSegmentProvider), ProfileSegment.personal);
    });
  });
}
