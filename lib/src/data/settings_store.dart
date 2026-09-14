import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Reads and writes the app's one settings row.
///
/// **A store rather than handing the database to UI code.** Widgets ask for the
/// value they need; they do not learn drift's query API, and swapping the
/// storage underneath them stays a change to this file.
///
/// **It deals in opaque strings.** Recognising a stored key — and deciding what
/// an unrecognised one means — belongs to the filter provider, which owns the
/// key vocabulary. Teaching this class that vocabulary too would put the same
/// list in two files, which is the drift the stable-key rule exists to stop.
class SettingsStore {
  const SettingsStore(this._db);

  final AppDatabase _db;

  /// The stored split-filter key, or null when the user has never chosen one.
  ///
  /// Null is a real answer, not an error: it is how first launch is told apart
  /// from a returning user.
  Future<String?> readWorkoutTemplateFilter() async {
    final row = await (_db.select(_db.settings)
          ..where((s) => s.id.equals(kSettingsRowId)))
        .getSingleOrNull();
    return row?.workoutTemplateFilter;
  }

  /// Stores [key] as the split filter to show on next launch.
  ///
  /// Upserts against the fixed row id, so repeated writes update the one row
  /// rather than accumulating rows.
  Future<void> writeWorkoutTemplateFilter(String key) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            id: const Value<int>(kSettingsRowId),
            workoutTemplateFilter: Value<String>(key),
          ),
        );
  }

  /// How many settings rows exist. Only a test should care — it is the guard
  /// that the upsert above really is an upsert.
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
