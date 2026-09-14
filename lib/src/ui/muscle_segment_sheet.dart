import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise_index.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'muscle_exercise_list_screen.dart';
import 'sub_group_row.dart';

/// Opens the exercise list for a tapped segment, asking first when the segment
/// stands for more than one sub-muscle group (R6, R7).
///
/// **The question is only asked when there is one**, which is the whole shape
/// of this function: 40 of the 42 segments resolve to a single sub-group and go
/// straight through, and interposing a one-option prompt on all of them would
/// be the picker R9 deletes, wearing a different hat.
///
/// **Which segment is ambiguous is not written down anywhere here.** In
/// practice it is front-delt, because `shoulders/side-delt` rides on that
/// polygon; but that fact lives in the generated taxonomy and reaches this
/// function through `BodyDiagram`'s reported set. A hard-coded pair would keep
/// working, wrongly, the day a regenerated taxonomy moves it.
Future<void> openTappedBodySegment(
  BuildContext context,
  Set<String> subMuscleGroupIds,
) async {
  final ordered = orderedSubMuscleGroups(subMuscleGroupIds);
  if (ordered.isEmpty) return;
  if (ordered.length == 1) {
    return pushMuscleExerciseList(context, ordered.single);
  }

  final chosen = await showMuscleSegmentSheet(context, subGroupIds: ordered);
  // Dismissing the sheet is an answer too — "neither" — and it must open
  // nothing. A tap on a 40pt polygon lands on the wrong one often enough that
  // backing out has to be free.
  if (chosen == null || !context.mounted) return;
  return pushMuscleExerciseList(context, chosen);
}

/// [ids] in the taxonomy's own order.
///
/// The diagram reports a `Set`, whose iteration order is the order the
/// inversion happened to build it in. Ordering here means the two delts are
/// listed front-then-side on the sheet exactly as they are in the list of 19,
/// so the prompt and the landing never disagree about which comes first.
List<String> orderedSubMuscleGroups(Iterable<String> ids) => <String>[
      for (final id in kSubMuscleGroups.keys)
        if (ids.contains(id)) id,
    ];

/// Asks which of [subGroupIds] the tap meant, and returns it — or null if the
/// user dismissed the question.
///
/// **A modal bottom sheet, not `showTemplateFilterMenu` (KTD6).** That menu
/// cannot serve this call site twice over: it requires a `current` value to
/// mark as selected, and there is no current muscle — the user has just tapped
/// a polygon — and it anchors off the tapped widget's own render box, while a
/// segment tap gives a bare coordinate inside one painter with no per-segment
/// widget to anchor to. The approved prototype
/// (`prototypes/muscles-tab-variants.html`, variant A) shows a sheet here, and
/// `CLAUDE.md` gives the prototype authority over how a screen looks. A sheet
/// also lands at the bottom of the screen, which is the reachable half for a
/// thumb that has just been up at the shoulder.
///
/// **Every visual is passed explicitly**, exactly as that menu's doc requires:
/// `lib/src/theme/app_theme.dart` sets no `bottomSheetTheme`, so Material's
/// defaults would bring an elevation, a tinted surface and a drag handle that
/// appear nowhere else in this app, and `test/theme_palette_test.dart` fails on
/// any colour outside §12.
Future<String?> showMuscleSegmentSheet(
  BuildContext context, {
  required List<String> subGroupIds,
}) =>
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppPalette.surface,
      // Flat, like every other surface in this app. Material's default
      // elevation would also tint the surface off-palette.
      elevation: 0,
      // Black at 55%, matching the prototype's scrim. An overlay rather than a
      // palette entry — `app_theme.dart` takes the same position on
      // `ColorScheme.scrim`.
      barrierColor: const Color(0x8C000000),
      // The app draws no drag handles; this sheet is dismissed by the scrim or
      // by answering, both of which are already available.
      showDragHandle: false,
      // The sheet is two rows tall. It never needs to grow past half the
      // screen, so it is not scroll-controlled.
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppPalette.border),
      ),
      builder: (_) => MuscleSegmentSheet(subGroupIds: subGroupIds),
    );

/// The sheet's contents: what was ambiguous, and the sub-groups to choose
/// between.
class MuscleSegmentSheet extends ConsumerWidget {
  const MuscleSegmentSheet({required this.subGroupIds, super.key});

  /// The sub-muscle groups the tapped segment stands for, in taxonomy order.
  final List<String> subGroupIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(exerciseIndexProvider);

    return SafeArea(
      // The sheet is pinned to the bottom edge, so only that inset applies;
      // taking the top one as well would pad a gap that is off-screen.
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                muscleSegmentSheetTitle(subGroupIds.length),
                style: kLandingSectionLabelStyle,
              ),
            ),
            const SizedBox(height: 9),
            for (final id in subGroupIds)
              // The same row as the landing's list, deliberately: the user is
              // choosing between the same two things they could have chosen
              // from there, and a differently shaped option would suggest it
              // leads somewhere else. Its own key, though — the landing's 19
              // rows are still mounted behind the scrim.
              SubGroupRow(
                key: muscleSegmentOptionKey(id),
                label: kSubMuscleGroups[id]?.label ?? id,
                exerciseCount: index.withPrimary(id).length,
                onTap: () => Navigator.of(context).pop(id),
              ),
          ],
        ),
      ),
    );
  }
}

/// The line above the options.
///
/// **Counted, not written as "two".** Only one segment carries more than one
/// sub-group today; a regenerated taxonomy that made a three-way segment would
/// otherwise leave a heading that lies about the list beneath it — the same
/// rule `MusclesRoot.listLabel` follows.
String muscleSegmentSheetTitle(int count) =>
    'THIS SEGMENT CARRIES $count MUSCLES';

/// The option for [subGroupId], so a test can answer the question by name
/// rather than by position — and so it never collides with the landing's own
/// row for the same sub-group, which is still mounted behind the sheet.
@visibleForTesting
Key muscleSegmentOptionKey(String subGroupId) =>
    ValueKey<String>('muscle-segment-option-$subGroupId');
