import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise.dart';
import '../data/exercise_index.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'divider_row.dart';
import 'exercise_detail_screen.dart';
import 'sub_group_row.dart';

/// Everything that trains one sub-muscle group directly.
///
/// **One screen away from the landing, from either route** (R6, R8). A segment
/// tap and a row tap land here, and nothing sits in between: `docs/03`
/// specified a muscle-group picker and then a sub-muscle-group picker on the
/// way, and R9 deletes both. Eighteen of the 19 are one polygon tap away — the
/// nineteenth, side-delt, is a tap and the front-delt sheet away — and all 19
/// are a row away, so a picker would only have asked the user to re-state
/// something they had already said by tapping.
///
/// **Primary involvement only** (R10). `ExerciseIndex.withPrimary` is the whole
/// query: this list answers "what do I do to train this muscle", and folding in
/// every lift that merely works it would make most of the 19 lists look alike —
/// and would put the barbell squat under Calves.
///
/// **Nothing here is derived from training history.** The prototype's row
/// carries a `Last: 60kg × 8` line and a "not logged yet" placeholder; both
/// belong to the deferred personal layer, and with no session table either
/// would be invented. The row is the name and the equipment, which is what a
/// reader standing at a rack has to choose between.
class MuscleExerciseListScreen extends ConsumerWidget {
  const MuscleExerciseListScreen({required this.subGroupId, super.key});

  /// A `group/sub` id from `muscle_taxonomy.dart`.
  final String subGroupId;

  /// The header over the rows. Counted from the list it sits above rather than
  /// typed, for the reason `MusclesRoot.listLabel` gives.
  ///
  /// The shouting is this header's own, but the sentence is not: it upper-cases
  /// [exerciseCountLabel] rather than restating it, so a header cannot end up
  /// pluralising differently from the rows beneath it.
  static String countLabel(int count) =>
      exerciseCountLabel(count).toUpperCase();

  /// The screen's title: the taxonomy's own label, falling back to the id.
  ///
  /// **A fallback rather than a `!`.** An id that misses is a stale route
  /// argument, and `ExerciseIndex.byId` already sets the precedent that such a
  /// thing is the caller's problem to see rather than a crash for the user.
  static String titleFor(String subGroupId) =>
      kSubMuscleGroups[subGroupId]?.label ?? subGroupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return exerciseListScreen(
      context,
      title: titleFor(subGroupId),
      exercises: ref.watch(exerciseIndexProvider).withPrimary(subGroupId),
    );
  }
}

/// The screen both exercise lists are: a header counting the rows, and the
/// rows (R13).
///
/// **A function over an already-resolved title and list, not a widget with a
/// flag.** [MuscleExerciseListScreen] and `EquipmentExerciseListScreen` stay
/// two classes — each owns its own title rule and its own query, and that
/// separation is the decision `EquipmentExerciseListScreen`'s header records —
/// but the part of them that is identical is written once, so the two cannot
/// count their rows in two different sentences or drift on the padding.
Widget exerciseListScreen(
  BuildContext context, {
  required String title,
  required List<Exercise> exercises,
}) =>
    AppScreen.pushed(
      title: title,
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              MuscleExerciseListScreen.countLabel(exercises.length),
              style: kLandingSectionLabelStyle,
            ),
          ),
          const SizedBox(height: 9),
          for (final exercise in exercises)
            ExerciseRow(
              key: exerciseRowKey(exercise.id),
              name: exercise.name,
              // Still shown on the equipment list, even though every row there
              // carries the same value: the row is the tab's one exercise row,
              // and a screen that quietly drops half of it teaches the reader
              // that the chip means something different there.
              equipment: exercise.equipment,
              // The one destination a row has, rather than a callback the
              // caller supplies: neither list wants a different answer to
              // "what is this exercise".
              onTap: () => pushExerciseDetail(context, exercise),
            ),
        ],
      ),
    );

/// Pushes [subGroupId]'s exercise list.
///
/// **One function, because there are two call sites and they must not drift**
/// — the landing's map and the landing's list (and, on the search screen, the
/// same 19 rows again). R8 is precisely the requirement that they arrive at the
/// same screen.
///
/// **Opaque, like every push in this app (KTD9).** It is the only kind of route
/// that covers the floating tab bar; a sheet or a transparent route leaves
/// "Workout" painted over the exercises and one stray tap away.
Future<void> pushMuscleExerciseList(
  BuildContext context,
  String subGroupId,
) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MuscleExerciseListScreen(subGroupId: subGroupId),
      ),
    );

/// The row for [exerciseId], so a test can reach one by name rather than by
/// position in a list of twenty-odd.
///
/// **Not `@visibleForTesting`, unlike the other row keys in this tab.** Two
/// production screens now key their rows with it — this one and
/// `EquipmentExerciseListScreen`, which renders the same [ExerciseRow] over a
/// different query — so it is shared production code rather than a test hook,
/// and the alternative was a second screen spelling the same key string out by
/// hand.
Key exerciseRowKey(String exerciseId) =>
    ValueKey<String>('exercise-$exerciseId');

/// How an equipment value is written on a row.
///
/// The shipped values are lower-case keys (`barbell`, `kettlebell`); the
/// prototype's `.eqchip` upper-cases them in CSS. Doing it here rather than in
/// the data keeps the library's own spelling on `Exercise.equipment`, which is
/// what `ExerciseIndex.withEquipment` matches on.
String exerciseEquipmentLabel(String equipment) => equipment.toUpperCase();

/// One exercise, as a row: its name, the equipment it needs, and a chevron.
///
/// **The same divider row as `SubGroupRow`, not a card** — both are the
/// prototype's `.row`, and both are read by scanning a column of twenty. The
/// pattern underneath is `template_row.dart`'s: the semantics wrapper, the
/// opaque gesture box, the 48pt floor, the trailing chevron. Not a `ListTile`,
/// which would bring its own density, ripple and text theme.
///
/// **The equipment is a chip rather than a sentence.** It is the one thing that
/// decides whether a row is usable right now — a bench is taken, a kettlebell
/// is not — so it reads as a tag the eye can filter on rather than as prose.
class ExerciseRow extends StatelessWidget {
  const ExerciseRow({
    required this.name,
    required this.equipment,
    required this.onTap,
    super.key,
  });

  final String name;

  /// The library's own lower-case value; [exerciseEquipmentLabel] writes it.
  final String equipment;

  final VoidCallback onTap;

  /// The minimum row height, matching [SubGroupRow.minHeight] and the app's
  /// other tap targets.
  static const double minHeight = DividerRow.minHeight;

  @override
  Widget build(BuildContext context) {
    return DividerRow(
      semanticsLabel: '$name. ${exerciseEquipmentLabel(equipment)}',
      onTap: onTap,
      children: <Widget>[
        Text(name, style: kExerciseRowNameStyle),
        const SizedBox(height: 4),
        RowTagChip(label: exerciseEquipmentLabel(equipment)),
      ],
    );
  }
}

/// The prototype's `.eqchip`: a small muted pill carrying one fact about the
/// row it sits on.
///
/// **One chip, two callers.** An exercise row labels it with the equipment and
/// a search result labels it with which vocabulary the hit came from; they had
/// been two identical `Container`s differing only in the string.
///
/// **The muted surface, not the accent**, in both cases: a chip states a fact
/// about the row rather than a state of it, and §12 gives the accent one
/// meaning — "active / this has been worked" — which neither is.
class RowTagChip extends StatelessWidget {
  const RowTagChip({required this.label, super.key});

  /// Written exactly as handed over — the display spelling belongs to the call
  /// site, for the reason [exerciseEquipmentLabel] gives.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppPalette.mutedSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.border),
      ),
      child: Text(label, style: kExerciseEquipmentChipStyle),
    );
  }
}

/// The row's name. Literally the sub-group row's style: both are the
/// prototype's `.row`, and two constants carrying the same numbers drift.
const TextStyle kExerciseRowNameStyle = kSubGroupRowLabelStyle;

/// `.eqchip` type: small, tracked out, quiet enough to sit under the name
/// without competing with it.
const TextStyle kExerciseEquipmentChipStyle = TextStyle(
  fontSize: 10,
  letterSpacing: 0.4,
  fontWeight: FontWeight.w600,
  color: AppPalette.textMuted,
);
