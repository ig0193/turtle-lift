import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise.dart';
import '../data/load_type.dart';
import '../data/session_progress.dart';
import 'exercise_detail_screen.dart';
import 'exercise_picker_sheet.dart';
import 'set_logging_screen.dart';

/// Opens [exercise] for logging in the open workout, starting an ad-hoc one when
/// none is open.
///
/// **The one way into the logging screen from a list.** The picker, the Workout
/// landing's search, and a row on the session screen all end here, so the rules
/// below cannot differ between them:
///
/// * The workout is created by the first exercise chosen, not by the tap that
///   asked to start one from search — so backing out of the exercise's page
///   leaves nothing half-made.
/// * **An exercise the user has never completed lands on its page first**, with
///   a Start logging action. They cannot know a lift they have never done, and
///   `docs/02` makes this the one detour in the flow. It applies to a row that
///   is already on the session's list too: on a fresh install every exercise in
///   a template is new, and the page is where the reviewed form cues live.
///   Nothing already written to the row is ever sent back through it.
/// * One already in the workout opens rather than duplicating, which would split
///   its sets across two prefill chains.
///
/// It also records that logging has started, which is what takes the session
/// screen from its ready view to the list.
Future<void> openExerciseForLogging(
  BuildContext context,
  WidgetRef ref,
  Exercise exercise,
) async {
  final loadType = LoadType.fromName(exercise.loadType);
  if (loadType == null) return;

  final notifier = ref.read(activeSessionProvider.notifier);
  var session = ref.read(activeSessionProvider);
  if (session == null) {
    await notifier.startAdHoc();
    session = ref.read(activeSessionProvider);
    if (session == null) return;
  }
  ref.read(loggingStartedProvider.notifier).start(session.id);

  final existing =
      session.exercises.where((e) => e.exerciseId == exercise.id).firstOrNull;
  final hasWrittenSets = existing != null && existing.sets.isNotEmpty;
  final neverDone =
      timesPerformed(exercise.id, ref.read(savedSessionsProvider)) == 0;

  if (neverDone && !hasWrittenSets) {
    if (!context.mounted) return;
    await pushExerciseDetail(context, exercise,
        entry: ExerciseDetailEntry.workoutStart);
    return;
  }

  final rowId = await notifier.addExercise(
    exerciseId: exercise.id,
    loadType: loadType,
  );
  if (rowId == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SetLoggingScreen(sessionExerciseId: rowId),
    ),
  );
}

/// Asks which exercise to log, then opens it.
///
/// A sheet over the session screen rather than a pushed page: the map stays
/// behind it, so choosing an exercise reads as something done *in* the workout
/// and not as leaving it.
Future<void> pickAndOpenExercise(
  BuildContext context,
  WidgetRef ref, {
  required String title,
}) async {
  final chosen = await showExercisePicker(context, title: title);
  if (chosen == null || !context.mounted) return;
  await openExerciseForLogging(context, ref, chosen);
}
