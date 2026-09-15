import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart' show appDatabaseProvider;

/// Proves the seam the Workout tab reads to decide whether it shows the landing
/// or the workout in progress.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  ProviderContainer containerWith({WorkoutSession? initial}) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        if (initial != null)
          initialActiveSessionProvider.overrideWithValue(initial),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('the value the first frame gets', () {
    test('is null on a fresh install', () {
      expect(containerWith().read(activeSessionProvider), isNull);
    });

    test('is the seeded session, with no frame spent showing the landing',
        () async {
      final seeded = await SessionStore(database)
          .createSession(templateName: 'Chest and triceps day');

      final container = containerWith(initial: seeded);

      expect(
        container.read(activeSessionProvider)!.title,
        'Chest and triceps day',
        reason: 'a user mid-workout must not see the landing first, even '
            'briefly — that is the wrong screen, not a flicker of the right one',
      );
    });
  });

  group('starting and finishing', () {
    test('a template start carries the name and groups onto the session',
        () async {
      final container = containerWith();

      await container.read(activeSessionProvider.notifier).startFromTemplate(
        templateId: 'chest-triceps',
        templateName: 'Chest and triceps day',
        groupIds: <String>['chest', 'triceps'],
      );

      final session = container.read(activeSessionProvider)!;
      expect(session.templateName, 'Chest and triceps day');
      expect(session.groupIds, <String>['chest', 'triceps']);
      expect(session.isTemplateSession, isTrue);
    });

    test('an ad-hoc start has no title and is not a template session',
        () async {
      final container = containerWith();

      await container.read(activeSessionProvider.notifier).startAdHoc();

      final session = container.read(activeSessionProvider)!;
      expect(session.title, isNull);
      expect(session.isTemplateSession, isFalse);
    });

    test('finishing clears the tab back to its landing', () async {
      final container = containerWith();
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.startFromTemplate(
        templateId: 'push',
        templateName: 'Push day',
        groupIds: <String>['chest'],
      );

      await notifier.finish();

      expect(container.read(activeSessionProvider), isNull);
      expect(await SessionStore(database).readSavedSessions(), hasLength(1));
    });

    test('discarding clears it and keeps nothing', () async {
      final container = containerWith();
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.startAdHoc();

      await notifier.discard();

      expect(container.read(activeSessionProvider), isNull);
      expect(await SessionStore(database).sessionCount(), 0);
    });
  });

  group('logging through the notifier', () {
    test('state follows what the database actually holds', () async {
      final container = containerWith();
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.startAdHoc();

      final rowId = await notifier.addExercise(
        exerciseId: 'barbell-bench-press',
        loadType: LoadType.weighted,
      );
      await notifier.writeSet(
        sessionExerciseId: rowId!,
        position: 0,
        weightKg: 60,
        reps: 8,
        completed: true,
      );

      final session = container.read(activeSessionProvider)!;
      expect(session.exercises.single.sets.single.weightKg, 60);
      expect(session.completedSets, hasLength(1));
    });

    test('a rejected write leaves the notifier matching disk', () async {
      final container = containerWith();
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.startAdHoc();
      final rowId = await notifier.addExercise(
        exerciseId: 'barbell-bench-press',
        loadType: LoadType.weighted,
      );
      await notifier.writeSet(
        sessionExerciseId: rowId!,
        position: 0,
        weightKg: 60,
        reps: 8,
        completed: true,
      );

      await expectLater(
        notifier.writeSet(
            sessionExerciseId: rowId, position: 1, assistKg: -20),
        throwsA(isA<Object>()),
      );

      expect(
        container.read(activeSessionProvider)!.exercises.single.sets,
        hasLength(1),
        reason: 'state is assigned from what a write read back, so a failed '
            'write can leave it behind disk but never ahead of it',
      );
    });

    test('renaming and re-dating go through to storage', () async {
      final container = containerWith();
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.startAdHoc();

      await notifier.rename('Leg day');
      final backdated = LocalDate.today().addDays(-2);
      await notifier.setPerformedOn(backdated);

      final reopened = await SessionStore(database).readOpenSession();
      expect(reopened!.title, 'Leg day');
      expect(reopened.performedOn, backdated);
    });
  });

  group('degrading when the tables cannot be read', () {
    test('the open-session read returns none rather than throwing', () async {
      final store = _ThrowingSessionStore(database);

      expect(await readOpenSession(store), isNull);
    });

    test('the saved-history read returns empty rather than throwing',
        () async {
      final store = _ThrowingSessionStore(database);

      expect(
        await readSavedSessions(store),
        isEmpty,
        reason: 'both boot reads hit the same three tables, so whatever makes '
            'one unreadable makes both unreadable — and letting either throw '
            'kills main() and shows a blank screen',
      );
    });

    test('and a workout can still be started afterwards', () async {
      // The row a degraded boot leaves behind: still marked open, still
      // unreadable. Without releasing the marker on create, the unique index
      // would reject every future session and the app could never start a
      // workout again — which is worse than the crash the degrade avoids.
      await database.into(database.sessions).insert(
            SessionsCompanion.insert(
              id: 'unreadable',
              performedOn: LocalDate.today(),
              loggedAt: DateTime.now(),
              openMarker: const Value<int?>(kOpenSessionMarker),
            ),
          );
      final container = containerWith();

      await container.read(activeSessionProvider.notifier).startFromTemplate(
        templateId: 'push',
        templateName: 'Push day',
        groupIds: <String>['chest'],
      );

      expect(container.read(activeSessionProvider)!.title, 'Push day');
      expect(
        await SessionStore(database).sessionCount(),
        2,
        reason: 'the unreadable row stays on disk; it just stops being open',
      );
    });
  });
}

/// A store whose open-session read always fails, standing in for a row a later
/// build wrote and this one cannot interpret.
class _ThrowingSessionStore extends SessionStore {
  _ThrowingSessionStore(super.db);

  @override
  Future<WorkoutSession?> readOpenSession() =>
      Future<WorkoutSession?>.error(StateError('unreadable session row'));

  @override
  Future<List<WorkoutSession>> readSavedSessions() =>
      Future<List<WorkoutSession>>.error(StateError('no such table: sessions'));
}
