import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
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

import 'support/fake_reminder_scheduler.dart';

/// The Schedule tab's training-day reminders (ADR 0005, KTD15): one weekly
/// notification per plan weekday at the one chosen time, rebuilt in full
/// whenever the plan or the preferences change, at boot and on resume.
void main() {
  const on = ReminderPreferences(
    scheduleOn: true,
    scheduleMinute: 7 * 60 + 15,
    dietOn: false,
    summaryOn: false,
    summaryMinute: 7 * 60 + 30,
    breakfast: SlotReminder(on: false, minute: 8 * 60),
    lunch: SlotReminder(on: false, minute: 13 * 60),
    snack: SlotReminder(on: false, minute: 17 * 60),
    dinner: SlotReminder(on: false, minute: 20 * 60 + 30),
  );

  group('trainingRemindersFor', () {
    test('one weekly reminder per training weekday, at the chosen time', () {
      final reminders =
          trainingRemindersFor(weekdays: const <int>{4, 0, 2}, prefs: on);

      expect(reminders.map((r) => r.weekday), <int>[0, 2, 4]);
      expect(reminders.map((r) => r.id), <int>[100, 102, 104]);
      for (final r in reminders) {
        expect(r.id, trainingReminderId(r.weekday));
        expect(r.minute, 7 * 60 + 15);
        expect(r.target, ReminderTarget.workout);
        expect(r.title, kTrainingReminderTitle);
        expect(r.body, kTrainingReminderBody);
      }
    });

    test('nothing while the switch is off', () {
      expect(
        trainingRemindersFor(
          weekdays: const <int>{0, 2, 4},
          prefs: ReminderPreferences.defaults,
        ),
        isEmpty,
      );
    });

    test('nothing when no training day is in force', () {
      expect(trainingRemindersFor(weekdays: const <int>{}, prefs: on), isEmpty);
    });

    test('the text is neutral and dash-free (ADR 0005 §4, §5)', () {
      for (final copy in <String>[kTrainingReminderTitle, kTrainingReminderBody]) {
        expect(copy, isNot(contains('miss')));
        expect(copy, isNot(contains('streak')));
        expect(copy, isNot(contains('—')));
        expect(copy, isNot(contains('–')));
      }
    });
  });

  group('rescheduleRange', () {
    test('cancels the whole range first, then schedules each reminder',
        () async {
      final fake = FakeReminderScheduler()
        ..pending[105] = (
          id: 105,
          weekday: 5,
          minute: 0,
          title: 'old',
          body: 'old',
          target: ReminderTarget.workout,
        )
        ..pending[200] = (
          id: 200,
          weekday: 0,
          minute: 0,
          title: 'diet',
          body: 'diet',
          target: ReminderTarget.dietToday,
        );

      await rescheduleRange(
        fake,
        kTrainingReminderIds,
        trainingRemindersFor(weekdays: const <int>{1}, prefs: on),
      );

      expect(fake.calls, <String>['cancelRange', 'schedule']);
      expect(fake.pending.keys.toSet(), <int>{101, 200},
          reason: 'the old Saturday went, the diet reminder was not touched');
    });

    test('refuses a reminder outside the range it reschedules', () {
      expect(
        () => rescheduleRange(
          FakeReminderScheduler(),
          kTrainingReminderIds,
          const <WeeklyReminder>[
            WeeklyReminder(
              id: 200,
              weekday: 0,
              minute: 0,
              title: 't',
              body: 'b',
              target: ReminderTarget.workout,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('keeping the OS in step', () {
    late AppDatabase database;
    late FakeReminderScheduler fake;
    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      fake = FakeReminderScheduler(permitted: true);
    });
    tearDown(() => database.close());

    final monWedFri = TrainingPlanEntry(
      effectiveFrom: LocalDate(2026, 10, 1),
      weekdays: const <int>{0, 2, 4},
    );

    ProviderContainer container({
      ReminderPreferences prefs = on,
      List<HistorySession> sessions = const <HistorySession>[],
    }) {
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(database),
        reminderSchedulerProvider.overrideWithValue(fake),
        planTodayProvider.overrideWithValue(LocalDate(2026, 10, 21)),
        initialTrainingPlanProvider
            .overrideWithValue(<TrainingPlanEntry>[monWedFri]),
        initialReminderPrefsProvider.overrideWithValue(prefs),
        historySessionsProvider.overrideWithValue(sessions),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('starting the sync schedules from the stored state (boot)', () async {
      final c = container();
      c.listen(trainingReminderSyncProvider, (_, _) {});
      await settle();

      expect(fake.pending.keys.toSet(), <int>{100, 102, 104});
      expect(fake.calls.first, 'cancelRange');
    });

    test('changing training days cancels the old ids and schedules the new',
        () async {
      final c = container();
      c.listen(trainingReminderSyncProvider, (_, _) {});
      await settle();

      await c.read(trainingPlanLogProvider.notifier).save(const <int>{1, 5});
      await settle();

      expect(fake.pending.keys.toSet(), <int>{101, 105});
    });

    test('changing the time reschedules every day at the new time', () async {
      final c = container();
      c.listen(trainingReminderSyncProvider, (_, _) {});
      await settle();

      await c
          .read(reminderPrefsProvider.notifier)
          .save(on.copyWith(scheduleMinute: 6 * 60));
      await settle();

      expect(fake.pending.values.map((r) => r.minute).toSet(), <int>{6 * 60});
      expect(fake.pending.keys.toSet(), <int>{100, 102, 104});
    });

    test('turning the switch off cancels the training range only', () async {
      final c = container();
      c.listen(trainingReminderSyncProvider, (_, _) {});
      await settle();
      fake.pending[300] = (
        id: 300,
        weekday: 0,
        minute: 0,
        title: 'diet',
        body: 'diet',
        target: ReminderTarget.dietToday,
      );

      await c
          .read(reminderPrefsProvider.notifier)
          .save(on.copyWith(scheduleOn: false));
      await settle();

      expect(fake.pending.keys.toSet(), <int>{300});
    });

    test('the reminders never vary with sessions logged (ADR 0005 §4)',
        () async {
      final none = container().read(trainingRemindersProvider);
      final logged = container(sessions: <HistorySession>[
        HistorySession(
          id: 'a',
          performedOn: DateTime(2026, 10, 19),
          exercises: const <HistoryExercise>[],
        ),
        HistorySession(
          id: 'b',
          performedOn: DateTime(2026, 10, 21),
          exercises: const <HistoryExercise>[],
        ),
      ]).read(trainingRemindersProvider);

      expect(logged, none);
      expect(logged, hasLength(3),
          reason: 'a day already trained still keeps its reminder');
    });
  });

  testWidgets('the app root reschedules at boot and again on resume',
      (tester) async {
    final fake = FakeReminderScheduler(permitted: true);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        reminderSchedulerProvider.overrideWithValue(fake),
        planTodayProvider.overrideWithValue(LocalDate(2026, 10, 21)),
        initialTrainingPlanProvider.overrideWithValue(<TrainingPlanEntry>[
          TrainingPlanEntry(
            effectiveFrom: LocalDate(2026, 10, 1),
            weekdays: const <int>{3},
          ),
        ]),
        initialReminderPrefsProvider.overrideWithValue(on),
      ],
      child: const RefreshTodayOnResume(child: SizedBox()),
    ));
    await tester.pump();
    expect(fake.pending.keys.toSet(), <int>{103}, reason: 'boot');

    fake.calls.clear();
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
    await tester.pump();

    expect(fake.calls, <String>['cancelRange', 'schedule'], reason: 'resume');
    expect(fake.pending.keys.toSet(), <int>{103});
  });
}
