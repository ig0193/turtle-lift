import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/exercise.dart';
import '../data/exercise_index.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';

/// Pick one or more exercises, with equipment and muscle filters.
///
/// **Multi-select, which the single-add search was not.** Building a routine or
/// opening a workout means naming five or six lifts; doing that one round trip
/// at a time is the difference between Hevy's picker and a search box, and it
/// is the reason this screen exists beside `exercise_search_screen.dart`.
///
/// Pops with the chosen ids, in the order they were ticked. Nothing is written
/// here — the caller decides whether they join a routine or a session, which
/// keeps one screen serving both.
///
/// **No Create.** Hevy lets a user add a custom exercise; `exercises.json` is
/// generated content with reviewed copy per exercise, and a user-typed row
/// would have none of it. See `CLAUDE.md`.
class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({this.preselectedGroupIds, super.key});

  /// Parent muscle groups to open filtered to — how a template becomes a
  /// starting point rather than a lock (`adr/0004`).
  final List<String>? preselectedGroupIds;

  static const Key searchKey = ValueKey<String>('picker-search');
  static const Key equipmentFilterKey = ValueKey<String>('picker-equipment');
  static const Key muscleFilterKey = ValueKey<String>('picker-muscle');
  static const Key addKey = ValueKey<String>('picker-add');
  static Key rowKey(String exerciseId) =>
      ValueKey<String>('picker-row-$exerciseId');

  @override
  ConsumerState<ExercisePickerScreen> createState() =>
      _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends ConsumerState<ExercisePickerScreen> {
  final TextEditingController _search = TextEditingController();
  final List<String> _selected = <String>[];
  String _query = '';
  final Set<String> _equipment = <String>{};
  late final Set<String> _groups = <String>{...?widget.preselectedGroupIds};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(exerciseIndexProvider);
    final matches = _matches(index);
    final recent = _recent(index, matches);

    return AppScreen.pushed(
      title: 'Add exercise',
      body: Stack(
        children: <Widget>[
          ListView(
            padding: screenScrollPadding(context),
            children: <Widget>[
              const SizedBox(height: 4),
              TextField(
                key: ExercisePickerScreen.searchKey,
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(color: AppPalette.textPrimary),
                decoration: const InputDecoration(
                  prefixIcon:
                      Icon(Icons.search, color: AppPalette.textMuted, size: 20),
                  hintText: 'Search exercise',
                  hintStyle: TextStyle(color: AppPalette.textMuted),
                  filled: true,
                  fillColor: AppPalette.mutedSurface,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _FilterButton(
                      buttonKey: ExercisePickerScreen.equipmentFilterKey,
                      label: _equipment.isEmpty
                          ? 'All equipment'
                          : _equipment.join(', '),
                      active: _equipment.isNotEmpty,
                      onTap: () => _pickEquipment(index),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FilterButton(
                      buttonKey: ExercisePickerScreen.muscleFilterKey,
                      label: _groups.isEmpty
                          ? 'All muscles'
                          : _groups.map(_groupLabel).join(', '),
                      active: _groups.isNotEmpty,
                      onTap: _pickMuscles,
                    ),
                  ),
                ],
              ),
              if (recent.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                const _SectionLabel('RECENT'),
                for (final exercise in recent) _row(exercise),
              ],
              const SizedBox(height: 16),
              _SectionLabel('ALL EXERCISES (${matches.length})'),
              for (final exercise in matches) _row(exercise),
              // Room for the floating Add button not to cover the last row.
              const SizedBox(height: 72),
            ],
          ),
          if (_selected.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: FilledButton(
                key: ExercisePickerScreen.addKey,
                onPressed: () => Navigator.of(context).pop(_selected),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.accentStrong,
                  foregroundColor: AppPalette.onAccent,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  _selected.length == 1
                      ? 'Add 1 exercise'
                      : 'Add ${_selected.length} exercises',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(Exercise exercise) {
    final selected = _selected.contains(exercise.id);
    return ListTile(
      key: ExercisePickerScreen.rowKey(exercise.id),
      contentPadding: EdgeInsets.zero,
      onTap: () => setState(() {
        if (selected) {
          _selected.remove(exercise.id);
        } else {
          _selected.add(exercise.id);
        }
      }),
      leading: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? AppPalette.accentStrong : AppPalette.textMuted,
      ),
      title: Text(exercise.name,
          style: const TextStyle(color: AppPalette.textPrimary)),
      subtitle: Text(
        // Equipment, not an illustration: `00` §13 still rules out per-exercise
        // artwork, and the equipment is what tells two variants apart anyway.
        '${exercise.equipment} · ${_primaryLabel(exercise)}',
        style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13),
      ),
    );
  }

  List<Exercise> _matches(ExerciseIndex index) {
    final query = _query.trim().toLowerCase();
    return index.all.where((exercise) {
      if (query.isNotEmpty && !exercise.name.toLowerCase().contains(query)) {
        return false;
      }
      if (_equipment.isNotEmpty && !_equipment.contains(exercise.equipment)) {
        return false;
      }
      if (_groups.isNotEmpty) {
        final parents = exercise.primary.map(_parentOf).toSet();
        if (!parents.any(_groups.contains)) return false;
      }
      return true;
    }).toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// The handful of exercises the user actually logs, lifted to the top.
  ///
  /// Derived from saved sessions rather than stored as a list, like everything
  /// else the app shows — a stored "recents" list would go stale the moment a
  /// session was deleted.
  List<Exercise> _recent(ExerciseIndex index, List<Exercise> matches) {
    if (_query.isNotEmpty) return const <Exercise>[];
    final saved = ref.watch(savedSessionsProvider);
    final seen = <String>[];
    for (final session in saved) {
      for (final exercise in session.exercises) {
        if (!seen.contains(exercise.exerciseId)) seen.add(exercise.exerciseId);
      }
      if (seen.length >= 5) break;
    }
    final allowed = matches.map((e) => e.id).toSet();
    return seen
        .where(allowed.contains)
        .map(index.byId)
        .whereType<Exercise>()
        .take(5)
        .toList(growable: false);
  }

  static String _parentOf(String subGroupId) => subGroupId.split('/').first;

  static String _groupLabel(String groupId) =>
      kMuscleGroupLabels[groupId] ?? groupId;

  static String _primaryLabel(Exercise exercise) => exercise.primary
      .map((id) => kSubMuscleGroups[id]?.label ?? id)
      .join(', ');

  Future<void> _pickEquipment(ExerciseIndex index) async {
    final options = index.all.map((e) => e.equipment).toSet().toList()..sort();
    await _showFilterSheet(
      title: 'Equipment',
      options: <String, String>{for (final o in options) o: o},
      selected: _equipment,
    );
  }

  Future<void> _pickMuscles() async {
    await _showFilterSheet(
      title: 'Muscle group',
      options: <String, String>{
        for (final id in kMuscleTaxonomy.keys) id: _groupLabel(id),
      },
      selected: _groups,
    );
  }

  /// One sheet for both filters: same grid, same Clear/Show pair, same
  /// multi-select. Two sheets would be two places for the count to go wrong.
  Future<void> _showFilterSheet({
    required String title,
    required Map<String, String> options,
    required Set<String> selected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surface,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title,
                    style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final entry in options.entries)
                          _FilterChip(
                            label: entry.value,
                            selected: selected.contains(entry.key),
                            onTap: () => setSheetState(() {
                              if (!selected.remove(entry.key)) {
                                selected.add(entry.key);
                              }
                              setState(() {});
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextButton(
                        onPressed: () => setSheetState(() {
                          selected.clear();
                          setState(() {});
                        }),
                        child: const Text('Clear filters',
                            style: TextStyle(color: AppPalette.textSecondary)),
                      ),
                    ),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.accentStrong,
                          foregroundColor: AppPalette.onAccent,
                        ),
                        child: Text(
                          'Show ${_matches(ref.read(exerciseIndexProvider)).length} results',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.buttonKey,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        key: buttonKey,
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor:
              active ? AppPalette.accentStrong : AppPalette.mutedSurface,
          side: const BorderSide(color: AppPalette.border),
          minimumSize: const Size.fromHeight(44),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? AppPalette.onAccent : AppPalette.textPrimary,
          ),
        ),
      );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:
                selected ? AppPalette.accentStrong : AppPalette.mutedSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppPalette.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppPalette.onAccent : AppPalette.textPrimary,
            ),
          ),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            )),
      );
}
