import 'dart:io';

import 'package:drift/drift.dart'
    show
        OpeningDetails,
        QueryExecutor,
        QueryExecutorUser,
        Value,
        driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/workout_templates.dart'
    show kPredefinedTemplates;

/// Proves the app's **first** schema migration, against the shape it will
/// actually meet on a user's phone.
///
/// A fresh version-3 database coming out right proves almost nothing: that is
/// `onCreate`, and `createAll()` was never in doubt. The migration only runs
/// for someone who already has the app installed, so every test here starts by
/// building a real version-1 database — settings table, a stored filter, and
/// `user_version = 1` — writing it to a file, and reopening it through
/// [AppDatabase]. That reopen is what triggers `onUpgrade`.
///
/// The target is version **3**: version 2 is reserved for the session tables,
/// which have not landed, so today's upgrade path is 1 → 3 in one hop.
///
/// An in-memory database cannot do this: each connection gets its own empty
/// database, so the "old install" would vanish before drift ever saw it. Hence
/// the temp file.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('turtle_lift_migration');
    dbFile = File('${tempDir.path}/turtle_lift.sqlite');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// Writes the version-1 schema exactly as it shipped: the settings table and
  /// nothing else. Transcribed rather than generated, because the point is to
  /// reproduce what is already on disk for an existing user — a helper derived
  /// from today's table definitions would drift along with them and stop being
  /// the old shape.
  Future<void> createVersion1Database({String? storedFilter}) async {
    final legacy = NativeDatabase(dbFile);
    await legacy.ensureOpen(_NoopUser());
    await legacy.runCustom(
      'CREATE TABLE settings ('
      'id INTEGER NOT NULL, '
      'workout_template_filter TEXT NULL, '
      'PRIMARY KEY (id))',
      const <Object?>[],
    );
    if (storedFilter != null) {
      await legacy.runCustom(
        'INSERT INTO settings (id, workout_template_filter) VALUES (?, ?)',
        <Object?>[kSettingsRowId, storedFilter],
      );
    }
    await legacy.runCustom('PRAGMA user_version = 1', const <Object?>[]);
    await legacy.close();
  }

  AppDatabase openUpgraded() {
    final database = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(database.close);
    return database;
  }

  Future<Set<String>> tableNames(AppDatabase database) async => (await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get())
      .map((r) => r.read<String>('name'))
      .toSet();

  /// Runs raw statements on an old-shape file, the way a build that wrote it
  /// would have, before [AppDatabase] reopens it.
  ///
  /// **[version] is required because reopening resets it.** [_NoopUser]
  /// reports schema 0, so opening a file through it stamps `user_version = 0`
  /// on the way in; every helper here therefore ends by writing the version
  /// the file is meant to be at, and so does this one.
  Future<void> runLegacy(List<String> statements, {required int version}) async {
    final legacy = NativeDatabase(dbFile);
    await legacy.ensureOpen(_NoopUser());
    for (final statement in statements) {
      await legacy.runCustom(statement, const <Object?>[]);
    }
    await legacy.runCustom('PRAGMA user_version = $version', const <Object?>[]);
    await legacy.close();
  }

  group('upgrading an existing version-1 install', () {
    test('keeps the settings row and the filter the user chose', () async {
      await createVersion1Database(storedFilter: 'ppl');
      final database = openUpgraded();

      final row = await database.select(database.settings).getSingle();

      expect(
        row.workoutTemplateFilter,
        'ppl',
        reason: 'the migration must not disturb what the user already chose',
      );
      expect(row.id, kSettingsRowId);
    });

    test('leaves gender unanswered rather than picking one', () async {
      await createVersion1Database(storedFilter: 'multi');
      final database = openUpgraded();

      final row = await database.select(database.settings).getSingle();

      expect(
        row.bodyGender,
        isNull,
        reason: 'a null gender means "never asked"; defaulting the column '
            'would make every upgraded install look like a user who answered',
      );
    });

    test('reaches schema version 10', () async {
      await createVersion1Database();
      final database = openUpgraded();
      await database.select(database.settings).get();

      expect(database.schemaVersion, 10);
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        10,
      );
    });

    test('adds a usable bodyweight table', () async {
      await createVersion1Database(storedFilter: 'single');
      final database = openUpgraded();

      await database.into(database.bodyweightEntries).insert(
            BodyweightEntriesCompanion.insert(
              date: '2026-09-14',
              weightKg: 78.5,
            ),
          );

      final entries = await database.select(database.bodyweightEntries).get();
      expect(entries.single.date, '2026-09-14');
      expect(entries.single.weightKg, 78.5);
    });

    test('has no training-plan table: the Schedule is gone (ADR 0015)',
        () async {
      await createVersion1Database();
      final database = openUpgraded();
      await database.select(database.settings).get();

      expect(await tableNames(database), isNot(contains('training_plan_entries')),
          reason: 'step 4 no longer creates it, and step 10 drops it wherever '
              'it exists');
    });

    test('adds a usable custom-templates table', () async {
      await createVersion1Database();
      final database = openUpgraded();

      await database.into(database.customTemplates).insert(
            CustomTemplatesCompanion.insert(
              id: 'push-mine',
              name: 'Push day (mine)',
              exerciseIds: const Value<String>('barbell-bench-press,plank'),
              sourceTemplateId: const Value<String?>('push'),
            ),
          );

      final rows = await database.select(database.customTemplates).get();
      expect(rows.single.name, 'Push day (mine)');
      expect(rows.single.exerciseIds, 'barbell-bench-press,plank');
      expect(rows.single.sourceTemplateId, 'push');
    });
  });

  group('the bodyweight table enforces one entry per day', () {
    test('a second weight on the same date replaces the first', () async {
      await createVersion1Database();
      final database = openUpgraded();

      await database.into(database.bodyweightEntries).insertOnConflictUpdate(
            BodyweightEntriesCompanion.insert(date: '2026-09-14', weightKg: 78),
          );
      await database.into(database.bodyweightEntries).insertOnConflictUpdate(
            BodyweightEntriesCompanion.insert(date: '2026-09-14', weightKg: 79),
          );

      final entries = await database.select(database.bodyweightEntries).get();
      expect(
        entries,
        hasLength(1),
        reason: 'date is the primary key, so a day cannot hold two weights',
      );
      expect(entries.single.weightKg, 79);
    });

    test('different dates accumulate rather than replace', () async {
      await createVersion1Database();
      final database = openUpgraded();

      await database.into(database.bodyweightEntries).insert(
            BodyweightEntriesCompanion.insert(date: '2026-09-13', weightKg: 78),
          );
      await database.into(database.bodyweightEntries).insert(
            BodyweightEntriesCompanion.insert(date: '2026-09-14', weightKg: 79),
          );

      expect(await database.select(database.bodyweightEntries).get(),
          hasLength(2));
    });

    test('a date survives the round trip verbatim, with no timezone shift',
        () async {
      await createVersion1Database();
      final database = openUpgraded();

      // The 11pm case CLAUDE.md warns about: a calendar date is not a
      // timestamp, and a text column cannot quietly move it to the next day.
      await database.into(database.bodyweightEntries).insert(
            BodyweightEntriesCompanion.insert(
              date: '2026-12-31',
              weightKg: 80,
            ),
          );

      final entries = await database.select(database.bodyweightEntries).get();
      expect(entries.single.date, '2026-12-31');
    });
  });

  group('the exercise-list step (4 → 5)', () {
    /// A version-4 database as it shipped: a custom template that still stores
    /// muscle groups, and no `exercise_ids` column.
    Future<void> createVersion4Database(
      List<({String id, String name, String groups, String? source})> rows,
    ) async {
      final legacy = NativeDatabase(dbFile);
      await legacy.ensureOpen(_NoopUser());
      // Every install has had `settings` since version 1, and the version-6
      // step adds a column to it, so a fixture without it is no real install.
      await legacy.runCustom(
        'CREATE TABLE settings ('
        'id INTEGER NOT NULL, '
        'workout_template_filter TEXT NULL, '
        'body_gender TEXT NULL, '
        'PRIMARY KEY (id))',
        const <Object?>[],
      );
      await legacy.runCustom(
        'CREATE TABLE custom_templates ('
        'id TEXT NOT NULL, '
        'name TEXT NOT NULL, '
        'group_ids TEXT NOT NULL, '
        'source_template_id TEXT NULL, '
        'PRIMARY KEY (id))',
        const <Object?>[],
      );
      for (final row in rows) {
        await legacy.runCustom(
          'INSERT INTO custom_templates (id, name, group_ids, source_template_id) '
          'VALUES (?, ?, ?, ?)',
          <Object?>[row.id, row.name, row.groups, row.source],
        );
      }
      await legacy.runCustom('PRAGMA user_version = 4', const <Object?>[]);
      await legacy.close();
    }

    test('a duplicate of a predefined template takes its exercise list',
        () async {
      await createVersion4Database(
        <({String id, String name, String groups, String? source})>[
          (
            id: 'a',
            name: 'Push day (mine)',
            groups: 'chest,shoulders,triceps',
            source: 'push',
          ),
          (id: 'b', name: 'Leg day (mine)', groups: 'quads', source: 'leg'),
        ],
      );
      final database = openUpgraded();

      final rows = {
        for (final r in await database.select(database.customTemplates).get())
          r.id: r,
      };

      expect(
        rows['a']!.exerciseIds.split(','),
        kPredefinedTemplates.firstWhere((t) => t.id == 'push').exerciseIds,
      );
      expect(
        rows['b']!.exerciseIds.split(','),
        kPredefinedTemplates.firstWhere((t) => t.id == 'leg').exerciseIds,
      );
      expect(rows['a']!.name, 'Push day (mine)',
          reason: 'the rest of the row is untouched');
      expect(rows['a']!.sourceTemplateId, 'push');
    });

    test('a row with no known source survives, empty', () async {
      await createVersion4Database(
        <({String id, String name, String groups, String? source})>[
          (id: 'a', name: 'Mine', groups: 'chest', source: null),
          (
            id: 'b',
            name: 'From a retired one',
            groups: 'chest',
            source: 'retired',
          ),
        ],
      );
      final database = openUpgraded();

      final rows = await database.select(database.customTemplates).get();

      expect(rows, hasLength(2),
          reason: "the user's own row is never dropped by the upgrade");
      expect(rows.every((r) => r.exerciseIds == ''), isTrue);
    });

    test('the legacy group column is left alone', () async {
      await createVersion4Database(
        <({String id, String name, String groups, String? source})>[
          (
            id: 'a',
            name: 'Mine',
            groups: 'chest,triceps',
            source: 'chest-triceps',
          ),
        ],
      );
      final database = openUpgraded();

      expect(
        (await database.select(database.customTemplates).get()).single.groupIds,
        'chest,triceps',
      );
    });

    test('an upgrade from 1 does not add the column twice', () async {
      // The version-3 step creates the table from today's definition, which
      // already has the column. A step that added it again would throw here,
      // and only for users who had skipped several releases.
      await createVersion1Database();
      final database = openUpgraded();

      await database.into(database.customTemplates).insert(
            CustomTemplatesCompanion.insert(id: 'x', name: 'X'),
          );

      expect(
        (await database.select(database.customTemplates).get())
            .single
            .exerciseIds,
        '',
      );
    });
  });

  group('a fresh install', () {
    test('creates every table without running the upgrade path', () async {
      final database = openUpgraded();

      await database.into(database.bodyweightEntries).insert(
            BodyweightEntriesCompanion.insert(date: '2026-01-01', weightKg: 70),
          );
      await database.into(database.customTemplates).insert(
            CustomTemplatesCompanion.insert(
              id: 'x',
              name: 'X',
              exerciseIds: const Value<String>('plank'),
            ),
          );

      expect(await database.select(database.settings).get(), isEmpty);
      expect(await database.select(database.bodyweightEntries).get(),
          hasLength(1));
      expect(await database.select(database.customTemplates).get(),
          hasLength(1));
    });
  });

  group('the session step', () {
    /// A session row, reduced to the fields these tests care about.
    Future<void> insertSession(
      AppDatabase database, {
      required String id,
      int? openMarker,
      String performedOn = '2026-09-14',
    }) =>
        database.into(database.sessions).insert(
              SessionsCompanion.insert(
                id: id,
                performedOn: LocalDate.parse(performedOn),
                loggedAt: DateTime(2026, 9, 14, 18),
                openMarker: Value<int?>(openMarker),
              ),
            );

    Future<String> insertExercise(
      AppDatabase database, {
      required String sessionId,
      String exerciseId = 'barbell-bench-press',
      String id = 'se-1',
    }) async {
      await database.into(database.sessionExercises).insert(
            SessionExercisesCompanion.insert(
              id: id,
              sessionId: sessionId,
              exerciseId: exerciseId,
              position: 0,
              loadType: 'weighted',
            ),
          );
      return id;
    }

    test('a version-1 install gains the three session tables', () async {
      await createVersion1Database(storedFilter: 'ppl');
      final database = openUpgraded();

      await insertSession(database, id: 's1');
      final exerciseRowId = await insertExercise(database, sessionId: 's1');
      await database.into(database.setEntries).insert(
            SetEntriesCompanion.insert(
              id: 'set-1',
              sessionExerciseId: exerciseRowId,
              position: 0,
              weightKg: const Value<double>(60),
              reps: const Value<int>(8),
            ),
          );

      expect(await database.select(database.sessions).get(), hasLength(1));
      expect(
          await database.select(database.sessionExercises).get(), hasLength(1));
      expect(await database.select(database.setEntries).get(), hasLength(1));
    });

    test('the filter the user chose survives the session step', () async {
      await createVersion1Database(storedFilter: 'single');
      final database = openUpgraded();
      await insertSession(database, id: 's1');

      final row = await database.select(database.settings).getSingle();

      expect(row.workoutTemplateFilter, 'single');
    });

    test('a calendar date round-trips as the day the user experienced',
        () async {
      await createVersion1Database();
      final database = openUpgraded();
      await insertSession(database, id: 's1', performedOn: '2026-09-14');

      final row = await database.select(database.sessions).getSingle();

      expect(row.performedOn, const LocalDate(2026, 9, 14));
    });

    test('deleting a session takes its exercises and sets with it', () async {
      await createVersion1Database();
      final database = openUpgraded();
      await insertSession(database, id: 's1');
      final exerciseRowId = await insertExercise(database, sessionId: 's1');
      await database.into(database.setEntries).insert(
            SetEntriesCompanion.insert(
              id: 'set-1',
              sessionExerciseId: exerciseRowId,
              position: 0,
              reps: const Value<int>(8),
            ),
          );

      await (database.delete(database.sessions)
            ..where((t) => t.id.equals('s1')))
          .go();

      expect(
        await database.select(database.sessionExercises).get(),
        isEmpty,
        reason: 'the cascade must be enforced, which needs the foreign-key '
            'pragma armed on every connection rather than inside the migration',
      );
      expect(await database.select(database.setEntries).get(), isEmpty);
    });

    test('a second open session is refused by the database', () async {
      await createVersion1Database();
      final database = openUpgraded();
      await insertSession(database, id: 's1', openMarker: kOpenSessionMarker);

      expect(
        () => insertSession(database, id: 's2', openMarker: kOpenSessionMarker),
        throwsA(isA<Exception>()),
        reason: 'two open sessions would leave one permanently unreachable '
            'with its sets still on disk, and there is no repair path',
      );
    });

    test('any number of saved sessions coexist', () async {
      await createVersion1Database();
      final database = openUpgraded();

      await insertSession(database, id: 's1');
      await insertSession(database, id: 's2');
      await insertSession(database, id: 's3', openMarker: kOpenSessionMarker);

      expect(await database.select(database.sessions).get(), hasLength(3));
    });

    test('the open marker rejects a value other than the one legal one',
        () async {
      await createVersion1Database();
      final database = openUpgraded();

      expect(
        () => insertSession(database, id: 's1', openMarker: 7),
        throwsA(isA<Exception>()),
      );
    });

    test('the same exercise cannot be added to one session twice', () async {
      await createVersion1Database();
      final database = openUpgraded();
      await insertSession(database, id: 's1');
      await insertExercise(database, sessionId: 's1', id: 'se-1');

      expect(
        () => insertExercise(database, sessionId: 's1', id: 'se-2'),
        throwsA(isA<Exception>()),
        reason: 'a second row would split the exercise\'s sets across two '
            'prefill chains for no gain',
      );
    });

    test('the same exercise in two different sessions is fine', () async {
      await createVersion1Database();
      final database = openUpgraded();
      await insertSession(database, id: 's1');
      await insertSession(database, id: 's2');

      await insertExercise(database, sessionId: 's1', id: 'se-1');
      await insertExercise(database, sessionId: 's2', id: 'se-2');

      expect(
          await database.select(database.sessionExercises).get(), hasLength(2));
    });

    test('a negative assistance value is refused by the database', () async {
      await createVersion1Database();
      final database = openUpgraded();
      await insertSession(database, id: 's1');
      final exerciseRowId = await insertExercise(database, sessionId: 's1');

      expect(
        () => database.into(database.setEntries).insert(
              SetEntriesCompanion.insert(
                id: 'set-1',
                sessionExerciseId: exerciseRowId,
                position: 0,
                assistKg: const Value<double>(-15),
                reps: const Value<int>(8),
              ),
            ),
        throwsA(isA<Exception>()),
        reason: 'a negative assist inverts the inverted record back and would '
            'present as a plausible personal best rather than as an error',
      );
    });

    test('a half-typed row is accepted while the session is open', () async {
      await createVersion1Database();
      final database = openUpgraded();
      await insertSession(database, id: 's1');
      final exerciseRowId = await insertExercise(database, sessionId: 's1');

      await database.into(database.setEntries).insert(
            SetEntriesCompanion.insert(
              id: 'set-1',
              sessionExerciseId: exerciseRowId,
              position: 0,
              weightKg: const Value<double>(60),
            ),
          );

      final row = await database.select(database.setEntries).getSingle();
      expect(
        row.reps,
        isNull,
        reason: 'a field is committed as it is touched, so a weight typed '
            'before its reps must reach disk rather than be rejected',
      );
      expect(row.completed, isFalse);
    });

    test('the stored load type is what a set is read back against', () async {
      await createVersion1Database();
      final database = openUpgraded();
      await insertSession(database, id: 's1');
      await database.into(database.sessionExercises).insert(
            SessionExercisesCompanion.insert(
              id: 'se-1',
              sessionId: 's1',
              exerciseId: 'assisted-pull-up',
              position: 0,
              loadType: 'assisted',
            ),
          );

      final row = await database.select(database.sessionExercises).getSingle();

      expect(
        row.loadType,
        'assisted',
        reason: 'the load type is snapshotted so a regenerated exercise '
            'library cannot change what a stored number means',
      );
      expect(row.markedDone, isFalse);
    });
  });

  group('a database already at the current version', () {
    /// Builds a database stamped at version 3 with the personal-details tables
    /// but no session tables, which is the shape a development install from
    /// before the session step carries.
    Future<void> createVersion3WithoutSessions() async {
      final legacy = NativeDatabase(dbFile);
      await legacy.ensureOpen(_NoopUser());
      await legacy.runCustom(
        'CREATE TABLE settings ('
        'id INTEGER NOT NULL, '
        'workout_template_filter TEXT NULL, '
        'body_gender TEXT NULL, '
        'PRIMARY KEY (id))',
        const <Object?>[],
      );
      await legacy.runCustom(
        'CREATE TABLE bodyweight_entries ('
        'date TEXT NOT NULL, weight_kg REAL NOT NULL, PRIMARY KEY (date))',
        const <Object?>[],
      );
      await legacy.runCustom(
        'CREATE TABLE custom_templates ('
        'id TEXT NOT NULL, name TEXT NOT NULL, group_ids TEXT NOT NULL, '
        'source_template_id TEXT NULL, PRIMARY KEY (id))',
        const <Object?>[],
      );
      await legacy.runCustom(
        'INSERT INTO bodyweight_entries (date, weight_kg) VALUES (?, ?)',
        <Object?>['2026-09-01', 78.5],
      );
      await legacy.runCustom('PRAGMA user_version = 3', const <Object?>[]);
      await legacy.close();
    }

    test('runs no upgrade branch, so it has no session tables', () async {
      await createVersion3WithoutSessions();
      final database = openUpgraded();

      expect(
        await database.select(database.bodyweightEntries).get(),
        hasLength(1),
        reason: 'its existing rows are untouched',
      );
      await expectLater(
        database.select(database.sessions).get(),
        throwsA(isA<Exception>()),
        reason: 'the reserved version-2 slot is below the stored version, so '
            'the session step never runs here. No shipped build is in this '
            'state, but a development install from before the session step is, '
            'and its app data has to be cleared once. This is that limit '
            'pinned as a test rather than discovered on a device.',
      );
    });
  });

  group('a fresh install', () {
    test('is created with every table, session tables included', () async {
      final database = openUpgraded();

      await database.into(database.sessions).insert(
            SessionsCompanion.insert(
              id: 's1',
              performedOn: const LocalDate(2026, 9, 14),
              loggedAt: DateTime(2026, 9, 14, 18),
            ),
          );

      expect(await database.select(database.sessions).get(), hasLength(1));
      expect(await database.select(database.settings).get(), isEmpty);
      expect(await database.select(database.bodyweightEntries).get(), isEmpty);
    });
  });

  /// Writes the version-5 schema exactly as it shipped, with one row in every
  /// table a user is likely to have filled. Transcribed from the DDL a fresh
  /// version-5 build created, for the reason [createVersion1Database] is.
  Future<void> createVersion5Database() async {
    final legacy = NativeDatabase(dbFile);
    await legacy.ensureOpen(_NoopUser());
    for (final statement in <String>[
      'CREATE TABLE "settings" ("id" INTEGER NOT NULL, '
          '"workout_template_filter" TEXT NULL, "body_gender" TEXT NULL, '
          'PRIMARY KEY ("id"))',
      'CREATE TABLE "bodyweight_entries" ("date" TEXT NOT NULL, '
          '"weight_kg" REAL NOT NULL, PRIMARY KEY ("date"))',
      'CREATE TABLE "training_plan_entries" ("effective_from" TEXT NOT NULL, '
          '"weekday_mask" INTEGER NOT NULL, PRIMARY KEY ("effective_from"), '
          'CHECK (weekday_mask BETWEEN 0 AND 127))',
      'CREATE TABLE "custom_templates" ("id" TEXT NOT NULL, '
          '"name" TEXT NOT NULL, "group_ids" TEXT NOT NULL DEFAULT \'\', '
          '"exercise_ids" TEXT NOT NULL DEFAULT \'\', '
          '"source_template_id" TEXT NULL, PRIMARY KEY ("id"))',
      'CREATE TABLE "sessions" ("id" TEXT NOT NULL, "title" TEXT NULL, '
          '"performed_on" TEXT NOT NULL, "logged_at" INTEGER NOT NULL, '
          '"template_id" TEXT NULL, "template_name" TEXT NULL, '
          '"group_ids" TEXT NULL, "open_marker" INTEGER NULL, '
          'PRIMARY KEY ("id"), UNIQUE (open_marker), '
          'CHECK (open_marker IS NULL OR open_marker = 1))',
      'CREATE TABLE "session_exercises" ("id" TEXT NOT NULL, '
          '"session_id" TEXT NOT NULL REFERENCES sessions (id) '
          'ON DELETE CASCADE, "exercise_id" TEXT NOT NULL, '
          '"position" INTEGER NOT NULL, "load_type" TEXT NOT NULL, '
          '"marked_done" INTEGER NOT NULL DEFAULT 0 '
          'CHECK ("marked_done" IN (0, 1)), PRIMARY KEY ("id"), '
          'UNIQUE (session_id, exercise_id))',
      'CREATE TABLE "set_entries" ("id" TEXT NOT NULL, '
          '"session_exercise_id" TEXT NOT NULL REFERENCES '
          'session_exercises (id) ON DELETE CASCADE, '
          '"position" INTEGER NOT NULL, "completed" INTEGER NOT NULL '
          'DEFAULT 0 CHECK ("completed" IN (0, 1)), "weight_kg" REAL NULL, '
          '"reps" INTEGER NULL, "added_kg" REAL NULL, "assist_kg" REAL NULL, '
          '"duration_sec" INTEGER NULL, PRIMARY KEY ("id"))',
      'INSERT INTO settings (id, workout_template_filter, body_gender) '
          "VALUES (1, 'ppl', 'female')",
      'INSERT INTO bodyweight_entries (date, weight_kg) '
          "VALUES ('2026-10-01', 64.5)",
      'INSERT INTO training_plan_entries (effective_from, weekday_mask) '
          "VALUES ('2026-10-26', 21)",
      'INSERT INTO custom_templates (id, name, exercise_ids) '
          "VALUES ('t1', 'Mine', 'plank')",
      'INSERT INTO sessions (id, performed_on, logged_at) '
          "VALUES ('s1', '2026-11-02', 1793635200)",
      'INSERT INTO session_exercises '
          '(id, session_id, exercise_id, position, load_type) '
          "VALUES ('se-1', 's1', 'barbell-bench-press', 0, 'weighted')",
      'INSERT INTO set_entries '
          '(id, session_exercise_id, position, completed, weight_kg, reps) '
          "VALUES ('set-1', 'se-1', 0, 1, 60, 8)",
      'PRAGMA user_version = 5',
    ]) {
      await legacy.runCustom(statement, const <Object?>[]);
    }
    await legacy.close();
  }

  group('the diet step (5 → 6)', () {
    test('keeps every row a version-5 install already holds', () async {
      await createVersion5Database();
      final database = openUpgraded();

      final settings = await database.select(database.settings).getSingle();
      expect(settings.workoutTemplateFilter, 'ppl');
      expect(settings.bodyGender, 'female');
      expect(
        settings.proteinTargetG,
        isNull,
        reason: 'null means "never set"; a default would make every upgraded '
            'install look like a user who chose a target',
      );
      expect(
        (await database.select(database.bodyweightEntries).getSingle())
            .weightKg,
        64.5,
      );
      expect(await tableNames(database), isNot(contains('training_plan_entries')),
          reason: 'the Schedule\'s one row is dropped with its table at step '
              '10; nothing else is');
      expect(
        (await database.select(database.customTemplates).getSingle())
            .exerciseIds,
        'plank',
      );
      expect(
        (await database.select(database.sessions).getSingle()).performedOn,
        const LocalDate(2026, 11, 2),
      );
      expect(
          await database.select(database.sessionExercises).get(), hasLength(1));
      expect((await database.select(database.setEntries).getSingle()).reps, 8);
    });

    test('ends with an empty diet log and none of the old diet tables',
        () async {
      await createVersion5Database();
      final database = openUpgraded();

      expect(await database.select(database.dietLogEntries).get(), isEmpty);
      expect(
        await tableNames(database),
        containsAll(<String>['diet_log_entries']),
      );
      expect(
        await tableNames(database),
        isNot(anyOf(contains('diet_plan_versions'), contains('diet_plan_items'),
            contains('meal_ticks'))),
      );
    });

    test('does not add the protein target column twice', () async {
      await createVersion5Database();
      final legacy = NativeDatabase(dbFile);
      await legacy.ensureOpen(_NoopUser());
      await legacy.runCustom(
        'ALTER TABLE settings ADD COLUMN "protein_target_g" INTEGER NULL '
        'CHECK (protein_target_g IS NULL OR protein_target_g BETWEEN 1 AND 400)',
        const <Object?>[],
      );
      await legacy.runCustom(
        'UPDATE settings SET protein_target_g = 140 WHERE id = 1',
        const <Object?>[],
      );
      await legacy.close();

      final database = openUpgraded();

      expect(
        (await database.select(database.settings).getSingle()).proteinTargetG,
        140,
      );
      expect(await database.select(database.dietLogEntries).get(), isEmpty);
    });

    test('an upgrade from 1 reaches 6 without adding a column twice',
        () async {
      // The protein target is added by ALTER TABLE to a settings table created
      // long before it. A step that added it again for a user who skipped
      // releases would throw "duplicate column" here.
      await createVersion1Database(storedFilter: 'single');
      final database = openUpgraded();

      await database.into(database.settings).insertOnConflictUpdate(
            const SettingsCompanion(
              id: Value<int>(kSettingsRowId),
              proteinTargetG: Value<int?>(140),
            ),
          );
      final row = await database.select(database.settings).getSingle();
      expect(row.workoutTemplateFilter, 'single');
      expect(row.proteinTargetG, 140);

      await database.into(database.dietLogEntries).insert(
            DietLogEntriesCompanion.insert(
              id: 'e1',
              date: const LocalDate(2026, 11, 2),
              slot: 'lunch',
              foodId: 'paneer',
              servingsHalves: 2,
              position: 0,
            ),
          );
      expect(await database.select(database.dietLogEntries).get(),
          hasLength(1));
    });
  });

  group('a fresh install', () {
    test('creates the diet log and reminder_prefs, and none of the retired '
        'tables', () async {
      final database = openUpgraded();

      final names = await tableNames(database);

      expect(
        names,
        containsAll(<String>[
          'settings',
          'bodyweight_entries',
          'custom_templates',
          'sessions',
          'session_exercises',
          'set_entries',
          'diet_log_entries',
          'reminder_prefs',
          'custom_exercises',
        ]),
      );
      for (final retired in <String>[
        'training_plan_entries',
        'diet_plan_versions',
        'diet_plan_items',
        'meal_ticks',
      ]) {
        expect(names, isNot(contains(retired)), reason: retired);
      }
    });
  });

  // Every diet-log constraint is proven twice: on a fresh install (`createAll`)
  // and on a database that reached 10 through the upgrade step, because the
  // two build their DDL by different routes. The protein target is the sharp
  // case: it arrives by ALTER TABLE, which a table-level CHECK would never
  // reach.
  for (final (label, prepare) in <(String, Future<void> Function())>[
    ('fresh install', () async {}),
    ('upgraded from 5', createVersion5Database),
  ]) {
    group('diet log constraints ($label)', () {
      const day = LocalDate(2026, 11, 4);

      Future<AppDatabase> open() async {
        await prepare();
        return openUpgraded();
      }

      Future<void> insertEntry(
        AppDatabase database, {
        String id = 'e1',
        LocalDate date = day,
        String slot = 'breakfast',
        String foodId = 'paneer',
        int servingsHalves = 2,
        int position = 0,
      }) =>
          database.into(database.dietLogEntries).insert(
                DietLogEntriesCompanion.insert(
                  id: id,
                  date: date,
                  slot: slot,
                  foodId: foodId,
                  servingsHalves: servingsHalves,
                  position: position,
                ),
              );

      test('a well-formed entry is accepted at both ends of the serving range '
          'and for all four meals', () async {
        final database = await open();

        await insertEntry(database, id: 'a', servingsHalves: 1);
        await insertEntry(database, id: 'b', slot: 'dinner', servingsHalves: 8);
        await insertEntry(database, id: 'c', slot: 'lunch');
        await insertEntry(database, id: 'd', slot: 'snack');

        final rows = await database.select(database.dietLogEntries).get();
        expect(rows, hasLength(4));
        expect(rows.first.date, day);
      });

      test('servings of 0 and 9 halves are rejected', () async {
        final database = await open();

        await expectLater(
          insertEntry(database, id: 'a', servingsHalves: 0),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          insertEntry(database, id: 'b', servingsHalves: 9),
          throwsA(isA<Exception>()),
          reason: 'servings are 0.5 to 4, stored as 1 to 8 halves',
        );
      });

      test('a slot outside the four meals is rejected', () async {
        final database = await open();

        await expectLater(
          insertEntry(database, slot: 'brunch'),
          throwsA(isA<Exception>()),
        );
      });

      test('the same food twice in one slot of one day is rejected, on '
          'another day or in another slot it is fine', () async {
        final database = await open();
        await insertEntry(database, id: 'a');

        await expectLater(
          insertEntry(database, id: 'b', servingsHalves: 4),
          throwsA(isA<Exception>()),
          reason: 'a repeat add replaces the row; two rows would count the '
              'food twice in every total',
        );
        await insertEntry(database, id: 'c', date: day.addDays(1));
        await insertEntry(database, id: 'd', slot: 'lunch');
        await insertEntry(database, id: 'e', foodId: 'curd');
        expect(await database.select(database.dietLogEntries).get(),
            hasLength(4));
      });

      test('an id is the primary key', () async {
        final database = await open();
        await insertEntry(database, id: 'a');

        await expectLater(
          insertEntry(database, id: 'a', foodId: 'curd'),
          throwsA(isA<Exception>()),
        );
      });

      test('a protein target of 0 or 401 is rejected; null and 1 to 400 are '
          'not', () async {
        final database = await open();

        Future<void> write(int? grams) =>
            database.into(database.settings).insertOnConflictUpdate(
                  SettingsCompanion(
                    id: const Value<int>(kSettingsRowId),
                    proteinTargetG: Value<int?>(grams),
                  ),
                );

        await expectLater(write(0), throwsA(isA<Exception>()));
        await expectLater(write(401), throwsA(isA<Exception>()));
        await write(1);
        await write(400);
        expect(
          (await database.select(database.settings).getSingle())
              .proteinTargetG,
          400,
        );
        await write(null);
        expect(
          (await database.select(database.settings).getSingle())
              .proteinTargetG,
          isNull,
        );
      });

      test('a log date round-trips as the same calendar day', () async {
        final database = await open();

        // The 11pm case: a calendar date stored as text cannot slide into the
        // next day the way a timestamp through UTC can.
        await insertEntry(database, date: const LocalDate(2026, 12, 31));

        final entry = await database.select(database.dietLogEntries).getSingle();
        expect(entry.date, const LocalDate(2026, 12, 31));
        expect(
          (await database
                  .customSelect('SELECT date FROM diet_log_entries')
                  .getSingle())
              .read<String>('date'),
          '2026-12-31',
        );
      });
    });
  }

  /// Writes the version-6 schema: version 5 as it shipped, then the DDL the
  /// diet step ran, transcribed from a fresh version-6 build, with a row in
  /// every diet table and a protein target on the settings row.
  Future<void> createVersion6Database() async {
    await createVersion5Database();
    final legacy = NativeDatabase(dbFile);
    await legacy.ensureOpen(_NoopUser());
    for (final statement in <String>[
      'ALTER TABLE settings ADD COLUMN "protein_target_g" INTEGER NULL '
          'CHECK (protein_target_g IS NULL OR protein_target_g '
          'BETWEEN 1 AND 400)',
      'CREATE TABLE "diet_plan_versions" ("effective_from" TEXT NOT NULL, '
          'PRIMARY KEY ("effective_from"))',
      'CREATE TABLE "diet_plan_items" ("id" TEXT NOT NULL, '
          '"effective_from" TEXT NOT NULL REFERENCES diet_plan_versions '
          '(effective_from) ON DELETE CASCADE, "weekday" INTEGER NOT NULL, '
          '"slot" TEXT NOT NULL, "food_id" TEXT NOT NULL, '
          '"servings_halves" INTEGER NOT NULL, "position" INTEGER NOT NULL, '
          'PRIMARY KEY ("id"), UNIQUE (effective_from, weekday, slot, '
          'food_id), CHECK (weekday BETWEEN 0 AND 6), CHECK (slot IN '
          "('breakfast', 'lunch', 'snack', 'dinner')), "
          'CHECK (servings_halves BETWEEN 1 AND 8))',
      'CREATE TABLE "meal_ticks" ("date" TEXT NOT NULL, '
          '"slot" TEXT NOT NULL, PRIMARY KEY ("date", "slot"), '
          "CHECK (slot IN ('breakfast', 'lunch', 'snack', 'dinner')))",
      'UPDATE settings SET protein_target_g = 140 WHERE id = 1',
      'INSERT INTO diet_plan_versions (effective_from) '
          "VALUES ('2026-11-02')",
      'INSERT INTO diet_plan_items (id, effective_from, weekday, slot, '
          'food_id, servings_halves, position) '
          "VALUES ('i1', '2026-11-02', 2, 'lunch', 'paneer', 2, 0)",
      'INSERT INTO meal_ticks (date, slot) '
          "VALUES ('2026-11-04', 'lunch')",
      'PRAGMA user_version = 6',
    ]) {
      await legacy.runCustom(statement, const <Object?>[]);
    }
    await legacy.close();
  }

  group('the reminder step (6 → 7)', () {
    test('keeps the protein target and what the user ate', () async {
      await createVersion6Database();
      final database = openUpgraded();

      final settings = await database.select(database.settings).getSingle();
      expect(settings.proteinTargetG, 140);
      expect(settings.bodyGender, 'female');
      // The v6 fixture planned paneer for Wednesday lunch and ticked
      // Wednesday 2026-11-04 as eaten: that tick is the one thing of the plan
      // that survives, as the foods that were logged.
      final entry = await database.select(database.dietLogEntries).getSingle();
      expect(entry.date, const LocalDate(2026, 11, 4));
      expect(entry.slot, 'lunch');
      expect(entry.foodId, 'paneer');
      expect(entry.servingsHalves, 2);
      expect((await database.select(database.setEntries).getSingle()).reps, 8);
    });

    test('creates reminder_prefs, empty', () async {
      await createVersion6Database();
      final database = openUpgraded();

      expect(await database.select(database.reminderPrefs).get(), isEmpty,
          reason: 'no row means every reminder is off at its default time; '
              'the store reads defaults for a missing row');
    });

    test('an upgrade from 1 reaches 7 with a usable reminder_prefs', () async {
      await createVersion1Database(storedFilter: 'single');
      final database = openUpgraded();

      await database.into(database.reminderPrefs).insert(
            const ReminderPrefsCompanion(
              id: Value<int>(kReminderPrefsRowId),
              dietOn: Value<bool>(true),
            ),
          );
      expect(
          (await database.select(database.reminderPrefs).getSingle()).dietOn,
          isTrue);
    });
  });

  /// Writes the version-7 schema: version 6, then the reminder step's DDL
  /// transcribed from a fresh version-7 build, with one preference row.
  Future<void> createVersion7Database() async {
    await createVersion6Database();
    final legacy = NativeDatabase(dbFile);
    await legacy.ensureOpen(_NoopUser());
    for (final statement in <String>[
      'CREATE TABLE "reminder_prefs" ("id" INTEGER NOT NULL, "schedule_on" '
          'INTEGER NOT NULL DEFAULT 0 CHECK ("schedule_on" IN (0, 1)), '
          '"schedule_minute" INTEGER NOT NULL DEFAULT 1110, "diet_on" INTEGER '
          'NOT NULL DEFAULT 0 CHECK ("diet_on" IN (0, 1)), "summary_on" '
          'INTEGER NOT NULL DEFAULT 0 CHECK ("summary_on" IN (0, 1)), '
          '"summary_minute" INTEGER NOT NULL DEFAULT 450, "breakfast_on" '
          'INTEGER NOT NULL DEFAULT 0 CHECK ("breakfast_on" IN (0, 1)), '
          '"breakfast_minute" INTEGER NOT NULL DEFAULT 480, "lunch_on" INTEGER '
          'NOT NULL DEFAULT 0 CHECK ("lunch_on" IN (0, 1)), "lunch_minute" '
          'INTEGER NOT NULL DEFAULT 780, "snack_on" INTEGER NOT NULL DEFAULT 0 '
          'CHECK ("snack_on" IN (0, 1)), "snack_minute" INTEGER NOT NULL '
          'DEFAULT 1020, "dinner_on" INTEGER NOT NULL DEFAULT 0 CHECK '
          '("dinner_on" IN (0, 1)), "dinner_minute" INTEGER NOT NULL DEFAULT '
          '1230, PRIMARY KEY ("id"), CHECK (schedule_minute BETWEEN 0 AND '
          '1439), CHECK (summary_minute BETWEEN 0 AND 1439), CHECK '
          '(breakfast_minute BETWEEN 0 AND 1439), CHECK (lunch_minute BETWEEN '
          '0 AND 1439), CHECK (snack_minute BETWEEN 0 AND 1439), CHECK '
          '(dinner_minute BETWEEN 0 AND 1439))',
      'INSERT INTO reminder_prefs (id, diet_on) VALUES (1, 1)',
      'PRAGMA user_version = 7',
    ]) {
      await legacy.runCustom(statement, const <Object?>[]);
    }
    await legacy.close();
  }

  group('the custom-exercise step (7 -> 8)', () {
    test('keeps every earlier row', () async {
      await createVersion7Database();
      final database = openUpgraded();

      expect(
          (await database.select(database.reminderPrefs).getSingle()).dietOn,
          isTrue);
      expect((await database.select(database.setEntries).getSingle()).reps, 8);
      expect((await database.select(database.settings).getSingle())
          .proteinTargetG, 140);
    });

    test('creates custom_exercises, empty and usable', () async {
      await createVersion7Database();
      final database = openUpgraded();

      expect(await database.select(database.customExercises).get(), isEmpty);
      await database.into(database.customExercises).insert(
            CustomExercisesCompanion.insert(
              id: 'custom-1',
              name: 'Hack squat',
              equipment: 'machine',
              loadType: 'weighted',
              primaryIds: 'quads/quads',
            ),
          );
      final row = await database.select(database.customExercises).getSingle();
      expect(row.secondaryIds, '');
    });

    test('an upgrade from 1 reaches 8 with a usable custom_exercises',
        () async {
      await createVersion1Database(storedFilter: 'single');
      final database = openUpgraded();
      await database.into(database.customExercises).insert(
            CustomExercisesCompanion.insert(
              id: 'custom-2',
              name: 'Ring row',
              equipment: 'other',
              loadType: 'bodyweight',
              primaryIds: 'back/upper',
            ),
          );
      expect(await database.select(database.customExercises).get(),
          hasLength(1));
    });

    for (final (label, row) in <(String, CustomExercisesCompanion)>[
      (
        'an id without the custom prefix',
        CustomExercisesCompanion.insert(
          id: 'barbell-bench-press',
          name: 'Clash',
          equipment: 'barbell',
          loadType: 'weighted',
          primaryIds: 'chest/mid',
        ),
      ),
      (
        'a blank name',
        CustomExercisesCompanion.insert(
          id: 'custom-3',
          name: '  ',
          equipment: 'barbell',
          loadType: 'weighted',
          primaryIds: 'chest/mid',
        ),
      ),
      (
        'no primary muscle',
        CustomExercisesCompanion.insert(
          id: 'custom-4',
          name: 'X',
          equipment: 'barbell',
          loadType: 'weighted',
          primaryIds: '',
        ),
      ),
      (
        'an unknown load type',
        CustomExercisesCompanion.insert(
          id: 'custom-5',
          name: 'X',
          equipment: 'barbell',
          loadType: 'negative',
          primaryIds: 'chest/mid',
        ),
      ),
    ]) {
      test('refuses $label', () async {
        await createVersion7Database();
        final database = openUpgraded();
        await expectLater(
          database.into(database.customExercises).insert(row),
          throwsA(isA<Exception>()),
        );
      });
    }
  });

  /// Writes the version-8 schema: version 7, then the custom-exercise step's
  /// DDL transcribed from a fresh version-8 build, with one custom exercise.
  Future<void> createVersion8Database() async {
    await createVersion7Database();
    final legacy = NativeDatabase(dbFile);
    await legacy.ensureOpen(_NoopUser());
    for (final statement in <String>[
      'CREATE TABLE "custom_exercises" ("id" TEXT NOT NULL, "name" TEXT NOT '
          'NULL, "equipment" TEXT NOT NULL, "load_type" TEXT NOT NULL, '
          '"primary_ids" TEXT NOT NULL, "secondary_ids" TEXT NOT NULL '
          "DEFAULT '', PRIMARY KEY (\"id\"), CHECK (id LIKE 'custom-%'), "
          'CHECK (length(trim(name)) > 0), CHECK (primary_ids <> \'\'), '
          "CHECK (load_type IN ('weighted', 'bodyweight', 'assisted', "
          "'timed')))",
      'INSERT INTO custom_exercises (id, name, equipment, load_type, '
          "primary_ids) VALUES ('custom-a', 'Hack squat', 'machine', "
          "'weighted', 'legs/quads')",
      'PRAGMA user_version = 8',
    ]) {
      await legacy.runCustom(statement, const <Object?>[]);
    }
    await legacy.close();
  }

  group('the hide-and-note step (8 -> 9)', () {
    test('keeps the custom exercise and every logged row', () async {
      await createVersion8Database();
      final database = openUpgraded();

      final custom =
          await database.select(database.customExercises).getSingle();
      expect(custom.name, 'Hack squat');
      expect(custom.hidden, isFalse,
          reason: 'an existing exercise stays in the picker');
      final row = await database.select(database.sessionExercises).getSingle();
      expect(row.note, isNull, reason: 'no note was ever written');
      expect((await database.select(database.setEntries).getSingle()).reps, 8);
    });

    test('the new columns are writable', () async {
      await createVersion8Database();
      final database = openUpgraded();

      await database.update(database.customExercises).write(
          const CustomExercisesCompanion(hidden: Value<bool>(true)));
      await database.update(database.sessionExercises).write(
          const SessionExercisesCompanion(note: Value<String?>('Seat 4')));
      expect(
          (await database.select(database.customExercises).getSingle()).hidden,
          isTrue);
      expect(
          (await database.select(database.sessionExercises).getSingle()).note,
          'Seat 4');
    });

    test('an upgrade from 1 reaches 9 with both columns', () async {
      await createVersion1Database(storedFilter: 'single');
      final database = openUpgraded();
      await database.into(database.customExercises).insert(
            CustomExercisesCompanion.insert(
              id: 'custom-z',
              name: 'Ring row',
              equipment: 'other',
              loadType: 'bodyweight',
              primaryIds: 'back/upper',
              hidden: const Value<bool>(true),
            ),
          );
      expect(
          (await database.select(database.customExercises).getSingle()).hidden,
          isTrue);
    });
  });

  /// Writes the version-9 schema: version 8, then the hide-and-note step's
  /// columns, transcribed from a fresh version-9 build. It still holds every
  /// table step 10 drops -- a training plan, the weekly diet plan and meal
  /// ticks -- plus a reminder row, a protein target, sessions and a custom
  /// exercise, which step 10 must not touch.
  Future<void> createVersion9Database() async {
    await createVersion8Database();
    await runLegacy(<String>[
      'ALTER TABLE custom_exercises ADD COLUMN "hidden" INTEGER NOT NULL '
          'DEFAULT 0 CHECK ("hidden" IN (0, 1))',
      'ALTER TABLE session_exercises ADD COLUMN "note" TEXT NULL',
    ], version: 9);
  }

  /// Replaces the fixture's single plan item and tick with a plan worth
  /// converting. Weeks start on Monday; `weekday` 0 is Monday.
  ///
  /// * Plan A, in force from Monday 2026-10-26: Monday breakfast oats;
  ///   Wednesday lunch rajma then curd, Wednesday dinner dal; Sunday dinner
  ///   paneer.
  /// * Plan B, in force from Monday 2026-11-09: Wednesday lunch chicken;
  ///   Friday snack nuts. (It does not repeat A's Wednesday lunch.)
  Future<void> seedConvertiblePlan(List<(String date, String slot)> ticks) =>
      runLegacy(<String>[
        'DELETE FROM meal_ticks',
        'DELETE FROM diet_plan_items',
        'DELETE FROM diet_plan_versions',
        "INSERT INTO diet_plan_versions (effective_from) VALUES ('2026-10-26')",
        "INSERT INTO diet_plan_versions (effective_from) VALUES ('2026-11-09')",
        'INSERT INTO diet_plan_items (id, effective_from, weekday, slot, '
            'food_id, servings_halves, position) VALUES '
            "('a1', '2026-10-26', 0, 'breakfast', 'oats', 2, 0), "
            "('a2', '2026-10-26', 2, 'lunch', 'rajma', 2, 0), "
            "('a3', '2026-10-26', 2, 'lunch', 'curd', 3, 1), "
            "('a4', '2026-10-26', 2, 'dinner', 'dal', 4, 0), "
            "('a5', '2026-10-26', 6, 'dinner', 'paneer', 4, 0), "
            "('b1', '2026-11-09', 2, 'lunch', 'chicken', 6, 0), "
            "('b2', '2026-11-09', 4, 'snack', 'nuts', 1, 0)",
        for (final (date, slot) in ticks)
          "INSERT INTO meal_ticks (date, slot) VALUES ('$date', '$slot')",
      ], version: 9);

  Future<List<(String, String, String, int, int)>> logRows(
    AppDatabase database,
  ) async =>
      <(String, String, String, int, int)>[
        for (final r in await database
            .customSelect('SELECT date, slot, food_id, servings_halves, '
                'position FROM diet_log_entries '
                'ORDER BY date, slot, position')
            .get())
          (
            r.read<String>('date'),
            r.read<String>('slot'),
            r.read<String>('food_id'),
            r.read<int>('servings_halves'),
            r.read<int>('position'),
          ),
      ];

  group('the log step (9 -> 10)', () {
    test('drops the training plan, the weekly diet plan and the ticks, and '
        'creates the log', () async {
      await createVersion9Database();
      final database = openUpgraded();

      final names = await tableNames(database);
      for (final retired in <String>[
        'training_plan_entries',
        'diet_plan_versions',
        'diet_plan_items',
        'meal_ticks',
      ]) {
        expect(names, isNot(contains(retired)), reason: retired);
      }
      expect(names, contains('diet_log_entries'));
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        10,
      );
    });

    test('a tick becomes the foods the plan in force that week had in that '
        'slot on that weekday', () async {
      await createVersion9Database();
      await seedConvertiblePlan(<(String, String)>[
        // A Wednesday in plan A's week: plan A, both lunch foods.
        ('2026-10-28', 'lunch'),
        // A Wednesday in plan B's week: plan B only, never A's rajma and curd.
        ('2026-11-11', 'lunch'),
        // A Wednesday two weeks after plan B started: plan B still governs.
        ('2026-11-18', 'lunch'),
        // Monday itself, the first day of plan A.
        ('2026-10-26', 'breakfast'),
        // Sunday: weekday 6, still the week that began on Monday 2026-10-26.
        ('2026-11-01', 'dinner'),
      ]);
      final database = openUpgraded();

      expect(await logRows(database), <(String, String, String, int, int)>[
        ('2026-10-26', 'breakfast', 'oats', 2, 0),
        ('2026-10-28', 'lunch', 'rajma', 2, 0),
        ('2026-10-28', 'lunch', 'curd', 3, 1),
        ('2026-11-01', 'dinner', 'paneer', 4, 0),
        ('2026-11-11', 'lunch', 'chicken', 6, 0),
        ('2026-11-18', 'lunch', 'chicken', 6, 0),
      ]);
    });

    test('a tick on a slot the plan had nothing in converts to nothing',
        () async {
      await createVersion9Database();
      await seedConvertiblePlan(<(String, String)>[
        ('2026-10-28', 'snack'), // Wednesday, plan A has no snack
        ('2026-11-12', 'breakfast'), // Thursday, plan B has no Thursday
        ('2026-10-28', 'lunch'), // the one that does convert
      ]);
      final database = openUpgraded();

      expect(await logRows(database), <(String, String, String, int, int)>[
        ('2026-10-28', 'lunch', 'rajma', 2, 0),
        ('2026-10-28', 'lunch', 'curd', 3, 1),
      ]);
    });

    test('a tick from before any plan existed converts to nothing',
        () async {
      await createVersion9Database();
      await seedConvertiblePlan(<(String, String)>[
        ('2026-10-19', 'breakfast'), // a Monday, the week before plan A
      ]);
      final database = openUpgraded();

      expect(await logRows(database), isEmpty);
    });

    test('planned meals that were never ticked are not logged', () async {
      await createVersion9Database();
      await seedConvertiblePlan(<(String, String)>[('2026-10-28', 'lunch')]);
      final database = openUpgraded();

      final foods = (await logRows(database)).map((r) => r.$3);
      expect(foods, isNot(contains('dal')),
          reason: 'Wednesday dinner was planned, not eaten: a plan is gone, '
              'only what was eaten is kept');
      expect(foods, isNot(contains('nuts')));
    });

    test('with no ticks the log starts empty', () async {
      await createVersion9Database();
      await seedConvertiblePlan(const <(String, String)>[]);
      final database = openUpgraded();

      expect(await logRows(database), isEmpty);
    });

    test('with no plan items at all a tick converts to nothing and the '
        'upgrade still succeeds', () async {
      await createVersion9Database();
      await runLegacy(<String>[
        'DELETE FROM diet_plan_items',
        'DELETE FROM diet_plan_versions',
        "INSERT INTO meal_ticks (date, slot) VALUES ('2026-11-04', 'dinner')",
      ], version: 9);
      final database = openUpgraded();

      expect(await logRows(database), isEmpty);
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        10,
      );
    });

    test('converted rows get their own distinct ids and obey the log\'s '
        'constraints', () async {
      await createVersion9Database();
      await seedConvertiblePlan(<(String, String)>[
        ('2026-10-28', 'lunch'),
        ('2026-11-11', 'lunch'),
      ]);
      final database = openUpgraded();

      final rows = await database.select(database.dietLogEntries).get();
      expect(rows, hasLength(3));
      expect(rows.map((r) => r.id).toSet(), hasLength(3));
      for (final row in rows) {
        expect(row.id, hasLength(32), reason: 'randomblob(16) as hex');
        expect(<String>['breakfast', 'lunch', 'snack', 'dinner'],
            contains(row.slot));
        expect(row.servingsHalves, inInclusiveRange(1, 8));
      }
      // The log's UNIQUE still applies to a converted day.
      await expectLater(
        database.into(database.dietLogEntries).insert(
              DietLogEntriesCompanion.insert(
                id: 'dup',
                date: const LocalDate(2026, 10, 28),
                slot: 'lunch',
                foodId: 'rajma',
                servingsHalves: 1,
                position: 5,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('nothing else the user has is disturbed', () async {
      await createVersion9Database();
      await seedConvertiblePlan(<(String, String)>[('2026-10-28', 'lunch')]);
      final database = openUpgraded();

      final settings = await database.select(database.settings).getSingle();
      expect(settings.workoutTemplateFilter, 'ppl');
      expect(settings.bodyGender, 'female');
      expect(settings.proteinTargetG, 140,
          reason: 'the target stays; only the plan is dropped');

      final session = await database.select(database.sessions).getSingle();
      expect(session.performedOn, const LocalDate(2026, 11, 2));
      expect(await database.select(database.sessionExercises).get(),
          hasLength(1));
      final set = await database.select(database.setEntries).getSingle();
      expect(set.reps, 8);
      expect(set.weightKg, 60);

      expect(
          (await database.select(database.bodyweightEntries).getSingle())
              .weightKg,
          64.5);
      expect(
          (await database.select(database.customTemplates).getSingle())
              .exerciseIds,
          'plank');
      final custom = await database.select(database.customExercises).getSingle();
      expect(custom.name, 'Hack squat');
      expect(custom.hidden, isFalse);

      final prefs = await database.select(database.reminderPrefs).getSingle();
      expect(prefs.dietOn, isTrue,
          reason: 'the reminder row survives, retired columns included');
    });

    test('reopening an upgraded database changes nothing and adds no rows',
        () async {
      await createVersion9Database();
      await seedConvertiblePlan(<(String, String)>[('2026-10-28', 'lunch')]);
      final first = openUpgraded();
      final before = await logRows(first);
      await first.close();

      final second = openUpgraded();
      expect(await logRows(second), before);
      expect(
        (await second.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        10,
      );
    });

    test('a version-5 install walks all the way to 10', () async {
      await createVersion5Database();
      final database = openUpgraded();

      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        10,
      );
      final names = await tableNames(database);
      expect(
          names,
          containsAll(<String>[
            'diet_log_entries',
            'reminder_prefs',
            'custom_exercises',
          ]));
      expect(names, isNot(contains('training_plan_entries')),
          reason: 'its one row goes with the table');
      expect(await database.select(database.dietLogEntries).get(), isEmpty,
          reason: 'a v5 install never had diet tables to convert');
      expect((await database.select(database.settings).getSingle()).bodyGender,
          'female');
      expect((await database.select(database.setEntries).getSingle()).reps, 8);
    });

    test('a version-1 install reaches the same tables as a fresh install',
        () async {
      await createVersion1Database(storedFilter: 'single');
      final upgraded = openUpgraded();
      final upgradedNames = await tableNames(upgraded);
      await upgraded.close();

      final fresh = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(fresh.close);
      final freshNames = await tableNames(fresh);

      expect(upgradedNames, freshNames);
    });
  });

  for (final (label, prepare) in <(String, Future<void> Function())>[
    ('fresh install', () async {}),
    ('upgraded from 6', createVersion6Database),
  ]) {
    group('reminder_prefs constraints ($label)', () {
      Future<void> write(ReminderPrefsCompanion row) async {
        await prepare();
        final database = openUpgraded();
        await database.into(database.reminderPrefs).insert(row);
      }

      test('a fresh row carries the A7 defaults, everything off', () async {
        await prepare();
        final database = openUpgraded();
        await database.into(database.reminderPrefs).insert(
              const ReminderPrefsCompanion(id: Value<int>(kReminderPrefsRowId)),
            );
        final row = await database.select(database.reminderPrefs).getSingle();
        expect(
          <Object>[
            row.scheduleOn,
            row.dietOn,
            row.summaryOn,
            row.breakfastOn,
            row.lunchOn,
            row.snackOn,
            row.dinnerOn,
          ],
          everyElement(isFalse),
          reason: 'reminders are opt-in (ADR 0005 §3)',
        );
        expect(row.scheduleMinute, 18 * 60 + 30);
        expect(row.summaryMinute, 7 * 60 + 30);
        expect(row.breakfastMinute, 8 * 60);
        expect(row.lunchMinute, 13 * 60);
        expect(row.snackMinute, 17 * 60);
        expect(row.dinnerMinute, 20 * 60 + 30);
      });

      test('0 and 1439 are accepted on every minute', () async {
        await write(const ReminderPrefsCompanion(
          id: Value<int>(kReminderPrefsRowId),
          scheduleMinute: Value<int>(0),
          summaryMinute: Value<int>(1439),
          breakfastMinute: Value<int>(0),
          lunchMinute: Value<int>(1439),
          snackMinute: Value<int>(0),
          dinnerMinute: Value<int>(1439),
        ));
      });

      final minutes = <String, ReminderPrefsCompanion Function(int)>{
        'schedule_minute': (m) => ReminderPrefsCompanion(
            id: const Value<int>(1), scheduleMinute: Value<int>(m)),
        'summary_minute': (m) => ReminderPrefsCompanion(
            id: const Value<int>(1), summaryMinute: Value<int>(m)),
        'breakfast_minute': (m) => ReminderPrefsCompanion(
            id: const Value<int>(1), breakfastMinute: Value<int>(m)),
        'lunch_minute': (m) => ReminderPrefsCompanion(
            id: const Value<int>(1), lunchMinute: Value<int>(m)),
        'snack_minute': (m) => ReminderPrefsCompanion(
            id: const Value<int>(1), snackMinute: Value<int>(m)),
        'dinner_minute': (m) => ReminderPrefsCompanion(
            id: const Value<int>(1), dinnerMinute: Value<int>(m)),
      };
      for (final MapEntry(key: column, value: row) in minutes.entries) {
        test('$column rejects 1440 and -1', () async {
          await prepare();
          final database = openUpgraded();
          await expectLater(
            database.into(database.reminderPrefs).insert(row(1440)),
            throwsA(isA<Exception>()),
            reason: 'a minute of the day is 0 to 1439',
          );
          await expectLater(
            database.into(database.reminderPrefs).insert(row(-1)),
            throwsA(isA<Exception>()),
          );
        });
      }
    });
  }
}

/// `ensureOpen` wants a `QueryExecutorUser`; the raw setup connection has no
/// schema of its own to manage, so this one reports version zero and does
/// nothing when asked to create or migrate.
class _NoopUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
