import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/glance_bridge.dart';
import '../data/session_progress.dart';
import '../data/session_store.dart';
import 'last_workout_line.dart';

/// When the Live Activity's clock counts from, or null when it must not show.
///
/// The live screen's rule exactly (`sessionClockElapsed`): a session dated the
/// day it started and under six hours old. The system then counts on its own,
/// so the six-hour cut-off is also passed as the timer's end.
DateTime? clockStartFor(WorkoutSession session, DateTime now) =>
    sessionClockElapsed(session, now) == null ? null : session.loggedAt;

/// The open workout as the Live Activity shows it, or null when there should
/// be none: no workout open, or one still on its ready view (an activity says
/// a workout is happening, and before Start logging it is not).
final sessionGlanceProvider = Provider<SessionGlance?>((ref) {
  final session = ref.watch(activeSessionProvider);
  if (session == null) return null;
  if (!hasLoggingStarted(session, ref.watch(loggingStartedProvider))) {
    return null;
  }
  final done = session.exercises
      .where((e) => progressOf(e) == ExerciseProgress.done)
      .length;
  return SessionGlance(
    title: resolvedTitle(session, ref.watch(exerciseIndexProvider)),
    done: done,
    total: session.exercises.length,
    clockStart: clockStartFor(session, DateTime.now()),
  );
});

/// What the home-screen widget shows: the last workout, in the Workout
/// landing's own words.
///
/// **The wire shape is the one the widget already decodes** (`headline`,
/// `caption`, `days`, `lastWorkout`), from when it also showed the training
/// week. The Schedule is gone (`docs/adr/0015-diet-is-a-log.md`), so the line
/// goes in `headline`, the widget's one always-drawn text, and the rest is
/// empty: no Swift change, and nothing for the widget to draw that the app no
/// longer has.
final weekGlanceProvider = Provider<WeekGlance>((ref) {
  final last = ref.watch(lastWorkoutProvider)?.line;
  return WeekGlance(
    headline: last ?? kNoWorkoutsGlance,
    caption: '',
    days: const <GlanceDay>[],
    lastWorkout: null,
  );
});

/// The widget's line before there is a saved workout.
const String kNoWorkoutsGlance = 'No workouts yet';

/// Keeps the Live Activity and the home-screen widget in step with the app.
///
/// **Pushed on change, from boot.** It listens to the two derived glances and
/// sends each one whenever it changes, and once at start: so a workout that
/// was open when the app was killed gets its activity back, and the reboot
/// after Delete all data (a new scope, no session, no week) ends the activity
/// and blanks the widget with nothing else to remember.
class GlanceSync extends ConsumerStatefulWidget {
  const GlanceSync({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<GlanceSync> createState() => _GlanceSyncState();
}

class _GlanceSyncState extends ConsumerState<GlanceSync> {
  @override
  void initState() {
    super.initState();
    final bridge = ref.read(glanceBridgeProvider);
    ref.listenManual<SessionGlance?>(
      sessionGlanceProvider,
      (previous, next) {
        if (next == null) {
          bridge.endSession();
        } else {
          bridge.showSession(next);
        }
      },
      fireImmediately: true,
    );
    ref.listenManual<WeekGlance>(
      weekGlanceProvider,
      (previous, next) => bridge.showWeek(next),
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
