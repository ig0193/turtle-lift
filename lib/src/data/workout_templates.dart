/// The shipped workout templates.
///
/// **Hand-authored, not generated.** `CLAUDE.md`'s generated-data table covers
/// the body diagrams, the muscle taxonomy and the exercise library — templates
/// are not in it, there is no generator for them, and `tool/sync_generated.sh`
/// would not guard them. So this file is edited directly, and
/// `test/workout_templates_test.dart` is what stops it drifting from the
/// exercise library it points into.
///
/// **A template is a list of exercises** (`docs/adr/0006-workout-tab-is-exercise-first.md`).
/// Starting one copies that list into the session; nothing a session does writes
/// back here.
library;

import 'exercise_index.dart';
import 'generated/muscle_taxonomy.dart';

/// One workout template: an ordered shortlist of exercises to start a session
/// with.
///
/// **Exercise ids only.** Names, equipment and muscles are read from the
/// exercise library at render time, so a correction to the library reaches every
/// template with no migration. The muscle line a row shows is derived by
/// [templateSubtitle], never stored.
///
/// **A starting point, not a contract.** The list can be added to, reordered and
/// shortened once the session is running; the template itself is untouched.
class WorkoutTemplate {
  const WorkoutTemplate({
    required this.id,
    required this.name,
    required this.exerciseIds,
    this.isPredefined = true,
    this.subtitleOverride,
  });

  /// Stable across renames of [name]; this is what a session references.
  final String id;

  final String name;

  /// Library exercise ids, in the order the session lists them.
  final List<String> exerciseIds;

  /// False only for templates the user authored. Predefined ones are immutable
  /// — a user duplicates one to get an editable copy (`docs/00-build-spec.md`
  /// §11).
  final bool isPredefined;

  /// Replaces the derived subtitle for the one template the join does not suit.
  ///
  /// Full body day spans a dozen muscle groups, so joining their labels would
  /// render a line roughly four times longer than any other row on the screen.
  final String? subtitleOverride;
}

/// The parent muscle groups [template]'s exercises train directly, in taxonomy
/// order.
///
/// **Primary muscles only**, matching what the rest of the app means by "trained
/// directly". An exercise id the library no longer has contributes nothing
/// rather than failing the screen.
List<String> templateGroupIds(WorkoutTemplate template, ExerciseIndex index) {
  final wanted = <String>{};
  for (final id in template.exerciseIds) {
    final exercise = index.byId(id);
    if (exercise == null) continue;
    for (final subGroupId in exercise.primary) {
      final parent = kSubMuscleGroups[subGroupId]?.group;
      if (parent != null) wanted.add(parent);
    }
  }
  return <String>[
    for (final id in kMuscleTaxonomy.keys)
      if (wanted.contains(id)) id,
  ];
}

/// The second line of a template's row: the muscles its exercises train.
///
/// Derived on read, like every other display value in the app — the labels live
/// in generated data that this file must not copy. An empty template has no
/// muscles to name, so it says what it is instead of rendering a blank line.
String templateSubtitle(WorkoutTemplate template, ExerciseIndex index) {
  if (template.subtitleOverride != null) return template.subtitleOverride!;
  final summary = muscleGroupSummary(templateGroupIds(template, index));
  return summary.isEmpty ? 'No exercises yet' : summary;
}

/// Parent group ids rendered as one line: the first label as the taxonomy
/// spells it, the rest lower-cased.
///
/// Sentence case rather than a raw join, because every value in
/// [kMuscleGroupLabels] is capitalised and "Chest, Triceps" reads as two
/// proper nouns.
///
/// Ordering comes from [kMuscleTaxonomy], not from the order the ids were
/// handed over, so two templates naming the same groups always render the same
/// string.
String muscleGroupSummary(List<String> groupIds) {
  if (groupIds.isEmpty) return '';
  final wanted = groupIds.toSet();
  final ordered = <String>[
    for (final id in kMuscleTaxonomy.keys)
      if (wanted.contains(id)) kMuscleGroupLabels[id]!,
  ];
  if (ordered.isEmpty) return '';
  return <String>[
    ordered.first,
    ...ordered.skip(1).map((label) => label.toLowerCase()),
  ].join(', ');
}

/// The eleven templates that ship with the app.
///
/// **The order here is the order the landing renders them in**: the three
/// push/pull/legs days, then the single-focus days, then the combined ones.
/// Each list leads with its heaviest compound lift and is a shortlist of what
/// people commonly do on that day, not a prescription.
///
/// A row's muscle line is derived from these lists, so choosing an exercise that
/// trains a neighbouring group as a *primary* (face pull, hammer curl) changes
/// what the template says it covers. `test/workout_templates_test.dart` pins
/// each template's derived line so that cannot happen by accident.
const List<WorkoutTemplate> kPredefinedTemplates = <WorkoutTemplate>[
  WorkoutTemplate(
    id: 'push',
    name: 'Push day',
    exerciseIds: <String>[
      'barbell-bench-press',
      'incline-dumbbell-press',
      'barbell-overhead-press',
      'dumbbell-lateral-raise',
      'cable-rope-pushdown',
      'overhead-cable-triceps-extension',
    ],
  ),
  WorkoutTemplate(
    id: 'pull',
    name: 'Pull day',
    exerciseIds: <String>[
      'lat-pulldown',
      'barbell-bent-over-row',
      'seated-cable-row',
      'single-arm-dumbbell-row',
      'barbell-curl',
      'incline-dumbbell-curl',
    ],
  ),
  WorkoutTemplate(
    id: 'leg',
    name: 'Leg day',
    exerciseIds: <String>[
      'barbell-back-squat',
      'barbell-romanian-deadlift',
      'leg-press',
      'seated-leg-curl',
      'walking-lunge',
      'standing-calf-raise-machine',
    ],
  ),
  WorkoutTemplate(
    id: 'chest',
    name: 'Chest day',
    exerciseIds: <String>[
      'barbell-bench-press',
      'incline-dumbbell-press',
      'chest-dip',
      'pec-deck-machine',
      'low-to-high-cable-crossover',
    ],
  ),
  WorkoutTemplate(
    id: 'back',
    name: 'Back day',
    exerciseIds: <String>[
      'pull-up',
      'barbell-bent-over-row',
      'lat-pulldown',
      'seated-cable-row',
      'single-arm-dumbbell-row',
    ],
  ),
  WorkoutTemplate(
    id: 'shoulders',
    name: 'Shoulders day',
    exerciseIds: <String>[
      'barbell-overhead-press',
      'arnold-press',
      'dumbbell-lateral-raise',
      'cable-lateral-raise',
      'reverse-pec-deck',
    ],
  ),
  WorkoutTemplate(
    id: 'arms',
    name: 'Arms day',
    exerciseIds: <String>[
      'barbell-curl',
      'close-grip-bench-press',
      'incline-dumbbell-curl',
      'cable-rope-pushdown',
      'preacher-curl',
      'overhead-cable-triceps-extension',
    ],
  ),
  WorkoutTemplate(
    id: 'chest-triceps',
    name: 'Chest and triceps day',
    exerciseIds: <String>[
      'barbell-bench-press',
      'incline-dumbbell-press',
      'chest-dip',
      'pec-deck-machine',
      'cable-rope-pushdown',
      'ez-bar-skull-crusher',
    ],
  ),
  WorkoutTemplate(
    id: 'back-biceps',
    name: 'Back and biceps day',
    exerciseIds: <String>[
      'pull-up',
      'barbell-bent-over-row',
      'lat-pulldown',
      'seated-cable-row',
      'barbell-curl',
      'incline-dumbbell-curl',
    ],
  ),
  WorkoutTemplate(
    id: 'upper-body',
    name: 'Upper body day',
    exerciseIds: <String>[
      'barbell-bench-press',
      'barbell-bent-over-row',
      'barbell-overhead-press',
      'lat-pulldown',
      'dumbbell-lateral-raise',
      'barbell-curl',
      'cable-rope-pushdown',
    ],
  ),
  WorkoutTemplate(
    id: 'full-body',
    name: 'Full body day',
    exerciseIds: <String>[
      'barbell-back-squat',
      'barbell-bench-press',
      'barbell-bent-over-row',
      'barbell-overhead-press',
      'barbell-romanian-deadlift',
      'standing-calf-raise-machine',
      'plank',
    ],
    subtitleOverride: 'A mix across all major groups',
  ),
];
