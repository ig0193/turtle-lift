import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'divider_row.dart';
import 'muscle_exercise_list_screen.dart';
import 'session_actions.dart';
import 'session_body_map.dart';
import 'session_date_control.dart';
import 'sub_group_row.dart';

/// The template path's overview: what today covers, and what has been trained.
///
/// **A nested muscle list, not an exercise list.** The template is a menu of
/// muscles the user chose; which lift trains each one is the next screen's
/// question, and answering it here would turn a coherent shortlist into a wall.
///
/// **Only chest, back, shoulders and abs expand.** The other eight parent
/// groups have exactly one sub-group, so an Arms day is two flat rows rather
/// than two accordions each hiding one identical child.
class TemplateOverviewBody extends ConsumerWidget {
  const TemplateOverviewBody({required this.onFinished, super.key});

  final void Function(String sessionId) onFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final index = ref.watch(exerciseIndexProvider);
    if (session == null) return const SizedBox.shrink();

    final trained = trainedSubGroups(session, index);

    return ListView(
      padding: screenScrollPadding(context),
      children: <Widget>[
        const SessionDateControl(),
        const SessionBodyMap(),
        const SizedBox(height: 6),
        for (final groupId in session.groupIds)
          _MuscleGroupSection(groupId: groupId, trained: trained),
        const SizedBox(height: 20),
        SessionActions(onFinished: onFinished),
      ],
    );
  }
}

/// One parent group: an accordion when it has more than one sub-group, a plain
/// row when it has exactly one.
class _MuscleGroupSection extends ConsumerStatefulWidget {
  const _MuscleGroupSection({required this.groupId, required this.trained});

  final String groupId;
  final Set<String> trained;

  @override
  ConsumerState<_MuscleGroupSection> createState() =>
      _MuscleGroupSectionState();
}

class _MuscleGroupSectionState extends ConsumerState<_MuscleGroupSection> {
  /// **Open by default.** The tick only renders inside the body, and this
  /// screen exists to be read at a glance between sets; starting collapsed
  /// would make the user open four groups by hand to see what they have done.
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    // **The taxonomy maps a parent to bare sub-group names**, not to full ids:
    // `chest` yields `upper`, `mid`, `lower`. Everything else in the app —
    // `kSubMuscleGroups`, the exercise library's `primary`, the trained set —
    // is keyed by `group/sub`, so the id has to be composed here or every
    // lookup silently misses and no row can ever tick.
    final subGroupIds = <String>[
      for (final name in kMuscleTaxonomy[widget.groupId] ?? const <String>[])
        '${widget.groupId}/$name',
    ];
    if (subGroupIds.isEmpty) return const SizedBox.shrink();

    // One sub-group is a flat row: an accordion hiding one identical child is
    // a tap that buys nothing.
    if (subGroupIds.length == 1) {
      return _SubGroupTile(
        subGroupId: subGroupIds.single,
        trained: widget.trained.contains(subGroupIds.single),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          expanded: _expanded,
          label: kMuscleGroupLabels[widget.groupId] ?? widget.groupId,
          excludeSemantics: true,
          child: GestureDetector(
            key: groupHeaderKey(widget.groupId),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    kMuscleGroupLabels[widget.groupId] ?? widget.groupId,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  // The chevron carries the state change, as every disclosure
                  // in this app does — there is no cross-fade or size
                  // animation anywhere in `lib/`.
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    child: const Icon(Icons.expand_more,
                        size: 20, color: AppPalette.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          for (final subGroupId in subGroupIds)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: _SubGroupTile(
                subGroupId: subGroupId,
                trained: widget.trained.contains(subGroupId),
              ),
            ),
      ],
    );
  }
}

/// One sub-muscle group: a tick when trained, a chevron otherwise.
///
/// **Ticked rows stay tappable.** This is the only route back in to add a
/// fourth set or correct a mistyped weight, so it must not be disabled the
/// moment the tick appears.
class _SubGroupTile extends ConsumerWidget {
  const _SubGroupTile({required this.subGroupId, required this.trained});

  final String subGroupId;
  final bool trained;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = kSubMuscleGroups[subGroupId]?.label ?? subGroupId;
    return DividerRow(
      key: subGroupTileKey(subGroupId),
      semanticsLabel: trained ? '$label, trained' : label,
      onTap: () =>
          pushMuscleExerciseList(context, subGroupId, inSession: true),
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label, style: kSubGroupRowLabelStyle),
            if (trained)
              // Animates in when the group becomes trained: a new element
              // appearing, not a container resizing.
              TweenAnimationBuilder<double>(
                key: trainedTickKey(subGroupId),
                tween: Tween<double>(begin: 0.7, end: 1),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: const Icon(Icons.check,
                    size: 17, color: AppPalette.accentStrong),
              ),
          ],
        ),
      ],
    );
  }
}

/// The header for [groupId], so a test can expand one by name.
Key groupHeaderKey(String groupId) => ValueKey<String>('group-header-$groupId');

/// The row for [subGroupId], so a test can tap one by name.
Key subGroupTileKey(String subGroupId) =>
    ValueKey<String>('sub-group-$subGroupId');

/// The tick on [subGroupId], so a test can assert it is there.
Key trainedTickKey(String subGroupId) =>
    ValueKey<String>('trained-tick-$subGroupId');
