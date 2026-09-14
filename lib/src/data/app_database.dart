import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// The app's local database. The **only** persistence in the app.
///
/// **Everything here is a preference, never a derived value.** `CLAUDE.md`'s
/// rule is that nothing computable from sessions is stored — streaks, counts,
/// personal bests and titles are all read-time derivations. What lives in this
/// database is the opposite: facts that cannot be derived from anything,
/// because the user simply told us (which split they are browsing; later their
/// units, sex and bodyweight). If you find yourself adding a column that could
/// be recomputed from session rows, that is the rule catching you.
///
/// Schema version 1 with no migration steps. The session tables of build-order
/// step 1 have not landed; when they do, they bring the first real migration
/// with them.
@DriftDatabase(tables: <Type>[Settings])
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database file.
  ///
  /// Reaching `path_provider` through `drift_flutter`, which means this
  /// constructor cannot run under `flutter test` — there is no platform channel
  /// there. That is exactly why [appDatabaseProvider] exists in
  /// `settings_store.dart` and why widget tests override it with
  /// [AppDatabase.forTesting]; constructing this directly in a widget is the
  /// mistake the seam is there to prevent.
  AppDatabase() : super(driftDatabase(name: 'turtle_lift'));

  /// An in-memory database for tests. Nothing is written to disk.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

/// The app's settings, as exactly one row.
///
/// **One row by construction, not by convention.** [id] is the primary key and
/// every write pins it to [kSettingsRowId], so a second row cannot appear
/// through a missed `where` clause — a settings table that quietly grows a
/// second row reads the wrong one forever after, and nothing fails.
@DataClassName('SettingsRow')
class Settings extends Table {
  IntColumn get id => integer()();

  /// The stable key of the split filter the Workout landing last showed —
  /// `single`, `multi` or `ppl`.
  ///
  /// **Nullable on purpose: null means "never chosen".** That is what the
  /// first-launch default keys off, so it must stay distinguishable from a
  /// stored value. Giving this column a default would erase the distinction
  /// and every install would look like a returning user.
  ///
  /// Stores the key, never the display label — a copy change must not strand
  /// what is already on disk.
  TextColumn get workoutTemplateFilter => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// The id of the one settings row.
const int kSettingsRowId = 1;
