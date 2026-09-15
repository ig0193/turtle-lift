import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/session_store.dart';

/// Proves the one writer of workouts.
///
/// The cases that matter most here are not the happy path: they are the ones
/// that can leave a user's logged sets unreachable with no repair path, because
/// this app has no server, no backup and no restore. Concurrency, a failed
/// write, and a kill between the two halves of auto-save are all in this file
/// for that reason.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late SessionStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = SessionStore(database);
  });

  tearDown(() => database.close());

  Future<String> addBench(String sessionId) => store.addExercise(
        sessionId: sessionId,
        exerciseId: 'barbell-bench-press',
        loadType: LoadType.weighted,
      );

  group('starting a workout', () {
    test('from a template, it carries the name, groups and today', () async {
      final session = await store.createSession(
        templateId: 'chest-triceps',
        templateName: 'Chest and triceps day',
        groupIds: <String>['chest', 'triceps'],
      );

      expect(session.templateId, 'chest-triceps');
      expect(session.title, 'Chest and triceps day');
      expect(session.templateName, 'Chest and triceps day');
      expect(session.groupIds, <String>['chest', 'triceps']);
      expect(session.performedOn, LocalDate.today());
      expect(session.isOpen, isTrue);
    });

    test('ad-hoc, it has no title and no template', () async {
      final session = await store.createSession();

      expect(session.title, isNull);
      expect(session.templateId, isNull);
      expect(session.groupIds, isEmpty);
    });

    test('starting another releases the first marker rather than failing',
        () async {
      await store.createSession(templateName: 'Push day');
      final second = await store.createSession(templateName: 'Pull day');

      expect(second.title, 'Pull day');
      expect(await store.sessionCount(), 2);
      final open = await store.readOpenSession();
      expect(open!.id, second.id);
    });
  });

  group('reading back', () {
    test('a fresh store sees the exercises and sets already written', () async {
      final session = await store.createSession(templateName: 'Push day');
      final exerciseRowId = await addBench(session.id);
      await store.writeSet(
        sessionExerciseId: exerciseRowId,
        position: 0,
        weightKg: 60,
        reps: 8,
        completed: true,
      );

      final reopened = await SessionStore(database).readOpenSession();

      expect(reopened!.exercises, hasLength(1));
      expect(reopened.exercises.single.sets.single.weightKg, 60);
      expect(reopened.exercises.single.loadType, LoadType.weighted);
    });

    test('a value typed and never navigated away from is on disk', () async {
      final session = await store.createSession();
      final exerciseRowId = await addBench(session.id);

      // No completion, no navigation — just a touched field, as the durability
      // rule requires: the process is killed in gyms, mid-set.
      await store.writeSet(
        sessionExerciseId: exerciseRowId,
        position: 0,
        weightKg: 60,
      );

      final reopened = await SessionStore(database).readOpenSession();
      expect(reopened!.exercises.single.sets.single.weightKg, 60);
      expect(reopened.exercises.single.sets.single.completed, isFalse);
    });

    test('saved sessions exclude the one still open', () async {
      final first = await store.createSession(templateName: 'Push day');
      await store.saveOpenSession();
      await store.createSession(templateName: 'Pull day');

      final saved = await store.readSavedSessions();

      expect(saved, hasLength(1));
      expect(saved.single.id, first.id);
    });
  });

  group('saving', () {
    test('drops rows the user never completed and keeps the rest', () async {
      final session = await store.createSession();
      final exerciseRowId = await addBench(session.id);
      await store.writeSet(
        sessionExerciseId: exerciseRowId,
        position: 0,
        weightKg: 60,
        reps: 8,
        completed: true,
      );
      await store.writeSet(
        sessionExerciseId: exerciseRowId,
        position: 1,
        weightKg: 60,
      );

      await store.saveOpenSession();

      final saved = await store.readSavedSessions();
      expect(
        saved.single.exercises.single.sets,
        hasLength(1),
        reason: 'a ghost row would render on a card built to be screenshotted',
      );
      expect(saved.single.exercises.single.sets.single.reps, 8);
    });

    test('keeps the original date rather than stamping today', () async {
      final monday = LocalDate.today().addDays(-2);
      final session = await store.createSession(performedOn: monday);
      final exerciseRowId = await addBench(session.id);
      await store.writeSet(
        sessionExerciseId: exerciseRowId,
        position: 0,
        reps: 8,
        completed: true,
      );

      await store.saveOpenSession();

      expect((await store.readSavedSessions()).single.performedOn, monday);
    });

    test('saving twice produces one saved workout and no exception', () async {
      await store.createSession(templateName: 'Push day');

      await store.saveOpenSession();
      await store.saveOpenSession();

      expect(await store.readSavedSessions(), hasLength(1));
      expect(await store.readOpenSession(), isNull);
    });

    test('saving with nothing open is a no-op', () async {
      await store.saveOpenSession();
      expect(await store.sessionCount(), 0);
    });
  });

  group('discarding', () {
    test('leaves no session, exercise or set rows behind', () async {
      final session = await store.createSession();
      final exerciseRowId = await addBench(session.id);
      await store.writeSet(
        sessionExerciseId: exerciseRowId,
        position: 0,
        reps: 8,
        completed: true,
      );

      await store.discardOpenSession();

      expect(await store.sessionCount(), 0);
      expect(await database.select(database.sessionExercises).get(), isEmpty);
      expect(await database.select(database.setEntries).get(), isEmpty);
    });
  });

  group('the session date', () {
    test('refuses tomorrow and accepts an earlier day', () async {
      final session = await store.createSession();

      await store.setPerformedOn(session.id, LocalDate.today().addDays(1));
      expect(
        (await store.readOpenSession())!.performedOn,
        LocalDate.today(),
        reason: 'a future-dated session makes the streak meaningless',
      );

      final lastMonday = LocalDate.today().addDays(-7);
      await store.setPerformedOn(session.id, lastMonday);
      expect((await store.readOpenSession())!.performedOn, lastMonday);
    });

    test('an unrelated edit never re-clamps a stored date', () async {
      final session = await store.createSession();
      final backdated = LocalDate.today().addDays(-3);
      await store.setPerformedOn(session.id, backdated);

      await store.setTitle(session.id, 'Renamed');

      expect(
        (await store.readOpenSession())!.performedOn,
        backdated,
        reason: 'a user who flies west must not have an unrelated edit move '
            'their workout to the previous day',
      );
    });
  });

  group('exercises', () {
    test('adding one already in the session returns the same row', () async {
      final session = await store.createSession();
      final first = await addBench(session.id);
      final second = await addBench(session.id);

      expect(second, first);
      expect((await store.readOpenSession())!.exercises, hasLength(1));
    });

    test('removing one takes its sets with it', () async {
      final session = await store.createSession();
      final exerciseRowId = await addBench(session.id);
      await store.writeSet(
        sessionExerciseId: exerciseRowId,
        position: 0,
        reps: 8,
        completed: true,
      );

      await store.removeExercise(exerciseRowId);

      expect((await store.readOpenSession())!.exercises, isEmpty);
      expect(await database.select(database.setEntries).get(), isEmpty);
    });

    test('mark-done is stored; the tri-state is not', () async {
      final session = await store.createSession();
      final exerciseRowId = await addBench(session.id);

      await store.setMarkedDone(exerciseRowId, true);

      expect((await store.readOpenSession())!.exercises.single.markedDone,
          isTrue);
    });
  });

  group('concurrent writes', () {
    test('ten rapid updates to one set apply in order, last value winning',
        () async {
      final session = await store.createSession();
      final exerciseRowId = await addBench(session.id);
      final setId = await store.writeSet(
        sessionExerciseId: exerciseRowId,
        position: 0,
        weightKg: 60,
      );

      // A held stepper fires a burst like this. Unserialized, the transactions
      // interleave and the value the user is watching can settle on the wrong
      // number.
      await Future.wait<void>(<Future<void>>[
        for (var i = 1; i <= 10; i++)
          store.writeSet(
            sessionExerciseId: exerciseRowId,
            position: 0,
            setId: setId,
            weightKg: 60 + i * 2.5,
          ),
      ]);

      expect(
        (await store.readOpenSession())!.exercises.single.sets.single.weightKg,
        85.0,
      );
    });

    test('a failed write leaves the store readable and the data intact',
        () async {
      final session = await store.createSession();
      final exerciseRowId = await addBench(session.id);
      await store.writeSet(
        sessionExerciseId: exerciseRowId,
        position: 0,
        weightKg: 60,
        reps: 8,
        completed: true,
      );

      // A negative assist is refused by the database, which is the cheapest
      // real failing write available.
      await expectLater(
        store.writeSet(
          sessionExerciseId: exerciseRowId,
          position: 1,
          assistKg: -20,
        ),
        throwsA(isA<Object>()),
      );

      final after = await store.readOpenSession();
      expect(
        after!.exercises.single.sets,
        hasLength(1),
        reason: 'a rejected write must leave disk as it was, so state assigned '
            'from a read-back can never run ahead of it',
      );
      expect(after.exercises.single.sets.single.weightKg, 60);
    });

    test('a write queued after a failure still runs', () async {
      final session = await store.createSession();
      final exerciseRowId = await addBench(session.id);

      await expectLater(
        store.writeSet(
            sessionExerciseId: exerciseRowId, position: 0, reps: -1),
        throwsA(isA<Object>()),
      );
      await store.writeSet(
        sessionExerciseId: exerciseRowId,
        position: 0,
        reps: 8,
        completed: true,
      );

      expect((await store.readOpenSession())!.exercises.single.sets.single.reps,
          8);
    });
  });

  group('the open slot', () {
    test('an unreadable row cannot block every future workout', () async {
      // The shape a degraded boot leaves behind: a session row still marked
      // open that the app could not interpret. Without releasing the marker on
      // create, the unique index would reject every session from here on and
      // the app could never start a workout again.
      await database.into(database.sessions).insert(
            SessionsCompanion.insert(
              id: 'unreadable',
              performedOn: LocalDate.today(),
              loggedAt: DateTime.now(),
              openMarker: const Value<int?>(kOpenSessionMarker),
            ),
          );

      final fresh = await store.createSession(templateName: 'Push day');

      expect(fresh.title, 'Push day');
      expect(
        await store.sessionCount(),
        2,
        reason: 'the unreadable row stays on disk; it just stops being open',
      );
    });

    test('only ever one session is open at a time', () async {
      await store.createSession(templateName: 'Push day');
      await store.createSession(templateName: 'Pull day');
      await store.createSession(templateName: 'Leg day');

      final open = await (database.select(database.sessions)
            ..where((s) => s.openMarker.isNotNull()))
          .get();

      expect(open, hasLength(1));
    });
  });
}
