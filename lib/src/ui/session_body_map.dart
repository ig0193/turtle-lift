import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/body_gender.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/session_store.dart';
import 'body_diagram.dart';
import 'exercise_detail_screen.dart' show MuscleFill;
import 'motion.dart';

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
///
/// **A newly worked muscle eases into its fill** (300ms, research item 6), and
/// only while this screen is the one on top: a set logged on the pushed logging
/// screen changes the fill underneath, and the ease plays as the user comes
/// back to the map rather than unseen behind the route. A workout opened with
/// work already done shows it at once, and with Reduce Motion on every change
/// is a cut.
class SessionBodyMap extends ConsumerStatefulWidget {
  /// [height] defaults to what the session's exercise count suggests, see
  /// [sessionDiagramHeightFor]; the ready view passes its own, larger one.
  const SessionBodyMap({this.height, super.key});

  final double? height;

  @override
  ConsumerState<SessionBodyMap> createState() => _SessionBodyMapState();
}

class _SessionBodyMapState extends ConsumerState<SessionBodyMap>
    with SingleTickerProviderStateMixin {
  MuscleFill _fill = MuscleFill(
    primary: const <String>{},
    secondary: const <String>{},
  );
  Set<String> _planned = const <String>{};

  /// What the map last finished showing; the ease runs from this to [_fill].
  /// Null until the first build, which shows the session as it is.
  MuscleFill? _shown;

  late final AnimationController _ease = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) _shown = _fill;
    });

  @override
  void dispose() {
    _ease.dispose();
    super.dispose();
  }

  /// Starts the ease when the fill moved on and this screen can be seen.
  void _maybeEase(BuildContext context) {
    final shown = _shown;
    if (shown == null) {
      _shown = _fill;
      return;
    }
    if (shown == _fill || _ease.isAnimating) return;
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    if (!visible) return;
    if (prefersReducedMotion(context)) {
      _shown = _fill;
      return;
    }
    _ease.forward(from: 0);
  }

  /// The colour for a segment part-way through the ease.
  Color _easedColorFor(Set<String> ids) {
    final target = _fill.colorFor(ids);
    final from = (_shown ?? _fill).colorFor(ids);
    if (from == target) return target;
    return Color.lerp(from, target, Curves.easeOut.transform(_ease.value))!;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final index = ref.watch(exerciseIndexProvider);
    if (session == null) return const SizedBox.shrink();

    _sync(session, index);
    _maybeEase(context);
    final height =
        widget.height ?? sessionDiagramHeightFor(session.exercises.length);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AnimatedBuilder(
        animation: _ease,
        builder: (context, _) {
          // At rest, the same tear-off of the same fill every build, so the
          // painter's identity check still skips the repaint.
          final settled = !_ease.isAnimating && _shown == _fill;
          final shown = _shown;
          final fill = settled
              ? _fill.colorFor
              : (_ease.isAnimating ? _easedColorFor : shown!.colorFor);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final view in BodyView.values)
                Expanded(
                  child: SizedBox(
                    height: height,
                    child: BodyDiagram(
                      view: view,
                      fill: fill,
                      planned: _planned,
                    ),
                  ),
                ),
            ],
          );
        },
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
  if (exerciseCount <= 3) return 196;
  if (exerciseCount <= 5) return 172;
  if (exerciseCount <= 7) return 148;
  return 124;
}

/// How tall the map stands on the ready view, where nothing competes with it.
const double kReadyDiagramHeight = 200;
