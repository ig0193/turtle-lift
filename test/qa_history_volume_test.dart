import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/session_store.dart';

/// QA (second pass, data volume): two years of training is about 300 saved
/// workouts and 1,800 exercise rows.
///
/// Reading them issued one query per workout and one more per exercise, so
/// every refresh (boot, Finish, and each keystroke in a past workout's edit)
/// ran about 2,100 queries: 300-400 ms on a desktop, longer on a phone. The
/// number of queries must not grow with the history.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('reading saved workouts takes a fixed number of queries', () async {
    final counter = _SelectCounter();
    final db = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(counter));
    addTearDown(db.close);
    final store = SessionStore(db);

    var day = 0;
    Future<void> seed(int n) async {
      for (var k = 0; k < n; k++) {
        final i = day++;
        final s = await store.createSession(
          performedOn: LocalDate(2026, 1, 1).addDays(i),
          exercises: [
            (exerciseId: 'barbell-bench-press', loadType: LoadType.weighted),
            (exerciseId: 'push-up', loadType: LoadType.bodyweight),
          ],
        );
        for (final ex in s.exercises) {
          await store.writeSet(
              sessionExerciseId: ex.id, position: 1, completed: true, reps: 5);
          await store.writeSet(
              sessionExerciseId: ex.id, position: 0, completed: true, reps: 8);
        }
        await store.saveOpenSession();
      }
    }

    Future<int> selectsFor(Future<void> Function() body) async {
      counter.selects = 0;
      await body();
      return counter.selects;
    }

    await seed(3);
    final few = await selectsFor(store.readSavedSessions);
    await seed(30);
    final many = await selectsFor(store.readSavedSessions);
    expect(many, few, reason: '$few queries for 3 workouts, $many for 33');

    final saved = await store.readSavedSessions();
    expect(saved, hasLength(33));
    expect(saved.first.performedOn, LocalDate(2026, 1, 1).addDays(32));
    for (final s in saved) {
      expect(s.exercises.map((e) => e.exerciseId),
          <String>['barbell-bench-press', 'push-up']);
      for (final e in s.exercises) {
        expect(e.sets.map((x) => x.position), <int>[0, 1]);
        expect(e.sets.map((x) => x.reps), <int>[8, 5]);
      }
    }
  });
}

class _SelectCounter extends QueryInterceptor {
  int selects = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
      QueryExecutor executor, String statement, List<Object?> args) {
    selects++;
    return executor.runSelect(statement, args);
  }
}
