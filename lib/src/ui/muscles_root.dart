import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/body_gender.dart';
import '../data/exercise_index.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'body_diagram.dart';
import 'muscle_exercise_list_screen.dart';
import 'muscle_search_field.dart';
import 'muscle_segment_sheet.dart';
import 'muscle_search_screen.dart';
import 'sub_group_row.dart';

/// Which side of the body the landing's map is showing.
///
/// **A provider rather than the root's own `State`**, for the reason
/// `tab_index.dart` gives: the root is a `ConsumerWidget` and the view has to
/// survive a rebuild of it. It also has to survive a tab switch — the shell
/// keeps all three roots mounted in an `IndexedStack`, and a user who flipped
/// to the back, went to Workout and came back would otherwise find the front
/// again with no idea why.
///
/// **Not persisted, and not a Settings column.** Which side you last looked at
/// is not a preference; it is where you are in a screen, and it resets on a
/// cold start exactly as the scroll position does.
class MusclesBodyView extends Notifier<BodyView> {
  /// Front. Thirteen of the 19 sub-groups are drawn on it, against nine on the
  /// back — three of them (upper back, forearms, calves) appear on both.
  @override
  BodyView build() => BodyView.front;

  void select(BodyView view) => state = view;
}

/// The side the landing's map is showing. Named for the thing, matching
/// `tabIndexProvider`.
final musclesBodyViewProvider =
    NotifierProvider<MusclesBodyView, BodyView>(MusclesBodyView.new);

/// The Muscles tab's body: search, the body map, and every sub-muscle group.
///
/// **Both routes to a muscle are on one screen, and that is the whole
/// decision** (KD2). The map answers "what is this bit of me called"; the list
/// answers "where are my lats in this app" without a game of hunt-the-polygon —
/// and it is the only *direct* route to `shoulders/side-delt`, which has no
/// polygon of its own (R5). The map does reach it, but only through the
/// front-delt segment's disambiguation sheet (R7), which a user has to tap the
/// wrong-looking muscle to find. Either alone would strand one of the two ways
/// people arrive here.
///
/// **The map is uncoloured, and says nothing about the user** (R2, KD1). Every
/// segment paints [mutedBodyFill]. There is no session table yet and no way to
/// log a set, so a fill standing for "trained" would be a claim the app cannot
/// support — and `CLAUDE.md`'s rule that nothing derived is stored is what
/// makes adding that colour later a one-line change to the fill argument rather
/// than a change to this screen.
///
/// **This tab has no empty state, and adding one would be a bug.** The landing
/// is shipped reference content: a user with zero sessions sees exactly what a
/// user with three hundred sees.
///
/// **A body, never a `Scaffold`**, and the scrollable carries
/// [screenScrollPadding] — a `ListView` that passes its own padding stops
/// absorbing the safe-area inset automatically, and the last of the 19 rows
/// would then hide under the floating tab bar with nothing failing.
class MusclesRoot extends ConsumerWidget {
  const MusclesRoot({super.key});

  /// The label over the sub-group list, counted from the taxonomy rather than
  /// typed. A regenerated taxonomy with a twentieth group would otherwise leave
  /// a heading that lies about the list directly beneath it.
  static String get listLabel => 'ALL ${kSubMuscleGroups.length} SUB-GROUPS';

  /// The line under the map. It is what tells a user the rows below are the
  /// same destinations as the polygons above, rather than a second, different
  /// list.
  static const String mapHint = 'Tap a muscle, or pick from the list below.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(musclesBodyViewProvider);
    final index = ref.watch(exerciseIndexProvider);

    return ListView(
      padding: screenScrollPadding(context),
      children: <Widget>[
        MuscleSearchField.tappable(
          onTap: () => Navigator.of(context).push(
            // Opaque, like every other push in this app: it is the only kind of
            // route that covers the floating tab bar, and a search screen with
            // the tab bar still floating over its results would offer to leave
            // mid-query.
            MaterialPageRoute<void>(
              builder: (_) => const MuscleSearchScreen(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _BodyViewControl(
          current: view,
          onSelected: (chosen) =>
              ref.read(musclesBodyViewProvider.notifier).select(chosen),
        ),
        const SizedBox(height: 12),
        BodyDiagram(
          view: view,
          fill: mutedBodyFill,
          // The diagram reports every sub-group the tapped segment stands
          // for and deliberately resolves none of them (R7): which of two
          // delts was meant is a screen's question, not a painter's.
          onSegmentTap: (subMuscleGroupIds) =>
              openTappedBodySegment(context, subMuscleGroupIds),
        ),
        const SizedBox(height: 10),
        Text(mapHint, style: kMusclesMapHintStyle, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        Semantics(
          header: true,
          child: Text(listLabel, style: kLandingSectionLabelStyle),
        ),
        const SizedBox(height: 9),
        ...subGroupRows(
          index: index,
          // The same destination a segment tap reaches (R8) — and the only
          // direct one for side-delt, which no polygon of its own carries
          // (R5); from the map it is behind the front-delt sheet.
          onSelected: (subGroupId) =>
              pushMuscleExerciseList(context, subGroupId),
        ),
      ],
    );
  }
}

/// The front / back switch above the map.
///
/// **Two buttons rather than a toggle or a swipe.** Both sides have to be
/// visible as choices: the back view holds lats, glutes, hamstrings and
/// triceps, and a user who does not know they are a flip away will conclude the
/// app has no artwork for them. A single "flip" button says there is another
/// side but not what is on it, and a swipe says nothing at all.
///
/// **Every visual is passed explicitly**, as `template_filter_control.dart`
/// does: the theme sets no `segmentedButtonTheme`, and Material's own would
/// bring a selected-state fill and a check mark that appear nowhere else in
/// this app.
class _BodyViewControl extends StatelessWidget {
  const _BodyViewControl({required this.current, required this.onSelected});

  final BodyView current;
  final ValueChanged<BodyView> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final view in BodyView.values) ...<Widget>[
          if (view != BodyView.values.first) const SizedBox(width: 7),
          Expanded(
            child: _BodyViewButton(
              view: view,
              selected: view == current,
              onTap: () => onSelected(view),
            ),
          ),
        ],
      ],
    );
  }
}

class _BodyViewButton extends StatelessWidget {
  const _BodyViewButton({
    required this.view,
    required this.selected,
    required this.onTap,
  });

  final BodyView view;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // `accentStrong`, and this is the one-meaning rule applied rather than a
    // default inherited: §12 gives it "active", and the selected side is the
    // one being looked at. `accentLight` -- which this shipped as -- is the
    // colour §12 reserves for "secondary muscle only, never a primary action",
    // and on a control sitting directly above a body map full of muscles it is
    // the one colour that could be read as a claim about the artwork below.
    // It is used as a hairline and a label here, not as a fill -- a solid
    // accent panel at this size reads as a primary action, and flipping the
    // body is not one.
    final border = selected ? AppPalette.accentStrong : AppPalette.border;
    final label = selected ? AppPalette.textPrimary : AppPalette.textSecondary;

    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: bodyViewLabel(view),
      excludeSemantics: true,
      child: GestureDetector(
        key: bodyViewButtonKey(view),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: kBodyViewButtonHeight),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppPalette.mutedSurface : AppPalette.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Text(
            bodyViewLabel(view),
            style: kBodyViewButtonStyle.copyWith(color: label),
          ),
        ),
      ),
    );
  }
}

/// The button for [view], so a test can flip the map without matching on copy.
@visibleForTesting
Key bodyViewButtonKey(BodyView view) =>
    ValueKey<String>('body-view-${view.name}');

/// What each side is called on screen.
///
/// Not [BodyView.taxonomyView], which is the generated data's spelling and is
/// lower-case because it is a key. Two vocabularies, joined in one place, the
/// same way `body_gender.dart` joins the asset names.
String bodyViewLabel(BodyView view) => switch (view) {
      BodyView.front => 'Front',
      BodyView.back => 'Back',
    };

/// The 48pt floor again: this control sits directly above a map full of small
/// tap targets, so it has to be the easy one to hit.
const double kBodyViewButtonHeight = 48;

const TextStyle kBodyViewButtonStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.1,
);

/// The centred line under the map — quieter than a row's own copy, because it
/// explains the screen rather than being part of it.
const TextStyle kMusclesMapHintStyle = TextStyle(
  fontSize: 11.5,
  color: AppPalette.textMuted,
);
