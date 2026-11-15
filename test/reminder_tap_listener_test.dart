import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/main.dart' as app;
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/glance_bridge.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart';
import 'package:turtle_lift/src/data/today.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/diet_root.dart';
import 'package:turtle_lift/src/ui/l0_shell.dart';
import 'package:turtle_lift/src/ui/you_root.dart';
import 'package:turtle_lift/src/ui/reminder_tap_listener.dart';
import 'package:turtle_lift/src/ui/tab_index.dart';
import 'package:turtle_lift/src/ui/tab_routes.dart' show kYouTabIndex;
import 'package:turtle_lift/src/ui/workout_root.dart';

import 'support/fake_reminder_scheduler.dart';

/// A reminder tap while the app is running (KTD17, R11): pop to the shell
/// route, then select the target's tab (a diet reminder is the Diet tab, a
/// workout target the Workout tab; `docs/adr/0016-you-tab-and-diet-tab.md`).
/// Driven through the real `TurtleLiftApp`, so the listener's place in the
/// tree is what is tested, not a copy of it.
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

  test('the tab indexes are found from the shell, not hard-coded', () {
    expect(kDietTabIndex, 0);
    expect(kWorkoutTabIndex, 1);
    expect(kYouTabIndex, 3);
    expect(L0Shell.tabs[kDietTabIndex].body, isA<DietRoot>());
    expect(L0Shell.tabs[kWorkoutTabIndex].body, isA<WorkoutRoot>());
    expect(L0Shell.tabs[kYouTabIndex].body, isA<YouRoot>());
  });

  testWidgets('a diet tap over a pushed route pops to the shell and shows '
      'the Diet tab', (tester) async {
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
    expect(container.read(tabIndexProvider), kDietTabIndex);
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

  testWidgets('a training tap leaves the Diet day alone', (tester) async {
    final container = await pumpApp(tester);
    container.read(dietSelectedDayProvider.notifier).select(LocalDate(2026, 11, 7));

    reminders.tap(ReminderTarget.workout);
    await tester.pumpAndSettle();

    expect(container.read(dietSelectedDayProvider), LocalDate(2026, 11, 7));
  });

  testWidgets('a diet tap brings today\'s week back into the strip, however '
      'far it was slid (ADR 0017)', (tester) async {
    final container = await pumpApp(tester);
    container.read(dietSelectedDayProvider.notifier).select(LocalDate(2026, 10, 28));
    container.read(dietStripStartProvider.notifier).shift(-9); // 24 Oct
    expect(container.read(dietStripStartProvider), LocalDate(2026, 10, 24));

    reminders.tap(ReminderTarget.dietToday);
    await tester.pumpAndSettle();

    expect(container.read(dietSelectedDayProvider), LocalDate(2026, 11, 4));
    expect(container.read(dietStripStartProvider), LocalDate(2026, 11, 2),
        reason: 'this week\'s Monday, with today in it');
  });

  testWidgets('a workout tap leaves the strip where it was', (tester) async {
    final container = await pumpApp(tester);
    container.read(dietStripStartProvider.notifier).shift(-3);

    reminders.tap(ReminderTarget.workout);
    await tester.pumpAndSettle();

    expect(container.read(dietStripStartProvider), LocalDate(2026, 10, 30));
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
    expect(container.read(tabIndexProvider), kDietTabIndex);
  });

  testWidgets('a workout-target tap opens the Workout tab, where you train '
      '(ADR 0008; a training notification an earlier build delivered still '
      'carries this payload)', (tester) async {
    final container = await pumpApp(tester);
    container.read(tabIndexProvider.notifier).select(kYouTabIndex);
    await tester.pumpAndSettle();

    reminders.tap(ReminderTarget.workout);
    await tester.pumpAndSettle();

    expect(container.read(tabIndexProvider), kWorkoutTabIndex);
    expect(find.byType(WorkoutLandingBody), findsOneWidget);
    expect(find.byType(DietPane), findsNothing);
  });

  testWidgets('a workout-target tap over a pushed route pops it first',
      (tester) async {
    final container = await pumpApp(tester);
    container.read(tabIndexProvider.notifier).select(kYouTabIndex);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('pushed screen')),
    ));
    await tester.pumpAndSettle();

    reminders.tap(ReminderTarget.workout);
    await tester.pumpAndSettle();

    expect(find.text('pushed screen'), findsNothing);
    expect(navigator.canPop(), isFalse);
    expect(container.read(tabIndexProvider), kWorkoutTabIndex);
  });

  testWidgets('a diet tap from the You tab switches to the Diet tab and leaves '
      'the You segment alone', (tester) async {
    final container = await pumpApp(tester);
    container.read(tabIndexProvider.notifier).select(kYouTabIndex);
    container
        .read(youSegmentProvider.notifier)
        .select(YouSegment.analysis);
    await tester.pumpAndSettle();

    reminders.tap(ReminderTarget.dietToday);
    await tester.pumpAndSettle();

    expect(container.read(tabIndexProvider), kDietTabIndex);
    expect(container.read(youSegmentProvider), YouSegment.analysis,
        reason: 'Diet is its own tab now; there is no segment to select');
    expect(find.byType(DietPane), findsOneWidget);
  });

  testWidgets('a diet tap from the Workout tab switches to the Diet tab',
      (tester) async {
    final container = await pumpApp(tester);
    expect(container.read(tabIndexProvider), kWorkoutTabIndex);

    reminders.tap(ReminderTarget.dietToday);
    await tester.pumpAndSettle();

    expect(container.read(tabIndexProvider), kDietTabIndex);
  });

  testWidgets('a tap on the Live Activity or the home-screen widget opens the '
      'Workout tab, popping what was pushed (ADR 0008)', (tester) async {
    final glance = _FakeGlance();
    final container = await pumpApp(tester,
        extra: [glanceBridgeProvider.overrideWithValue(glance)]);
    container.read(tabIndexProvider.notifier).select(kYouTabIndex);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('pushed screen')),
    ));
    await tester.pumpAndSettle();

    glance.taps.add(null);
    await tester.pumpAndSettle();

    expect(find.text('pushed screen'), findsNothing);
    expect(container.read(tabIndexProvider), kWorkoutTabIndex);
  });

  group('launch overrides (cold start)', () {
    testWidgets('a diet launch target opens on the Diet tab on the first '
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
      expect(container.read(tabIndexProvider), kDietTabIndex);
    });

    test('a training launch target opens on the Workout tab', () {
      final container = ProviderContainer(
          overrides: reminderLaunchOverrides(ReminderTarget.workout));
      addTearDown(container.dispose);

      expect(container.read(tabIndexProvider), kWorkoutTabIndex);
      expect(container.read(youSegmentProvider), YouSegment.activity,
          reason: 'You is left alone: it still opens on Activity');
    });

    test('no launch target overrides nothing', () {
      expect(reminderLaunchOverrides(null), isEmpty);
    });

    test('a launch override only sets where the app opens; the user can still '
        'move', () {
      final container = ProviderContainer(
          overrides: reminderLaunchOverrides(ReminderTarget.dietToday));
      addTearDown(container.dispose);

      expect(container.read(tabIndexProvider), kDietTabIndex);
      container.read(tabIndexProvider.notifier).select(kWorkoutTabIndex);
      expect(container.read(tabIndexProvider), kWorkoutTabIndex);
      container
          .read(youSegmentProvider.notifier)
          .select(YouSegment.profile);
      expect(container.read(youSegmentProvider), YouSegment.profile);
    });
  });
}

class _FakeGlance implements GlanceBridge {
  final StreamController<void> taps = StreamController<void>.broadcast();

  @override
  Stream<void> get openWorkoutTaps => taps.stream;

  @override
  Future<void> showSession(SessionGlance glance) async {}

  @override
  Future<void> endSession() async {}

  @override
  Future<void> showWeek(WeekGlance glance) async {}
}
