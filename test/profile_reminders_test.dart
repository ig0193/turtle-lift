import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/notification_permission.dart';
import 'package:turtle_lift/src/data/reminder_prefs.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/diet_reminders_screen.dart';
import 'package:turtle_lift/src/ui/profile_root.dart';
import 'package:turtle_lift/src/ui/reminder_controls.dart';
import 'package:turtle_lift/src/ui/schedule_pane.dart';

import 'support/fake_reminder_scheduler.dart';

/// Profile audit B5-B8 and B11 (ADR 0014 §5): reminders never say "on" when
/// nothing will fire, every time row names its meal, quick taps never lose a
/// change, and the notifications-off note leads to Settings.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late FakeReminderScheduler reminders;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    reminders = FakeReminderScheduler();
  });
  tearDown(() => database.close());

  group('B5: saves show the new value before the write finishes', () {
    test('training days', () async {
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(database),
        planTodayProvider.overrideWithValue(const LocalDate(2026, 11, 10)),
      ]);
      addTearDown(container.dispose);
      final log = container.read(trainingPlanLogProvider.notifier);
      final first = log.save(<int>{0});
      expect(container.read(todayPlanWeekdaysProvider), <int>{0},
          reason: 'a second tap reads this, so it must already be there');
      final second =
          log.save(<int>{...container.read(todayPlanWeekdaysProvider), 1});
      await Future.wait(<Future<void>>[first, second]);
      expect(container.read(todayPlanWeekdaysProvider), <int>{0, 1});
    });

    test('reminder preferences', () async {
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(database),
      ]);
      addTearDown(container.dispose);
      final log = container.read(reminderPrefsProvider.notifier);
      final write = log.save(ReminderPreferences.defaults.copyWith(dietOn: true));
      expect(container.read(reminderPrefsProvider).dietOn, isTrue);
      await write;
    });
  });

  group('B7: the Diet Reminders row value', () {
    const on = ReminderPreferences.defaults;
    test('off', () {
      expect(DietPane.remindersValue(on, permitted: true), 'Off');
    });
    test('on with nothing chosen says so', () {
      expect(DietPane.remindersValue(on.copyWith(dietOn: true), permitted: true),
          'None chosen');
    });
    test('on with two chosen', () {
      final prefs = on
          .copyWith(dietOn: true, summaryOn: true)
          .withSlot(MealSlot.lunch, const SlotReminder(on: true, minute: 780));
      expect(DietPane.remindersValue(prefs, permitted: true), '2 a day');
    });
    test('on but notifications turned off in Settings', () {
      final prefs = on.copyWith(dietOn: true, summaryOn: true);
      expect(DietPane.remindersValue(prefs, permitted: false),
          'Off in Settings');
    });
  });

  test('notificationPermissionProvider reads the scheduler and refreshes',
      () async {
    final container = ProviderContainer(overrides: [
      reminderSchedulerProvider.overrideWithValue(reminders),
    ]);
    addTearDown(container.dispose);
    expect(container.read(notificationPermissionProvider), isNull);
    await container.read(notificationPermissionProvider.notifier).refresh();
    expect(container.read(notificationPermissionProvider), isFalse);
    reminders.permitted = true;
    await container.read(notificationPermissionProvider.notifier).refresh();
    expect(container.read(notificationPermissionProvider), isTrue);
  });

  Widget scheduleHost({
    required ReminderPreferences prefs,
    Set<int> days = const <int>{},
    Future<void> Function()? openSettings,
  }) =>
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          planTodayProvider.overrideWithValue(const LocalDate(2026, 11, 10)),
          initialTrainingPlanProvider.overrideWithValue(<TrainingPlanEntry>[
            if (days.isNotEmpty)
              TrainingPlanEntry(
                  effectiveFrom: const LocalDate(2026, 11, 9), weekdays: days),
          ]),
          initialReminderPrefsProvider.overrideWithValue(prefs),
          reminderSchedulerProvider.overrideWithValue(reminders),
          if (openSettings != null)
            openAppSettingsProvider.overrideWithValue(openSettings),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: AppScreen.root(title: 'Profile', body: const ProfileRoot()),
        ),
      );

  Future<void> openSchedule(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.schedule)));
    await tester.pumpAndSettle();
  }

  testWidgets('B6: Remind me on with no training days says to pick one',
      (tester) async {
    reminders.permitted = true;
    await tester.pumpWidget(scheduleHost(
        prefs: ReminderPreferences.defaults.copyWith(scheduleOn: true)));
    await openSchedule(tester);
    expect(find.text(SchedulePane.noDaysNote), findsOneWidget);

    await tester.tap(find.byKey(SchedulePane.dayChipKey(0)));
    await tester.pumpAndSettle();
    expect(find.text(SchedulePane.noDaysNote), findsNothing);
  });

  testWidgets('B6: no hint while Remind me is off', (tester) async {
    await tester.pumpWidget(scheduleHost(prefs: ReminderPreferences.defaults));
    await openSchedule(tester);
    expect(find.text(SchedulePane.noDaysNote), findsNothing);
  });

  testWidgets('B11: the notifications-off note opens Settings',
      (tester) async {
    var opened = 0;
    reminders.permitted = false;
    await tester.pumpWidget(scheduleHost(
      prefs: ReminderPreferences.defaults.copyWith(scheduleOn: true),
      days: <int>{0},
      openSettings: () async => opened++,
    ));
    await openSchedule(tester);
    expect(find.text(kNotificationsOffCopy), findsOneWidget);
    await tester.tap(find.byKey(NotificationsOffNote.openSettingsKey));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('B8: each meal time row is named, and the disabled reason '
      'appears once', (tester) async {
    tester.view.physicalSize = const Size(1170, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        reminderSchedulerProvider.overrideWithValue(reminders),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const DietRemindersScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    for (final slot in MealSlot.values) {
      expect(
        tester
            .getSemantics(find.byKey(DietRemindersScreen.slotTimeKey(slot)))
            .label,
        startsWith('${slot.label} time.'),
      );
    }
    expect(
      tester
          .getSemantics(find.byKey(DietRemindersScreen.summaryTimeKey))
          .label,
      startsWith('Morning summary time.'),
    );
    expect(find.text(DietRemindersScreen.disabledReason), findsOneWidget);
  });
}
