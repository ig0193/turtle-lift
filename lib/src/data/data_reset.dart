import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Deletes every row the user has ever written, in one transaction.
///
/// **A hard delete, by design.** V1 has no soft delete (`CLAUDE.md`, "Out of
/// scope"), and "Delete all data" promises exactly this. The schema itself is
/// kept, so the app reopens on an empty database rather than migrating again.
///
/// Children go before parents so the foreign keys (on in every connection, see
/// `AppDatabase`) never see an orphan, even mid-transaction.
Future<void> wipeAllData(AppDatabase db) => db.transaction(() async {
      await db.delete(db.setEntries).go();
      await db.delete(db.sessionExercises).go();
      await db.delete(db.sessions).go();
      await db.delete(db.customTemplates).go();
      await db.delete(db.trainingPlanEntries).go();
      await db.delete(db.bodyweightEntries).go();
      await db.delete(db.settings).go();
    });

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
