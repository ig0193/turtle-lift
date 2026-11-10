import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/derived.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;

/// QA: editing or deleting a saved workout moves every derived figure with no
/// manual refresh -- the personal-best count, the streak, the trained
/// muscles, the "Last time" prefill and the History rows -- driven through the
/// same notifier the History detail screen calls.
///
/// The pure functions are proven in `derived_test.dart` and
/// `personal_best_test.dart`; this proves the wiring between the store, the
/// notifier and the providers that read them.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseIndex index;
  late AppDatabase database;
  late SessionStore store;
  late ProviderContainer container;

  final today = LocalDate.today();

  setUpAll(() async {
    final boot = ProviderContainer();
    addTearDown(boot.dispose);
    index = ExerciseIndex.fromJson(
      await boot.read(exerciseLibraryProvider.future),
    );
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = SessionStore(database);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        exerciseIndexProvider.overrideWithValue(index),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await database.close();
  });

  ActiveSession notifier() => container.read(activeSessionProvider.notifier);
  List<WorkoutSession> saved() => container.read(savedSessionsProvider);

  /// Saves a workout of one exercise and one completed set per entry in
  /// [sets], dated [daysAgo] before today, and refreshes saved history the way
  /// Finish does. Returns the session id.
  Future<String> saveWorkout({
    required int daysAgo,
    String exerciseId = 'barbell-bench-press',
    LoadType loadType = LoadType.weighted,
    List<({double kg, int reps})> sets = const [(kg: 60, reps: 8)],
  }) async {
    final session = await store.createSession(
      performedOn: today.addDays(-daysAgo),
    );
    final row = await store.addExercise(
      sessionId: session.id,
      exerciseId: exerciseId,
      loadType: loadType,
    );
    for (var i = 0; i < sets.length; i++) {
      await store.writeSet(
        sessionExerciseId: row,
        position: i,
        completed: true,
        weightKg: sets[i].kg,
        reps: sets[i].reps,
      );
    }
    await container.read(savedSessionsProvider.notifier).refresh();
    await notifier().finish();
    return session.id;
  }

  WorkoutSession byId(String id) => saved().firstWhere((s) => s.id == id);
  int pbOf(String id) => container.read(historyProjectionProvider)[id]!.pbCount;

  group('personal bests follow an edit', () {
    test('raising an earlier best removes a later record', () async {
      final a = await saveWorkout(daysAgo: 10, sets: [(kg: 60, reps: 8)]);
      final b = await saveWorkout(daysAgo: 7, sets: [(kg: 65, reps: 8)]);
      expect(pbOf(b), 1);

      final set = byId(a).exercises.single.sets.single;
      await notifier().editSavedSet(
        sessionExerciseId: byId(a).exercises.single.id,
        position: 0,
        setId: set.id,
        completed: true,
        weightKg: 70,
        reps: 8,
      );

      expect(pbOf(b), 0, reason: '65 kg no longer beats the corrected 70 kg');
      expect(pbOf(a), 0, reason: 'the first-ever session is never a record');
    });

    test(
      'deleting the earlier workout makes the later one a first, not a PB',
      () async {
        final a = await saveWorkout(daysAgo: 10, sets: [(kg: 60, reps: 8)]);
        final b = await saveWorkout(daysAgo: 7, sets: [(kg: 65, reps: 8)]);
        expect(pbOf(b), 1);

        await notifier().deleteSaved(a);

        expect(saved().map((s) => s.id), [b]);
        expect(pbOf(b), 0);
      },
    );

    test(
      're-dating the later workout before the earlier one moves the record',
      () async {
        final a = await saveWorkout(daysAgo: 10, sets: [(kg: 60, reps: 8)]);
        final b = await saveWorkout(daysAgo: 7, sets: [(kg: 65, reps: 8)]);

        await notifier().setSavedPerformedOn(b, today.addDays(-12));

        expect(pbOf(b), 0, reason: 'it is now the first bench session');
        expect(pbOf(a), 0, reason: '60 kg does not beat 65 kg');
      },
    );

    test('deleting the set that made the record removes it', () async {
      await saveWorkout(daysAgo: 10, sets: [(kg: 60, reps: 8)]);
      final b = await saveWorkout(
        daysAgo: 7,
        sets: [(kg: 55, reps: 8), (kg: 65, reps: 8)],
      );
      expect(pbOf(b), 1);

      final heavy = byId(b).exercises.single.sets
          .firstWhere((s) => s.weightKg == 65);
      await notifier().deleteSavedSet(heavy.id);

      expect(pbOf(b), 0);
      expect(setCountOf(byId(b)), 1);
    });
  });

  group('the streak follows an edit', () {
    test(
      'moving a session past the three-day tolerance breaks the chain',
      () async {
        await saveWorkout(daysAgo: 0);
        final older = await saveWorkout(daysAgo: 3);
        expect(streakAsOf(today, saved()), 2);

        await notifier().setSavedPerformedOn(older, today.addDays(-4));

        expect(streakAsOf(today, saved()), 1);
      },
    );

    test('deleting the only session drops the streak to zero', () async {
      final only = await saveWorkout(daysAgo: 1);
      expect(streakAsOf(today, saved()), 1);

      await notifier().deleteSaved(only);

      expect(streakAsOf(today, saved()), 0);
    });

    test('a session edited down to no completed sets stops counting', () async {
      await saveWorkout(daysAgo: 0);
      final middle = await saveWorkout(daysAgo: 2);
      await saveWorkout(daysAgo: 5);
      expect(streakAsOf(today, saved()), 3);

      final set = byId(middle).exercises.single.sets.single;
      await notifier().deleteSavedSet(set.id);

      expect(
        streakAsOf(today, saved()),
        1,
        reason: 'today and five days ago are five days apart without it',
      );
    });

    test('the History detail card agrees once a session is emptied', () async {
      // The History detail now shows the one shared card, whose streak is
      // derived from the saved sessions (audit B3). A saved workout edited
      // down to nothing is no longer a History row (audit B6), and it must
      // not keep the chain alive (docs/00 §7: only a session with >= 1
      // completed set counts).
      final newest = await saveWorkout(daysAgo: 0);
      final middle = await saveWorkout(daysAgo: 2);
      await saveWorkout(daysAgo: 5);

      final set = byId(middle).exercises.single.sets.single;
      await notifier().deleteSavedSet(set.id);

      final rows = container.read(historySessionsProvider);
      expect(rows.map((r) => r.id), contains(newest));
      expect(rows.map((r) => r.id), isNot(contains(middle)));
      expect(streakAsOf(today, saved()), 1);
    });
  });

  group('the map, the prefill and History follow an edit', () {
    test('removing an exercise un-trains its muscles', () async {
      final session = await store.createSession(performedOn: today.addDays(-1));
      for (final id in ['barbell-bench-press', 'barbell-back-squat']) {
        final row = await store.addExercise(
          sessionId: session.id,
          exerciseId: id,
          loadType: LoadType.weighted,
        );
        await store.writeSet(
          sessionExerciseId: row,
          position: 0,
          completed: true,
          weightKg: 60,
          reps: 5,
        );
      }
      await notifier().finish();
      final before = trainedSubGroups(byId(session.id), index);
      expect(before, contains('chest/mid'));

      final bench = byId(session.id).exercises
          .firstWhere((e) => e.exerciseId == 'barbell-bench-press');
      await notifier().removeSavedExercise(bench.id);

      final after = trainedSubGroups(byId(session.id), index);
      expect(after, isNot(contains('chest/mid')));
      expect(after, isNotEmpty, reason: 'the squat still trained its muscles');
      expect(exerciseCountOf(byId(session.id)), 1);
    });

    test('the "Last time" prefill reads the corrected value', () async {
      final a = await saveWorkout(daysAgo: 3, sets: [(kg: 60, reps: 8)]);
      expect(prefillFor('barbell-bench-press', 0, saved())?.weightKg, 60);

      final set = byId(a).exercises.single.sets.single;
      await notifier().editSavedSet(
        sessionExerciseId: byId(a).exercises.single.id,
        position: 0,
        setId: set.id,
        completed: true,
        weightKg: 62.5,
        reps: 6,
      );

      final prefill = prefillFor('barbell-bench-press', 0, saved());
      expect(prefill?.weightKg, 62.5);
      expect(prefill?.reps, 6);
    });

    test(
      'deleting the latest workout falls the prefill back to the one before',
      () async {
        await saveWorkout(daysAgo: 6, sets: [(kg: 50, reps: 10)]);
        final latest = await saveWorkout(daysAgo: 2, sets: [(kg: 60, reps: 8)]);
        expect(prefillFor('barbell-bench-press', 0, saved())?.weightKg, 60);

        await notifier().deleteSaved(latest);

        expect(prefillFor('barbell-bench-press', 0, saved())?.weightKg, 50);
        expect(timesPerformed('barbell-bench-press', saved()), 1);
      },
    );

    test(
      'History rows and counts follow a delete and a set correction',
      () async {
        final a = await saveWorkout(daysAgo: 4, sets: [(kg: 60, reps: 8)]);
        final b = await saveWorkout(
          daysAgo: 1,
          sets: [(kg: 60, reps: 8), (kg: 60, reps: 8)],
        );
        expect(
          container.read(historySessionsNewestFirstProvider).map((s) => s.id),
          [b, a],
        );
        expect(container.read(historyProjectionProvider)[b]!.setCount, 2);

        await notifier().deleteSavedSet(byId(b).exercises.single.sets.last.id);
        expect(container.read(historyProjectionProvider)[b]!.setCount, 1);

        await notifier().deleteSaved(a);
        expect(
          container.read(historySessionsNewestFirstProvider).map((s) => s.id),
          [b],
        );
      },
    );
  });

  group('History order', () {
    test('two workouts on one day list the later-logged first, '
        'however long the history', () async {
      // Past 32 rows Dart's List.sort is no longer an insertion sort and stops
      // being stable, so a same-day pair can only be kept in order by an
      // explicit tiebreak (docs/00 §11: performedOn, loggedAt as tiebreaker).
      final ids = <String>[];
      for (var day = 0; day < 40; day++) {
        ids.add(await saveWorkout(daysAgo: 50 - day)); // logged first
        ids.add(await saveWorkout(daysAgo: 50 - day)); // logged second
      }
      // The store's own order is the contract: performedOn, then loggedAt,
      // both newest first.
      final expected = saved().map((s) => s.id).toList();
      expect(
        container
            .read(historySessionsNewestFirstProvider)
            .map((s) => s.id)
            .toList(),
        expected,
      );
    });
  });
}
