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
/// **It starts uncoloured and fills in, rather than previewing a plan.** The
/// map is a running record of what has actually been worked, not of what today
/// covers — an exercise fills its muscles when it has a completed set or is
/// marked done, and not before.
///
/// **It fills secondaries too, and the muscle list does not.** The map answers
/// "what got worked"; the list answers "what have I trained directly". After an
/// incline press the triceps fill lightly here while the triceps row stays
/// unticked, and `docs/02` is explicit that this is not to be "fixed".
///
/// **The fill is held, not rebuilt.** `BodyDiagramPainter.shouldRepaint`
/// compares the fill, so handing it a fresh object every build would repaint 42
/// polygons every frame. The fill is kept in state and replaced only when the
/// muscles it colours actually change.
class SessionBodyMap extends ConsumerStatefulWidget {
  const SessionBodyMap({super.key});

  @override
  ConsumerState<SessionBodyMap> createState() => _SessionBodyMapState();
}

class _SessionBodyMapState extends ConsumerState<SessionBodyMap> {
  MuscleFill _fill = MuscleFill(
    primary: const <String>{},
    secondary: const <String>{},
  );

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final index = ref.watch(exerciseIndexProvider);
    if (session == null) return const SizedBox.shrink();

    _syncFill(session, index);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final view in BodyView.values)
            Expanded(
              child: SizedBox(
                height: kSessionDiagramHeight,
                child: BodyDiagram(view: view, fill: _fill.colorFor),
              ),
            ),
        ],
      ),
    );
  }

  /// Replaces the fill only when the muscles it colours have changed, so the
  /// painter's identity check keeps meaning something.
  void _syncFill(WorkoutSession session, ExerciseIndex index) {
    final worked = workedSubGroups(session, index);
    final next = MuscleFill(
      primary: worked.primary,
      secondary: worked.secondary,
    );
    if (next != _fill) _fill = next;
  }
}

/// How tall the overview's pair of diagrams stands.
///
/// Shorter than the exercise page's, because this screen has a list under it
/// that the user is coming back to between sets.
const double kSessionDiagramHeight = 170;
