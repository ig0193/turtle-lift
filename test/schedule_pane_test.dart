import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/main.dart' show RefreshTodayOnResume;
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/reminder_prefs.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/data/training_reminders.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/profile_root.dart';
import 'package:turtle_lift/src/ui/reminder_controls.dart';
import 'package:turtle_lift/src/ui/schedule_pane.dart';
import 'package:turtle_lift/src/ui/week_day_chip.dart';

import 'support/fake_reminder_scheduler.dart';

/// A scheduler on a platform without notifications (R23).
class _UnsupportedScheduler extends FakeReminderScheduler {
  @override
  bool get isSupported => false;
}

/// The Schedule pane, driven through the Profile root the way the app mounts
/// it. "Today" is pinned to Wednesday 21 October 2026.
void main() {
  late AppDatabase database;
  late FakeReminderScheduler reminders;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    reminders = FakeReminderScheduler();
  });
  tearDown(() => database.close());

  HistorySession session(String id, int day) => HistorySession(
        id: id,
        performedOn: DateTime(2026, 10, day),
        exercises: const <HistoryExercise>[],
      );

  final monWedFri = TrainingPlanEntry(
    effectiveFrom: LocalDate(2026, 10, 1),
    weekdays: const <int>{0, 2, 4},
  );

  // Wrapped in the app's RefreshTodayOnResume, which holds the
  // training-reminder sync, so these tests see what the OS would be asked.
  Widget host({
    List<TrainingPlanEntry> plan = const <TrainingPlanEntry>[],
    List<HistorySession> sessions = const <HistorySession>[],
    ReminderPreferences prefs = ReminderPreferences.defaults,
    ReminderScheduler? scheduler,
  }) =>
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          planTodayProvider.overrideWithValue(LocalDate(2026, 10, 21)),
          initialTrainingPlanProvider.overrideWithValue(plan),
          historySessionsProvider.overrideWithValue(sessions),
          initialReminderPrefsProvider.overrideWithValue(prefs),
          reminderSchedulerProvider.overrideWithValue(scheduler ?? reminders),
        ],
        child: RefreshTodayOnResume(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: AppScreen.root(title: 'Profile', body: const ProfileRoot()),
          ),
        ),
      );

  Future<void> openSchedule(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.schedule)));
    await tester.pumpAndSettle();
  }

  group('the week (ADR 0008)', () {
    testWidgets('is not on Profile any more: the pane holds only what the '
        'user types', (tester) async {
      await openSchedule(
        tester,
        host(
          plan: <TrainingPlanEntry>[monWedFri],
          sessions: <HistorySession>[session('a', 19), session('b', 12)],
        ),
      );

      expect(find.textContaining('of 3'), findsNothing,
          reason: 'the derived week lives on the Workout landing now');
      expect(find.text('Last week'), findsNothing);
      expect(find.text(SchedulePane.daysLabel), findsOneWidget);
      expect(find.text(SchedulePane.daysNote), findsOneWidget);
    });
  });

  group('the training-day chips', () {
    testWidgets('show the plan in force today', (tester) async {
      final handle = tester.ensureSemantics();
      await openSchedule(tester, host(plan: <TrainingPlanEntry>[monWedFri]));

      for (var d = 0; d < kWeekdayCount; d++) {
        expect(
          tester.getSemantics(find.byKey(SchedulePane.dayChipKey(d))),
          isSemantics(isButton: true, isSelected: monWedFri.weekdays.contains(d)),
          reason: 'weekday $d',
        );
      }
      handle.dispose();
    });

    testWidgets('are the shared WeekDayChip, outlined when selected',
        (tester) async {
      await openSchedule(tester, host(plan: <TrainingPlanEntry>[monWedFri]));

      final chip = find.byKey(SchedulePane.dayChipKey(0));
      expect(tester.widget(chip), isA<WeekDayChip>());
      final disc = tester.widget<Container>(find.descendant(
        of: chip,
        matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration),
      ));
      final box = disc.decoration! as BoxDecoration;
      expect(box.color, isNot(AppPalette.accentStrong),
          reason: 'selection controls are outlined, never filled');
      expect((box.border! as Border).top.color, AppPalette.accentStrong);
    });

    testWidgets('tapping one saves a dated plan and selects the chip',
        (tester) async {
      final handle = tester.ensureSemantics();
      await openSchedule(tester, host());

      await tester.tap(find.byKey(SchedulePane.dayChipKey(4))); // Friday
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byKey(SchedulePane.dayChipKey(4))),
        isSemantics(isButton: true, isSelected: true),
      );
      handle.dispose();

      final stored = await readStoredTrainingPlan(TrainingPlanStore(database));
      expect(stored, <TrainingPlanEntry>[
        TrainingPlanEntry(
          effectiveFrom: LocalDate(2026, 10, 19),
          weekdays: const <int>{4},
        ),
      ]);
    });

    testWidgets('turning the last day off clears the plan from today',
        (tester) async {
      await openSchedule(
        tester,
        host(
          plan: <TrainingPlanEntry>[
            TrainingPlanEntry(
              effectiveFrom: LocalDate(2026, 10, 1),
              weekdays: const <int>{4},
            ),
          ],
        ),
      );

      await tester.tap(find.byKey(SchedulePane.dayChipKey(4)));
      await tester.pumpAndSettle();

      final stored = await readStoredTrainingPlan(TrainingPlanStore(database));
      expect(stored.single.weekdays, isEmpty);
    });
  });

  group('the reminder row (ADR 0005 §3)', () {
    bool toggled(WidgetTester tester) =>
        tester
            .getSemantics(find.byKey(SchedulePane.remindSwitchKey))
            .getSemanticsData()
            .flagsCollection
            .isToggled
            .name ==
        'isTrue';

    Future<void> tapSwitch(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(SchedulePane.remindSwitchKey));
      await tester.tap(find.byKey(SchedulePane.remindSwitchKey));
      await tester.pumpAndSettle();
    }

    final on = ReminderPreferences.defaults.copyWith(scheduleOn: true);

    testWidgets('first enable shows the explain-first sheet', (tester) async {
      await openSchedule(tester, host(plan: <TrainingPlanEntry>[monWedFri]));

      await tapSwitch(tester);

      expect(find.text('Remind you on training days?'), findsOneWidget);
      expect(find.textContaining('Mon, Wed, Fri'), findsOneWidget);
      expect(find.textContaining('notification at 6:30 PM'), findsOneWidget);
      expect(find.textContaining('no "you missed a day"'), findsOneWidget);
      expect(reminders.calls, isNot(contains('request')),
          reason: 'the sheet comes before any system prompt');
    });

    testWidgets('Not now leaves it off and requests nothing', (tester) async {
      final handle = tester.ensureSemantics();
      await openSchedule(tester, host(plan: <TrainingPlanEntry>[monWedFri]));
      reminders.calls.clear();

      await tapSwitch(tester);
      await tester.tap(find.byKey(SchedulePane.notNowKey));
      await tester.pumpAndSettle();

      expect(toggled(tester), isFalse);
      expect(reminders.calls, isEmpty);
      expect(reminders.pending, isEmpty);
      expect(await ReminderPrefsStore(database).read(),
          ReminderPreferences.defaults);
      expect(find.text(kNotificationsOffCopy), findsNothing);
      handle.dispose();
    });

    testWidgets('Allow, granted: stored on, one reminder per training weekday',
        (tester) async {
      final handle = tester.ensureSemantics();
      await openSchedule(tester, host(plan: <TrainingPlanEntry>[monWedFri]));

      await tapSwitch(tester);
      await tester.tap(find.byKey(SchedulePane.allowKey));
      await tester.pumpAndSettle();

      expect(toggled(tester), isTrue);
      expect(reminders.calls, contains('request'));
      expect((await ReminderPrefsStore(database).read()).scheduleOn, isTrue);
      expect(reminders.pending.keys.toSet(), <int>{100, 102, 104});
      for (final r in reminders.pending.values) {
        expect(r.id, trainingReminderId(r.weekday));
        expect(r.minute, kDefaultScheduleReminderMinute);
        expect(r.target, ReminderTarget.workout);
        expect(r.title, kTrainingReminderTitle);
        expect(r.body, kTrainingReminderBody);
      }
      expect(await readStoredTrainingPlan(TrainingPlanStore(database)),
          isEmpty,
          reason: 'the reminder switch must not touch the plan series');
      handle.dispose();
    });

    testWidgets('denied: stays off with the Settings line; the week still works',
        (tester) async {
      final handle = tester.ensureSemantics();
      reminders.grantOnRequest = false;
      await openSchedule(tester, host(plan: <TrainingPlanEntry>[monWedFri]));

      await tapSwitch(tester);
      await tester.tap(find.byKey(SchedulePane.allowKey));
      await tester.pumpAndSettle();

      expect(toggled(tester), isFalse);
      expect(find.text(kNotificationsOffCopy), findsOneWidget);
      expect((await ReminderPrefsStore(database).read()).scheduleOn, isFalse);
      expect(reminders.pending, isEmpty);

      await tester.tap(find.byKey(SchedulePane.dayChipKey(3)));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
          tester.element(find.byType(SchedulePane)));
      expect(container.read(thisWeekSummaryProvider)!.planned, 4,
          reason: 'training days drive the week with or without permission');
      expect(reminders.pending, isEmpty);
      handle.dispose();
    });

    testWidgets('already permitted: turns on with no sheet', (tester) async {
      reminders.permitted = true;
      await openSchedule(tester, host(plan: <TrainingPlanEntry>[monWedFri]));

      await tapSwitch(tester);

      expect(find.byType(ExplainSheet), findsNothing);
      expect(reminders.calls, isNot(contains('request')));
      expect(reminders.pending.keys.toSet(), <int>{100, 102, 104});
    });

    testWidgets('turning it off needs no sheet and cancels the reminders',
        (tester) async {
      final handle = tester.ensureSemantics();
      reminders.permitted = true;
      await openSchedule(
          tester, host(plan: <TrainingPlanEntry>[monWedFri], prefs: on));
      expect(reminders.pending.keys.toSet(), <int>{100, 102, 104});

      await tapSwitch(tester);

      expect(find.byType(ExplainSheet), findsNothing);
      expect(toggled(tester), isFalse);
      expect(reminders.pending, isEmpty);
      expect((await ReminderPrefsStore(database).read()).scheduleOn, isFalse);
      handle.dispose();
    });

    testWidgets('changing training days cancels the old ids, schedules new',
        (tester) async {
      reminders.permitted = true;
      await openSchedule(
          tester, host(plan: <TrainingPlanEntry>[monWedFri], prefs: on));

      await tester.tap(find.byKey(SchedulePane.dayChipKey(0))); // Monday off
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SchedulePane.dayChipKey(6))); // Sunday on
      await tester.pumpAndSettle();

      expect(reminders.pending.keys.toSet(), <int>{102, 104, 106});
    });

    testWidgets('changing the time stores it and reschedules', (tester) async {
      reminders.permitted = true;
      await openSchedule(
          tester, host(plan: <TrainingPlanEntry>[monWedFri], prefs: on));

      await tester.ensureVisible(find.byKey(SchedulePane.timeRowKey));
      await tester.tap(find.byKey(SchedulePane.timeRowKey));
      await tester.pumpAndSettle();
      // Type the time rather than drag the dial.
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '7');
      await tester.enterText(fields.at(1), '05');
      await tester.tap(find.text('AM'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect((await ReminderPrefsStore(database).read()).scheduleMinute,
          7 * 60 + 5);
      expect(find.text('7:05 AM'), findsOneWidget);
      expect(reminders.pending.values.map((r) => r.minute).toSet(),
          <int>{7 * 60 + 5});
    });

    testWidgets('the switch and time survive a restart', (tester) async {
      final handle = tester.ensureSemantics();
      reminders.permitted = true;
      await ReminderPrefsStore(database)
          .write(on.copyWith(scheduleMinute: 6 * 60 + 45));
      // A fresh scope seeded from the store, as main.dart boots.
      final stored = await ReminderPrefsStore(database).read();

      await openSchedule(
          tester, host(plan: <TrainingPlanEntry>[monWedFri], prefs: stored));

      expect(toggled(tester), isTrue);
      expect(find.text('6:45 AM'), findsOneWidget);
      expect(reminders.pending.keys.toSet(), <int>{100, 102, 104},
          reason: 'boot reschedules from what was stored');
      handle.dispose();
    });

    testWidgets('permission revoked in Settings: reads off, says why',
        (tester) async {
      final handle = tester.ensureSemantics();
      reminders.permitted = false;
      await openSchedule(
          tester, host(plan: <TrainingPlanEntry>[monWedFri], prefs: on));

      expect(toggled(tester), isFalse);
      expect(find.text(kNotificationsOffCopy), findsOneWidget);

      // Turned back on in Settings, then back to the app.
      reminders.permitted = true;
      for (final state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      expect(toggled(tester), isTrue);
      expect(find.text(kNotificationsOffCopy), findsNothing);
      handle.dispose();
    });

    testWidgets('no reminder row where notifications are unsupported',
        (tester) async {
      await openSchedule(
        tester,
        host(
          plan: <TrainingPlanEntry>[monWedFri],
          scheduler: _UnsupportedScheduler(),
        ),
      );

      expect(find.byKey(SchedulePane.remindSwitchKey), findsNothing);
      expect(find.byKey(SchedulePane.timeRowKey), findsNothing);
      expect(find.text(SchedulePane.remindersLabel), findsNothing);
      expect(find.byKey(SchedulePane.dayChipKey(0)), findsOneWidget);
    });
  });
}
