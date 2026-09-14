/// The shipped workout templates, and the split filter the Workout landing
/// groups them by.
///
/// **Hand-authored, not generated.** `CLAUDE.md`'s generated-data table covers
/// the body diagrams, the muscle taxonomy and the exercise library — templates
/// are not in it, there is no generator for them, and `tool/sync_generated.sh`
/// would not guard them. So this file is edited directly, and
/// `test/workout_templates_test.dart` is what stops it drifting from the set
/// `docs/01-app-idea.md` describes.
library;

import 'generated/muscle_taxonomy.dart';

/// How the Workout landing groups the predefined templates.
///
/// **A filter over single-day templates, not a training programme.** The app
/// has no multi-day split system, no rotation and no "today's workout"
/// (`docs/01-app-idea.md`), and this enum must not become the seed of one: it
/// says which templates are *shown*, never which one to do. Nothing stores
/// "the user's split", nothing advances it, and nothing here knows what day it
/// is.
///
/// **There is no unfiltered value.** Every arrival lands in a named split, so
/// each of the three must always have at least one template behind it — the
/// membership test in `test/workout_templates_test.dart` is what keeps that
/// true, because an empty filter is a dead end with no "All" to escape to.
enum TemplateFilter {
  /// One muscle group per session. Arms day counts as one: that is the user's
  /// reading, not the taxonomy's, and it is why this is not called
  /// "single parent group".
  singleMuscle('single', '1 Muscle per day'),

  /// Two or more groups in a session, including the whole-body days.
  multiSplit('multi', 'Multi Split'),

  /// The push / pull / legs trio.
  pushPullLegs('ppl', 'Push-Pull-Legs');

  const TemplateFilter(this.key, this.label);

  /// What gets persisted. **Never store [label]** — it is display copy, and a
  /// wording change would strand every value already written to disk.
  final String key;

  /// What the filter control shows.
  final String label;

  /// The filter for a stored [key], or null when the key is absent or is one
  /// this build does not recognise.
  ///
  /// Returning null rather than throwing is deliberate: an unreadable stored
  /// value is a user who downgraded or hand-edited the database, and the right
  /// answer is the ordinary default, not a crash on the app's first screen.
  static TemplateFilter? fromKey(String? key) {
    if (key == null) return null;
    for (final filter in values) {
      if (filter.key == key) return filter;
    }
    return null;
  }
}

/// One workout template: a curated shortlist of muscle groups to browse within.
///
/// **A template stores parent muscle groups only** (`docs/00-build-spec.md`
/// §2). Sub-groups are derived from [kMuscleTaxonomy] at render time, so a
/// sub-group added to the taxonomy later is picked up by every existing
/// template with no migration.
///
/// **It is a menu, not a checklist.** Nothing in a template is ever "finished"
/// and no group carries a completion state, which is why a seven-group day is
/// unremarkable rather than daunting.
class WorkoutTemplate {
  const WorkoutTemplate({
    required this.id,
    required this.name,
    required this.groupIds,
    required this.filters,
    this.isPredefined = true,
    this.subtitleOverride,
  });

  /// Stable across renames of [name]; this is what a session will reference.
  final String id;

  final String name;

  /// Parent muscle group ids, in taxonomy order. Never sub-group ids.
  final List<String> groupIds;

  /// Which filters show this template.
  ///
  /// **A set, not a single value.** Leg day genuinely belongs to both
  /// [TemplateFilter.singleMuscle] and [TemplateFilter.pushPullLegs], so the
  /// eleven templates carry twelve memberships between them. A single field
  /// here would force a duplicate row or an arbitrary choice.
  final Set<TemplateFilter> filters;

  /// False only for templates the user authored. Predefined ones are immutable
  /// — a user duplicates one to get an editable copy (`docs/00-build-spec.md`
  /// §11).
  final bool isPredefined;

  /// Replaces the derived subtitle for the one template the join does not suit.
  ///
  /// Full body day spans all twelve groups, so joining its labels would render
  /// a line roughly four times longer than any other row on the screen.
  /// `prototypes/workout-l0-filtered-templates.html` already made that call,
  /// and the prototype governs this screen's layout.
  final String? subtitleOverride;

  /// The second line of the template's row.
  ///
  /// Derived on read rather than stored, like every other display value in the
  /// app — the labels live in generated data that this file must not copy.
  String get subtitle => subtitleOverride ?? muscleGroupSummary(groupIds);
}

/// Parent group ids rendered as one line: the first label as the taxonomy
/// spells it, the rest lower-cased.
///
/// Sentence case rather than a raw join, because every value in
/// [kMuscleGroupLabels] is capitalised and "Chest, Triceps" reads as two
/// proper nouns. The prototype's rows are sentence-cased for the same reason.
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

/// The templates [filter] shows, in the order they are authored below.
List<WorkoutTemplate> templatesFor(TemplateFilter filter) => <WorkoutTemplate>[
      for (final template in kPredefinedTemplates)
        if (template.filters.contains(filter)) template,
    ];

/// The eleven templates that ship with the app.
///
/// Nine come from `docs/01-app-idea.md`; Chest day and Back day were added so
/// [TemplateFilter.singleMuscle] covers the two big pushing and pulling groups
/// rather than jumping from shoulders to arms.
///
/// **The order here is the order every filter renders in.** It is arranged so
/// that filtering this one list yields each filter's curated sequence — the
/// single-muscle days first, then the trio, then the multi-group days — rather
/// than needing a per-filter ordering.
const List<WorkoutTemplate> kPredefinedTemplates = <WorkoutTemplate>[
  WorkoutTemplate(
    id: 'chest',
    name: 'Chest day',
    groupIds: <String>['chest'],
    filters: <TemplateFilter>{TemplateFilter.singleMuscle},
  ),
  WorkoutTemplate(
    id: 'back',
    name: 'Back day',
    groupIds: <String>['back'],
    filters: <TemplateFilter>{TemplateFilter.singleMuscle},
  ),
  WorkoutTemplate(
    id: 'shoulders',
    name: 'Shoulders day',
    groupIds: <String>['shoulders'],
    filters: <TemplateFilter>{TemplateFilter.singleMuscle},
  ),
  WorkoutTemplate(
    id: 'arms',
    name: 'Arms day',
    // "Arms" is not a parent group. The taxonomy splits it, and a template
    // stores what the taxonomy has.
    groupIds: <String>['biceps', 'triceps'],
    filters: <TemplateFilter>{TemplateFilter.singleMuscle},
  ),
  WorkoutTemplate(
    id: 'push',
    name: 'Push day',
    groupIds: <String>['chest', 'shoulders', 'triceps'],
    filters: <TemplateFilter>{TemplateFilter.pushPullLegs},
  ),
  WorkoutTemplate(
    id: 'pull',
    name: 'Pull day',
    groupIds: <String>['back', 'biceps'],
    filters: <TemplateFilter>{TemplateFilter.pushPullLegs},
  ),
  WorkoutTemplate(
    id: 'leg',
    name: 'Leg day',
    groupIds: <String>['quads', 'hamstrings', 'glutes', 'calves'],
    // The one template in two filters: it is both the legs of push/pull/legs
    // and a single-focus day in its own right.
    filters: <TemplateFilter>{
      TemplateFilter.singleMuscle,
      TemplateFilter.pushPullLegs,
    },
  ),
  WorkoutTemplate(
    id: 'upper-body',
    name: 'Upper body day',
    groupIds: <String>['chest', 'back', 'shoulders', 'biceps', 'triceps'],
    filters: <TemplateFilter>{TemplateFilter.multiSplit},
  ),
  WorkoutTemplate(
    id: 'full-body',
    name: 'Full body day',
    groupIds: <String>[
      'chest',
      'back',
      'shoulders',
      'biceps',
      'triceps',
      'forearms',
      'abs',
      'obliques',
      'quads',
      'hamstrings',
      'glutes',
      'calves',
    ],
    filters: <TemplateFilter>{TemplateFilter.multiSplit},
    subtitleOverride: 'A mix across all major groups',
  ),
  WorkoutTemplate(
    id: 'chest-triceps',
    name: 'Chest and triceps day',
    groupIds: <String>['chest', 'triceps'],
    filters: <TemplateFilter>{TemplateFilter.multiSplit},
  ),
  WorkoutTemplate(
    id: 'back-biceps',
    name: 'Back and biceps day',
    groupIds: <String>['back', 'biceps'],
    filters: <TemplateFilter>{TemplateFilter.multiSplit},
  ),
];
