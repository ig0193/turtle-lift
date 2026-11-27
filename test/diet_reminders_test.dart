import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/main.dart' show RefreshTodayOnResume;
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/diet_reminders.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/reminder_prefs.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart';
import 'package:turtle_lift/src/data/settings_store.dart';

import 'support/fake_reminder_scheduler.dart';

/// Diet's reminders (R20, ADR 0015, KTD15): one weekly "log your meal" nudge
/// per switched-on slot, built from the switches alone, and kept in step with
/// the OS by a derived provider that also cancels the retired ranges.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const allOn = ReminderPreferences(
    dietOn: true,
    breakfast: SlotReminder(on: true, minute: 8 * 60),
    lunch: SlotReminder(on: true, minute: 13 * 60),
    snack: SlotReminder(on: true, minute: 17 * 60),
    dinner: SlotReminder(on: true, minute: 20 * 60 + 30),
  );

  group('dietRemindersFor', () {
    test('every enabled slot gets a reminder on all seven weekdays', () {
      final reminders = dietRemindersFor(allOn);

      expect(reminders, hasLength(28));
      expect(
        reminders.map((r) => r.id).toSet(),
        <int>{
          for (var wd = 0; wd < 7; wd++)
            for (final slot in MealSlot.values) dietMealReminderId(wd, slot),
        },
      );
      for (final r in reminders) {
        expect(kDietMealReminderIds.contains(r.id), isTrue);
        expect(r.target, ReminderTarget.dietToday);
      }
    });

    test('a slot that is off has no reminder, the others keep theirs', () {
      final reminders = dietRemindersFor(allOn.withSlot(
          MealSlot.snack, const SlotReminder(on: false, minute: 17 * 60)));

      expect(reminders, hasLength(21));
      expect(reminders.where((r) => r.id % 10 == MealSlot.snack.index),
          isEmpty);
      expect(
          reminders.map((r) => r.id),
          contains(dietMealReminderId(3, MealSlot.lunch)));
    });

    test('each reminder carries its own slot time on its own weekday', () {
      final byId = {for (final r in dietRemindersFor(allOn)) r.id: r};

      final lunchThursday = byId[dietMealReminderId(3, MealSlot.lunch)]!;
      expect(lunchThursday.weekday, 3);
      expect(lunchThursday.minute, 13 * 60);
      final dinnerSunday = byId[dietMealReminderId(6, MealSlot.dinner)]!;
      expect(dinnerSunday.weekday, 6);
      expect(dinnerSunday.minute, 20 * 60 + 30);
    });

    test('a changed time is the time the reminder carries', () {
      final reminders = dietRemindersFor(allOn.withSlot(
          MealSlot.lunch, const SlotReminder(on: true, minute: 12 * 60 + 15)));
      final lunch = reminders
          .where((r) => r.id == dietMealReminderId(0, MealSlot.lunch))
          .single;
      expect(lunch.minute, 12 * 60 + 15);
    });

    test('the master switch off means nothing, whatever each slot says', () {
      expect(dietRemindersFor(allOn.copyWith(dietOn: false)), isEmpty);
      expect(dietRemindersFor(ReminderPreferences.defaults), isEmpty);
    });

    test('there is no morning summary: no id in 200-206 is ever built', () {
      final ids = dietRemindersFor(allOn).map((r) => r.id);
      for (final retired in kRetiredReminderIds) {
        expect(ids.where(retired.contains), isEmpty);
      }
    });

    test('the copy is fixed: "Log your lunch" and one neutral body', () {
      final reminders = dietRemindersFor(allOn);
      final lunch = reminders
          .where((r) => r.id == dietMealReminderId(2, MealSlot.lunch))
          .single;

      expect(lunch.title, 'Log your lunch');
      expect(lunch.body, kDietMealBody);
      expect(dietMealTitle(MealSlot.breakfast), 'Log your breakfast');
      expect(dietMealTitle(MealSlot.snack), 'Log your snack');
      expect(dietMealTitle(MealSlot.dinner), 'Log your dinner');
      for (final r in reminders) {
        expect(r.body, kDietMealBody);
      }
    });

    test('copy never carries a dash, nor a word about what was eaten or '
        'missed', () {
      for (final r in dietRemindersFor(allOn)) {
        for (final copy in <String>[r.title, r.body]) {
          expect(copy, isNot(contains('—')));
          expect(copy, isNot(contains('–')));
          expect(copy.toLowerCase(), isNot(contains('miss')));
          expect(copy.toLowerCase(), isNot(contains('forgot')));
        }
      }
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

    ProviderContainer container({ReminderPreferences prefs = allOn}) {
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(database),
        reminderSchedulerProvider.overrideWithValue(fake),
        initialReminderPrefsProvider.overrideWithValue(prefs),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('boot schedules every enabled slot on every weekday', () async {
      final c = container();
      c.listen(dietReminderSyncProvider, (_, _) {});
      await settle();

      expect(fake.pending, hasLength(28));
      expect(fake.pending.keys.every(kDietMealReminderIds.contains), isTrue);
      expect(fake.pending[dietMealReminderId(3, MealSlot.lunch)]!.title,
          'Log your lunch');
    });

    test('a preference change reschedules at the new time', () async {
      final c = container();
      c.listen(dietReminderSyncProvider, (_, _) {});
      await settle();

      await c.read(reminderPrefsProvider.notifier).save(allOn.withSlot(
          MealSlot.lunch, const SlotReminder(on: true, minute: 12 * 60)));
      await settle();

      expect(fake.pending[dietMealReminderId(3, MealSlot.lunch)]!.minute,
          12 * 60);
      expect(fake.pending, hasLength(28));
    });

    test('turning a slot off removes just that slot', () async {
      final c = container();
      c.listen(dietReminderSyncProvider, (_, _) {});
      await settle();

      await c.read(reminderPrefsProvider.notifier).save(allOn.withSlot(
          MealSlot.dinner, const SlotReminder(on: false, minute: 20 * 60)));
      await settle();

      expect(fake.pending, hasLength(21));
      expect(
          fake.pending.keys
              .where((id) => id % 10 == MealSlot.dinner.index),
          isEmpty);
    });

    test('master off cancels the meal range and leaves nothing pending',
        () async {
      final c = container();
      c.listen(dietReminderSyncProvider, (_, _) {});
      await settle();
      expect(fake.pending, isNotEmpty);

      await c
          .read(reminderPrefsProvider.notifier)
          .save(allOn.copyWith(dietOn: false));
      await settle();

      expect(fake.pending, isEmpty);
      expect(fake.calls, isNot(contains('cancelAll')));
    });

    test('every run cancels the retired training and summary ranges, so an '
        'upgrade leaves none behind', () async {
      // What a build with the Schedule and the morning summary left pending.
      for (final id in <int>[100, 103, 106, 200, 204]) {
        fake.pending[id] = (
          id: id,
          weekday: 0,
          minute: 8 * 60,
          title: 'old',
          body: 'old',
          target: ReminderTarget.workout,
        );
      }
      final c = container();
      c.listen(dietReminderSyncProvider, (_, _) {});
      await settle();

      expect(
          fake.pending.keys.where((id) => id < 300), isEmpty,
          reason: 'retired ids are gone');
      expect(fake.pending, hasLength(28), reason: 'meal reminders stay');
    });

    test('the retired ranges are cancelled again on a later change', () async {
      final c = container();
      c.listen(dietReminderSyncProvider, (_, _) {});
      await settle();
      fake.pending[101] = (
        id: 101,
        weekday: 1,
        minute: 0,
        title: 'old',
        body: 'old',
        target: ReminderTarget.workout,
      );

      await c.read(reminderPrefsProvider.notifier).save(allOn.withSlot(
          MealSlot.snack, const SlotReminder(on: true, minute: 16 * 60)));
      await settle();

      expect(fake.pending.containsKey(101), isFalse);
    });

    test('the meal range is the only range rescheduled; cancelAll is never '
        'used', () async {
      final c = container();
      c.listen(dietReminderSyncProvider, (_, _) {});
      await settle();

      expect(fake.calls, isNot(contains('cancelAll')));
      expect(fake.calls.where((call) => call == 'cancelRange'), isNotEmpty);
    });

    test('with the master off nothing is scheduled at all', () async {
      final c = container(prefs: ReminderPreferences.defaults);
      c.listen(dietReminderSyncProvider, (_, _) {});
      await settle();

      expect(fake.pending, isEmpty);
      expect(fake.calls, isNot(contains('schedule')));
    });

    test('with the master off the reminder list is empty without reading '
        'anything else', () {
      final c = ProviderContainer(overrides: [
        initialReminderPrefsProvider
            .overrideWithValue(ReminderPreferences.defaults),
      ]);
      addTearDown(c.dispose);
      expect(c.read(dietRemindersProvider), isEmpty);
    });
  });

  testWidgets('the app root reschedules diet reminders at boot and on resume',
      (tester) async {
    final fake = FakeReminderScheduler(permitted: true);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        reminderSchedulerProvider.overrideWithValue(fake),
        initialReminderPrefsProvider.overrideWithValue(allOn),
      ],
      child: const RefreshTodayOnResume(child: SizedBox()),
    ));
    await tester.pump();
    expect(fake.pending, hasLength(28), reason: 'boot');

    fake.pending.clear();
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

    expect(fake.pending, hasLength(28), reason: 'resume');
  });
}
