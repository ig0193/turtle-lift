import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/main.dart' as app;
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/data_reset.dart';
import 'package:turtle_lift/src/data/diet_plan.dart';
import 'package:turtle_lift/src/data/diet_plan_store.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/meal_ticks.dart';
import 'package:turtle_lift/src/data/reminder_prefs.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/glass_tab_bar.dart';
import 'package:turtle_lift/src/ui/history_root.dart';
import 'package:turtle_lift/src/ui/l0_shell.dart';
import 'package:turtle_lift/src/ui/muscles_root.dart';
import 'package:turtle_lift/src/ui/profile_root.dart';
import 'package:turtle_lift/src/ui/tab_index.dart';
import 'package:turtle_lift/src/ui/workout_root.dart';

import 'support/fake_reminder_scheduler.dart';

/// What the app opens on. Cheap to break and expensive to notice: `main.dart`
/// is edited rarely and by hand, and a wrong `home:` still compiles, still
/// renders and still passes every widget test that pumps its own screen.
///
/// **One of these tests runs `main()` itself.** Pumping `TurtleLiftApp` with a
/// hand-copied override list — which is all this file used to do — proves the
/// list in this file, not the one in `main.dart`. Deleting
/// `exerciseIndexProvider` from the real boot would have thrown on the Muscles
/// root's first frame on a device, and left every test green.
void main() {
  // The exercise library is read off `rootBundle`, which needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  // `main()` opens its own database while this file's tests hold others.
  // Drift flags that on debug builds as a possible mistake; here it is the
  // arrangement under test.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  /// The shipped library, indexed the way `main()` indexes it.
  ///
  /// Only the direct-pump tests below need this. The test that runs `main()`
  /// deliberately does not build an index of its own — `main()` building the
  /// right one is the thing being asserted.
  late ExerciseIndex index;

  // `main()` starts reminders through a seam, because the notification plugin
  // and `flutter_timezone` have no platform channel here. Every test that runs
  // `main()` gets a launch with no notification unless it says otherwise.
  var prepareCalls = 0;
  setUp(() {
    prepareCalls = 0;
    app.prepareReminders = () async {
      prepareCalls++;
      return null;
    };
  });
  tearDown(() => app.prepareReminders = pluginReminderScheduler.initialize);

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    index = ExerciseIndex.fromJson(
      await container.read(exerciseLibraryProvider.future),
    );
  });

  testWidgets('the app boots into the L0 shell on the page background',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [exerciseIndexProvider.overrideWithValue(index)],
        child: const app.TurtleLiftApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(L0Shell), findsOneWidget,
        reason: 'the app must open on the tab shell, not on any other screen');

    // Which tab it opens on is part of the boot contract, and only this file
    // exercises the real TurtleLiftApp path -- the shell's own tests host
    // L0Shell directly and would not notice main.dart handing it a different
    // starting index.
    expect(find.text('Ready-made').hitTestable(), findsOneWidget,
        reason: 'the app opens on the Workout tab, which lists the templates');

    final context = tester.element(find.byType(L0Shell));
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      AppPalette.pageBackground,
      reason: 'the shell must sit on the palette page background',
    );
  });

  testWidgets('running main() itself boots an app with every provider it '
      'needs already overridden', (tester) async {
    // The one thing swapped out, and the reason `openAppDatabase` exists: the
    // real constructor reaches `path_provider`, which has no platform channel
    // here. Everything else below is `main()` as it ships.
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    app.openAppDatabase = () => database;
    addTearDown(() async {
      app.openAppDatabase = AppDatabase.new;
      await database.close();
    });

    // **`runAsync`, because `main()`'s two awaits are real I/O.** A
    // `testWidgets` body runs under fake async, where the asset read and the
    // database query never complete and the boot simply hangs. This is the
    // one place in the suite that needs it, and it is needed precisely
    // because the entrypoint is being run rather than imitated.
    await tester.runAsync(app.main);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'booting the real entrypoint must not throw');
    expect(find.byType(ErrorWidget), findsNothing,
        reason: 'a provider that threw during build renders an ErrorWidget '
            'rather than failing the pump');
    expect(find.byType(L0Shell), findsOneWidget);

    // The assertion this test exists for. `L0Shell` mounts all three roots in
    // an IndexedStack, so the Muscles root builds on the first frame whichever
    // tab is showing -- and it reads `exerciseIndexProvider`, which throws
    // rather than defaulting. Drop that override from `main()` and this line
    // is what catches it.
    // `skipOffstage: false` because the IndexedStack keeps the two unselected
    // roots mounted but off stage; the app opens on Workout.
    final muscles = find.byType(MusclesRoot, skipOffstage: false);
    expect(muscles, findsOneWidget,
        reason: 'the Muscles root must build under the boot overrides that '
            "main() installs, not under a test file's copy of them");

    // And it must have a real index, not merely an instance: the heading is
    // counted from the taxonomy and the rows are counted from the library, so
    // a root that rendered with an empty index would still be found above.
    final shellContext = tester.element(muscles);
    expect(
      ProviderScope.containerOf(shellContext).read(exerciseIndexProvider).all,
      hasLength(260),
      reason: 'main() must fold the shipped library into the index it '
          'overrides with -- an empty one renders the whole tab as zeroes, '
          'silently',
    );

    // The food list joins the same boot record (KTD11). Like the exercise
    // index, the provider throws without an override; unlike it, the real
    // asset must have loaded into an available index, not the fallback.
    final foods =
        ProviderScope.containerOf(shellContext).read(foodIndexProvider);
    expect(foods.isAvailable, isTrue,
        reason: 'main() must load the shipped food list, not fall back');
    expect(foods.all, isNotEmpty);
  });

  testWidgets('a broken food list still boots, Diet is unavailable and every '
      'tab renders (KTD11, R26)', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    app.openAppDatabase = () => database;
    app.readFoodListAsset = () async => '[{"id": "curd",';
    final reported = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() async {
      FlutterError.onError = previousOnError;
      app.openAppDatabase = AppDatabase.new;
      app.readFoodListAsset = readShippedFoodList;
      await database.close();
    });

    await tester.runAsync(app.main);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'a bad food asset must not fail boot');
    expect(reported, hasLength(1),
        reason: 'the load failure is reported, not swallowed');
    expect(reported.single.exception, isA<FormatException>());

    final shellContext = tester.element(find.byType(L0Shell));
    final container = ProviderScope.containerOf(shellContext);
    expect(container.read(foodIndexProvider).isAvailable, isFalse);
    expect(container.read(exerciseIndexProvider).all, hasLength(260),
        reason: 'the exercise library is unaffected by the food list');

    // Every tab still renders: walk the bar and look for each root on stage.
    final roots = <Type>[WorkoutRoot, MusclesRoot, HistoryRoot, ProfileRoot];
    for (var tab = 0; tab < roots.length; tab++) {
      await tester.tap(find.byKey(GlassTabBar.itemKey(tab)));
      await tester.pumpAndSettle();
      expect(find.byType(roots[tab]), findsOneWidget,
          reason: 'tab $tab must render with the food list unavailable');
    }
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('main() seeds the Diet plan, ticks and target from the '
      'database, and refreshes today on resume', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    app.openAppDatabase = () => database;
    addTearDown(() async {
      app.openAppDatabase = AppDatabase.new;
      await database.close();
    });
    final today = LocalDate.today();
    await tester.runAsync(() async {
      await DietPlanStore(database).addFood(
        weekdays: <int>{today.weekday - 1},
        slot: MealSlot.lunch,
        foodId: 'any-food',
        halves: 2,
      );
      await MealTickStore(database).toggle(today, MealSlot.lunch);
      await SettingsStore(database).writeProteinTarget(140);
    });

    await tester.runAsync(app.main);
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(L0Shell)));
    expect(container.read(dietPlanLogProvider).single.items.single.foodId,
        'any-food');
    expect(container.read(mealTicksProvider),
        <MealTick>{MealTick(date: today, slot: MealSlot.lunch)});
    expect(container.read(proteinTargetProvider), 140);
    expect(find.byType(app.RefreshTodayOnResume), findsOneWidget,
        reason: 'the app must re-read today when it comes back (KTD13)');
  });

  testWidgets('a debug main() over an empty database seeds a sample Diet '
      '(U18)', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    app.openAppDatabase = () => database;
    addTearDown(() async {
      app.openAppDatabase = AppDatabase.new;
      await database.close();
    });

    await tester.runAsync(app.main);
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(L0Shell)));
    expect(container.read(proteinTargetProvider), isNotNull,
        reason: 'tests run in debug mode, where main() seeds a sample diet');
    expect(container.read(dietPlanLogProvider).single.items, isNotEmpty);
    expect(container.read(mealTicksProvider), hasLength(1));
  });

  group('reminders at boot (KTD17)', () {
    ProviderContainer shellContainer(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(L0Shell)));

    testWidgets('a cold-start diet/today launch boots into Profile with Diet '
        'selected (AE6)', (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      app.openAppDatabase = () => database;
      app.prepareReminders = () async => ReminderTarget.dietToday;
      addTearDown(() async {
        app.openAppDatabase = AppDatabase.new;
        await database.close();
      });

      await tester.runAsync(app.main);
      await tester.pump();

      final container = shellContainer(tester);
      expect(container.read(tabIndexProvider), 3);
      expect(container.read(profileSegmentProvider), ProfileSegment.diet);
      expect(find.byType(DietPane), findsOneWidget,
          reason: 'the first frame after boot is Profile, Diet');
    });

    testWidgets('after a cold-start diet launch, Delete all data and the '
        'reboot land on Personal, not Diet (AE8)', (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      app.openAppDatabase = () => database;
      app.prepareReminders = () async {
        prepareCalls++;
        return ReminderTarget.dietToday;
      };
      addTearDown(() async {
        app.openAppDatabase = AppDatabase.new;
        await database.close();
      });

      await tester.runAsync(app.main);
      await tester.pumpAndSettle();
      expect(shellContainer(tester).read(profileSegmentProvider),
          ProfileSegment.diet);

      final restart = shellContainer(tester).read(appRestartProvider);
      final reminders = FakeReminderScheduler();
      await tester.runAsync(() async {
        await wipeAllData(database, reminders: reminders);
        await restart();
      });
      await tester.pumpAndSettle();

      final rebooted = shellContainer(tester);
      expect(rebooted.read(profileSegmentProvider), ProfileSegment.personal,
          reason: 'the launch target belongs to the first boot only; the '
              'plugin reports it for the whole process');
      expect(rebooted.read(tabIndexProvider), 0);
      expect(rebooted.read(dietPlanLogProvider), isEmpty,
          reason: 'the debug sample diet is never re-seeded after a wipe');
      expect(rebooted.read(proteinTargetProvider), isNull);
      expect(prepareCalls, 1,
          reason: 'reminders start once per process, never on the reboot');
      expect(reminders.cancelAllCount, 1);
    });

    testWidgets('main() seeds the reminder preferences from the database',
        (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      app.openAppDatabase = () => database;
      addTearDown(() async {
        app.openAppDatabase = AppDatabase.new;
        await database.close();
      });
      final stored = ReminderPreferences.defaults
          .copyWith(dietOn: true, summaryOn: true, summaryMinute: 6 * 60);
      await tester.runAsync(() => ReminderPrefsStore(database).write(stored));

      await tester.runAsync(app.main);
      await tester.pumpAndSettle();

      expect(shellContainer(tester).read(reminderPrefsProvider), stored);
      expect(shellContainer(tester).read(tabIndexProvider), 0,
          reason: 'with no launch target the app opens on Workout');
    });

    testWidgets('reminders that fail to start are reported and the app still '
        'boots', (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      app.openAppDatabase = () => database;
      app.prepareReminders = () async => throw StateError('no plugin');
      final reported = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() async {
        FlutterError.onError = previousOnError;
        app.openAppDatabase = AppDatabase.new;
        await database.close();
      });

      await tester.runAsync(app.main);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(L0Shell), findsOneWidget);
      expect(reported.single.exception, isA<StateError>());
    });
  });
}
