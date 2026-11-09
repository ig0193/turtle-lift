/// The words people use for a muscle, mapped to the sub-group ids they mean.
///
/// **Hand-written, not generated, and not part of the taxonomy.** The taxonomy
/// (`generated/muscle_taxonomy.dart`) is the app's own vocabulary: 12 parent
/// groups, 19 sub-groups and the diagram segments they fill. This table is the
/// user's vocabulary pointing into it, so search can answer "shoulders",
/// "pecs" or "legs" — none of which is a sub-group label (audit B1).
///
/// **Keys are already `searchFold`ed** (lower case, no punctuation) and are
/// matched against the whole folded query, so a two-letter key such as "bi"
/// fires only when that is all the user typed. `test/muscle_search_vocabulary_test.dart`
/// proves every key is folded and every target id exists.
///
/// Reviewed for anatomical accuracy against the taxonomy (2026-11-09):
/// * "legs" is the four lower-limb groups in the taxonomy: quads, hamstrings,
///   glutes and calves. Glutes are hip extensors, so "hip" points at glutes.
/// * "arms" is biceps, triceps and forearms. The deltoids are shoulder
///   muscles, not arm muscles, so they are left out.
/// * "core" is abs and obliques. The lower back stabilises the trunk too, but
///   it has its own group under Back and common usage of "core" means the
///   front of the trunk.
/// * "traps" points at "Upper back & traps"; the taxonomy does not split the
///   trapezius out.
/// * "thighs" is quads and hamstrings (front and back of the thigh).
/// * "side delt" has the anatomical synonyms "lateral" and "medial" delt;
///   "front delt" has "anterior"; "rear delt" has "posterior".
const Map<String, List<String>> kMuscleSynonyms = <String, List<String>>{
  // Shoulders.
  'shoulder': _delts,
  'shoulders': _delts,
  'delt': _delts,
  'delts': _delts,
  'deltoid': _delts,
  'deltoids': _delts,
  'front delts': <String>['shoulders/front-delt'],
  'anterior delt': <String>['shoulders/front-delt'],
  'anterior delts': <String>['shoulders/front-delt'],
  'front shoulder': <String>['shoulders/front-delt'],
  'side delts': <String>['shoulders/side-delt'],
  'lateral delt': <String>['shoulders/side-delt'],
  'lateral delts': <String>['shoulders/side-delt'],
  'medial delt': <String>['shoulders/side-delt'],
  'medial delts': <String>['shoulders/side-delt'],
  'rear delts': <String>['shoulders/rear-delt'],
  'posterior delt': <String>['shoulders/rear-delt'],
  'posterior delts': <String>['shoulders/rear-delt'],

  // Chest.
  'chest': _chest,
  'pec': _chest,
  'pecs': _chest,
  'pectoral': _chest,
  'pectorals': _chest,

  // Back.
  'back': _back,
  'trap': <String>['back/upper'],
  'traps': <String>['back/upper'],
  'trapezius': <String>['back/upper'],
  'rhomboids': <String>['back/upper'],
  'lat': <String>['back/lats'],
  'lats': <String>['back/lats'],
  'latissimus': <String>['back/lats'],
  'erector': <String>['back/lower'],
  'erectors': <String>['back/lower'],
  'spinal erectors': <String>['back/lower'],

  // Arms.
  'arm': _arms,
  'arms': _arms,
  'bi': <String>['biceps/biceps'],
  'bis': <String>['biceps/biceps'],
  'bicep': <String>['biceps/biceps'],
  'tri': <String>['triceps/triceps'],
  'tris': <String>['triceps/triceps'],
  'tricep': <String>['triceps/triceps'],
  'forearm': <String>['forearms/forearms'],
  'grip': <String>['forearms/forearms'],

  // Core.
  'core': _core,
  'ab': _abs,
  'abs': _abs,
  'abdominal': _abs,
  'abdominals': _abs,
  'stomach': _abs,
  'oblique': <String>['obliques/obliques'],

  // Legs.
  'leg': _legs,
  'legs': _legs,
  'thigh': _thighs,
  'thighs': _thighs,
  'quad': <String>['quads/quads'],
  'quadriceps': <String>['quads/quads'],
  'ham': <String>['hamstrings/hamstrings'],
  'hams': <String>['hamstrings/hamstrings'],
  'hamstring': <String>['hamstrings/hamstrings'],
  'glute': <String>['glutes/glutes'],
  'gluteus': <String>['glutes/glutes'],
  'butt': <String>['glutes/glutes'],
  'hip': <String>['glutes/glutes'],
  'hips': <String>['glutes/glutes'],
  'calf': <String>['calves/calves'],
};

const List<String> _delts = <String>[
  'shoulders/front-delt',
  'shoulders/side-delt',
  'shoulders/rear-delt',
];
const List<String> _chest = <String>['chest/upper', 'chest/mid', 'chest/lower'];
const List<String> _back = <String>['back/upper', 'back/lats', 'back/lower'];
const List<String> _arms = <String>[
  'biceps/biceps',
  'triceps/triceps',
  'forearms/forearms',
];
const List<String> _abs = <String>['abs/upper', 'abs/lower'];
const List<String> _core = <String>['abs/upper', 'abs/lower', 'obliques/obliques'];
const List<String> _legs = <String>[
  'quads/quads',
  'hamstrings/hamstrings',
  'glutes/glutes',
  'calves/calves',
];
const List<String> _thighs = <String>['quads/quads', 'hamstrings/hamstrings'];
