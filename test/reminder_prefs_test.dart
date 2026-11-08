import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/reminder_prefs.dart';
import 'package:turtle_lift/src/data/settings_store.dart';

/// The reminder preferences row (schema v7, KTD18): what the user switched on
/// and when. Everything is off until the user opts in (ADR 0005 §3).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late ReminderPrefsStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = ReminderPrefsStore(database);
  });

  tearDown(() => database.close());

  group('the defaults (A7)', () {
    test('a fresh database reads every reminder off at its default time',
        () async {
      final prefs = await store.read();

      expect(prefs, ReminderPreferences.defaults);
      expect(prefs.scheduleOn, isFalse);
      expect(prefs.scheduleMinute, 18 * 60 + 30);
      expect(prefs.dietOn, isFalse);
      expect(prefs.summaryOn, isFalse);
      expect(prefs.summaryMinute, 7 * 60 + 30);
      expect(prefs.slot(MealSlot.breakfast),
          const SlotReminder(on: false, minute: 8 * 60));
      expect(prefs.slot(MealSlot.lunch),
          const SlotReminder(on: false, minute: 13 * 60));
      expect(prefs.slot(MealSlot.snack),
          const SlotReminder(on: false, minute: 17 * 60));
      expect(prefs.slot(MealSlot.dinner),
          const SlotReminder(on: false, minute: 20 * 60 + 30));
    });

    test('reading writes nothing: no row until the user changes something',
        () async {
      await store.read();
      expect(await database.select(database.reminderPrefs).get(), isEmpty);
    });

    test('the Dart defaults match the column defaults', () async {
      // Two sources of the same seven numbers: the table's column defaults
      // and [ReminderPreferences.defaults]. A row inserted with nothing but
      // its id must read back as the Dart defaults, or the two have drifted.
      await database.into(database.reminderPrefs).insert(
            ReminderPrefsCompanion.insert(id: const Value(kReminderPrefsRowId)),
          );
      expect(await store.read(), ReminderPreferences.defaults);
    });
  });

  group('writing', () {
    test('round-trips every field and keeps exactly one row', () async {
      final changed = ReminderPreferences.defaults
          .copyWith(
            scheduleOn: true,
            scheduleMinute: 6 * 60,
            dietOn: true,
            summaryOn: true,
            summaryMinute: 0,
          )
          .withSlot(MealSlot.lunch,
              const SlotReminder(on: true, minute: 12 * 60 + 15))
          .withSlot(MealSlot.dinner,
              const SlotReminder(on: true, minute: 1439));

      await store.write(changed);
      await store.write(changed.copyWith(summaryMinute: 7 * 60));

      final read = await store.read();
      expect(read, changed.copyWith(summaryMinute: 7 * 60));
      expect(read.slot(MealSlot.lunch).minute, 12 * 60 + 15);
      expect(read.slot(MealSlot.breakfast),
          ReminderPreferences.defaults.slot(MealSlot.breakfast));
      expect(await database.select(database.reminderPrefs).get(),
          hasLength(1));
    });

    for (final bad in <int>[-1, 1440]) {
      test('a minute of $bad is refused before anything is written',
          () async {
        await expectLater(
          store.write(ReminderPreferences.defaults.copyWith(summaryMinute: bad)),
          throwsArgumentError,
        );
        await expectLater(
          store.write(ReminderPreferences.defaults
              .withSlot(MealSlot.snack, SlotReminder(on: true, minute: bad))),
          throwsArgumentError,
        );
        expect(await database.select(database.reminderPrefs).get(), isEmpty);
      });
    }
  });

  group('reminderPrefsProvider', () {
    ProviderContainer containerWith(ReminderPreferences initial) {
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(database),
        initialReminderPrefsProvider.overrideWithValue(initial),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('starts from the value boot read', () {
      final seeded = ReminderPreferences.defaults.copyWith(dietOn: true);
      final container = containerWith(seeded);
      expect(container.read(reminderPrefsProvider), seeded);
    });

    test('defaults to the A7 defaults without a boot override', () {
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(database),
      ]);
      addTearDown(container.dispose);
      expect(container.read(reminderPrefsProvider),
          ReminderPreferences.defaults);
    });

    test('save writes through and then updates the state', () async {
      final container = containerWith(ReminderPreferences.defaults);
      final next = ReminderPreferences.defaults.copyWith(scheduleOn: true);

      await container.read(reminderPrefsProvider.notifier).save(next);

      expect(container.read(reminderPrefsProvider), next);
      expect(await store.read(), next);
    });

    test('a refused save leaves the state unchanged', () async {
      final container = containerWith(ReminderPreferences.defaults);

      await expectLater(
        container
            .read(reminderPrefsProvider.notifier)
            .save(ReminderPreferences.defaults.copyWith(scheduleMinute: 1440)),
        throwsArgumentError,
      );
      expect(container.read(reminderPrefsProvider),
          ReminderPreferences.defaults);
    });
  });
}
