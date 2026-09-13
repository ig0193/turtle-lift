// GENERATED FILE -- do not edit by hand.
// Produced by generate_muscle_taxonomy.py; validated against the SVG assets.

class SubMuscleGroup {
  final String id, group, label;
  final List<({String view, String segment})> segments;
  const SubMuscleGroup(this.id, this.group, this.label, this.segments);
}

/// Parent muscle group -> ordered sub-muscle group ids.
/// Templates store PARENT ids only; rows are derived from this map.
const Map<String, List<String>> kMuscleTaxonomy = {
  'chest': ['upper', 'mid', 'lower'],
  'back': ['upper', 'lats', 'lower'],
  'shoulders': ['front-delt', 'side-delt', 'rear-delt'],
  'biceps': ['biceps'],
  'triceps': ['triceps'],
  'forearms': ['forearms'],
  'abs': ['upper', 'lower'],
  'obliques': ['obliques'],
  'quads': ['quads'],
  'hamstrings': ['hamstrings'],
  'glutes': ['glutes'],
  'calves': ['calves'],
};

const Map<String, String> kMuscleGroupLabels = {
  'chest': 'Chest',
  'back': 'Back',
  'shoulders': 'Shoulders',
  'biceps': 'Biceps',
  'triceps': 'Triceps',
  'forearms': 'Forearms',
  'abs': 'Abs',
  'obliques': 'Obliques',
  'quads': 'Quads',
  'hamstrings': 'Hamstrings',
  'glutes': 'Glutes',
  'calves': 'Calves',
};

/// Sub-muscle group -> display label and the diagram segment(s) it fills.
const Map<String, SubMuscleGroup> kSubMuscleGroups = {
  'chest/upper': SubMuscleGroup('chest/upper', 'chest', 'Upper chest', [(view: 'front', segment: 'chest/upper')]),
  'chest/mid': SubMuscleGroup('chest/mid', 'chest', 'Mid chest', [(view: 'front', segment: 'chest/mid')]),
  'chest/lower': SubMuscleGroup('chest/lower', 'chest', 'Lower chest', [(view: 'front', segment: 'chest/lower')]),
  'back/upper': SubMuscleGroup('back/upper', 'back', 'Upper back & traps', [(view: 'front', segment: 'back/upper'), (view: 'back', segment: 'back/upper')]),
  'back/lats': SubMuscleGroup('back/lats', 'back', 'Lats', [(view: 'back', segment: 'back/lats')]),
  'back/lower': SubMuscleGroup('back/lower', 'back', 'Lower back', [(view: 'back', segment: 'back/lower')]),
  'shoulders/front-delt': SubMuscleGroup('shoulders/front-delt', 'shoulders', 'Front delt', [(view: 'front', segment: 'shoulders/front-delt')]),
  'shoulders/side-delt': SubMuscleGroup('shoulders/side-delt', 'shoulders', 'Side delt', [(view: 'front', segment: 'shoulders/front-delt')]),
  'shoulders/rear-delt': SubMuscleGroup('shoulders/rear-delt', 'shoulders', 'Rear delt', [(view: 'back', segment: 'shoulders/rear-delt')]),
  'biceps/biceps': SubMuscleGroup('biceps/biceps', 'biceps', 'Biceps', [(view: 'front', segment: 'biceps/biceps')]),
  'triceps/triceps': SubMuscleGroup('triceps/triceps', 'triceps', 'Triceps', [(view: 'back', segment: 'triceps/triceps')]),
  'forearms/forearms': SubMuscleGroup('forearms/forearms', 'forearms', 'Forearms', [(view: 'front', segment: 'forearms/forearms'), (view: 'back', segment: 'forearms/forearms')]),
  'abs/upper': SubMuscleGroup('abs/upper', 'abs', 'Upper abs', [(view: 'front', segment: 'abs/upper')]),
  'abs/lower': SubMuscleGroup('abs/lower', 'abs', 'Lower abs', [(view: 'front', segment: 'abs/lower')]),
  'obliques/obliques': SubMuscleGroup('obliques/obliques', 'obliques', 'Obliques', [(view: 'front', segment: 'obliques/obliques')]),
  'quads/quads': SubMuscleGroup('quads/quads', 'quads', 'Quads', [(view: 'front', segment: 'quads/quads')]),
  'hamstrings/hamstrings': SubMuscleGroup('hamstrings/hamstrings', 'hamstrings', 'Hamstrings', [(view: 'back', segment: 'hamstrings/hamstrings')]),
  'glutes/glutes': SubMuscleGroup('glutes/glutes', 'glutes', 'Glutes', [(view: 'back', segment: 'glutes/glutes')]),
  'calves/calves': SubMuscleGroup('calves/calves', 'calves', 'Calves', [(view: 'front', segment: 'calves/calves'), (view: 'back', segment: 'calves/calves')]),
};
