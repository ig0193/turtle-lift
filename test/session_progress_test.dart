import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/session_progress.dart';
import 'package:turtle_lift/src/data/session_store.dart';

/// The two small rules behind the session screen: when the live clock shows,
/// and when the screen is past its ready view.
void main() {
  WorkoutSession session({
    required DateTime loggedAt,
    LocalDate? performedOn,
    List<SessionExercise> exercises = const <SessionExercise>[],
    String id = 's1',
  }) =>
      WorkoutSession(
        id: id,
        title: null,
        performedOn: performedOn ?? LocalDate.fromDateTime(loggedAt),
        loggedAt: loggedAt,
        templateId: null,
        templateName: null,
        isOpen: true,
        exercises: exercises,
      );

  SessionExercise exercise({List<SetEntry> sets = const <SetEntry>[]}) =>
      SessionExercise(
        id: 'e1',
        exerciseId: 'plank',
        position: 0,
        loadType: LoadType.timed,
        markedDone: false,
        sets: sets,
      );

  group('the live clock', () {
    final started = DateTime(2026, 10, 24, 18, 0, 0);

    test('reads how long the workout has been running', () {
      expect(
        sessionClockElapsed(
            session(loggedAt: started), started.add(const Duration(minutes: 42))),
        const Duration(minutes: 42),
      );
    });

    test('is nothing for a session that was logged for another day', () {
      final backdated = session(
        loggedAt: started,
        performedOn: LocalDate.fromDateTime(started).addDays(-1),
      );

      expect(
        sessionClockElapsed(backdated, started.add(const Duration(minutes: 5))),
        isNull,
        reason: 'a backdated workout was written down afterwards, so a clock '
            'on it would be measuring the wrong thing',
      );
    });

    test('is nothing once the workout has run for six hours', () {
      final s = session(loggedAt: started);

      expect(
        sessionClockElapsed(s, started.add(kSessionClockLimit)),
        isNull,
        reason: 'past this it is a workout someone walked away from',
      );
      expect(
        sessionClockElapsed(
            s, started.add(kSessionClockLimit - const Duration(seconds: 1))),
        isNotNull,
      );
    });

    test('is nothing for a session left open for days', () {
      expect(
        sessionClockElapsed(
            session(loggedAt: started), started.add(const Duration(days: 3))),
        isNull,
      );
    });

    test('keeps running across midnight', () {
      final late = DateTime(2026, 10, 24, 23, 50);

      expect(
        sessionClockElapsed(
            session(loggedAt: late), DateTime(2026, 10, 25, 0, 20)),
        const Duration(minutes: 30),
        reason: 'it compares against the day the workout started on, not '
            'against today, so a late session does not lose its clock at 00:00',
      );
    });

    test('is nothing if the device clock went backwards', () {
      expect(
        sessionClockElapsed(session(loggedAt: started),
            started.subtract(const Duration(minutes: 1))),
        isNull,
      );
    });
  });

  group('the clock text', () {
    test('is m:ss under an hour', () {
      expect(formatClock(Duration.zero), '0:00');
      expect(formatClock(const Duration(seconds: 59)), '0:59');
      expect(formatClock(const Duration(minutes: 1, seconds: 5)), '1:05');
      expect(formatClock(const Duration(minutes: 42, seconds: 7)), '42:07');
    });

    test('is h:mm:ss from the first hour', () {
      expect(formatClock(const Duration(hours: 1)), '1:00:00');
      expect(formatClock(const Duration(hours: 5, minutes: 9, seconds: 3)),
          '5:09:03');
    });
  });

  group('having started logging', () {
    final at = DateTime(2026, 10, 24, 18);

    test('is not true of a workout with nothing on its list', () {
      expect(
        hasLoggingStarted(session(loggedAt: at), <String>{'s1'}),
        isFalse,
        reason: 'the list it would show is empty',
      );
    });

    test('is true once Start logging was tapped', () {
      expect(
        hasLoggingStarted(
          session(loggedAt: at, exercises: <SessionExercise>[exercise()]),
          <String>{'s1'},
        ),
        isTrue,
      );
    });

    test('is true once anything has been written, even after a restart', () {
      final withSet = session(loggedAt: at, exercises: <SessionExercise>[
        exercise(sets: const <SetEntry>[
          SetEntry(id: 'a', position: 0, completed: false, durationSec: 30),
        ]),
      ]);

      expect(hasLoggingStarted(withSet, const <String>{}), isTrue,
          reason: 'the tapped-set is in memory only; a set on disk is proof');
    });

    test('is false for a list nobody has touched', () {
      expect(
        hasLoggingStarted(
          session(loggedAt: at, exercises: <SessionExercise>[exercise()]),
          const <String>{},
        ),
        isFalse,
      );
    });

    test('is per session', () {
      final other = session(
        loggedAt: at,
        id: 's2',
        exercises: <SessionExercise>[exercise()],
      );

      expect(hasLoggingStarted(other, <String>{'s1'}), isFalse);
    });
  });

  group('the started set', () {
    test('records a session once, however often it is told', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loggingStartedProvider.notifier);

      notifier.start('s1');
      notifier.start('s1');
      notifier.start('s2');

      expect(container.read(loggingStartedProvider), <String>{'s1', 's2'});
    });

    test('starts empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(loggingStartedProvider), isEmpty);
    });
  });
}
