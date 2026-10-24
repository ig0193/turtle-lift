import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise.dart';
import '../data/exercise_index.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import 'muscle_exercise_list_screen.dart' show ExerciseRow;
import 'muscle_search_field.dart';
import 'template_row.dart' show kLandingSectionLabelStyle;

/// Asks which exercise to log, and returns it — or null when dismissed.
///
/// **A modal sheet, the same shape as `showMuscleSegmentSheet`**, and every
/// visual is passed explicitly for the reason that function documents:
/// `app_theme.dart` sets no `bottomSheetTheme`, so Material's defaults would
/// bring an elevation, a tint and a drag handle that appear nowhere else here.
///
/// It is tall (most of the screen) because it is a list of up to 260 rows with a
/// search field above it; a half-height sheet would leave room for four.
Future<Exercise?> showExercisePicker(
  BuildContext context, {
  required String title,
}) =>
    showModalBottomSheet<Exercise>(
      context: context,
      backgroundColor: AppPalette.surface,
      elevation: 0,
      barrierColor: const Color(0x8C000000),
      showDragHandle: false,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppPalette.border),
      ),
      builder: (_) => ExercisePickerSheet(title: title),
    );

/// The sheet's contents: a search field, a muscle filter, and the exercises.
///
/// **The workout's own exercises come first**, under their own heading. On a
/// template session that is the plan, so the sheet opens as "here is what you
/// came to do" with everything else a scroll away; on an ad-hoc one it is the
/// exercises already added, which a user adding another wants out of the way
/// but still visible.
///
/// **The muscle filter is a filter, not a way through.** Muscles narrow the list
/// to what the user is looking for; they are never a level to navigate down, and
/// the Muscles tab remains where the app explains which exercise trains what.
class ExercisePickerSheet extends ConsumerStatefulWidget {
  const ExercisePickerSheet({required this.title, super.key});

  final String title;

  /// The key a test finds the heading by.
  static const Key titleKey = ValueKey<String>('picker-title');

  /// The row for [exerciseId].
  static Key rowKey(String exerciseId) =>
      ValueKey<String>('picker-row-$exerciseId');

  /// The filter chip for [groupId], or `all`.
  static Key chipKey(String groupId) => ValueKey<String>('picker-chip-$groupId');

  @override
  ConsumerState<ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<ExercisePickerSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  /// A parent muscle group id, or null for every exercise.
  String? _group;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _matchesGroup(Exercise exercise) =>
      _group == null || exercise.primary.any((id) => id.startsWith('$_group/'));

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(exerciseIndexProvider);
    final session = ref.watch(activeSessionProvider);
    final saved = ref.watch(savedSessionsProvider);
    final inWorkout = <String>{
      for (final e in session?.exercises ?? const []) e.exerciseId,
    };

    // A blank query is the whole library: `searchByName` answers a blank query
    // with nothing, which suits a search box but not a list to pick from.
    final matching =
        _query.trim().isEmpty ? index.all : index.searchByName(_query);
    final results = matching.where(_matchesGroup).toList();
    final planned = <Exercise>[
      for (final e in session?.exercises ?? const [])
        if (index.byId(e.exerciseId) case final exercise?)
          if (results.contains(exercise)) exercise,
    ];
    final others = <Exercise>[
      for (final exercise in results)
        if (!inWorkout.contains(exercise.id)) exercise,
    ];

    return Padding(
      // Lifts the sheet over the keyboard so the field being typed in stays
      // visible.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Semantics(
                header: true,
                child: Text(
                  widget.title,
                  key: ExercisePickerSheet.titleKey,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: AppPalette.textPrimary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: MuscleSearchField.editable(
                controller: _controller,
                autofocus: false,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: <Widget>[
                  _GroupChip(
                    key: ExercisePickerSheet.chipKey('all'),
                    label: 'All',
                    selected: _group == null,
                    onTap: () => setState(() => _group = null),
                  ),
                  for (final groupId in kMuscleTaxonomy.keys)
                    _GroupChip(
                      key: ExercisePickerSheet.chipKey(groupId),
                      label: kMuscleGroupLabels[groupId] ?? groupId,
                      selected: _group == groupId,
                      onTap: () => setState(() => _group = groupId),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  4,
                  18,
                  18 + MediaQuery.paddingOf(context).bottom,
                ),
                children: <Widget>[
                  if (planned.isNotEmpty) ...<Widget>[
                    const _SectionLabel('IN THIS WORKOUT'),
                    for (final exercise in planned) _row(exercise, saved),
                  ],
                  if (others.isNotEmpty) ...<Widget>[
                    _SectionLabel(planned.isEmpty ? 'EXERCISES' : 'ADD ANOTHER'),
                    for (final exercise in others) _row(exercise, saved),
                  ],
                  if (planned.isEmpty && others.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No exercise matches.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Exercise exercise, List<WorkoutSession> saved) => KeyedSubtree(
        key: ExercisePickerSheet.rowKey(exercise.id),
        child: ExerciseRow(
          name: exercise.name,
          equipment: exercise.equipment,
          subtitle: _lastSetLine(exercise, saved),
          onTap: () => Navigator.of(context).pop(exercise),
        ),
      );

  /// What the user last did with this exercise, or null when they never have.
  ///
  /// The weight they used last time is what decides which of several
  /// alternatives to reach for, so it sits on the row rather than a tap away.
  String? _lastSetLine(Exercise exercise, List<WorkoutSession> saved) {
    final last = lastSessionOf(exercise.id, saved);
    if (last == null) return null;
    final logged =
        last.exercises.firstWhere((e) => e.exerciseId == exercise.id);
    final completed = logged.completedSets.toList();
    if (completed.isEmpty) return null;
    return 'Last ${formatSet(logged.loadType, completed.last)}';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 2),
        child: Semantics(
          header: true,
          child: Text(text, style: kLandingSectionLabelStyle),
        ),
      );
}

/// One muscle in the filter row. The selected one is the active accent, like a
/// selected tab: it is the one thing on the row that is "on".
class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: selected ? AppPalette.mutedSurface : AppPalette.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? AppPalette.accentStrong : AppPalette.border,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? AppPalette.accentStrong
                      : AppPalette.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
}
