import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/body_gender.dart';
import '../data/exercise.dart';
import '../data/active_session.dart';
import '../data/exercise_index.dart';
import '../data/load_type.dart';
import '../data/session_store.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'set_logging_screen.dart';
import 'body_diagram.dart';
import 'disclosure_row.dart';
import 'muscle_exercise_list_screen.dart';

/// One exercise, as reference: what it needs, what it trains, how to do it,
/// and what else would do instead.
///
/// **The page carries no history section, and that is a requirement rather
/// than an omission** (R15). The prototype's detail screen opens with three
/// stat tiles, a "Recent" list and a personal-best badge; there is no session
/// table in this slice, so every one of those numbers would be invented. Nor
/// is there a line standing in for them — not even "You haven't logged this
/// yet", which the prototype does render. That sentence is still a claim about
/// the reader, and it is the one claim a reference page has no business
/// making: a user with zero sessions must see exactly what a user with three
/// hundred sees.
///
/// **The way into a workout depends on how you got here** ([ExerciseDetailEntry]).
/// Browsed from the Muscles tab it is a reference page and adds nothing, except
/// during an ad-hoc session, where it offers to add the exercise. Reached as the
/// first-time gate inside the workout flow it offers to start logging. Reached
/// from the logging screen's info button it offers neither, because the user is
/// already there.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({
    required this.exercise,
    this.entry = ExerciseDetailEntry.reference,
    super.key,
  });

  /// The exercise, passed whole rather than by id: every caller already holds
  /// one — the muscle list, the rail, and later the search results — and a
  /// second lookup would only add a way for the id to miss.
  final Exercise exercise;

  /// How the user arrived, which decides which action the page offers.
  final ExerciseDetailEntry entry;

  /// The key a test taps to start logging this exercise.
  static const Key startLoggingKey = ValueKey<String>('start-logging');

  /// The key a test taps to add this exercise to an ad-hoc session.
  static const Key addToWorkoutKey = ValueKey<String>('add-to-workout');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(exerciseIndexProvider);
    final session = ref.watch(activeSessionProvider);
    final substitutes = substitutesFor(index, exercise);
    // Bound once so the "which row opens" rule below can be asked positionally
    // rather than by re-typing a field name the compiler would not check.
    final fields = exerciseContentFields(exercise);
    final leadField = fields.first;

    return AppScreen.pushed(
      title: exercise.name,
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              exerciseFactsLabel(exercise),
              style: kLandingSectionLabelStyle,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(kExerciseMusclesLabel, style: kLandingSectionLabelStyle),
          ),
          const SizedBox(height: 9),
          _MuscleChips(exercise: exercise),
          const SizedBox(height: 6),
          _ExerciseDiagrams(exercise: exercise),
          ..._action(context, ref, session),
          const SizedBox(height: 20),
          for (final field in fields)
            DisclosureRow(
              key: exerciseContentRowKey(field.field),
              label: field.label,
              body: field.text,
              // Exactly one row opens, and it is the injury-relevant one
              // (R17). Asked as "the first one", which is what
              // [exerciseContentFields] guarantees and documents — a repeated
              // `field == 'commonMistakes'` literal would let a typo close the
              // one row this page makes a safety decision about, silently.
              initiallyExpanded: field == leadField,
              emphasised: field == leadField,
            ),
          if (substitutes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 22),
            Semantics(
              header: true,
              child: Text(
                substituteRailLabel(exercise),
                style: kLandingSectionLabelStyle,
              ),
            ),
            const SizedBox(height: 9),
            _SubstituteRail(substitutes: substitutes),
          ],
        ],
      ),
    );
  }

  /// The one contextual action, or nothing.
  ///
  /// Sits below the diagrams and above the reviewed copy: it is the reason this
  /// user is here on the workout routes, and burying it under four collapsible
  /// blocks would make the first-time gate feel like a dead end.
  List<Widget> _action(
    BuildContext context,
    WidgetRef ref,
    WorkoutSession? session,
  ) {
    switch (entry) {
      case ExerciseDetailEntry.fromLogging:
        // Already logging it. A second way in from here is a loop.
        return const <Widget>[];

      case ExerciseDetailEntry.workoutStart:
        return <Widget>[
          const SizedBox(height: 16),
          _DetailAction(
            actionKey: startLoggingKey,
            label: 'Start logging',
            onTap: () => startLoggingFromDetail(context, ref, exercise),
          ),
        ];

      case ExerciseDetailEntry.reference:
        // Offered only during an ad-hoc session: a template session is locked
        // to its own muscle groups, and with no session there is nothing to add
        // to. `docs/03` fixes all three cases.
        if (session == null || session.isTemplateSession) {
          return const <Widget>[];
        }
        return <Widget>[
          const SizedBox(height: 16),
          _DetailAction(
            actionKey: addToWorkoutKey,
            label: 'Add to current workout',
            onTap: () async {
              final loadType = LoadType.fromName(exercise.loadType);
              if (loadType == null) return;
              await ref.read(activeSessionProvider.notifier).addExercise(
                    exerciseId: exercise.id,
                    loadType: loadType,
                  );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${exercise.name} added')),
              );
            },
          ),
        ];
    }
  }
}

/// How the user reached the exercise's page, which decides what it offers.
enum ExerciseDetailEntry {
  /// Browsed from the Muscles tab. A pure reference page, unless an ad-hoc
  /// session is open.
  reference,

  /// The first-time gate inside the workout flow: the user has never completed
  /// this exercise, so they meet its page before its logging screen.
  workoutStart,

  /// Opened from the logging screen's info button, mid-set.
  fromLogging,
}

/// Adds [exercise] to the open session if needed, then opens its logging
/// screen, replacing this page so Back does not land on the gate again.
Future<void> startLoggingFromDetail(
  BuildContext context,
  WidgetRef ref,
  Exercise exercise,
) async {
  final loadType = LoadType.fromName(exercise.loadType);
  if (loadType == null) return;
  final rowId = await ref.read(activeSessionProvider.notifier).addExercise(
        exerciseId: exercise.id,
        loadType: loadType,
      );
  if (rowId == null || !context.mounted) return;
  await Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => SetLoggingScreen(sessionExerciseId: rowId),
    ),
  );
}

/// The page's one contextual action.
class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.actionKey,
    required this.label,
    required this.onTap,
  });

  final Key actionKey;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) => FilledButton(
        key: actionKey,
        onPressed: onTap,
        child: Text(label),
      );
}

/// Pushes [exercise]'s page.
///
/// **Opaque, like every push in this app (KTD9).** It is the only kind of
/// route that covers the floating tab bar; a sheet or a transparent route
/// leaves "Workout" painted over the reviewed copy and one stray tap away.
Future<void> pushExerciseDetail(
  BuildContext context,
  Exercise exercise, {
  ExerciseDetailEntry entry = ExerciseDetailEntry.reference,
}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseDetailScreen(exercise: exercise, entry: entry),
      ),
    );

/// The line under the header: what the lift needs, and how it is loaded.
///
/// Both are the library's own lower-case keys, upper-cased here for the same
/// reason [exerciseEquipmentLabel] upper-cases equipment on a row — the
/// display spelling belongs to the screen, and `Exercise.loadType` stays the
/// value the set-logging screen will match on.
String exerciseFactsLabel(Exercise exercise) =>
    '${exercise.equipment.toUpperCase()} · ${exercise.loadType.toUpperCase()}';

/// The label over the chips and the diagram.
const String kExerciseMusclesLabel = 'MUSCLES';

/// The row for [field], so a test can open one by name rather than by
/// position.
@visibleForTesting
Key exerciseContentRowKey(String field) =>
    ValueKey<String>('exercise-content-$field');

/// The card for [exerciseId] in the rail, so a test can reach one without
/// counting along a horizontal scroller.
@visibleForTesting
Key substituteCardKey(String exerciseId) =>
    ValueKey<String>('substitute-$exerciseId');

/// The four reviewed fields, in the order the page renders them.
///
/// **Common mistakes leads, and it is the only one that starts open** (R17).
/// It is the field that carries the injury risk, and the prototype — which
/// `CLAUDE.md` makes the authority on layout — puts it first for that reason.
/// Setup, Posture and Execution then read in the order they happen.
///
/// **The text is the shipped string and nothing else touches it.** `CLAUDE.md`
/// forbids rewriting, summarising, regenerating, truncating or reflowing these
/// four; this function exists so there is one place they are named, rather
/// than four call sites each free to clamp one.
List<({String field, String label, String text})> exerciseContentFields(
  Exercise exercise,
) =>
    <({String field, String label, String text})>[
      (
        field: 'commonMistakes',
        label: 'COMMON MISTAKES',
        text: exercise.commonMistakes,
      ),
      (field: 'setup', label: 'SETUP', text: exercise.setup),
      (field: 'posture', label: 'POSTURE', text: exercise.posture),
      (field: 'execution', label: 'EXECUTION', text: exercise.execution),
    ];

/// The body views needed to show every muscle [exercise] names.
///
/// **Chosen from the exercise's own muscles, never fixed to the front**
/// (`docs/00` §5, `docs/03`): "if the relevant muscles span both views, both
/// diagrams render side by side, each full body. If one view covers
/// everything, only that one shows, centred." 55 of the 260 shipped exercises
/// are covered by the back view alone, so a page hard-wired to the front would
/// render a complete, plausible body with the one muscle it exists to show
/// left grey — a failure that looks like artwork rather than like a bug.
///
/// **Secondary muscles count, not only primaries.** `docs/03` settles this
/// with the case it chose as its worked example: incline dumbbell press has
/// chest and front delts on the front, but the triceps it also works are drawn
/// only on the back, "so both diagrams are needed here". A rule reading
/// primaries alone would leave half the chips on this page pointing at nothing
/// on the body beside them.
///
/// Front is preferred when either view alone would do — the same default the
/// landing opens on, and the view 12 of the 19 sub-groups are drawn on.
List<BodyView> bodyViewsForExercise(Exercise exercise) {
  var front = true;
  var back = true;
  for (final id in <String>{...exercise.primary, ...exercise.secondary}) {
    final drawnOn = kSubMuscleGroups[id]?.segments;
    // An id the taxonomy does not carry cannot be drawn on either view, so it
    // must not be allowed to force a second body. The library is validated
    // against the taxonomy; this is the same "a stale id is not a crash"
    // position `ExerciseIndex.byId` takes.
    if (drawnOn == null) continue;
    final views = drawnOn.map((placement) => placement.view).toSet();
    front &= views.contains(BodyView.front.taxonomyView);
    back &= views.contains(BodyView.back.taxonomyView);
  }
  if (front) return const <BodyView>[BodyView.front];
  if (back) return const <BodyView>[BodyView.back];
  return const <BodyView>[BodyView.front, BodyView.back];
}

/// Fills a segment by what [exercise] does to the muscles it stands for:
/// primary in [AppPalette.accentStrong], secondary in [AppPalette.accentLight],
/// everything else in [AppPalette.mutedSurface] (`docs/00` §5).
///
/// **`accentLight` is read from [AppPalette] rather than off the
/// `ColorScheme`.** `app_theme.dart` leaves it out of the scheme deliberately:
/// §12 gives it one meaning, "secondary muscle", and a scheme role would invite
/// a button to pick it up.
///
/// **One instance per exercise, handed out by [exerciseMuscleFill], and that
/// is what makes the repaint guard work.** `BodyDiagramPainter.shouldRepaint`
/// compares `fill`, which is the `colorFor` tear-off — and Dart compares a
/// bound tear-off by its *receiver's identity*, not by the receiver's `==`.
/// Two instances holding the same muscles still produce unequal tear-offs, so
/// constructing one per build would repaint both bodies on every unrelated
/// rebuild of the page. Memoizing the receiver is the only thing that stops
/// it; a `==` on this class does not.
///
/// **`any`, not `single`.** A segment can stand for more than one sub-muscle
/// group — the front-delt polygon carries both delts — which is exactly the
/// case `BodySegmentFill`'s doc hands to the caller to decide. A lift that
/// works the front delt fills that polygon even though the side delt beside it
/// is untouched, because there is no second polygon to distinguish them with.
@immutable
class MuscleFill {
  /// A fill over two explicit sets, which is what a whole session has.
  MuscleFill({
    required Set<String> primary,
    required Set<String> secondary,
  })  : primary = Set<String>.unmodifiable(primary),
        secondary = Set<String>.unmodifiable(secondary);

  /// A fill for one exercise's own muscles.
  MuscleFill.forExercise(Exercise exercise)
      : primary = Set<String>.unmodifiable(exercise.primary),
        secondary = Set<String>.unmodifiable(exercise.secondary);

  final Set<String> primary;
  final Set<String> secondary;

  Color colorFor(Set<String> subMuscleGroupIds) {
    if (subMuscleGroupIds.any(primary.contains)) return AppPalette.accentStrong;
    if (subMuscleGroupIds.any(secondary.contains)) return AppPalette.accentLight;
    return AppPalette.mutedSurface;
  }

  /// Two fills are the same when they colour the same muscles, so a rebuild
  /// that produces an equal fill does not repaint 42 polygons.
  @override
  bool operator ==(Object other) =>
      other is MuscleFill &&
      setEquals(other.primary, primary) &&
      setEquals(other.secondary, secondary);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(primary),
        Object.hashAllUnordered(secondary),
      );
}

/// The one [MuscleFill] for [exercise], the same object every time.
///
/// **Identity is the point** — see that class's header. The painter's
/// `shouldRepaint` can only answer "nothing changed" if the fill it is handed
/// is the same receiver as last frame's, and a page rebuilt for any reason at
/// all rebuilds `_ExerciseDiagrams` with it.
///
/// Keyed by id and bounded by construction — 260 shipped exercises, read-only
/// content, and an entry is two small sets, so the whole map has a ceiling it
/// cannot be argued past. **A session's fill gets no such cache**: its key is
/// the set of muscles trained so far, which has no ceiling, so the overview
/// holds its one fill in its own state instead.
MuscleFill exerciseMuscleFill(Exercise exercise) =>
    _muscleFills.putIfAbsent(exercise.id, () => MuscleFill.forExercise(exercise));

final Map<String, MuscleFill> _muscleFills = <String, MuscleFill>{};

/// Everything else that trains one of [exercise]'s primary sub-muscle groups,
/// different equipment first.
///
/// **Any of its primaries, not all of them** (R19). 31 of the 260 shipped
/// exercises name two primary sub-groups, and the barbell bent-over row is
/// one: requiring the full set to match would hand exactly those 31 — the
/// compound lifts a substitute is most often wanted for — an empty rail, while
/// every single-primary exercise around them looked fine.
///
/// **Different equipment first, because that is the question being asked.**
/// Someone reading this rail is standing in front of an occupied rack or a
/// gym that has no cable tower; another barbell lift for the same muscle
/// answers nothing. Same-equipment alternatives still follow, because they are
/// the right answer to the other question this rail gets asked — "what else,
/// with what I already have".
///
/// **Within each half the primaries take turns**, and the whole is capped at
/// [kSubstituteRailLimit] — the rail is a sideways glance, and the muscle's
/// full list is one screen away through the list this page was reached from.
/// Taking turns is what makes the cap and the any-rule survive each other:
/// the bent-over row's lats bucket alone holds 15 cards on other equipment, so
/// reading the buckets end to end would fill all eight slots from the first
/// muscle and quietly turn a two-muscle rail back into a one-muscle rail.
List<Exercise> substitutesFor(ExerciseIndex index, Exercise exercise) {
  // An exercise naming two of this one's primaries belongs to the first bucket
  // that claims it, not to both.
  final seen = <String>{exercise.id};
  final byPrimary = <List<Exercise>>[
    for (final subGroupId in exercise.primary)
      <Exercise>[
        for (final other in index.withPrimary(subGroupId))
          if (seen.add(other.id)) other,
      ],
  ];

  List<List<Exercise>> equipment({required bool matching}) => <List<Exercise>>[
        for (final bucket in byPrimary)
          <Exercise>[
            for (final other in bucket)
              if ((other.equipment == exercise.equipment) == matching) other,
          ],
      ];

  return List<Exercise>.unmodifiable(
    <Exercise>[
      ..._takingTurns(equipment(matching: false)),
      ..._takingTurns(equipment(matching: true)),
    ].take(kSubstituteRailLimit),
  );
}

/// [queues] flattened one round at a time, keeping each queue's own order.
List<Exercise> _takingTurns(List<List<Exercise>> queues) {
  final flattened = <Exercise>[];
  for (var round = 0;; round++) {
    var added = false;
    for (final queue in queues) {
      if (round < queue.length) {
        flattened.add(queue[round]);
        added = true;
      }
    }
    if (!added) return flattened;
  }
}

/// How many cards the rail carries, following the approved prototype.
const int kSubstituteRailLimit = 8;

/// The label over the rail.
///
/// **Named after the muscle only when there is exactly one** (R19). Naming it
/// after the first of two primaries would mislabel every card that matched the
/// second — a bent-over row's rail would be titled "for Lats" while half of it
/// is upper-back work — and the reader has no way to tell which cards are
/// which.
String substituteRailLabel(Exercise exercise) {
  if (exercise.primary.length != 1) return kNeutralSubstituteRailLabel;
  final id = exercise.primary.single;
  final label = kSubMuscleGroups[id]?.label ?? id;
  return 'OTHER EXERCISES FOR ${label.toUpperCase()}';
}

/// Said when the exercise has more than one primary muscle.
const String kNeutralSubstituteRailLabel = 'OTHER EXERCISES FOR THESE MUSCLES';

/// The muscles this exercise trains, as chips over the diagram they colour.
///
/// The chips are a legend as much as a list: the primary ones are filled in
/// the colour their segments are filled in below.
class _MuscleChips extends StatelessWidget {
  const _MuscleChips({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final id in exercise.primary)
          _MuscleChip(subGroupId: id, isPrimary: true),
        for (final id in exercise.secondary)
          _MuscleChip(subGroupId: id, isPrimary: false),
      ],
    );
  }
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({required this.subGroupId, required this.isPrimary});

  final String subGroupId;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final label = kSubMuscleGroups[subGroupId]?.label ?? subGroupId;

    return Semantics(
      // Which half of the list a chip is in is carried visually by its fill,
      // which a screen reader cannot see. Said out loud rather than shown
      // twice: a second visible heading would split a list the eye reads as
      // one.
      label: isPrimary ? 'Primary muscle: $label' : 'Also works: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary ? AppPalette.accentStrong : AppPalette.mutedSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isPrimary ? AppPalette.accentStrong : AppPalette.border,
          ),
        ),
        child: Text(
          label,
          style: isPrimary
              ? kMuscleChipPrimaryStyle
              : kMuscleChipSecondaryStyle,
        ),
      ),
    );
  }
}

/// One body, or two side by side — see [bodyViewsForExercise].
class _ExerciseDiagrams extends StatelessWidget {
  const _ExerciseDiagrams({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final views = bodyViewsForExercise(exercise);
    // Asked for, not constructed: a fresh instance here would defeat the
    // painter's repaint guard entirely. See [exerciseMuscleFill].
    final fill = exerciseMuscleFill(exercise);

    return SizedBox(
      height: kExerciseDiagramHeight,
      child: Row(
        children: <Widget>[
          for (final view in views) ...<Widget>[
            if (view != views.first) const SizedBox(width: 10),
            // Expanded rather than a fixed width: one body then takes the
            // whole content width and the painter's own centring puts it on
            // the screen's axis, which is what "centred" means here.
            Expanded(
              child: BodyDiagram(
                view: view,
                fill: fill.colorFor,
                // Read-only (R16). There is nowhere for a tap to go: the
                // reader is already looking at the answer this body would
                // navigate to, and a polygon that highlights under the thumb
                // and then does nothing reads as broken.
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tall enough to read a filled muscle at a glance, short enough that the
/// content rows are still on the first screen. Both layouts use it, so a
/// one-view page and a two-view page scroll the same distance.
const double kExerciseDiagramHeight = 210;

/// The rail of substitutes.
///
/// **A `SingleChildScrollView` over a `Row`, not a horizontal `ListView`.** At
/// [kSubstituteRailLimit] cards there is nothing to recycle, and a lazy
/// viewport would leave the off-screen cards unbuilt — which would make "the
/// rail lists it" a claim about the viewport rather than about the rail.
class _SubstituteRail extends StatelessWidget {
  const _SubstituteRail({required this.substitutes});

  final List<Exercise> substitutes;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kSubstituteCardHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final exercise in substitutes) ...<Widget>[
              if (exercise != substitutes.first) const SizedBox(width: 9),
              _SubstituteCard(exercise: exercise),
            ],
          ],
        ),
      ),
    );
  }
}

/// One substitute: its name and the equipment it needs.
///
/// A card rather than the list screen's divider row, because the rail is read
/// sideways — the same reason `TemplateRow` is a card and `SubGroupRow` is not.
class _SubstituteCard extends StatelessWidget {
  const _SubstituteCard({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${exercise.name}. '
          '${exerciseEquipmentLabel(exercise.equipment)}',
      excludeSemantics: true,
      child: GestureDetector(
        key: substituteCardKey(exercise.id),
        behavior: HitTestBehavior.opaque,
        // The page for that exercise, which is this same screen: a reader
        // comparing three ways to train one muscle should be able to keep
        // going without backing out to the list each time.
        onTap: () => pushExerciseDetail(context, exercise),
        child: Container(
          width: kSubstituteCardWidth,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppPalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Expanded(
                child: Text(
                  exercise.name,
                  style: kSubstituteCardNameStyle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                exerciseEquipmentLabel(exercise.equipment),
                style: kExerciseEquipmentChipStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The prototype's `.rail .card` measurements: wide enough for three words a
/// line, narrow enough that the next card is visibly there to be scrolled to.
const double kSubstituteCardWidth = 132;

/// Past the 48pt floor several times over — the card is the tap target.
const double kSubstituteCardHeight = 92;

/// A primary muscle: the diagram's own fill, so the chip and the polygon read
/// as the same statement.
const TextStyle kMuscleChipPrimaryStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: AppPalette.onAccent,
);

/// A secondary muscle. **Not [AppPalette.accentLight]**, even though that is
/// what its segment is filled with: §12 allows that colour for the muscle
/// fill, and a chip is not a fill. The prototype draws these as quiet muted
/// chips, and the ordering — primaries first — is what pairs them with the
/// body.
const TextStyle kMuscleChipSecondaryStyle = TextStyle(
  fontSize: 11,
  color: AppPalette.textSecondary,
);

/// The card's name. Smaller than a row's, because a rail is glanced at.
const TextStyle kSubstituteCardNameStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  height: 1.35,
  color: AppPalette.textPrimary,
);
