import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/body_gender.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/session_store.dart';
import 'body_diagram.dart';
import 'exercise_detail_screen.dart' show MuscleFill;

/// The workout's muscle map, heating as work is logged.
///
/// **Filled muscles are a record; outlined ones are a plan.** A muscle fills
/// when an exercise that trains it has a completed set or is marked done, and not
/// before. What the workout *intends* to train — the primary muscles of every
/// exercise on its list that has not been worked yet — is only outlined, so
/// planning never looks like having done it. An ad-hoc workout outlines as it is
/// built, a template one from the first frame.
///
/// **It fills secondaries too.** The map answers "what got worked", so after an
/// incline press the triceps fill lightly. That is not a bug to be reconciled
/// with a list: there is no longer a second list that answers a different
/// question.
///
/// **The fill is held, not rebuilt.** `BodyDiagramPainter.shouldRepaint`
/// compares the fill, so handing it a fresh object every build would repaint 42
/// polygons every frame. The fill is kept in state and replaced only when the
/// muscles it colours actually change.
class SessionBodyMap extends ConsumerStatefulWidget {
  /// [height] defaults to what the session's exercise count suggests, see
  /// [sessionDiagramHeightFor]; the ready view passes its own, larger one.
  const SessionBodyMap({this.height, super.key});

  final double? height;

  @override
  ConsumerState<SessionBodyMap> createState() => _SessionBodyMapState();
}

class _SessionBodyMapState extends ConsumerState<SessionBodyMap> {
  MuscleFill _fill = MuscleFill(
    primary: const <String>{},
    secondary: const <String>{},
  );
  Set<String> _planned = const <String>{};

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final index = ref.watch(exerciseIndexProvider);
    if (session == null) return const SizedBox.shrink();

    _sync(session, index);
    final height =
        widget.height ?? sessionDiagramHeightFor(session.exercises.length);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final view in BodyView.values)
            Expanded(
              child: SizedBox(
                height: height,
                child: BodyDiagram(
                  view: view,
                  fill: _fill.colorFor,
                  planned: _planned,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Replaces the fill and the outline only when the muscles they cover have
  /// changed, so the painter's identity check keeps meaning something.
  void _sync(WorkoutSession session, ExerciseIndex index) {
    final worked = workedSubGroups(session, index);
    final next = MuscleFill(
      primary: worked.primary,
      secondary: worked.secondary,
    );
    if (next != _fill) _fill = next;

    final planned = plannedSubGroups(session, index)
      ..removeAll(worked.primary)
      ..removeAll(worked.secondary);
    if (planned.length != _planned.length || !_planned.containsAll(planned)) {
      _planned = Set<String>.unmodifiable(planned);
    }
  }
}

/// How tall the pair of diagrams stands for a workout with [exerciseCount]
/// exercises.
///
/// **The map is the screen's hero, so it gives way only as the list needs room.**
/// A short list leaves the map large; a long one shrinks it in steps so the next
/// exercise stays on screen without scrolling. Steps rather than a continuous
/// scale, so adding one exercise does not make the whole body twitch.
double sessionDiagramHeightFor(int exerciseCount) {
  if (exerciseCount <= 3) return 176;
  if (exerciseCount <= 5) return 152;
  if (exerciseCount <= 7) return 128;
  return 108;
}

/// How tall the map stands on the ready view, where nothing competes with it.
const double kReadyDiagramHeight = 200;
