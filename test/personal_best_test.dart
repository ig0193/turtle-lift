import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/personal_best.dart';
import 'package:turtle_lift/src/data/session_store.dart';

/// Proves the personal-best metric, and above all that the assisted one is
/// inverted.
///
/// `CLAUDE.md` names the assisted inversion "the thing most likely to ship
/// backwards", and these assertions were written before the metric they check
/// for exactly that reason: a test written afterwards tends to agree with
/// whatever the implementation happened to do.
void main() {
  var nextId = 0;
  SetEntry set({
    double? weightKg,
    int? reps,
    double? addedKg,
    double? assistKg,
    int? durationSec,
    bool completed = true,
  }) =>
      SetEntry(
        id: 'set-${nextId++}',
        position: 0,
        completed: completed,
        weightKg: weightKg,
        reps: reps,
        addedKg: addedKg,
        assistKg: assistKg,
        durationSec: durationSec,
      );

  SessionExercise exercise(
    LoadType type,
    List<SetEntry> sets, {
    String exerciseId = 'ex',
  }) =>
      SessionExercise(
        id: 'se-${nextId++}',
        exerciseId: exerciseId,
        position: 0,
        loadType: type,
        markedDone: false,
        sets: sets,
      );

  WorkoutSession session(
    LocalDate date,
    List<SessionExercise> exercises, {
    DateTime? loggedAt,
  }) =>
      WorkoutSession(
        id: 'session-${nextId++}',
        title: null,
        performedOn: date,
        loggedAt: loggedAt ?? date.toDateTime(),
        templateId: null,
        templateName: null,
        groupIds: const <String>[],
        isOpen: false,
        exercises: exercises,
      );

  group('the assisted metric is inverted', () {
    test('less assistance beats more', () {
      final lighter = metricFor(LoadType.assisted, set(assistKg: 15, reps: 8));
      final heavier = metricFor(LoadType.assisted, set(assistKg: 20, reps: 8));

      expect(
        lighter.compareTo(heavier) > 0,
        isTrue,
        reason: 'the record on an assist machine is the lightest assist used',
      );
    });

    test('more assistance does not beat the record', () {
      final heavier = metricFor(LoadType.assisted, set(assistKg: 25, reps: 8));
      final record = metricFor(LoadType.assisted, set(assistKg: 20, reps: 8));

      expect(heavier.compareTo(record) < 0, isTrue);
    });

    test('at equal assistance, more reps wins', () {
      final more = metricFor(LoadType.assisted, set(assistKg: 20, reps: 10));
      final fewer = metricFor(LoadType.assisted, set(assistKg: 20, reps: 8));

      expect(more.compareTo(fewer) > 0, isTrue);
    });

    test('an identical set is not an improvement', () {
      final a = metricFor(LoadType.assisted, set(assistKg: 20, reps: 8));
      final b = metricFor(LoadType.assisted, set(assistKg: 20, reps: 8));

      expect(a.compareTo(b), 0);
    });
  });

  group('the other three metrics', () {
    test('weighted: heavier wins, and at equal weight more reps wins', () {
      expect(
        metricFor(LoadType.weighted, set(weightKg: 62.5, reps: 6))
                .compareTo(metricFor(LoadType.weighted, set(weightKg: 60, reps: 10))) >
            0,
        isTrue,
        reason: 'weight is compared before reps, so a heavier single beats a '
            'lighter set of many',
      );
      expect(
        metricFor(LoadType.weighted, set(weightKg: 60, reps: 10))
                .compareTo(metricFor(LoadType.weighted, set(weightKg: 60, reps: 8))) >
            0,
        isTrue,
      );
    });

    test('bodyweight: added weight wins, then reps', () {
      expect(
        metricFor(LoadType.bodyweight, set(addedKg: 10, reps: 6))
                .compareTo(metricFor(LoadType.bodyweight, set(reps: 12))) >
            0,
        isTrue,
      );
    });

    test('bodyweight degenerates to max reps when nobody adds weight', () {
      expect(
        metricFor(LoadType.bodyweight, set(reps: 12))
                .compareTo(metricFor(LoadType.bodyweight, set(reps: 9))) >
            0,
        isTrue,
      );
    });

    test('timed: weight wins, then duration', () {
      expect(
        metricFor(LoadType.timed, set(durationSec: 60))
                .compareTo(metricFor(LoadType.timed, set(durationSec: 45))) >
            0,
        isTrue,
      );
      expect(
        metricFor(LoadType.timed, set(weightKg: 24, durationSec: 45))
                .compareTo(metricFor(LoadType.timed, set(durationSec: 60))) >
            0,
        isTrue,
      );
    });
  });

  group('per-session personal-best count', () {
    final monday = LocalDate(2026, 9, 7);
    final wednesday = LocalDate(2026, 9, 9);
    final friday = LocalDate(2026, 9, 11);

    test('the first-ever session of an exercise earns no record', () {
      final first = session(monday, <SessionExercise>[
        exercise(LoadType.weighted, <SetEntry>[set(weightKg: 60, reps: 8)]),
      ]);

      expect(
        pbCountFor(first, <WorkoutSession>[first]),
        0,
        reason: 'the first time is trivially a maximum; badging it would give '
            'a beginner six records on day one and none afterwards',
      );
    });

    test('beating an earlier session earns one', () {
      final first = session(monday, <SessionExercise>[
        exercise(LoadType.weighted, <SetEntry>[set(weightKg: 60, reps: 8)]),
      ]);
      final second = session(wednesday, <SessionExercise>[
        exercise(LoadType.weighted, <SetEntry>[set(weightKg: 62.5, reps: 8)]),
      ]);

      expect(pbCountFor(second, <WorkoutSession>[first, second]), 1);
    });

    test('repeating the same set is not a record', () {
      final first = session(monday, <SessionExercise>[
        exercise(LoadType.weighted, <SetEntry>[set(weightKg: 60, reps: 8)]),
      ]);
      final second = session(wednesday, <SessionExercise>[
        exercise(LoadType.weighted, <SetEntry>[set(weightKg: 60, reps: 8)]),
      ]);

      expect(pbCountFor(second, <WorkoutSession>[first, second]), 0);
    });

    test('three heavier sets of one exercise count as one record', () {
      final first = session(monday, <SessionExercise>[
        exercise(LoadType.weighted, <SetEntry>[set(weightKg: 60, reps: 8)]),
      ]);
      final second = session(wednesday, <SessionExercise>[
        exercise(LoadType.weighted, <SetEntry>[
          set(weightKg: 62.5, reps: 8),
          set(weightKg: 65, reps: 6),
          set(weightKg: 67.5, reps: 4),
        ]),
      ]);

      expect(
        pbCountFor(second, <WorkoutSession>[first, second]),
        1,
        reason: 'records are counted per exercise, not per set',
      );
    });

    test('an incomplete set cannot set a record', () {
      final first = session(monday, <SessionExercise>[
        exercise(LoadType.weighted, <SetEntry>[set(weightKg: 60, reps: 8)]),
      ]);
      final second = session(wednesday, <SessionExercise>[
        exercise(LoadType.weighted, <SetEntry>[
          set(weightKg: 100, reps: 8, completed: false),
        ]),
      ]);

      expect(pbCountFor(second, <WorkoutSession>[first, second]), 0);
    });

    test('backdating a heavier session removes a later record', () {
      final wednesdaySession = session(wednesday, <SessionExercise>[
        exercise(LoadType.weighted, <SetEntry>[set(weightKg: 62.5, reps: 8)]),
      ]);
      final mondaySession = session(monday, <SessionExercise>[
        exercise(LoadType.weighted, <SetEntry>[set(weightKg: 60, reps: 8)]),
      ]);
      expect(
        pbCountFor(wednesdaySession,
            <WorkoutSession>[mondaySession, wednesdaySession]),
        1,
      );

      // The user now backdates a heavier Monday session. Wednesday is no longer
      // a record, and the badge vanishes — correct, and worth knowing.
      final heavierMonday = session(monday, <SessionExercise>[
        exercise(LoadType.weighted, <SetEntry>[set(weightKg: 65, reps: 8)]),
      ]);

      expect(
        pbCountFor(wednesdaySession,
            <WorkoutSession>[heavierMonday, wednesdaySession]),
        0,
      );
    });

    test('two sessions on one day compare against the same prior best', () {
      final earlier = session(monday, <SessionExercise>[
        exercise(LoadType.weighted, <SetEntry>[set(weightKg: 60, reps: 8)]),
      ]);
      final morning = session(
        wednesday,
        <SessionExercise>[
          exercise(LoadType.weighted, <SetEntry>[set(weightKg: 62.5, reps: 8)]),
        ],
        loggedAt: DateTime(2026, 9, 9, 8),
      );
      final evening = session(
        wednesday,
        <SessionExercise>[
          exercise(LoadType.weighted, <SetEntry>[set(weightKg: 65, reps: 8)]),
        ],
        loggedAt: DateTime(2026, 9, 9, 19),
      );
      final all = <WorkoutSession>[earlier, morning, evening];

      // Both beat Monday, and neither is "earlier" than the other by date, so
      // the running best advances at a date boundary rather than per session.
      expect(pbCountFor(morning, all), 1);
      expect(
        pbCountFor(evening, all),
        1,
        reason: 'a record is strictly greater than every session with an '
            'earlier performedOn, so same-day sessions share a baseline',
      );
    });

    test('an assisted improvement is counted as a record', () {
      final first = session(monday, <SessionExercise>[
        exercise(LoadType.assisted, <SetEntry>[set(assistKg: 25, reps: 8)],
            exerciseId: 'assisted-pull-up'),
      ]);
      final second = session(friday, <SessionExercise>[
        exercise(LoadType.assisted, <SetEntry>[set(assistKg: 20, reps: 8)],
            exerciseId: 'assisted-pull-up'),
      ]);

      expect(
        pbCountFor(second, <WorkoutSession>[first, second]),
        1,
        reason: 'dropping from 25kg of help to 20kg is progress',
      );
    });

    test('taking more assistance is not a record', () {
      final first = session(monday, <SessionExercise>[
        exercise(LoadType.assisted, <SetEntry>[set(assistKg: 20, reps: 8)],
            exerciseId: 'assisted-pull-up'),
      ]);
      final second = session(friday, <SessionExercise>[
        exercise(LoadType.assisted, <SetEntry>[set(assistKg: 30, reps: 8)],
            exerciseId: 'assisted-pull-up'),
      ]);

      expect(pbCountFor(second, <WorkoutSession>[first, second]), 0);
    });

    test('two different exercises can each set a record in one session', () {
      final first = session(monday, <SessionExercise>[
        exercise(LoadType.weighted, <SetEntry>[set(weightKg: 60, reps: 8)],
            exerciseId: 'bench'),
        exercise(LoadType.weighted, <SetEntry>[set(weightKg: 30, reps: 12)],
            exerciseId: 'curl'),
      ]);
      final second = session(wednesday, <SessionExercise>[
        exercise(LoadType.weighted, <SetEntry>[set(weightKg: 62.5, reps: 8)],
            exerciseId: 'bench'),
        exercise(LoadType.weighted, <SetEntry>[set(weightKg: 32.5, reps: 12)],
            exerciseId: 'curl'),
      ]);

      expect(pbCountFor(second, <WorkoutSession>[first, second]), 2);
    });
  });
}
