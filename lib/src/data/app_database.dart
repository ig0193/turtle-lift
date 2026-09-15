import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'local_date.dart';

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
/// Schema version 3, and the app's **first** migration — so the shape here is
/// the one every later migration will be copied from.
///
/// **Version 2 is the session tables and it has now landed.** Step 2 creates
/// `Sessions`, `SessionExercises` and `SetEntries`; step 3 is the bodyweight
/// log, the user's own templates and the gender field. Numbering around the gap
/// rather than taking 2 kept the chain in the order the two pieces of work
/// actually landed, so a user upgrading from 1 runs the session step and then
/// the personal-details one.
///
/// **The reserved slot only worked because nothing had shipped.** A device that
/// had already installed a version-3 build is past step 2 and never runs it, so
/// it opens with no session tables at all. No build has reached any track, so no
/// user is in that state — but a development install from before this change
/// is, and its app data has to be cleared once. That is the one-time cost of
/// the reserved slot, and it is why no later step may be numbered below the
/// current version.
///
/// Each step therefore guards on its own range and creates only what it owns.
@DriftDatabase(
  tables: <Type>[
    Settings,
    BodyweightEntries,
    CustomTemplates,
    Sessions,
    SessionExercises,
    SetEntries,
  ],
)
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
  int get schemaVersion => 3;

  /// **The first migration in the app's history.** There was no
  /// [MigrationStrategy] before this one, so the shape here is the precedent:
  /// `onUpgrade` walks the version range and each step adds only what it
  /// introduced, never rebuilding a table that already holds a user's data.
  ///
  /// An existing install carries exactly one thing worth keeping — the settings
  /// row with the split filter the user last chose — and this step must not
  /// disturb it. So the two new tables are created and the gender column is
  /// added; nothing is dropped and nothing is rewritten.
  ///
  /// **Each guard is a range, not an exact version.** A user upgrading from 1
  /// runs both branches in order; one already at 2 runs only the second.
  /// Keying on an exact version would silently skip a step for exactly the
  /// users who need it.
  ///
  /// **Every migration is one transaction and is idempotent, or it does not
  /// ship.** Both branches here are pure table creation with no data movement,
  /// so a process killed mid-upgrade rolls back and retries on the next launch.
  /// That guarantee disappears the moment a step reads, transforms and writes
  /// rows in batches, which is the point at which a migration needs its own
  /// recovery story rather than this comment.
  ///
  /// That is also why `test/app_database_migration_test.dart` opens a real
  /// version-1 database with a row in it rather than only checking that a fresh
  /// database comes out right: a migration that is never run against the old
  /// shape is a migration nobody has tested.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          // **Every open, not once in the migration.** SQLite disables foreign
          // keys per connection, so setting this inside `onUpgrade` would arm
          // it for that one call and leave every later connection
          // unenforced — and an unenforced cascade fails silently as orphaned
          // rows rather than as an error.
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(sessions);
            await m.createTable(sessionExercises);
            await m.createTable(setEntries);
          }
          if (from < 3) {
            await m.createTable(bodyweightEntries);
            await m.createTable(customTemplates);
            await m.addColumn(settings, settings.bodyGender);
          }
        },
      );
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

  /// Which body-diagram artwork every diagram in the app renders in — the name
  /// of a `BodyGender` value, or null when the user has never answered.
  ///
  /// **Nullable for the same reason [workoutTemplateFilter] is.** `docs/04`
  /// gives an unset field the male artwork, and `BodyGender.preferNotToSay`
  /// resolves to that same artwork — but "I declined" and "I have not reached
  /// this screen" are different answers, and only a null tells them apart.
  /// A default here would make every fresh install look like a user who chose.
  ///
  /// Stores the enum's name, not its index: reordering the enum must not
  /// repaint a user's diagrams.
  TextColumn get bodyGender => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// The id of the one settings row.
const int kSettingsRowId = 1;

/// The user's bodyweight, as a dated series rather than one number.
///
/// **A series because the calorie estimate is derived on read.** One stored
/// bodyweight plus read-time derivation means changing your weight silently
/// rewrites the calorie figure on every session you ever logged, including one
/// you screenshotted. Resolving the weight *in effect on* a session's date
/// fixes that — but only if the weight that was in effect is still recorded,
/// which is what this table is.
///
/// **This does not break the nothing-derivable-is-stored rule.** A past
/// bodyweight cannot be recomputed from anything; the user told us, and then
/// time passed. That is the definition of a preference, not of an aggregate.
///
/// **Entries are immutable, and the schema is what enforces it.** There is no
/// update or delete path in the store above this table, and [date] is the
/// primary key so recording a second weight on a day replaces that day rather
/// than accumulating two. The only day that can ever be replaced is today,
/// whose sessions are not yet history.
@DataClassName('BodyweightEntryRow')
class BodyweightEntries extends Table {
  /// The local calendar date the weight took effect, as `YYYY-MM-DD`.
  ///
  /// **Text, not drift's `dateTime()`.** `CLAUDE.md` is explicit that a
  /// calendar date is not a timestamp: a weight recorded at 11pm must not land
  /// on the next day because the value round-tripped through UTC. Text in
  /// ISO order also sorts and compares correctly as a string, which is the
  /// whole of what resolution needs.
  TextColumn get date => text()();

  /// Kilograms. `docs/04` picks one unit for V1 and does not offer a toggle.
  RealColumn get weightKg => real()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{date};
}

/// The templates the user made for themselves.
///
/// Predefined templates are immutable and live in `workout_templates.dart`;
/// only a duplicate of one lands here, where it can be renamed and deleted.
@DataClassName('CustomTemplateRow')
class CustomTemplates extends Table {
  /// Stable across renames, exactly like a predefined template's id — this is
  /// what a session will reference once sessions exist.
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// Parent muscle group ids, comma-joined in taxonomy order.
  ///
  /// **A joined string rather than a child table**, because the app never
  /// queries templates *by* group: it loads the whole template and renders it.
  /// A second table would buy a join for a list that is read whole and is at
  /// most twelve short ids long.
  TextColumn get groupIds => text()();

  /// The predefined template this was duplicated from, so the row can say
  /// "Duplicated from Push day" without guessing. Null once that template no
  /// longer ships.
  TextColumn get sourceTemplateId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// One workout: a container for every exercise and set logged in that sitting.
///
/// **Two date fields that must never be collapsed into one.** [performedOn] is
/// the calendar day the workout happened and is the only field that feeds
/// streaks, history order and date labels. [loggedAt] is when the rows were
/// written, used as a tiebreaker between two sessions on the same day and never
/// shown. `CLAUDE.md` calls storing the first as a timestamp a bug, because an
/// 11pm session would land on the wrong day for the user.
@DataClassName('SessionRow')
class Sessions extends Table {
  TextColumn get id => text()();

  /// Optional, at most 40 characters — it is the hero text on a share card.
  /// May be empty in storage and is never displayed empty; the fallback chain
  /// in `docs/00` §6 resolves it on read.
  TextColumn get title => text().nullable()();

  /// The local calendar day the workout happened, as `YYYY-MM-DD`.
  TextColumn get performedOn => text().map(const LocalDateConverter())();

  /// Internal only. Never rendered, and never re-stamped by an edit — two
  /// sessions on the same day would otherwise reorder under the user.
  DateTimeColumn get loggedAt => dateTime()();

  /// Null for an ad-hoc session. **No foreign key**: eleven of the twelve
  /// template ids are `const` Dart in `workout_templates.dart` rather than
  /// rows, so a reference here cannot be one.
  TextColumn get templateId => text().nullable()();

  /// The template's name as it was when the session started.
  ///
  /// Snapshotted because the title fallback chain's second step is the template
  /// name, and a custom template the user later deletes no longer has one. Not
  /// an aggregate over the user's data, so it cannot go stale the way a stored
  /// count would — it records what was true when the session began.
  TextColumn get templateName => text().nullable()();

  /// The parent muscle group ids this session is allowed to train, comma-joined
  /// in taxonomy order, or null for an ad-hoc session.
  ///
  /// Snapshotted for the same reason as [templateName]: the template lock has
  /// to keep working for an open session whose template has been deleted.
  /// **Read only while the session is open** — a saved session's muscles come
  /// from its sets, or it gains a second source of truth for what it trained.
  TextColumn get groupIds => text().nullable()();

  /// Set on the one open session, null on every saved one.
  ///
  /// **A nullable column with a unique index, so "one at a time" is the
  /// database's rule rather than a promise the app has to keep forever.** SQLite
  /// treats nulls as distinct in a unique index, so any number of saved sessions
  /// coexist while a second open row is rejected outright. Without it, a partial
  /// write during auto-save leaves two open sessions, the loader picks one, and
  /// the other becomes permanently invisible and permanently unfinishable with
  /// its sets still on disk — and a local-only app has no repair path.
  IntColumn get openMarker => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
        'UNIQUE (open_marker)',
        'CHECK (open_marker IS NULL OR open_marker = $kOpenSessionMarker)',
      ];
}

/// The one value [Sessions.openMarker] may hold.
const int kOpenSessionMarker = 1;

/// One exercise within a session, in the order it was added.
@DataClassName('SessionExerciseRow')
class SessionExercises extends Table {
  TextColumn get id => text()();

  TextColumn get sessionId =>
      text().references(Sessions, #id, onDelete: KeyAction.cascade)();

  /// The library exercise this row logs.
  TextColumn get exerciseId => text()();

  IntColumn get position => integer()();

  /// The exercise's load type, by name, as it was when this row was added.
  ///
  /// **Snapshotted, and this is the column that stops a record shipping
  /// backwards.** Load types live in `assets/exercises/exercises.json`, which
  /// ships in the binary and is regenerated by a generator. A set row is
  /// otherwise a bag of nullable numbers whose meaning is resolved at read time
  /// against content a later build can change: reclassify one of the three
  /// assisted exercises and every historical set of it is reinterpreted, so a
  /// record that is a *minimum* is read as a maximum. Nothing fails; the number
  /// is just wrong.
  ///
  /// Stored by name, not index, so appending a variant cannot remap old rows.
  TextColumn get loadType => text()();

  /// Whether the user tapped "Mark exercise done".
  ///
  /// **The only per-exercise state stored.** The `not started / in progress /
  /// done` value the UI shows is derived: deleting every set from an
  /// in-progress exercise would otherwise leave a stored state that is simply
  /// wrong, which is exactly what `docs/01` §Derived values exists to prevent.
  BoolColumn get markedDone => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
        'UNIQUE (session_id, exercise_id)',
      ];
}

/// One set. Which columns carry a value follows the exercise's load type.
///
/// **Every number is unsigned and assistance has its own column.** The sign is
/// carried by the type, never typed by the user, and `assistKg` is never a
/// negative `addedKg` — a signed column would invite booking a `+30kg` record
/// on an assist machine.
///
/// The non-negative checks are here rather than only on the keypad because a
/// stepper underflow or a converter bug would otherwise write a negative
/// assistance value, which inverts the inverted metric back and presents as a
/// plausible record rather than as an error.
///
/// **There is no check that the required column for the load type is present.**
/// It could not be written — the load type lives on [SessionExercises], and a
/// check on this row cannot see another table — and it should not be: a row is
/// written as soon as one field is touched, so a user who steps the weight
/// before typing reps would have that write rejected and watch the number
/// vanish. The completion rule and dropping incomplete rows at save are what
/// enforce it.
@DataClassName('SetEntryRow')
class SetEntries extends Table {
  TextColumn get id => text()();

  TextColumn get sessionExerciseId =>
      text().references(SessionExercises, #id, onDelete: KeyAction.cascade)();

  IntColumn get position => integer()();

  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  RealColumn get weightKg => real().nullable()();

  IntColumn get reps => integer().nullable()();

  RealColumn get addedKg => real().nullable()();

  RealColumn get assistKg => real().nullable()();

  IntColumn get durationSec => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  /// Declared here rather than per column: drift's `check()` on a column that
  /// names itself is a recursive getter, which the analyzer rejects.
  @override
  List<String> get customConstraints => <String>[
        'CHECK (weight_kg IS NULL OR weight_kg >= 0)',
        'CHECK (reps IS NULL OR reps >= 0)',
        'CHECK (added_kg IS NULL OR added_kg >= 0)',
        'CHECK (assist_kg IS NULL OR assist_kg >= 0)',
        'CHECK (duration_sec IS NULL OR duration_sec >= 0)',
      ];
}
