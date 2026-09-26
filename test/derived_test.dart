import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/derived.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart'
    show BodyweightEntry;
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/set_format.dart';

/// Proves the figures every screen reads.
///
/// None of these is stored, so each one has to be right on read — and the two
/// that would read as *broken* rather than wrong if they drifted are the streak
/// decaying against today, and the muscle tick counting a completed set as
/// training even when the user never tapped Mark exercise done.
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
    String exerciseId,
    LoadType type,
    List<SetEntry> sets, {
    bool markedDone = false,
  }) =>
      SessionExercise(
        id: 'se-${nextId++}',
        exerciseId: exerciseId,
        position: 0,
        loadType: type,
        markedDone: markedDone,
        sets: sets,
      );

  WorkoutSession session(
    LocalDate date,
    List<SessionExercise> exercises, {
    String? title,
    String? templateName,
    String? templateId,
    DateTime? loggedAt,
  }) =>
      WorkoutSession(
        id: 'session-${nextId++}',
        title: title,
        performedOn: date,
        loggedAt: loggedAt ?? date.toDateTime(),
        templateId: templateId ?? (templateName == null ? null : 'tpl'),
        templateName: templateName,
        groupIds: const <String>[],
        isOpen: false,
        exercises: exercises,
      );

  Exercise libraryExercise(
    String id, {
    required String name,
    required List<String> primary,
    List<String> secondary = const <String>[],
  }) =>
      Exercise(
        id: id,
        name: name,
        equipment: 'Barbell',
        loadType: 'weighted',
        primary: primary,
        secondary: secondary,
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
      );

  final index = ExerciseIndex(<Exercise>[
    libraryExercise('incline-press',
        name: 'Incline dumbbell press',
        primary: <String>['chest/upper'],
        secondary: <String>['shoulders/front-delt', 'triceps/triceps']),
    libraryExercise('pushdown',
        name: 'Cable rope pushdown', primary: <String>['triceps/triceps']),
    libraryExercise('squat',
        name: 'Barbell back squat',
        primary: <String>['quads/quads'],
        secondary: <String>['glutes/glutes']),
  ]);

  group('display formats', () {
    test('render exactly as the spec table fixes them', () {
      expect(formatSet(LoadType.weighted, set(weightKg: 22, reps: 10)),
          '22kg × 10');
      expect(formatSet(LoadType.bodyweight, set(reps: 12)), '12 reps');
      expect(formatSet(LoadType.bodyweight, set(addedKg: 10, reps: 8)),
          '+10kg × 8');
      expect(formatSet(LoadType.assisted, set(assistKg: 20, reps: 8)),
          '20kg assist × 8');
      expect(formatSet(LoadType.timed, set(durationSec: 45)), '0:45');
      expect(formatSet(LoadType.timed, set(weightKg: 24, durationSec: 45)),
          '24kg × 0:45');
    });

    test('keeps a half-kilo and drops a trailing zero', () {
      expect(formatSet(LoadType.weighted, set(weightKg: 57.5, reps: 8)),
          '57.5kg × 8');
      expect(
          formatSet(LoadType.weighted, set(weightKg: 60, reps: 8)), '60kg × 8');
    });

    test('formats a duration above and below a minute', () {
      expect(formatDuration(90), '1:30');
      expect(formatDuration(45), '0:45');
      expect(formatDuration(60), '1:00');
    });
  });

  group('the completed-set rule', () {
    test('a ticked set with a zero required field does not count', () {
      expect(isSetComplete(LoadType.weighted, set(weightKg: 60, reps: 0)),
          isFalse);
      expect(isSetComplete(LoadType.timed, set(durationSec: 0)), isFalse);
    });

    test('an untouched tick does not count however full the row is', () {
      expect(
        isSetComplete(
            LoadType.weighted, set(weightKg: 60, reps: 8, completed: false)),
        isFalse,
      );
    });

    test('an optional field never gates completion', () {
      expect(isSetComplete(LoadType.bodyweight, set(reps: 8)), isTrue);
      expect(isSetComplete(LoadType.timed, set(durationSec: 45)), isTrue);
    });
  });

  group('the trained tick', () {
    final today = LocalDate.today();

    test('a completed set ticks the muscle without Mark exercise done', () {
      final s = session(today, <SessionExercise>[
        exercise('incline-press', LoadType.weighted,
            <SetEntry>[set(weightKg: 24, reps: 10)]),
      ]);

      expect(
        trainedSubGroups(s, index),
        <String>{'chest/upper'},
        reason: 'a user who logs three sets and walks to the next machine has '
            'trained that muscle, button or no button',
      );
    });

    test('Mark exercise done ticks it even with no sets logged', () {
      final s = session(today, <SessionExercise>[
        exercise('incline-press', LoadType.weighted, <SetEntry>[],
            markedDone: true),
      ]);

      expect(trainedSubGroups(s, index), <String>{'chest/upper'});
    });

    test('a secondary muscle never ticks', () {
      final s = session(today, <SessionExercise>[
        exercise('incline-press', LoadType.weighted,
            <SetEntry>[set(weightKg: 24, reps: 10)]),
      ]);

      expect(
        trainedSubGroups(s, index).contains('triceps/triceps'),
        isFalse,
        reason: 'the list answers "what have I trained directly"; an incline '
            'press is not a triceps movement',
      );
    });

    test('the map fills secondaries even though the list does not', () {
      final s = session(today, <SessionExercise>[
        exercise('incline-press', LoadType.weighted,
            <SetEntry>[set(weightKg: 24, reps: 10)]),
      ]);

      final worked = workedSubGroups(s, index);

      expect(worked.primary, <String>{'chest/upper'});
      expect(worked.secondary, contains('triceps/triceps'));
    });

    test('a muscle trained directly is not downgraded to secondary', () {
      final s = session(today, <SessionExercise>[
        exercise('incline-press', LoadType.weighted,
            <SetEntry>[set(weightKg: 24, reps: 10)]),
        exercise('pushdown', LoadType.weighted,
            <SetEntry>[set(weightKg: 30, reps: 12)]),
      ]);

      final worked = workedSubGroups(s, index);

      expect(worked.primary, contains('triceps/triceps'));
      expect(worked.secondary.contains('triceps/triceps'), isFalse);
    });

    test('an exercise with no completed sets ticks nothing', () {
      final s = session(today, <SessionExercise>[
        exercise('incline-press', LoadType.weighted,
            <SetEntry>[set(weightKg: 24, reps: 10, completed: false)]),
      ]);

      expect(trainedSubGroups(s, index), isEmpty);
    });
  });

  group('per-exercise progress', () {
    test('is derived from the sets and the mark, never stored', () {
      expect(
        progressOf(exercise('pushdown', LoadType.weighted, <SetEntry>[])),
        ExerciseProgress.notStarted,
      );
      expect(
        progressOf(exercise('pushdown', LoadType.weighted,
            <SetEntry>[set(weightKg: 30, reps: 12)])),
        ExerciseProgress.inProgress,
      );
      expect(
        progressOf(exercise('pushdown', LoadType.weighted,
            <SetEntry>[set(weightKg: 30, reps: 12)],
            markedDone: true)),
        ExerciseProgress.done,
      );
    });

    test('deleting every set drops it back rather than leaving it wrong', () {
      expect(
        progressOf(exercise('pushdown', LoadType.weighted, <SetEntry>[])),
        ExerciseProgress.notStarted,
      );
    });
  });

  group('the streak', () {
    List<WorkoutSession> on(List<LocalDate> dates) => <WorkoutSession>[
          for (final date in dates)
            session(date, <SessionExercise>[
              exercise('squat', LoadType.weighted,
                  <SetEntry>[set(weightKg: 80, reps: 8)]),
            ]),
        ];

    test('chains across a Friday-to-Monday gap', () {
      final friday = LocalDate(2026, 9, 11);
      final monday = LocalDate(2026, 9, 14);

      expect(streakAsOf(monday, on(<LocalDate>[friday, monday])), 2);
    });

    test('breaks across a four-day gap', () {
      final start = LocalDate(2026, 9, 9);
      final later = LocalDate(2026, 9, 14);

      expect(streakAsOf(later, on(<LocalDate>[start, later])), 1);
    });

    test('decays against the date asked about, not the stored data', () {
      final fiveDaysAgo = LocalDate.today().addDays(-5);

      expect(
        streakAsOf(LocalDate.today(), on(<LocalDate>[fiveDaysAgo])),
        0,
        reason: 'otherwise the app says 12, you open it a week later, and it '
            'still says 12',
      );
    });

    test('a session with no completed sets does not count', () {
      final today = LocalDate.today();
      final empty = session(today, <SessionExercise>[
        exercise('squat', LoadType.weighted,
            <SetEntry>[set(weightKg: 80, reps: 8, completed: false)]),
      ]);

      expect(streakAsOf(today, <WorkoutSession>[empty]), 0);
    });

    test('two sessions on one day count once', () {
      final today = LocalDate.today();

      expect(streakAsOf(today, on(<LocalDate>[today, today])), 1);
    });

    test('a past date sees the streak as it stood then', () {
      final monday = LocalDate(2026, 9, 7);
      final wednesday = LocalDate(2026, 9, 9);
      final sessions = on(<LocalDate>[monday, wednesday]);

      expect(streakAsOf(wednesday, sessions), 2);
      expect(streakAsOf(monday, sessions), 1);
    });
  });

  group('the resolved title', () {
    final today = LocalDate.today();

    test('uses the user\'s own title first', () {
      final s = session(today, <SessionExercise>[], title: 'Leg day');
      expect(resolvedTitle(s, index), 'Leg day');
    });

    test('falls back to the template name', () {
      final s = session(today, <SessionExercise>[],
          templateName: 'Chest and triceps day');
      expect(resolvedTitle(s, index), 'Chest and triceps day');
    });

    test('uses a snapshotted template name after that template is deleted',
        () {
      final s = session(today, <SessionExercise>[], templateName: 'My push day');
      expect(resolvedTitle(s, index), 'My push day');
    });

    test('falls back to the single exercise for a quick log', () {
      final s = session(today, <SessionExercise>[
        exercise('squat', LoadType.weighted,
            <SetEntry>[set(weightKg: 80, reps: 8)]),
      ]);
      expect(resolvedTitle(s, index), 'Barbell back squat');
    });

    test('falls back to the muscle groups trained, in taxonomy order', () {
      final s = session(today, <SessionExercise>[
        exercise('pushdown', LoadType.weighted,
            <SetEntry>[set(weightKg: 30, reps: 12)]),
        exercise('incline-press', LoadType.weighted,
            <SetEntry>[set(weightKg: 24, reps: 10)]),
      ]);

      expect(resolvedTitle(s, index), 'Chest, triceps');
    });

    test('never invents a time-of-day name', () {
      final s = session(today, <SessionExercise>[]);
      expect(resolvedTitle(s, index), isNot(contains('Evening')));
      expect(resolvedTitle(s, index), isNot(contains('Morning')));
    });

    test('a whitespace-only title is treated as empty', () {
      final s = session(today, <SessionExercise>[], title: '   ');
      expect(resolvedTitle(s, index), isNot('   '));
    });
  });

  group('prefill and history', () {
    final monday = LocalDate(2026, 9, 7);
    final wednesday = LocalDate(2026, 9, 9);

    test('counts only sessions with a completed set of that exercise', () {
      final logged = session(monday, <SessionExercise>[
        exercise('squat', LoadType.weighted,
            <SetEntry>[set(weightKg: 80, reps: 8)]),
      ]);
      final opened = session(wednesday, <SessionExercise>[
        exercise('squat', LoadType.weighted,
            <SetEntry>[set(weightKg: 80, reps: 8, completed: false)]),
      ]);

      expect(timesPerformed('squat', <WorkoutSession>[logged, opened]), 1);
      expect(timesPerformed('pushdown', <WorkoutSession>[logged]), 0);
    });

    test('prefills row zero from the same index of the last session', () {
      final last = session(wednesday, <SessionExercise>[
        exercise('squat', LoadType.weighted, <SetEntry>[
          set(weightKg: 80, reps: 8),
          set(weightKg: 75, reps: 10),
        ]),
      ]);

      expect(prefillFor('squat', 0, <WorkoutSession>[last])!.weightKg, 80);
      expect(prefillFor('squat', 1, <WorkoutSession>[last])!.weightKg, 75);
    });

    test('prefills from the most recent session even when backdating', () {
      final older = session(monday, <SessionExercise>[
        exercise('squat', LoadType.weighted,
            <SetEntry>[set(weightKg: 70, reps: 8)]),
      ]);
      final newer = session(wednesday, <SessionExercise>[
        exercise('squat', LoadType.weighted,
            <SetEntry>[set(weightKg: 80, reps: 8)]),
      ]);

      expect(
        prefillFor('squat', 0, <WorkoutSession>[older, newer])!.weightKg,
        80,
        reason: 'a user backdating today\'s entry still prefills from what '
            'they actually last lifted',
      );
    });

    test('opens with as many rows as the last session held, at least one', () {
      final last = session(wednesday, <SessionExercise>[
        exercise('squat', LoadType.weighted, <SetEntry>[
          set(weightKg: 80, reps: 8),
          set(weightKg: 80, reps: 8),
          set(weightKg: 75, reps: 10),
        ]),
      ]);

      expect(openingRowCount('squat', <WorkoutSession>[last]), 3);
      expect(openingRowCount('pushdown', <WorkoutSession>[last]), 1);
    });

    test('an exercise with no history prefills nothing', () {
      expect(prefillFor('squat', 0, <WorkoutSession>[]), isNull);
    });
  });

  group('the calorie estimate', () {
    final today = LocalDate.today();

    WorkoutSession withSets(int count) => session(today, <SessionExercise>[
          exercise('squat', LoadType.weighted, <SetEntry>[
            for (var i = 0; i < count; i++) set(weightKg: 80, reps: 8),
          ]),
        ]);

    test('is absent when no weight was in effect on that day', () {
      expect(
        caloriesFor(withSets(10), const <BodyweightEntry>[]),
        isNull,
        reason: 'the prompt to add a weight is a real state; a wrong number '
            'would not be',
      );
    });

    test('is absent for a session predating every weigh-in', () {
      final series = <BodyweightEntry>[
        BodyweightEntry(date: today.toDateTime(), weightKg: 78),
      ];
      final old = session(today.addDays(-30), <SessionExercise>[
        exercise('squat', LoadType.weighted,
            <SetEntry>[set(weightKg: 80, reps: 8)]),
      ]);

      expect(caloriesFor(old, series), isNull);
    });

    test('resolves the weight in effect on the session\'s own day', () {
      final series = <BodyweightEntry>[
        BodyweightEntry(date: today.addDays(-30).toDateTime(), weightKg: 70),
        BodyweightEntry(date: today.toDateTime(), weightKg: 90),
      ];
      final older = session(today.addDays(-10), <SessionExercise>[
        exercise('squat', LoadType.weighted,
            <SetEntry>[set(weightKg: 80, reps: 8)]),
      ]);

      final olderCalories = caloriesFor(older, series)!;
      final todayCalories = caloriesFor(withSets(1), series)!;

      expect(
        olderCalories < todayCalories,
        isTrue,
        reason: 'the older session resolves against the 70kg entry that was in '
            'effect then, not the newest one',
      );
    });

    test('moves across the tier boundaries', () {
      expect(effortTierFor(9), EffortTier.light);
      expect(effortTierFor(10), EffortTier.moderate);
      expect(effortTierFor(20), EffortTier.moderate);
      expect(effortTierFor(21), EffortTier.vigorous);
    });

    test('a session with no completed sets has no figure', () {
      final series = <BodyweightEntry>[
        BodyweightEntry(date: today.toDateTime(), weightKg: 78),
      ];
      expect(caloriesFor(withSets(0), series), isNull);
    });
  });

  group('session counts', () {
    final today = LocalDate.today();

    test('count completed sets and the exercises that carry them', () {
      final s = session(today, <SessionExercise>[
        exercise('squat', LoadType.weighted, <SetEntry>[
          set(weightKg: 80, reps: 8),
          set(weightKg: 80, reps: 8),
          set(weightKg: 75, reps: 10, completed: false),
        ]),
        exercise('pushdown', LoadType.weighted, <SetEntry>[]),
      ]);

      expect(setCountOf(s), 2);
      expect(exerciseCountOf(s), 1);
    });

    test('a saved session edited down to nothing still resolves', () {
      final s = session(today, <SessionExercise>[
        exercise('squat', LoadType.weighted, <SetEntry>[]),
      ]);

      expect(setCountOf(s), 0);
      expect(streakAsOf(today, <WorkoutSession>[s]), 0);
      expect(resolvedTitle(s, index), isNotEmpty);
      expect(trainedSubGroups(s, index), isEmpty);
    });
  });

  group('lastPerformed', () {
    final today = LocalDate.today();
    final bench = libraryExercise('bench', name: 'Bench', primary: ['chest/mid']);
    final index = ExerciseIndex(<Exercise>[bench]);

    WorkoutSession ran(String templateId, LocalDate on, {bool completed = true}) =>
        session(
          on,
          <SessionExercise>[
            exercise('bench', LoadType.weighted, <SetEntry>[
              set(weightKg: 60, reps: 8, completed: completed),
            ]),
          ],
          templateId: templateId,
        );

    test('is null for a template that has never been run', () {
      expect(lastPerformed('push', <WorkoutSession>[]), isNull);
      expect(
        lastPerformed('push', <WorkoutSession>[ran('pull', today)]),
        isNull,
        reason: 'another template being run is not this one being run',
      );
    });

    test('is the most recent day, whatever order history arrives in', () {
      final sessions = <WorkoutSession>[
        ran('push', today.addDays(-9)),
        ran('push', today.addDays(-2)),
        ran('push', today.addDays(-30)),
      ];
      expect(lastPerformed('push', sessions), today.addDays(-2));
    });

    test('ignores sessions with no completed set', () {
      // The same bar the streak and timesPerformed use: an opened and
      // abandoned template was not performed.
      final sessions = <WorkoutSession>[
        ran('push', today.addDays(-6)),
        ran('push', today, completed: false),
      ];
      expect(
        lastPerformed('push', sessions),
        today.addDays(-6),
        reason: 'today\'s session ticked nothing, so it is not a performance',
      );
    });

    test('reads performedOn, not loggedAt', () {
      // A Monday workout entered on Wednesday was done on Monday, and the row
      // has to say so -- the rule `performedOn` exists for.
      final monday = today.addDays(-2);
      final sessions = <WorkoutSession>[
        ran('push', today.addDays(-1)),
        session(
          monday,
          <SessionExercise>[
            exercise('bench', LoadType.weighted, <SetEntry>[
              set(weightKg: 60, reps: 8),
            ]),
          ],
          templateId: 'push',
          loggedAt: today.toDateTime(),
        ),
      ];
      expect(
        lastPerformed('push', sessions),
        today.addDays(-1),
        reason: 'the backdated session is older than yesterday\'s, however '
            'recently it was typed in',
      );
    });

    test('is unaffected by an ad-hoc session, which names no template', () {
      final adHoc = session(today, <SessionExercise>[
        exercise('bench', LoadType.weighted, <SetEntry>[
          set(weightKg: 60, reps: 8),
        ]),
      ]);
      expect(lastPerformed('push', <WorkoutSession>[adHoc]), isNull);
      expect(index.byId('bench'), isNotNull);
    });
  });

  group('lifted volume', () {
    // Volume returned in `adr/0004` for Hevy's summary bar, after being banned
    // outright by `00` §3. It is a *partial* figure on purpose: two of the four
    // load types move no external weight at all, so the number can only ever
    // describe part of a session. These tests pin that partiality, because the
    // tempting "fix" is to invent a weight for bodyweight work, and that would
    // quietly make the figure a lie.
    final today = LocalDate(2026, 9, 23);

    test('sums weight by reps over completed weighted sets', () {
      final s = session(today, <SessionExercise>[
        exercise('bench', LoadType.weighted, <SetEntry>[
          set(weightKg: 60, reps: 10), // 600
          set(weightKg: 62.5, reps: 8), // 500
        ]),
      ]);
      expect(volumeOf(s), 1100);
    });

    test('an incomplete set contributes nothing', () {
      final s = session(today, <SessionExercise>[
        exercise('bench', LoadType.weighted, <SetEntry>[
          set(weightKg: 60, reps: 10),
          set(weightKg: 60, reps: 10, completed: false),
        ]),
      ]);
      expect(volumeOf(s), 600);
    });

    test('bodyweight counts only the weight actually added', () {
      final s = session(today, <SessionExercise>[
        exercise('pullup', LoadType.bodyweight, <SetEntry>[
          set(reps: 12), // no external load — contributes nothing
          set(reps: 8, addedKg: 10), // 80
        ]),
      ]);
      expect(volumeOf(s), 80);
    });

    test('assisted and timed work contribute nothing', () {
      final s = session(today, <SessionExercise>[
        exercise('assisted-pullup', LoadType.assisted, <SetEntry>[
          set(reps: 10, assistKg: 20),
        ]),
        exercise('plank', LoadType.timed, <SetEntry>[
          set(durationSec: 60),
        ]),
      ]);
      // Not zero because they are unimportant — zero because neither moves a
      // weight this figure could honestly count. Assist is weight *removed*.
      expect(volumeOf(s), 0);
    });
  });
}
