import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/body_gender.dart';
import '../data/exercise_index.dart';
import '../data/muscle_training.dart';
import '../data/training_plan.dart' show planTodayProvider;
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
  static String get listLabel => 'Muscles';

  /// The line under the map. It is what tells a user the rows below are the
  /// same destinations as the polygons above, rather than a second, different
  /// list.
  static const String mapHint = 'Tap a muscle, or pick from the list below.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(musclesBodyViewProvider);
    final index = ref.watch(exerciseIndexProvider);
    final training = ref.watch(muscleTrainingProvider);
    final today = ref.watch(planTodayProvider);
    final anyThisWeek = training.values.any((t) => t.workedThisWeek);

    return LayoutBuilder(builder: (context, constraints) {
    final padding = screenScrollPadding(context);
    return ListView(
      padding: padding,
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
        _CappedMap(
          maxHeight: musclesMapMaxHeight(context, constraints, padding),
          child: BodyDiagram(
          view: view,
          fill: trainingFill(training),
          segmentValue: (ids) => <String>[
            for (final id in orderedSubMuscleGroups(ids))
              muscleTrainingLine(training[id] ?? MuscleTraining.none, today),
          ].join('; '),
          // The diagram reports every sub-group the tapped segment stands
          // for and deliberately resolves none of them (R7): which of two
          // delts was meant is a screen's question, not a painter's.
          onSegmentTap: (subMuscleGroupIds) =>
              openTappedBodySegment(context, subMuscleGroupIds),
        ),
        ),
        const SizedBox(height: 10),
        if (anyThisWeek)
          const _TrainingLegend()
        else
          const Text(
            kMusclesEmptyWeekNote,
            style: kMusclesMapHintStyle,
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 6),
        Text(mapHint, style: kMusclesMapHintStyle, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(listLabel, style: kLandingSectionLabelStyle),
        ),
        const SizedBox(height: 8),
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
    });
  }
}

/// The tallest the landing map may be: what is left of the viewport once the
/// search field, the Front/Back control, the hint and the tab bar clearance
/// are taken out (audit B5). Without a cap the map was sized from the width
/// alone — 670pt on a 17e — and the calves sat under the floating tab bar.
double musclesMapMaxHeight(
  BuildContext context,
  BoxConstraints constraints,
  EdgeInsets padding,
) {
  if (!constraints.hasBoundedHeight) return double.infinity;
  final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
  // Search field 48 + 14, Front/Back 48 + 12, gap 10 above the hint, the hint
  // itself, and a little air so the first list heading can peek.
  final above = 48.0 + 14 + kBodyViewButtonHeight + 12;
  final below = 10.0 + 2 * 18 * textScale + 6 + 30;
  return (constraints.maxHeight - padding.vertical - above - below)
      .clamp(280.0, double.infinity);
}

/// The landing map's fill: what the log says about this week (ADR 0012).
///
/// The accent where any of the segment's muscles was trained directly this
/// week, the secondary-muscle colour where one was only worked as a secondary
/// muscle, muted otherwise. The same two colours, with the same meanings, as
/// the exercise page's diagram.
BodySegmentFill trainingFill(Map<String, MuscleTraining> training) {
  if (training.isEmpty) return mutedBodyFill;
  return (ids) {
    var secondary = false;
    for (final id in ids) {
      final t = training[id];
      if (t == null) continue;
      if (t.trainedThisWeek) return AppPalette.accentStrong;
      if (t.secondarySets > 0) secondary = true;
    }
    return secondary ? AppPalette.accentLight : AppPalette.mutedSurface;
  };
}

/// Under the map when nothing has been trained this week.
const String kMusclesEmptyWeekNote =
    'Nothing trained this week yet. Muscles fill as you log sets.';

/// The legend's two entries.
const String kMusclesLegendWorked = 'Worked this week';
const String kMusclesLegendSecondary = 'Secondary';

class _TrainingLegend extends StatelessWidget {
  const _TrainingLegend();

  @override
  Widget build(BuildContext context) {
    Widget entry(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: kMusclesMapHintStyle),
          ],
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: <Widget>[
        entry(AppPalette.accentStrong, kMusclesLegendWorked),
        entry(AppPalette.accentLight, kMusclesLegendSecondary),
      ],
    );
  }
}

/// Bounds the map's height and centres it, so the figure keeps its aspect
/// ratio inside a box narrower than the screen when the height is the limit.
class _CappedMap extends StatelessWidget {
  const _CappedMap({required this.maxHeight, required this.child});

  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // The tallest of the four assets is 700×1324; sizing from it keeps
          // every asset inside the box.
          final natural = width * 1324 / 700;
          final height = natural < maxHeight ? natural : maxHeight;
          return SizedBox(width: width, height: height, child: child);
        },
      );
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
          if (view != BodyView.values.first) const SizedBox(width: 8),
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
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: bodyViewLabel(view),
      onTap: onTap,
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
            borderRadius: BorderRadius.circular(999),
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
);

/// The centred line under the map — quieter than a row's own copy, because it
/// explains the screen rather than being part of it.
const TextStyle kMusclesMapHintStyle = TextStyle(
  fontSize: 12,
  color: AppPalette.textMuted,
);
