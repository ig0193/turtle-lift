import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/notification_permission.dart';
import 'package:turtle_lift/src/data/reminder_prefs.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/diet_reminders_screen.dart';
import 'package:turtle_lift/src/ui/reminder_controls.dart';

import 'support/fake_reminder_scheduler.dart';

/// Profile audit B5, B7, B8 and B11 (ADR 0014 §5): reminders never say "on"
/// when nothing will fire, every time row names its meal, quick taps never lose
/// a change, and the notifications-off note leads to Settings. (B6, the
/// training-days note, went with the Schedule: ADR 0015.)
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
          .copyWith(dietOn: true)
          .withSlot(MealSlot.breakfast,
              const SlotReminder(on: true, minute: 480))
          .withSlot(MealSlot.lunch, const SlotReminder(on: true, minute: 780));
      expect(DietPane.remindersValue(prefs, permitted: true), '2 a day');
    });
    test('on but notifications turned off in Settings', () {
      final prefs = on.copyWith(dietOn: true).withSlot(
          MealSlot.lunch, const SlotReminder(on: true, minute: 780));
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

  testWidgets('B11: the notifications-off note opens Settings',
      (tester) async {
    var opened = 0;
    reminders.permitted = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        initialReminderPrefsProvider.overrideWithValue(
            ReminderPreferences.defaults.copyWith(dietOn: true)),
        reminderSchedulerProvider.overrideWithValue(reminders),
        openAppSettingsProvider.overrideWithValue(() async => opened++),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const DietRemindersScreen(),
      ),
    ));
    await tester.pumpAndSettle();
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
    expect(find.text(DietRemindersScreen.disabledReason), findsOneWidget);
  });
}
