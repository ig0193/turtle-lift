import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Reads and writes the app's one settings row.
///
/// **A store rather than handing the database to UI code.** Widgets ask for the
/// value they need; they do not learn drift's query API, and swapping the
/// storage underneath them stays a change to this file.
///
/// **It no longer stores the split filter.** That went with the exercise-first
/// Workout tab (`docs/adr/0006-workout-tab-is-exercise-first.md`). Its
/// `workout_template_filter` column is left in the table, unread: SQLite cannot
/// drop a column without rebuilding a table that holds a user's data.
class SettingsStore {
  const SettingsStore(this._db);

  final AppDatabase _db;

  /// How many settings rows exist. Only a test should care — it is the guard
  /// that the one settings row really is one row.
  @visibleForTesting
  Future<int> rowCount() async => (await _db.select(_db.settings).get()).length;
}

/// The app's database handle.
///
/// **This exists to be overridden.** [AppDatabase]'s default constructor opens
/// a file through `path_provider`, which has no platform channel under
/// `flutter test`, so any widget test that reaches persistence would throw. A
/// test overrides this provider with [AppDatabase.forTesting] and an in-memory
/// executor; without the seam there is no way to test the landing at all.
///
/// Closed on dispose so a test that builds several containers does not leak
/// open databases.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// The settings store, named for the thing rather than the word "provider" —
/// matching `exerciseLibraryProvider` and `tabIndexProvider`.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(ref.watch(appDatabaseProvider)),
);
