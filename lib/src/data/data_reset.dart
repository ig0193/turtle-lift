import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'reminder_scheduler.dart';

/// Deletes every row the user has ever written, in one transaction.
///
/// **A hard delete, by design.** V1 has no soft delete (`CLAUDE.md`, "Out of
/// scope"), and "Delete all data" promises exactly this. The schema itself is
/// kept, so the app reopens on an empty database rather than migrating again.
///
/// Children go before parents so the foreign keys (on in every connection, see
/// `AppDatabase`) never see an orphan, even mid-transaction.
///
/// Deleting the one settings row also clears the daily protein target, which
/// is a column on it. `test/data_export_reset_test.dart` checks every table in
/// `allTables`, so a table added later fails that test until it is listed
/// here.
///
/// **Then every scheduled notification is cancelled (R25), after the
/// transaction commits.** A reminder built from a deleted plan must not fire
/// next week; and cancelling only once the rows are gone means a wipe that
/// fails leaves the user's data and its reminders together. The reminder
/// preferences row goes with the rest, so everything is off after the reboot.
Future<void> wipeAllData(
  AppDatabase db, {
  required ReminderScheduler reminders,
}) async {
  await db.transaction(() async {
    await db.delete(db.reminderPrefs).go();
    await db.delete(db.mealTicks).go();
    await db.delete(db.dietPlanItems).go();
    await db.delete(db.dietPlanVersions).go();
    await db.delete(db.setEntries).go();
    await db.delete(db.sessionExercises).go();
    await db.delete(db.sessions).go();
    await db.delete(db.customTemplates).go();
    await db.delete(db.customExercises).go();
    await db.delete(db.trainingPlanEntries).go();
    await db.delete(db.bodyweightEntries).go();
    await db.delete(db.settings).go();
  });
  await reminders.cancelAll();
}

/// Rebuilds the running app from the database, as a cold start would.
///
/// Every piece of user state in this app is a notifier seeded once at boot
/// (see `main.dart`), so after [wipeAllData] the cheapest way to make every
/// screen agree with the empty database is to boot again rather than to reset
/// each notifier by hand -- a hand-written reset is one forgotten provider
/// away from showing deleted data. `main.dart` overrides this with the real
/// reboot; the default throws so a missing override fails loudly.
final appRestartProvider = Provider<Future<void> Function()>(
  (ref) => () => throw StateError('appRestartProvider was not overridden'),
);
