import 'package:flutter/material.dart';

import '../data/exercise_index.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../theme/app_palette.dart';
import 'divider_row.dart';

/// One of the 19 sub-muscle groups, as a row: its name, how many exercises
/// train it directly, and a chevron.
///
/// **A divider row, not a card.** `template_row.dart` is the pattern this
/// inherits — the semantics wrapper, the opaque gesture box, the 48pt floor,
/// the trailing chevron — but not its surface. A template is a thing you pick
/// one of; these 19 are an index of the whole body, and 19 bordered cards in a
/// column read as 19 separate offers rather than as one list. The prototype's
/// `.row` is a hairline between rows, and that is what this is.
class SubGroupRow extends StatelessWidget {
  const SubGroupRow({
    required this.label,
    required this.exerciseCount,
    required this.onTap,
    this.note,
    super.key,
  });

  /// The sub-group's display name, verbatim from `muscle_taxonomy.dart`.
  final String label;

  /// How many exercises name this sub-group as a *primary* muscle.
  ///
  /// Secondary involvement is excluded (R10), so this is "what to do to train
  /// it" rather than "what touches it".
  final int exerciseCount;

  /// An extra clause on the second line — today, only "no map artwork".
  final String? note;

  final VoidCallback onTap;

  /// The minimum row height, matching `TemplateRow.minHeight` and the app's
  /// other tap targets.
  static const double minHeight = DividerRow.minHeight;

  /// The air this row carries, which is a point more than the other two
  /// divider rows take — see [DividerRow.verticalPadding]. Preserved as it
  /// shipped rather than quietly rounded to theirs.
  static const double verticalPadding = 11;

  /// The second line: the count, and whatever [note] adds to it.
  String get subtitle {
    final exercises = exerciseCountLabel(exerciseCount);
    return note == null ? exercises : '$exercises · $note';
  }

  @override
  Widget build(BuildContext context) {
    return DividerRow(
      semanticsLabel: '$label. $subtitle',
      onTap: onTap,
      verticalPadding: verticalPadding,
      children: <Widget>[
        Text(label, style: kSubGroupRowLabelStyle),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: kSubGroupRowCountStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// The row for [subGroupId], so a test can reach one by name rather than by
/// position in a list of 19.
@visibleForTesting
Key subGroupRowKey(String subGroupId) =>
    ValueKey<String>('sub-group-$subGroupId');

/// All 19 sub-muscle groups as rows, in `kSubMuscleGroups`' own order.
///
/// **The map's insertion order is the order, and it is not re-sorted.** The
/// generator writes it grouped by parent — the three chest rows together, then
/// the three back rows — so the flat list still reads as a body rather than as
/// an alphabet (R4). Sorting by name would scatter "Lats", "Lower back" and
/// "Upper back & traps" across the screen; sorting by count would make the list
/// reorder itself as the library grows.
///
/// **A function, not a widget, so both screens can splice these into their own
/// `ListView`.** The landing puts them under the body map and the search screen
/// puts them under the field; neither wants a nested scrollable.
List<Widget> subGroupRows({
  required ExerciseIndex index,
  required ValueChanged<String> onSelected,
}) =>
    <Widget>[
      for (final group in kSubMuscleGroups.values)
        SubGroupRow(
          key: subGroupRowKey(group.id),
          label: group.label,
          exerciseCount: index.withPrimary(group.id).length,
          note: hasOwnArtwork(group.id) ? null : kNoArtworkNote,
          onTap: () => onSelected(group.id),
        ),
    ];

/// Said on the one row the body map cannot offer.
///
/// R5: `shoulders/side-delt` has no polygon of its own, so this list is its
/// only *direct* route — the map reaches it only by tapping the front delt and
/// answering the disambiguation sheet (R7), which nobody finds by looking. The
/// line exists so that a user who went looking for it on the diagram and failed
/// learns why, rather than concluding the app is missing a muscle.
const String kNoArtworkNote = 'no map artwork';

/// Whether [subGroupId] has a segment of its own on any body view.
///
/// **Derived, not a hard-coded exception.** Side-delt is the only sub-group
/// whose placement points at *another* group's segment (it rides on the
/// front-delt polygon), and that fact lives in the generated taxonomy. Reading
/// it back means a regenerated taxonomy that gave side-delt its own artwork —
/// or took another group's away — changes this list instead of leaving a stale
/// literal behind. `test/body_diagram_test.dart` is what pins side-delt as the
/// only such group today.
bool hasOwnArtwork(String subGroupId) =>
    kSubMuscleGroups[subGroupId]!
        .segments
        .any((placement) => placement.segment == subGroupId);

/// The row's name. A shade larger than the template row's subtitle and a shade
/// smaller than its title: this is a list of 19, read by scanning.
const TextStyle kSubGroupRowLabelStyle = TextStyle(
  fontSize: 13.5,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.1,
  color: AppPalette.textPrimary,
);

/// The count line beneath it.
const TextStyle kSubGroupRowCountStyle = TextStyle(
  fontSize: 11,
  color: AppPalette.textMuted,
);
