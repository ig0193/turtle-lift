import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart' show lastSetLine;
import '../data/exercise.dart';
import '../data/exercise_index.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../data/session_store.dart';
import '../data/muscle_training.dart';
import '../data/training_plan.dart' show planTodayProvider;
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
/// **Browsed from the Muscles tab, nothing here is derived from training
/// history.** The prototype's row carries a `Last: 60kg × 8` line and a "not
/// logged yet" placeholder; both belong to the deferred personal layer. The row
/// is the name and the equipment, which is what a reader standing at a rack has
/// to choose between.
///
/// **It is a reference page in every context.** It used to double as the swap
/// screen inside a workout; the exercise-first Workout tab
/// (`docs/adr/0006-workout-tab-is-exercise-first.md`) lists a session's
/// exercises directly, so a tap here always opens the exercise's page.
class MuscleExerciseListScreen extends ConsumerWidget {
  const MuscleExerciseListScreen({required this.subGroupId, super.key});

  /// A `group/sub` id from `muscle_taxonomy.dart`.
  final String subGroupId;

  /// The header over the rows. Counted from the list it sits above rather than
  /// typed, for the reason `MusclesRoot.listLabel` gives.
  ///
  /// It reuses [exerciseCountLabel] rather than restating it, so a header
  /// cannot end up pluralising differently from the rows beneath it.
  static String countLabel(int count) => exerciseCountLabel(count);

  /// The screen's title: the taxonomy's own label, falling back to the id.
  ///
  /// **A fallback rather than a `!`.** An id that misses is a stale route
  /// argument, and `ExerciseIndex.byId` already sets the precedent that such a
  /// thing is the caller's problem to see rather than a crash for the user.
  static String titleFor(String subGroupId) =>
      kSubMuscleGroups[subGroupId]?.label ?? subGroupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(exerciseIndexProvider).withPrimary(subGroupId);
    final training =
        ref.watch(muscleTrainingProvider)[subGroupId] ?? MuscleTraining.none;
    return exerciseListScreen(
      context,
      title: titleFor(subGroupId),
      exercises: exercises,
      trainingLine:
          muscleTrainingLine(training, ref.watch(planTodayProvider)),
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
  String? trainingLine,
}) =>
    AppScreen.pushed(
      title: title,
      body: _ExerciseListBody(
        exercises: exercises,
        trainingLine: trainingLine,
      ),
    );

/// The list itself: optional training line, equipment chips, count, rows.
///
/// **The chosen equipment lives in this widget's state and nowhere else**
/// (ADR 0012): leaving the screen forgets it, so a filter set last week never
/// silently hides exercises today.
class _ExerciseListBody extends ConsumerStatefulWidget {
  const _ExerciseListBody({required this.exercises, this.trainingLine});

  final List<Exercise> exercises;
  final String? trainingLine;

  @override
  ConsumerState<_ExerciseListBody> createState() => _ExerciseListBodyState();
}

class _ExerciseListBodyState extends ConsumerState<_ExerciseListBody> {
  String? _equipment;

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedSessionsProvider);
    // Derived from the list, sorted: a chip for gear this muscle has no
    // exercise for would be a button that empties the list.
    final values = <String>{for (final e in widget.exercises) e.equipment}
        .toList()
      ..sort();
    final chosen = values.contains(_equipment) ? _equipment : null;
    final shown = chosen == null
        ? widget.exercises
        : widget.exercises.where((e) => e.equipment == chosen).toList();

    return ListView(
      padding: screenScrollPadding(context),
      children: <Widget>[
        const SizedBox(height: 14),
        if (widget.trainingLine != null) ...<Widget>[
          // ADR 0012: what the log says about this muscle, above what to
          // train it with.
          Text(widget.trainingLine!, style: kSubGroupRowCountStyle),
          const SizedBox(height: 12),
        ],
        if (values.length > 1) ...<Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              EquipmentChip(
                key: equipmentChipKey(null),
                label: 'All',
                selected: chosen == null,
                onTap: () => setState(() => _equipment = null),
              ),
              for (final value in values)
                EquipmentChip(
                  key: equipmentChipKey(value),
                  label: exerciseEquipmentLabel(value),
                  selected: chosen == value,
                  // A second tap on the chosen chip clears it.
                  onTap: () => setState(
                    () => _equipment = chosen == value ? null : value,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        Semantics(
          header: true,
          child: Text(
            MuscleExerciseListScreen.countLabel(shown.length),
            style: kLandingSectionLabelStyle,
          ),
        ),
        const SizedBox(height: 8),
        for (final exercise in shown)
          ExerciseRow(
            key: exerciseRowKey(exercise.id),
            name: exercise.name,
            // Still shown on the equipment list, even though every row there
            // carries the same value: the row is the tab's one exercise row.
            equipment: exercise.equipment,
            subtitle: _rowNote(exercise, saved),
            onTap: () => pushExerciseDetail(context, exercise),
          ),
      ],
    );
  }

  /// "Last 80kg × 10" when logged, "Yours" on a custom exercise — the same
  /// words the picker uses (ADR 0012 decision 7).
  static String? _rowNote(Exercise exercise, List<WorkoutSession> saved) {
    final last = lastSetLine(exercise.id, saved);
    if (!exercise.isCustom) return last;
    return last == null ? 'Yours' : 'Yours · $last';
  }
}

/// The chip for [equipment], or the All chip when null.
@visibleForTesting
Key equipmentChipKey(String? equipment) =>
    ValueKey<String>('equipment-chip-${equipment ?? 'all'}');

/// An outlined selection chip: capsule, a hairline that turns accent-strong
/// when selected (the Front/Back control's treatment). Never filled — only the
/// primary action is filled.
class EquipmentChip extends StatelessWidget {
  const EquipmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          // widthFactor 1: centred vertically but only as wide as its label.
          // A bare `alignment` would stretch every chip to the full row.
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppPalette.accentStrong : AppPalette.border,
            ),
          ),
          child: Align(
            widthFactor: 1,
            child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? AppPalette.textPrimary
                  : AppPalette.textSecondary,
            ),
          ),
          ),
        ),
      ),
    );
  }
}

Future<void> pushMuscleExerciseList(BuildContext context, String subGroupId) =>
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
/// The shipped values are lower-case keys (`barbell`, `kettlebell`); a chip
/// shows them in sentence case ("Barbell"), never tracked capitals. Doing it
/// here rather than in the data keeps the library's own spelling on
/// `Exercise.equipment`, which is what `ExerciseIndex.withEquipment` matches on.
String exerciseEquipmentLabel(String equipment) => equipment.isEmpty
    ? equipment
    : equipment[0].toUpperCase() + equipment.substring(1);

/// One exercise, as a row: its name, the equipment it needs, and a chevron.
///
/// **The same divider row as `SubGroupRow`, not a card** — both are the
/// prototype's `.row`, and both are read by scanning a column of twenty. The
/// pattern underneath is `template_row.dart`'s: the semantics wrapper, the
/// opaque gesture box, the 48pt floor, the trailing chevron. Not a `ListTile`,
/// which would bring its own density, ripple and text theme.
///
/// **The equipment is a short muted line under the name.** It is the one thing
/// that decides whether a row is usable right now — a bench is taken, a
/// kettlebell is not — so it sits where the eye lands after the name. It used
/// to be a pill; a pill on every row of a twenty-row list is twenty pills.
class ExerciseRow extends StatelessWidget {
  const ExerciseRow({
    required this.name,
    required this.equipment,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  /// An extra fact after the equipment — the last set logged, on the picker.
  /// Absent on the browsing lists.
  final String? subtitle;

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
        // Equipment and the last set share one muted line, so a row that has
        // history is the same height as its neighbours that do not.
        Row(
          children: <Widget>[
            RowTagChip(label: exerciseEquipmentLabel(equipment)),
            if (subtitle != null) ...<Widget>[
              const Text(' · ', style: kExerciseEquipmentChipStyle),
              Flexible(
                child: Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kExerciseEquipmentChipStyle.copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// One fact about the row it sits on, as quiet muted text.
///
/// **Text, not a pill.** It began as the prototype's `.eqchip` pill, but it is
/// neither a button nor a chip -- nothing about it can be tapped -- and the
/// repo's capsule shape is for those. On a list of twenty rows the pills were
/// the loudest thing on the screen while carrying the least.
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
    return Text(label, style: kExerciseEquipmentChipStyle);
  }
}

/// The row's name. Literally the sub-group row's style: both are the
/// prototype's `.row`, and two constants carrying the same numbers drift.
const TextStyle kExerciseRowNameStyle = kSubGroupRowLabelStyle;

/// The row fact's type: small and muted, quiet enough to sit under the name
/// without competing with it.
const TextStyle kExerciseEquipmentChipStyle = TextStyle(
  fontSize: 13,
  color: AppPalette.textMuted,
);
