import 'dart:convert';

import 'body_gender.dart';
import 'exercise_index.dart';
import 'personal_details_store.dart';
import 'session_store.dart';
import 'training_plan.dart';
import 'workout_templates.dart';

/// The version of the export file's shape. Bump it when a field is renamed or
/// removed, so a future import can tell old files from new ones.
const int kExportFormatVersion = 1;

/// Everything the user has entered, as one JSON document.
///
/// **Only what was entered, never what is derived.** Streaks, personal bests,
/// set counts and calorie estimates are computed on read everywhere else in
/// the app (`01` §Derived values), so writing them here would freeze numbers
/// that change the moment a session is edited. A reader recomputes them.
///
/// Exercise names travel next to their ids, so the file is readable without
/// the app's library; the ids are what an import would match on.
String buildExportJson({
  required List<WorkoutSession> sessions,
  required List<BodyweightEntry> bodyweight,
  required List<WorkoutTemplate> customTemplates,
  required List<TrainingPlanEntry> trainingPlan,
  required BodyGender gender,
  required ExerciseIndex index,
  required DateTime exportedAt,
}) {
  final document = <String, Object?>{
    'app': 'TurtleLift',
    'formatVersion': kExportFormatVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'bodyDiagram': gender.name,
    'workouts': <Object?>[
      for (final session in sessions)
        if (!session.isOpen)
          <String, Object?>{
            'id': session.id,
            if (session.title != null) 'title': session.title,
            'performedOn': session.performedOn.encode(),
            'loggedAt': session.loggedAt.toUtc().toIso8601String(),
            if (session.templateName != null)
              'template': session.templateName,
            'exercises': <Object?>[
              for (final exercise in session.exercises)
                <String, Object?>{
                  'exerciseId': exercise.exerciseId,
                  'name': index.byId(exercise.exerciseId)?.name,
                  if (exercise.loadType != null)
                    'loadType': exercise.loadType!.name,
                  'sets': <Object?>[
                    for (final set in exercise.completedSets)
                      <String, Object?>{
                        if (set.weightKg != null) 'weightKg': set.weightKg,
                        if (set.reps != null) 'reps': set.reps,
                        if (set.addedKg != null) 'addedKg': set.addedKg,
                        if (set.assistKg != null) 'assistKg': set.assistKg,
                        if (set.durationSec != null)
                          'durationSec': set.durationSec,
                      },
                  ],
                },
            ],
          },
    ],
    'bodyweight': <Object?>[
      for (final entry in bodyweight)
        <String, Object?>{
          'date': encodeCalendarDateOf(entry.date),
          'weightKg': entry.weightKg,
        },
    ],
    'templates': <Object?>[
      for (final template in customTemplates)
        <String, Object?>{
          'name': template.name,
          'exerciseIds': template.exerciseIds,
        },
    ],
    'schedule': <Object?>[
      for (final entry in trainingPlan)
        <String, Object?>{
          'effectiveFrom': entry.effectiveFrom.encode(),
          'weekdays': (entry.weekdays.toList()..sort()),
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(document);
}

/// `2026-11-07` for a bodyweight entry's date, which is stored as a
/// `DateTime` at local midnight rather than as a `LocalDate`.
String encodeCalendarDateOf(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// The export's file name, dated so a second export never overwrites the
/// first in the user's Files app.
String exportFileName(DateTime now) =>
    'turtlelift-export-${encodeCalendarDateOf(now)}.json';
