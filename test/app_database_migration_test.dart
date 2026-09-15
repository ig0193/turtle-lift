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

    test('reaches schema version 3', () async {
      await createVersion1Database();
      final database = openUpgraded();
      await database.select(database.settings).get();

      expect(database.schemaVersion, 3);
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

    test('adds a usable custom-templates table', () async {
      await createVersion1Database();
      final database = openUpgraded();

      await database.into(database.customTemplates).insert(
            CustomTemplatesCompanion.insert(
              id: 'push-mine',
              name: 'Push day (mine)',
              groupIds: 'chest,shoulders,triceps',
              sourceTemplateId: const Value<String?>('push'),
            ),
          );

      final rows = await database.select(database.customTemplates).get();
      expect(rows.single.name, 'Push day (mine)');
      expect(rows.single.groupIds, 'chest,shoulders,triceps');
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
              groupIds: 'chest',
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
