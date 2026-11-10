import 'dart:convert';

import 'body_gender.dart';
import 'diet_plan_store.dart';
import 'exercise.dart';
import 'exercise_index.dart';
import 'food_index.dart';
import 'meal_ticks.dart';
import 'meal_slot.dart';
import 'personal_details_store.dart';
import 'reminder_prefs.dart';
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
///
/// **Diet** (KTD19, R25) is the top-level `diet` key: the target or null,
/// every plan version (`effectiveFrom` and its items, servings as a decimal),
/// and the eaten ticks as `date` + `slot`. Food names travel beside their ids
/// the same way; an id the food list no longer knows exports its id with a
/// null `name`, exactly as an unknown exercise does, rather than the "Unknown
/// food" display string, which is UI copy and not data. No total, eaten sum,
/// to-go figure or suggestion is written. Adding a key is not a rename, so
/// [kExportFormatVersion] stays 1.
String buildExportJson({
  required List<WorkoutSession> sessions,
  required List<BodyweightEntry> bodyweight,
  required List<WorkoutTemplate> customTemplates,
  required List<TrainingPlanEntry> trainingPlan,
  required BodyGender gender,
  required ExerciseIndex index,
  required List<DietPlanVersion> dietPlan,
  required Iterable<MealTick> mealTicks,
  required int? proteinTargetG,
  required FoodIndex foods,
  required DateTime exportedAt,
  List<Exercise> customExercises = const <Exercise>[],
  ReminderPreferences? reminders,
}) {
  final ticks = mealTicks.toList()
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.slot.index.compareTo(b.slot.index);
    });
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
                  if (exercise.note != null) 'note': exercise.note,
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
    // The user's own exercises (ADR 0009): what they typed, nothing more.
    // There is no content to export because a custom exercise has none.
    'exercises': <Object?>[
      for (final exercise in customExercises)
        <String, Object?>{
          'id': exercise.id,
          'name': exercise.name,
          'equipment': exercise.equipment,
          'loadType': exercise.loadType,
          'primary': exercise.primary,
          'secondary': exercise.secondary,
          if (exercise.hidden) 'hiddenFromPicker': true,
        },
    ],
    'schedule': <Object?>[
      for (final entry in trainingPlan)
        <String, Object?>{
          'effectiveFrom': entry.effectiveFrom.encode(),
          'weekdays': (entry.weekdays.toList()..sort()),
        },
    ],
    // The reminder switches and times the user set (profile audit B10,
    // ADR 0014): entered data, so it is in "everything".
    if (reminders != null) 'reminders': _remindersJson(reminders),
    'diet': <String, Object?>{
      'proteinTargetG': proteinTargetG,
      'planVersions': <Object?>[
        for (final version in dietPlan)
          <String, Object?>{
            'effectiveFrom': version.effectiveFrom.encode(),
            'items': <Object?>[
              for (final item in version.items)
                <String, Object?>{
                  'weekday': item.weekday,
                  'slot': item.slot.name,
                  'foodId': item.foodId,
                  'name': foods.byId(item.foodId)?.name,
                  'servings': item.servingsHalves / 2,
                },
            ],
          },
      ],
      'eaten': <Object?>[
        for (final tick in ticks)
          <String, Object?>{'date': tick.date.encode(), 'slot': tick.slot.name},
      ],
    },
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

String _clock(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';

Map<String, Object?> _remindersJson(ReminderPreferences p) => <String, Object?>{
      'training': <String, Object?>{
        'on': p.scheduleOn,
        'time': _clock(p.scheduleMinute),
      },
      'diet': <String, Object?>{
        'on': p.dietOn,
        'morningSummary': <String, Object?>{
          'on': p.summaryOn,
          'time': _clock(p.summaryMinute),
        },
        for (final slot in MealSlot.values)
          slot.name: <String, Object?>{
            'on': p.slot(slot).on,
            'time': _clock(p.slot(slot).minute),
          },
      },
    };

/// Every completed set of every finished workout as CSV, one row per set,
/// for a spreadsheet (ADR 0014 §6). **Entered data only**: the title and
/// template as stored (never the resolved title, which is derived), and the
/// unit in each weight column's name so nobody has to guess kg or lb.
String buildSetsCsv({
  required List<WorkoutSession> sessions,
  required ExerciseIndex index,
}) {
  final out = StringBuffer(
    'date,title,template,exercise,exercise_id,load_type,set,weight_kg,'
    'reps,added_kg,assist_kg,duration_sec,note\n',
  );
  String cell(Object? value) {
    if (value == null) return '';
    final text = value is double
        ? (value == value.roundToDouble()
            ? value.toStringAsFixed(0)
            : value.toString())
        : value.toString();
    if (text.contains(RegExp(r'[",\n\r]'))) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  final ordered = sessions.where((s) => !s.isOpen).toList()
    ..sort((a, b) {
      final byDate = a.performedOn.compareTo(b.performedOn);
      return byDate != 0 ? byDate : a.loggedAt.compareTo(b.loggedAt);
    });
  for (final session in ordered) {
    for (final exercise in session.exercises) {
      var n = 0;
      for (final set in exercise.completedSets) {
        n++;
        out.writeln(<Object?>[
          session.performedOn.encode(),
          session.title,
          session.templateName,
          index.byId(exercise.exerciseId)?.name ?? exercise.exerciseId,
          exercise.exerciseId,
          exercise.loadType?.name,
          n,
          set.weightKg,
          set.reps,
          set.addedKg,
          set.assistKg,
          set.durationSec,
          exercise.note,
        ].map(cell).join(','));
      }
    }
  }
  return out.toString();
}

/// `turtlelift-sets-2026-11-03.csv`, beside the JSON of the same day.
String setsCsvFileName(DateTime now) =>
    'turtlelift-sets-${encodeCalendarDateOf(now)}.csv';
