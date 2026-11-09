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
import 'custom_exercise_screens.dart' show showCustomExerciseEditor;
import 'muscle_exercise_list_screen.dart'
    show ExerciseRow, exerciseEquipmentLabel;
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
///
/// [alreadyChosen] leads the list instead of the open workout's exercises:
/// the template editor's swap passes the template's list.
Future<Exercise?> showExercisePicker(
  BuildContext context, {
  required String title,
  List<String>? alreadyChosen,
}) =>
    _showSheet<Exercise>(
      context,
      ExercisePickerSheet(title: title, alreadyChosen: alreadyChosen),
    );

/// Asks for **several** exercises at once — the template editor's picker.
///
/// Rows toggle instead of closing the sheet, and an `Add N` button returns the
/// ones chosen, in the order they were tapped. [alreadyChosen] (the template's
/// current list) is shown first and cannot be added twice. Null when
/// dismissed.
Future<List<Exercise>?> showMultiExercisePicker(
  BuildContext context, {
  required String title,
  required List<String> alreadyChosen,
}) =>
    _showSheet<List<Exercise>>(
      context,
      ExercisePickerSheet(
        title: title,
        multiSelect: true,
        alreadyChosen: alreadyChosen,
      ),
    );

Future<T?> _showSheet<T>(BuildContext context, Widget sheet) =>
    showModalBottomSheet<T>(
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
      builder: (_) => sheet,
    );

/// The sheet's contents: a search field, a muscle filter, and the exercises.
///
/// **The workout's own exercises come first**, under their own heading. On a
/// template session that is the plan, so the sheet opens as "here is what you
/// came to do" with everything else a scroll away; on an ad-hoc one it is the
/// exercises already added, which a user adding another wants out of the way
/// but still visible.
///
/// **Then what was logged lately** (Recent), then the rest of the library.
///
/// **The muscle filter is a filter, not a way through.** Muscles narrow the list
/// to what the user is looking for; they are never a level to navigate down, and
/// the Muscles tab remains where the app explains which exercise trains what.
class ExercisePickerSheet extends ConsumerStatefulWidget {
  const ExercisePickerSheet({
    required this.title,
    this.multiSelect = false,
    this.alreadyChosen,
    super.key,
  });

  final String title;

  /// Rows toggle and an Add button returns the list (the template editor).
  final bool multiSelect;

  /// The template's current exercises, in multi-select mode. Null means the
  /// open workout's exercises lead the list, as in a session.
  final List<String>? alreadyChosen;

  /// The row that creates a new exercise of the user's own (ADR 0009).
  static const Key createKey = ValueKey<String>('picker-create-exercise');

  /// The multi-select mode's Add button.
  static const Key addSelectedKey = ValueKey<String>('picker-add-selected');

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

  /// What multi-select mode has picked so far, in tap order.
  final List<Exercise> _picked = <Exercise>[];

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
    final leadIds = widget.alreadyChosen ??
        <String>[for (final e in session?.exercises ?? const []) e.exerciseId];
    final inWorkout = leadIds.toSet();

    // A blank query is the whole library. A typed one matches the name, the
    // equipment or a muscle, which is what the field's hint promises (the
    // audit found it matched names only, so "chest" found nothing).
    final needle = searchFold(_query);
    // A custom exercise the user hid is not offered (schema step 9), unless
    // it is already in this workout or template, where it must stay visible.
    final offered = <Exercise>[
      for (final exercise in index.all)
        if (!exercise.hidden || inWorkout.contains(exercise.id)) exercise,
    ];
    final matching = needle.isEmpty
        ? offered
        : <Exercise>[
            for (final exercise in offered)
              if (_matchesQuery(exercise, needle)) exercise,
          ];
    final results = matching.where(_matchesGroup).toList();
    final planned = <Exercise>[
      for (final id in leadIds)
        if (index.byId(id) case final exercise?)
          if (results.contains(exercise)) exercise,
    ];
    // The user's own exercises get their own group, so one they just made is
    // never lost among 260.
    final yours = <Exercise>[
      for (final exercise in results)
        if (exercise.isCustom && !inWorkout.contains(exercise.id)) exercise,
    ];
    // Recent: what the user logged lately, derived from saved sessions on
    // read. It follows the search and the filter like every other group, and
    // never repeats an exercise shown elsewhere in the sheet.
    final recent = <Exercise>[
      for (final id in recentExerciseIds(saved))
        if (!inWorkout.contains(id))
          if (index.byId(id) case final exercise?)
            if (!exercise.isCustom && results.contains(exercise)) exercise,
    ];
    final others = <Exercise>[
      for (final exercise in results)
        if (!inWorkout.contains(exercise.id) &&
            !recent.contains(exercise) &&
            !exercise.isCustom)
          exercise,
    ];
    final leadLabel =
        widget.alreadyChosen == null ? 'In this workout' : 'In this template';

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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Semantics(
                header: true,
                child: Text(
                  widget.title,
                  key: ExercisePickerSheet.titleKey,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: AppPalette.textPrimary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  _CreateRow(
                    query: _query.trim(),
                    onTap: () => _create(context),
                  ),
                  if (planned.isNotEmpty) ...<Widget>[
                    _SectionLabel(leadLabel),
                    for (final exercise in planned)
                      _row(exercise, saved, alreadyIn: widget.multiSelect),
                  ],
                  if (yours.isNotEmpty) ...<Widget>[
                    const _SectionLabel('Your exercises'),
                    for (final exercise in yours) _row(exercise, saved),
                  ],
                  if (recent.isNotEmpty) ...<Widget>[
                    const _SectionLabel('Recent'),
                    for (final exercise in recent) _row(exercise, saved),
                  ],
                  if (others.isNotEmpty) ...<Widget>[
                    _SectionLabel(planned.isEmpty && recent.isEmpty
                        ? 'Exercises'
                        : planned.isEmpty
                            ? 'All exercises'
                            : 'Add another'),
                    for (final exercise in others) _row(exercise, saved),
                  ],
                  if (planned.isEmpty &&
                      yours.isEmpty &&
                      recent.isEmpty &&
                      others.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No exercise called “${_query.trim()}”. '
                        'Try part of the name, a muscle or the equipment, '
                        'or create it above.',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppPalette.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.multiSelect)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  12 + MediaQuery.paddingOf(context).bottom,
                ),
                child: FilledButton(
                  key: ExercisePickerSheet.addSelectedKey,
                  onPressed: _picked.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                            List<Exercise>.unmodifiable(_picked),
                          ),
                  child: Text(_picked.isEmpty
                      ? 'Pick exercises to add'
                      : 'Add ${_picked.length} '
                          'exercise${_picked.length == 1 ? '' : 's'}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Makes a new exercise of the user's own and treats it as picked.
  Future<void> _create(BuildContext context) async {
    final made = await showCustomExerciseEditor(
      context,
      initialName: _query.trim(),
    );
    if (made == null || !context.mounted) return;
    if (widget.multiSelect) {
      setState(() {
        _picked.add(made);
        _controller.clear();
        _query = '';
      });
    } else {
      Navigator.of(context).pop(made);
    }
  }

  bool _matchesQuery(Exercise exercise, String needle) {
    if (searchMatches(exercise.name, needle)) return true;
    if (searchFold(exercise.equipment).contains(needle)) return true;
    for (final id in <String>[...exercise.primary, ...exercise.secondary]) {
      final muscle = kSubMuscleGroups[id];
      if (muscle == null) continue;
      if (searchFold(muscle.label).contains(needle)) return true;
      final parent = kMuscleGroupLabels[muscle.group];
      if (parent != null && searchFold(parent).contains(needle)) return true;
    }
    return false;
  }

  Widget _row(
    Exercise exercise,
    List<WorkoutSession> saved, {
    bool alreadyIn = false,
  }) {
    final last = _lastSetLine(exercise, saved);
    final subtitle = exercise.isCustom
        ? (last == null ? 'Yours' : 'Yours · $last')
        : last;
    if (!widget.multiSelect) {
      return KeyedSubtree(
        key: ExercisePickerSheet.rowKey(exercise.id),
        child: ExerciseRow(
          name: exercise.name,
          equipment: exercise.equipment,
          subtitle: subtitle,
          onTap: () => Navigator.of(context).pop(exercise),
        ),
      );
    }
    final picked = _picked.contains(exercise);
    return _PickRow(
      key: ExercisePickerSheet.rowKey(exercise.id),
      name: exercise.name,
      detail: <String>[
        exerciseEquipmentLabel(exercise.equipment),
        ?subtitle,
      ].join(' · '),
      state: alreadyIn
          ? _PickState.alreadyIn
          : picked
              ? _PickState.picked
              : _PickState.none,
      onTap: alreadyIn
          ? null
          : () => setState(() {
                if (!_picked.remove(exercise)) _picked.add(exercise);
              }),
    );
  }

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
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  fontSize: 13,
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

/// The first row of the picker: make an exercise the library does not have.
class _CreateRow extends StatelessWidget {
  const _CreateRow({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = query.isEmpty ? 'Create an exercise' : 'Create “$query”';
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: ExercisePickerSheet.createKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppPalette.border)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.add_rounded,
                  size: 20, color: AppPalette.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppPalette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PickState { none, picked, alreadyIn }

/// A row in multi-select mode: tapping toggles the check instead of closing.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.name,
    required this.detail,
    required this.state,
    required this.onTap,
    super.key,
  });

  final String name;
  final String detail;
  final _PickState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final checked = state != _PickState.none;
    return Semantics(
      container: true,
      button: onTap != null,
      checked: checked,
      label: '$name. $detail'
          '${state == _PickState.alreadyIn ? '. Already in the template' : ''}',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppPalette.border)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: state == _PickState.alreadyIn
                            ? AppPalette.textSecondary
                            : AppPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                checked
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: state == _PickState.picked
                    ? AppPalette.accentStrong
                    : AppPalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
