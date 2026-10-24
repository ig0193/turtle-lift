import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_date.dart';
import 'session_store.dart';

/// How long the live clock keeps showing.
///
/// A workout longer than this is almost certainly one the user walked away from,
/// and a clock reading `9:41:07` on a session left open overnight says nothing
/// true. Six hours is well past any real session.
const Duration kSessionClockLimit = Duration(hours: 6);

/// The live clock's reading, or null when the clock should not show.
///
/// **Display-only, and never stored** (`docs/adr/0006-workout-tab-is-exercise-first.md`).
/// `docs/01` rules out a stored duration because retrospective logging makes one
/// meaningless; a clock that is derived from the moment the workout started and
/// is shown nowhere but the live screen keeps that reason intact.
///
/// **It shows only for a workout that is happening now.** A session dated the day
/// it was started and under [kSessionClockLimit] old is live. A backdated session
/// was logged afterwards, so a clock on it would be measuring the wrong thing; a
/// session left open for days has no meaningful elapsed time at all. Comparing
/// against the day `loggedAt` falls on, rather than against today, is what keeps
/// the clock alive for a workout that crosses midnight.
Duration? sessionClockElapsed(WorkoutSession session, DateTime now) {
  if (session.performedOn != LocalDate.fromDateTime(session.loggedAt)) {
    return null;
  }
  final elapsed = now.difference(session.loggedAt);
  if (elapsed.isNegative || elapsed >= kSessionClockLimit) return null;
  return elapsed;
}

/// `m:ss`, or `h:mm:ss` from the first hour on.
String formatClock(Duration elapsed) {
  final totalSeconds = elapsed.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
  return '$minutes:$ss';
}

/// The sessions whose user has tapped **Start logging**.
///
/// **Held in memory, deliberately not stored.** It only decides which of two
/// views the session screen shows — the "ready" view with one button, or the
/// list — and nothing else reads it. After a cold start it is empty, and the
/// answer comes from [hasLoggingStarted] reading the session itself, so a user
/// who has typed anything lands on the list and one who has not lands back on
/// the ready view, which is the honest state of a workout with nothing in it.
class LoggingStarted extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  /// Records that logging has started for [sessionId].
  void start(String sessionId) {
    if (state.contains(sessionId)) return;
    state = <String>{...state, sessionId};
  }
}

/// Which sessions have had Start logging tapped this run.
final loggingStartedProvider =
    NotifierProvider<LoggingStarted, Set<String>>(LoggingStarted.new);

/// Whether [session] is past its ready view.
///
/// True once the user tapped Start logging, or once anything has been written to
/// it — whichever happened. A session with no exercises cannot have started
/// logging, because the list it would show is empty.
bool hasLoggingStarted(WorkoutSession session, Set<String> started) =>
    session.exercises.isNotEmpty &&
    (started.contains(session.id) || session.hasAnyWrittenSets);
