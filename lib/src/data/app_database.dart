import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'local_date.dart';
import 'workout_templates.dart' show kPredefinedTemplates;

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
/// Schema version 8 (step 8 is the user's own exercises, see
/// `docs/adr/0009-custom-exercises-and-template-editing.md`; step 7 is the reminder preferences, see
/// `docs/adr/0005-schedule-and-opt-in-notifications.md` and ADR 0007; step 6
/// is the Diet plan, meal ticks and protein target,
/// see `docs/adr/0007-diet-in-profile.md`; step 5 gives a custom template its
/// exercise list, see `docs/adr/0006-workout-tab-is-exercise-first.md`; step 4
/// is the training-day plan), and the app's **first** migration — so the shape here is the one every
/// later migration will be copied from.
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
    TrainingPlanEntries,
    CustomTemplates,
    Sessions,
    SessionExercises,
    SetEntries,
    DietPlanVersions,
    DietPlanItems,
    MealTicks,
    ReminderPrefs,
    CustomExercises,
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
  int get schemaVersion => 9;

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
          if (from < 4) {
            // The Schedule's dated training-day plan. Pure table creation, so
            // the one-transaction, idempotent rule above holds.
            await m.createTable(trainingPlanEntries);
          }
          if (from >= 3 && from < 5) {
            // A template is now a list of exercises, not of muscle groups.
            //
            // **Only for an install that already has the table.** A user
            // upgrading from before 3 has just had `custom_templates` created
            // by the step above, from today's definition, which carries this
            // column already — adding it again is a "duplicate column" error,
            // and one that only shows up for people who skipped releases.
            await m.addColumn(customTemplates, customTemplates.exerciseIds);
            // The only custom templates that can exist are duplicates of a
            // predefined one, so each takes that template's exercise list.
            // **Guarded on `exercise_ids = ''`, so a retry after a kill
            // mid-upgrade rewrites nothing it already wrote.** A row with no
            // known source stays empty, which the landing renders as a template
            // with no exercises rather than hiding the user's own row.
            for (final template in kPredefinedTemplates) {
              await customStatement(
                "UPDATE custom_templates SET exercise_ids = ? "
                "WHERE source_template_id = ? AND exercise_ids = ''",
                <Object>[template.exerciseIds.join(','), template.id],
              );
            }
          }
          if (from < 6) {
            // The Diet plan. Pure DDL, so the one-transaction, idempotent rule
            // above holds.
            //
            // **`addColumn` is safe for every `from` here.** Unlike step 5,
            // no earlier step creates `settings`: it exists from version 1,
            // so a user upgrading from any older version is still missing
            // the column at this point, and nobody gets a duplicate.
            await m.createTable(dietPlanVersions);
            await m.createTable(dietPlanItems);
            await m.createTable(mealTicks);
            await _addColumnIfMissing(m, settings, settings.proteinTargetG);
          }
          if (from < 7) {
            // Reminder preferences, one row. Pure table creation, so the
            // one-transaction, idempotent rule above holds.
            await m.createTable(reminderPrefs);
          }
          if (from < 8) {
            // The user's own exercises (`docs/adr/0009-custom-exercises-and-template-editing.md`).
            // Pure table creation, so the one-transaction, idempotent rule
            // above holds; no existing row is read or rewritten.
            await m.createTable(customExercises);
          }
          if (from < 9) {
            // Hide from picker and per-exercise notes
            // (`docs/adr/0011-combined-build-decisions.md`). Both are
            // `addColumn` with a default or nullable, so every existing row
            // reads as "shown" and "no note"; nothing is rewritten.
            //
            // **Added only where the table exists without the column.** A step
            // that has just created a table from today's definition already
            // has it, and a development install that skipped the reserved
            // session step (see `a database already at the current version`
            // in the migration test) has no `session_exercises` at all.
            await _addColumnIfMissing(m, customExercises, customExercises.hidden);
            await _addColumnIfMissing(m, sessionExercises, sessionExercises.note);
          }
        },
      );

  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, Object?> table,
    GeneratedColumn<Object> column,
  ) async {
    final columns = await customSelect(
      'PRAGMA table_info("${table.actualTableName}")',
    ).get();
    if (columns.isEmpty) return;
    if (columns.any((c) => c.read<String>('name') == column.name)) return;
    await m.addColumn(table, column);
  }
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

  /// The user's daily protein target in grams, 1 to 400, or null when they
  /// have never set one (`docs/adr/0007-diet-in-profile.md`).
  ///
  /// **One value, not a dated series** like [BodyweightEntries]: no screen
  /// shows a past week's target, so a series would buy nothing visible.
  /// Nullable for the reason [bodyGender] is.
  ///
  /// **The CHECK is on the column, not in a table-level constraint.** This
  /// column reaches an existing install through `ALTER TABLE ADD COLUMN`,
  /// which carries a column's own constraints and never a table's, so a
  /// table-level CHECK would guard fresh installs only. A custom constraint
  /// rather than drift's `check()`, because `check()` naming its own column is
  /// the recursive getter [SetEntries] explains.
  IntColumn get proteinTargetG => integer().nullable().customConstraint(
        'NULL CHECK (protein_target_g IS NULL '
        'OR protein_target_g BETWEEN 1 AND 400)',
      )();

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

/// The weekdays the user aims to train on, as a dated series.
///
/// **The same shape as [BodyweightEntries], for the same reason.**
/// `docs/adr/0005-schedule-and-opt-in-notifications.md`: an entry is immutable
/// and takes effect from the day it is saved, so a past week keeps being read
/// against the plan that was in force *then*. One stored pattern, re-read
/// against old weeks, would turn every past hit into a miss the moment the user
/// changed a day. Whether a plan day was hit is derived on read from sessions
/// and is never stored here.
///
/// There is no update or delete path in the store above this table.
/// [effectiveFrom] is the primary key, so saving twice on one day replaces that
/// day -- the user fixing a mis-tap, which is the only correction allowed
/// because today is not yet history.
@DataClassName('TrainingPlanEntryRow')
class TrainingPlanEntries extends Table {
  /// The local calendar date the plan took effect, as `YYYY-MM-DD`. Text for
  /// the reason [BodyweightEntries.date] is.
  TextColumn get effectiveFrom => text()();

  /// The training weekdays as a bitmask: bit 0 is Monday ... bit 6 is Sunday.
  /// Zero is a real answer -- "no training days from here" -- and is how a user
  /// clears the plan without rewriting history.
  IntColumn get weekdayMask => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{effectiveFrom};

  @override
  List<String> get customConstraints => <String>[
        'CHECK (weekday_mask BETWEEN 0 AND 127)',
      ];
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

  /// **Legacy: no longer written or read.** Templates were a list of parent
  /// muscle group ids before `docs/adr/0006-workout-tab-is-exercise-first.md`.
  /// The column stays because SQLite cannot drop a `NOT NULL` column without
  /// rebuilding the table, and a rebuild is a worse trade than one empty string
  /// per row. New rows write `''`.
  TextColumn get groupIds => text().withDefault(const Constant(''))();

  /// Library exercise ids, comma-joined in session order.
  ///
  /// **A joined string rather than a child table**, because the app never
  /// queries templates *by* exercise: it loads the whole template and renders
  /// it. A second table would buy a join for a list that is read whole and is a
  /// dozen short ids long at most. Exercise ids are lower-case words and hyphens,
  /// so the separator cannot collide with one.
  ///
  /// **Order is the point**, unlike the group ids this replaces: it is the order
  /// the session lists the exercises in.
  TextColumn get exerciseIds => text().withDefault(const Constant(''))();

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

  /// **Legacy: no longer written or read.** It snapshotted the muscle groups a
  /// template session was locked to, and the lock is gone
  /// (`docs/adr/0006-workout-tab-is-exercise-first.md`). The column stays for the
  /// reason `CustomTemplates.groupIds` does: dropping it means rebuilding a table
  /// that carries the open-session unique index.
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

  /// The user's one free-text note for this exercise in this session ("seat
  /// 4"), schema step 9. `null` when there is none; never an empty string —
  /// the store trims and writes `null` for a blank note.
  ///
  /// Entered data, not derived: the "last time" hint in set logging is read
  /// from the most recent earlier row that has one.
  TextColumn get note => text().nullable()();

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

/// The four meal slots, by the name stored in [DietPlanItems.slot] and
/// [MealTicks.slot]. Inlined into both tables' CHECKs, so a fifth slot is a
/// schema step, not a quiet new string.
const String _mealSlotCheck =
    "CHECK (slot IN ('breakfast', 'lunch', 'snack', 'dinner'))";

/// One whole-week version of the Diet plan, keyed by the Monday it takes
/// effect from (`docs/adr/0007-diet-in-profile.md`).
///
/// **The same dated-series idea as [TrainingPlanEntries].** An edit in week W
/// copies the latest earlier version into a new one at W's Monday before it
/// applies, so a past week keeps reading the plan that was in force then. The
/// store, not this table, keeps the Monday rule and never writes an older
/// version: a CHECK cannot see "this week".
///
/// A version with no items is a real answer, "nothing planned from here", in
/// the way a zero weekday mask is.
@DataClassName('DietPlanVersionRow')
class DietPlanVersions extends Table {
  /// The Monday this version takes effect from, as `YYYY-MM-DD`.
  TextColumn get effectiveFrom => text().map(const LocalDateConverter())();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{effectiveFrom};
}

/// One food in one meal slot of one weekday, within a [DietPlanVersions] week.
///
/// **No protein figure is stored.** Every total is derived on read from
/// [foodId] and [servingsHalves] against the bundled food list, so a corrected
/// food value flows into the plan rather than being frozen into old rows.
@DataClassName('DietPlanItemRow')
class DietPlanItems extends Table {
  TextColumn get id => text()();

  /// The version this item belongs to. Deleting the version takes its items.
  TextColumn get effectiveFrom => text()
      .map(const LocalDateConverter())
      .references(DietPlanVersions, #effectiveFrom,
          onDelete: KeyAction.cascade)();

  /// 0 is Monday ... 6 is Sunday, matching [TrainingPlanEntries]' bit order.
  IntColumn get weekday => integer()();

  /// `breakfast`, `lunch`, `snack` or `dinner`. Stored by name, never index.
  TextColumn get slot => text()();

  /// The bundled food's id. **No foreign key**: the food list is an asset,
  /// not a table, which is the `Sessions.templateId` precedent.
  TextColumn get foodId => text()();

  /// Servings as a count of halves, 1 to 8, so 0.5 to 4 servings with no
  /// floating-point drift.
  IntColumn get servingsHalves => integer()();

  /// Order within the slot, as the user added the foods.
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  /// The UNIQUE makes a repeat add of the same food to the same slot a
  /// replace rather than a second row that double counts every total.
  @override
  List<String> get customConstraints => <String>[
        'UNIQUE (effective_from, weekday, slot, food_id)',
        'CHECK (weekday BETWEEN 0 AND 6)',
        _mealSlotCheck,
        'CHECK (servings_halves BETWEEN 1 AND 8)',
      ];
}

/// A meal the user ticked as eaten on a calendar day.
///
/// **Presence means eaten; an untick is a hard delete.** There is no "false"
/// row. Which dates may be ticked (this week, never the future) is the store's
/// rule, because a CHECK cannot see "today".
@DataClassName('MealTickRow')
class MealTicks extends Table {
  /// The local calendar day, as `YYYY-MM-DD`. Text for the reason
  /// [BodyweightEntries.date] is.
  TextColumn get date => text().map(const LocalDateConverter())();

  /// `breakfast`, `lunch`, `snack` or `dinner`.
  TextColumn get slot => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{date, slot};

  @override
  List<String> get customConstraints => <String>[_mealSlotCheck];
}

/// The user's reminder preferences, as exactly one row
/// (`docs/adr/0005-schedule-and-opt-in-notifications.md`, ADR 0007).
///
/// **One row by construction, as [Settings] is:** [id] is the primary key and
/// every write pins it to [kReminderPrefsRowId]. A separate table rather than
/// more columns on [Settings], so reminder state is one unit to wipe and test,
/// and the settings row whose legacy columns cannot be dropped stops growing.
///
/// **Every switch defaults to off.** Reminders are opt-in (ADR 0005 §3), and a
/// missing row reads as these defaults, so a fresh install and an upgraded one
/// agree without a seed row. Times are minutes after local midnight, the
/// defaults from the plan's A7. What a reminder says is never stored: its text
/// is built from the plan on every reschedule.
@DataClassName('ReminderPrefsRow')
class ReminderPrefs extends Table {
  IntColumn get id => integer()();

  /// The Schedule tab's training-day reminder (ADR 0005).
  BoolColumn get scheduleOn => boolean().withDefault(const Constant(false))();

  IntColumn get scheduleMinute => integer()
      .withDefault(const Constant(kDefaultScheduleReminderMinute))();

  /// The Diet master switch. Off silences every diet reminder below while
  /// keeping each one's own switch and time for when it comes back on.
  BoolColumn get dietOn => boolean().withDefault(const Constant(false))();

  /// The morning summary of the day's plan.
  BoolColumn get summaryOn => boolean().withDefault(const Constant(false))();

  IntColumn get summaryMinute => integer()
      .withDefault(const Constant(7 * 60 + 30))();

  BoolColumn get breakfastOn => boolean().withDefault(const Constant(false))();

  IntColumn get breakfastMinute => integer()
      .withDefault(const Constant(8 * 60))();

  BoolColumn get lunchOn => boolean().withDefault(const Constant(false))();

  IntColumn get lunchMinute => integer()
      .withDefault(const Constant(13 * 60))();

  BoolColumn get snackOn => boolean().withDefault(const Constant(false))();

  IntColumn get snackMinute => integer()
      .withDefault(const Constant(17 * 60))();

  BoolColumn get dinnerOn => boolean().withDefault(const Constant(false))();

  IntColumn get dinnerMinute => integer()
      .withDefault(const Constant(20 * 60 + 30))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  /// Every time is a minute of the day, 0 (00:00) to 1439 (23:59).
  ///
  /// **Table-level, unlike [Settings.proteinTargetG]'s column CHECK.** That
  /// column arrives by `ALTER TABLE`, which drops table constraints; this whole
  /// table arrives by `CREATE TABLE` in step 7, so a table-level CHECK reaches
  /// fresh and upgraded installs alike.
  @override
  List<String> get customConstraints => <String>[
        for (final column in <String>[
          'schedule_minute',
          'summary_minute',
          'breakfast_minute',
          'lunch_minute',
          'snack_minute',
          'dinner_minute',
        ])
          'CHECK ($column BETWEEN 0 AND 1439)',
      ];
}

/// The id of the one reminder-preferences row.
const int kReminderPrefsRowId = 1;

/// The Schedule reminder's default time, 18:30: the time the Schedule pane's
/// Remind me row has shown since it shipped inert.
const int kDefaultScheduleReminderMinute = 18 * 60 + 30;

/// An exercise the user created (`docs/adr/0009-custom-exercises-and-template-editing.md`), schema
/// step 8.
///
/// **The same shape as a library exercise minus the four reviewed content
/// fields**, which a custom exercise does not have and the app never writes.
/// Muscles are sub-muscle-group ids from the taxonomy, comma-joined in the
/// order the user picked them, exactly as a template stores its exercise ids.
///
/// **The id always starts with `custom-`**, enforced here, so it can never
/// collide with a shipped library id (none of which carries that prefix;
/// `test/custom_exercises_test.dart` pins that).
///
/// Nothing derived lives here: how often it was logged, its records and its
/// last set are all read from the session tables like any library exercise.
@DataClassName('CustomExerciseRow')
class CustomExercises extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// One of the library's equipment values (`barbell`, `dumbbell`, ...).
  TextColumn get equipment => text()();

  /// One of `weighted`, `bodyweight`, `assisted`, `timed`, by name.
  TextColumn get loadType => text()();

  /// Primary sub-muscle-group ids, comma-joined. Never empty.
  TextColumn get primaryIds => text()();

  /// Secondary sub-muscle-group ids, comma-joined. May be empty.
  TextColumn get secondaryIds => text().withDefault(const Constant(''))();

  /// Hidden from the exercise picker (schema step 9). A logged custom
  /// exercise cannot be deleted — history must never show "Unknown exercise"
  /// — so hiding is how the user retires one. It stays in History, records,
  /// the Muscles tab's lists of what was trained, and export.
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
        "CHECK (id LIKE 'custom-%')",
        "CHECK (length(trim(name)) > 0)",
        "CHECK (primary_ids <> '')",
        "CHECK (load_type IN ('weighted', 'bodyweight', 'assisted', 'timed'))",
      ];
}
