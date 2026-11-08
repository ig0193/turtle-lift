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

    test('reaches schema version 7', () async {
      await createVersion1Database();
      final database = openUpgraded();
      await database.select(database.settings).get();

      expect(database.schemaVersion, 7);
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        7,
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

    test('adds a usable training-plan table', () async {
      await createVersion1Database();
      final database = openUpgraded();

      await database.into(database.trainingPlanEntries).insert(
            TrainingPlanEntriesCompanion.insert(
              effectiveFrom: '2026-10-24',
              weekdayMask: 0x15, // Monday, Wednesday, Friday
            ),
          );

      final entries = await database.select(database.trainingPlanEntries).get();
      expect(entries.single.effectiveFrom, '2026-10-24');
      expect(entries.single.weekdayMask, 0x15);
    });

    test('the plan table rejects a mask outside the seven weekdays', () async {
      await createVersion1Database();
      final database = openUpgraded();

      expect(
        database.into(database.trainingPlanEntries).insert(
              TrainingPlanEntriesCompanion.insert(
                effectiveFrom: '2026-10-24',
                weekdayMask: 128,
              ),
            ),
        throwsA(anything),
      );
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
      expect(
        (await database.select(database.trainingPlanEntries).getSingle())
            .weekdayMask,
        21,
      );
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

    test('adds the three diet tables, empty', () async {
      await createVersion5Database();
      final database = openUpgraded();

      expect(await database.select(database.dietPlanVersions).get(), isEmpty);
      expect(await database.select(database.dietPlanItems).get(), isEmpty);
      expect(await database.select(database.mealTicks).get(), isEmpty);
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

      await database.into(database.dietPlanVersions).insert(
            DietPlanVersionsCompanion.insert(
              effectiveFrom: const LocalDate(2026, 11, 2),
            ),
          );
      expect(await database.select(database.dietPlanVersions).get(),
          hasLength(1));
    });
  });

  group('a fresh install', () {
    test('creates the three diet tables and reminder_prefs', () async {
      final database = openUpgraded();

      final names = (await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'table'",
              )
              .get())
          .map((r) => r.read<String>('name'))
          .toSet();

      expect(
        names,
        containsAll(<String>[
          'settings',
          'bodyweight_entries',
          'training_plan_entries',
          'custom_templates',
          'sessions',
          'session_exercises',
          'set_entries',
          'diet_plan_versions',
          'diet_plan_items',
          'meal_ticks',
          'reminder_prefs',
        ]),
      );
    });
  });

  // Every diet constraint is proven twice: on a fresh install (`createAll`) and
  // on a database that reached 6 through the upgrade step, because the two
  // build their DDL by different routes. The protein target is the sharp case:
  // it arrives by ALTER TABLE, which a table-level CHECK would never reach.
  for (final (label, prepare) in <(String, Future<void> Function())>[
    ('fresh install', () async {}),
    ('upgraded from 5', createVersion5Database),
  ]) {
    group('diet constraints ($label)', () {
      const monday = LocalDate(2026, 11, 2);

      Future<AppDatabase> openWithVersion() async {
        await prepare();
        final database = openUpgraded();
        await database.into(database.dietPlanVersions).insert(
              DietPlanVersionsCompanion.insert(effectiveFrom: monday),
            );
        return database;
      }

      Future<void> insertItem(
        AppDatabase database, {
        String id = 'i1',
        LocalDate effectiveFrom = monday,
        int weekday = 0,
        String slot = 'breakfast',
        String foodId = 'paneer',
        int servingsHalves = 2,
      }) =>
          database.into(database.dietPlanItems).insert(
                DietPlanItemsCompanion.insert(
                  id: id,
                  effectiveFrom: effectiveFrom,
                  weekday: weekday,
                  slot: slot,
                  foodId: foodId,
                  servingsHalves: servingsHalves,
                  position: 0,
                ),
              );

      test('a well-formed item is accepted at both ends of every range',
          () async {
        final database = await openWithVersion();

        await insertItem(database, id: 'a', weekday: 0, servingsHalves: 1);
        await insertItem(
          database,
          id: 'b',
          weekday: 6,
          slot: 'dinner',
          servingsHalves: 8,
        );
        await insertItem(database, id: 'c', slot: 'lunch');
        await insertItem(database, id: 'd', slot: 'snack');

        final rows = await database.select(database.dietPlanItems).get();
        expect(rows, hasLength(4));
        expect(rows.first.effectiveFrom, monday);
      });

      test('servings of 0 and 9 halves are rejected', () async {
        final database = await openWithVersion();

        await expectLater(
          insertItem(database, id: 'a', servingsHalves: 0),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          insertItem(database, id: 'b', servingsHalves: 9),
          throwsA(isA<Exception>()),
          reason: 'servings are 0.5 to 4, stored as 1 to 8 halves',
        );
      });

      test('a slot outside the four meals is rejected', () async {
        final database = await openWithVersion();

        await expectLater(
          insertItem(database, slot: 'brunch'),
          throwsA(isA<Exception>()),
        );
      });

      test('weekday 7 is rejected; 0 is Monday and 6 is Sunday', () async {
        final database = await openWithVersion();

        await expectLater(
          insertItem(database, id: 'a', weekday: 7),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          insertItem(database, id: 'b', weekday: -1),
          throwsA(isA<Exception>()),
        );
      });

      test('the same food twice in one slot of one day is rejected',
          () async {
        final database = await openWithVersion();
        await insertItem(database, id: 'a');

        await expectLater(
          insertItem(database, id: 'b', servingsHalves: 4),
          throwsA(isA<Exception>()),
          reason: 'a repeat add replaces the row; two rows would count the '
              'food twice in every total',
        );
        await insertItem(database, id: 'c', weekday: 1);
        await insertItem(database, id: 'd', slot: 'lunch');
        expect(await database.select(database.dietPlanItems).get(),
            hasLength(3));
      });

      test('an item cannot point at a version that does not exist', () async {
        final database = await openWithVersion();

        await expectLater(
          insertItem(
            database,
            id: 'orphan',
            effectiveFrom: const LocalDate(2026, 11, 9),
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('deleting a version takes its items with it', () async {
        final database = await openWithVersion();
        const nextMonday = LocalDate(2026, 11, 9);
        await database.into(database.dietPlanVersions).insert(
              DietPlanVersionsCompanion.insert(effectiveFrom: nextMonday),
            );
        await insertItem(database, id: 'a');
        await insertItem(database, id: 'b', weekday: 3);
        await insertItem(database, id: 'kept', effectiveFrom: nextMonday);

        await (database.delete(database.dietPlanVersions)
              ..where((t) => t.effectiveFrom.equalsValue(monday)))
            .go();

        final rows = await database.select(database.dietPlanItems).get();
        expect(
          rows.map((r) => r.id),
          <String>['kept'],
          reason: 'the cascade needs the foreign-key pragma armed on every '
              'connection, migrated ones included',
        );
      });

      test('a protein target of 0 or 401 is rejected; null and 1 to 400 are not',
          () async {
        final database = await openWithVersion();

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

      test('a tick date round-trips as the same calendar day', () async {
        final database = await openWithVersion();

        // The 11pm case: a calendar date stored as text cannot slide into the
        // next day the way a timestamp through UTC can.
        await database.into(database.mealTicks).insert(
              MealTicksCompanion.insert(
                date: const LocalDate(2026, 12, 31),
                slot: 'dinner',
              ),
            );

        final tick = await database.select(database.mealTicks).getSingle();
        expect(tick.date, const LocalDate(2026, 12, 31));
        expect(tick.slot, 'dinner');
        expect(
          (await database.customSelect('SELECT date FROM meal_ticks').getSingle())
              .read<String>('date'),
          '2026-12-31',
        );
      });

      test('a meal is ticked at most once a day, and only a real meal',
          () async {
        final database = await openWithVersion();
        Future<void> tick(String slot) =>
            database.into(database.mealTicks).insert(
                  MealTicksCompanion.insert(date: monday, slot: slot),
                );

        await tick('lunch');
        await expectLater(tick('lunch'), throwsA(isA<Exception>()));
        await expectLater(tick('brunch'), throwsA(isA<Exception>()));
        await tick('snack');
        expect(await database.select(database.mealTicks).get(), hasLength(2));
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
    test('keeps every diet row and the protein target', () async {
      await createVersion6Database();
      final database = openUpgraded();

      final settings = await database.select(database.settings).getSingle();
      expect(settings.proteinTargetG, 140);
      expect(settings.bodyGender, 'female');
      expect(
        (await database.select(database.dietPlanVersions).getSingle())
            .effectiveFrom,
        const LocalDate(2026, 11, 2),
      );
      final item = await database.select(database.dietPlanItems).getSingle();
      expect(item.foodId, 'paneer');
      expect(item.servingsHalves, 2);
      expect(
        (await database.select(database.mealTicks).getSingle()).date,
        const LocalDate(2026, 11, 4),
      );
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
