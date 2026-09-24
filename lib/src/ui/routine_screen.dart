import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/exercise_index.dart';
import '../data/load_type.dart';
import '../data/routine_store.dart';
import '../data/routines.dart';
import '../data/set_format.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'destructive_confirmation.dart';
import 'exercise_picker_screen.dart';
import 'ghost_chip.dart';
import 'rest_timer.dart';

/// One routine: read it, change it, start it. **One screen, not two.**
///
/// There used to be a detail screen and a builder. The detail screen's only
/// unique element was the Start button — everything else it showed, it showed
/// *worse*: `1 set` where the builder showed the actual targets. The app
/// already had the rule written down: `SessionSummaryScreen` is explicitly
/// "not a read-only viewer".
///
/// **It writes as you go, so there is no Save.** Every add, every target and
/// every note reaches disk as it happens. The name lives in the header, where
/// the live workout's title lives, and commits when it loses focus.
///
/// **The chrome had to come down before this screen could hold a real
/// routine.** At eight exercises it rendered five rows of furniture each — a
/// name, a bordered notes field, a `SET · KG · REPS` header, one empty row and
/// an Add set — for one row of data. The headings are gone (each cell says its
/// own unit), notes and rest are ghost chips, and what is left is the plan.
class RoutineScreen extends ConsumerStatefulWidget {
  const RoutineScreen({this.routineId, super.key});

  /// Null creates a routine; a value opens that one.
  final String? routineId;

  static const Key titleKey = ValueKey<String>('routine-title');
  static const Key startKey = ValueKey<String>('routine-start');
  static const Key menuKey = ValueKey<String>('routine-screen-menu');
  static const Key addExerciseKey = ValueKey<String>('routine-add-exercise');
  static Key addSetKey(String routineExerciseId) =>
      ValueKey<String>('routine-add-set-$routineExerciseId');
  static Key exerciseMenuKey(String routineExerciseId) =>
      ValueKey<String>('routine-exercise-menu-$routineExerciseId');

  /// A planned set's input. [column] is 0 for the first field (weight, assist
  /// or time) and 1 for reps — the same order the cells read in.
  static Key targetFieldKey(String setId, int column) =>
      ValueKey<String>('routine-target-$setId-$column');

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  final TextEditingController _title = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  String? _routineId;

  @override
  void initState() {
    super.initState();
    _routineId = widget.routineId;
    if (_routineId != null) {
      final existing = ref
          .read(routinesProvider)
          .where((r) => r.id == _routineId)
          .firstOrNull;
      _title.text = existing?.name ?? '';
    }
    _titleFocus.addListener(_commitTitle);
  }

  /// Commits the name on blur. Removed before the node is disposed and guarded
  /// on `mounted`: disposing a focused `FocusNode` notifies its listeners, and
  /// a listener reaching for `ref` then is reading a tree being torn down.
  void _commitTitle() {
    if (_titleFocus.hasFocus || !mounted) return;
    final id = _routineId;
    if (id == null) return;
    final name = _title.text.trim();
    ref
        .read(routineListProvider.notifier)
        .rename(id, name.isEmpty ? 'New routine' : name);
  }

  @override
  void dispose() {
    _titleFocus.removeListener(_commitTitle);
    _title.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  /// Creates the routine on the first thing added to it, not on arrival — the
  /// same rule the ad-hoc session path follows.
  Future<String> _ensureRoutine() async {
    final existing = _routineId;
    if (existing != null) return existing;
    final created = await ref.read(routineListProvider.notifier).create(
          name: _title.text.trim().isEmpty ? 'New routine' : _title.text.trim(),
        );
    setState(() => _routineId = created.id);
    return created.id;
  }

  Routine? get _routine => _routineId == null
      ? null
      : ref.watch(routinesProvider).where((r) => r.id == _routineId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final routine = _routine;
    final index = ref.watch(exerciseIndexProvider);
    final isEmpty = routine == null || routine.isEmpty;

    return AppScreen.pushed(
      title: routine?.name ?? 'New routine',
      // **The name lives in the header**, where the live workout's title lives.
      // As a labelled field in the body it was a whole block of screen for one
      // word, and the header said "Routine" — a heading with nothing to say.
      titleWidget: _NameField(controller: _title, focusNode: _titleFocus),
      actions: <Widget>[
        if (routine != null) _RoutineScreenMenu(routine: routine),
      ],
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: AppMetrics.gapSnug),
          FilledButton(
            key: RoutineScreen.startKey,
            onPressed: isEmpty ? null : () => _start(context, routine, index),
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.accentStrong,
              foregroundColor: AppPalette.onAccent,
              disabledBackgroundColor: AppPalette.mutedSurface,
              disabledForegroundColor: AppPalette.textMuted,
              minimumSize: const Size.fromHeight(AppMetrics.controlHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppMetrics.radiusControl),
              ),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: Text(isEmpty ? 'Add an exercise to start' : 'Start routine'),
          ),
          const SizedBox(height: AppMetrics.gapSection),
          if (isEmpty)
            const _EmptyRoutine()
          else ...<Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text('EXERCISES',
                    style: TextStyle(
                      color: AppPalette.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    )),
                Text(_meta(routine),
                    style: const TextStyle(
                        color: AppPalette.textMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: AppMetrics.gapLabel),
            // Long-press an exercise to move it. A plan's order is the order
            // you do it in, so it has to be changeable without deleting.
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) {
                final ids =
                    routine.exercises.map((e) => e.id).toList(growable: true);
                ids.insert(newIndex, ids.removeAt(oldIndex));
                ref.read(routineListProvider.notifier).reorderExercises(ids);
              },
              children: <Widget>[
                for (final (i, exercise) in routine.exercises.indexed)
                  ReorderableDelayedDragStartListener(
                    key: ValueKey<String>('routine-exercise-${exercise.id}'),
                    index: i,
                    child: _RoutineExerciseBlock(
                      exercise: exercise,
                      loadType: LoadType.fromName(
                            index.byId(exercise.exerciseId)?.loadType ?? '',
                          ) ??
                          LoadType.weighted,
                      name: index.byId(exercise.exerciseId)?.name ??
                          exercise.exerciseId,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppMetrics.gap),
          OutlinedButton.icon(
            key: RoutineScreen.addExerciseKey,
            onPressed: _addExercises,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.accentLight,
              backgroundColor: AppPalette.surface,
              side: const BorderSide(color: AppPalette.border),
              minimumSize: const Size.fromHeight(AppMetrics.controlHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppMetrics.radiusControl),
              ),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add exercise'),
          ),
          const SizedBox(height: AppMetrics.gapSection),
        ],
      ),
    );
  }

  Future<void> _start(
    BuildContext context,
    Routine routine,
    ExerciseIndex index,
  ) async {
    // The title may still be focused with an uncommitted rename.
    _titleFocus.unfocus();
    await ref
        .read(activeSessionProvider.notifier)
        .startFromRoutine(routine, index);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _addExercises() async {
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        builder: (_) => const ExercisePickerScreen(),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    final routineId = await _ensureRoutine();
    for (final exerciseId in picked) {
      final rowId = await ref
          .read(routineListProvider.notifier)
          .addExercise(routineId: routineId, exerciseId: exerciseId);
      // A new exercise opens with one planned set: an exercise with no sets is
      // a plan that says nothing.
      await ref
          .read(routineListProvider.notifier)
          .addSet(routineExerciseId: rowId);
    }
  }
}

/// `2 exercises · 4 sets`.
String _meta(Routine routine) {
  final exercises = routine.exercises.length;
  final sets =
      routine.exercises.fold<int>(0, (total, e) => total + e.sets.length);
  return '$exercises exercise${exercises == 1 ? '' : 's'}'
      ' · $sets set${sets == 1 ? '' : 's'}';
}

/// The routine's name, in the header.
class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) => TextField(
        key: RoutineScreen.titleKey,
        controller: controller,
        focusNode: focusNode,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => focusNode.unfocus(),
        style: const TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          counterText: '',
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: 'Name this routine',
          hintStyle: TextStyle(color: AppPalette.textMuted, fontSize: 18),
        ),
      );
}

class _EmptyRoutine extends StatelessWidget {
  const _EmptyRoutine();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 24, bottom: AppMetrics.gapSection),
        child: Column(
          children: <Widget>[
            Icon(Icons.list_alt_outlined,
                size: 28, color: AppPalette.textMuted),
            SizedBox(height: AppMetrics.gap),
            Text('No exercises yet',
                style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: AppMetrics.gapTight + 2),
            Text('Add the lifts this routine plans',
                style:
                    TextStyle(color: AppPalette.textSecondary, fontSize: 14)),
          ],
        ),
      );
}

/// Duplicate and delete. Editing is the screen itself, so it is not in here.
class _RoutineScreenMenu extends ConsumerWidget {
  const _RoutineScreenMenu({required this.routine});

  final Routine routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: RoutineScreen.menuKey,
      icon: const Icon(Icons.more_horiz, color: AppPalette.textSecondary),
      color: AppPalette.surface,
      tooltip: 'Routine options',
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
            value: 'duplicate', child: Text('Duplicate')),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete routine',
              style: TextStyle(color: AppPalette.danger)),
        ),
      ],
      onSelected: (value) async {
        switch (value) {
          case 'duplicate':
            await ref.read(routineListProvider.notifier).duplicate(routine);
            if (context.mounted) Navigator.of(context).pop();
          case 'delete':
            final confirmed = await confirmDestructive(
              context,
              title: 'Delete ${routine.name}?',
              message: 'The routine and its planned sets are permanently '
                  'removed. Workouts you already logged from it are kept.',
              confirmLabel: 'Delete',
            );
            if (confirmed) {
              await ref.read(routineListProvider.notifier).delete(routine.id);
              if (context.mounted) Navigator.of(context).pop();
            }
        }
      },
    );
  }
}

/// One exercise in the plan.
class _RoutineExerciseBlock extends ConsumerWidget {
  const _RoutineExerciseBlock({
    required this.exercise,
    required this.loadType,
    required this.name,
  });

  final RoutineExercise exercise;
  final LoadType loadType;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(routineListProvider.notifier);
    final hasNote = (exercise.notes ?? '').trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppMetrics.gapSection),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                // Not accent: a name is not a state. See `00` §12.
                child: Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2)),
              ),
              _ExerciseMenu(exercise: exercise, name: name),
            ],
          ),
          Row(
            children: <Widget>[
              RestTimerChip(
                chipKey: RestTimerChip.lineKey(exercise.id),
                seconds: exercise.restTimerSec,
                onChanged: (seconds) => notifier.setExerciseRestTimer(
                  routineExerciseId: exercise.id,
                  seconds: seconds,
                ),
              ),
              const SizedBox(width: AppMetrics.gapSnug),
              _NoteChip(exercise: exercise, hasNote: hasNote),
            ],
          ),
          const SizedBox(height: AppMetrics.gapTight),
          for (final (i, set) in exercise.sets.indexed)
            _TargetRow(
              key: ValueKey<String>('target-${set.id}'),
              index: i,
              set: set,
              loadType: loadType,
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: AppMetrics.touchTarget,
              child: TextButton.icon(
                key: RoutineScreen.addSetKey(exercise.id),
                onPressed: () => notifier.addSet(routineExerciseId: exercise.id),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppMetrics.gapSnug),
                ),
                icon: const Icon(Icons.add,
                    size: 17, color: AppPalette.textSecondary),
                label: const Text('Add set',
                    style: TextStyle(
                        color: AppPalette.textSecondary, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseMenu extends ConsumerWidget {
  const _ExerciseMenu({required this.exercise, required this.name});

  final RoutineExercise exercise;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
        key: RoutineScreen.exerciseMenuKey(exercise.id),
        icon: const Icon(Icons.more_vert, color: AppPalette.textSecondary),
        color: AppPalette.surface,
        tooltip: 'Options for $name',
        itemBuilder: (_) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'remove',
            child: Text('Remove exercise',
                style: TextStyle(color: AppPalette.danger)),
          ),
        ],
        onSelected: (value) {
          if (value == 'remove') {
            ref.read(routineListProvider.notifier).removeExercise(exercise.id);
          }
        },
      );
}

/// The note, as a chip that becomes a field.
class _NoteChip extends ConsumerStatefulWidget {
  const _NoteChip({required this.exercise, required this.hasNote});

  final RoutineExercise exercise;
  final bool hasNote;

  @override
  ConsumerState<_NoteChip> createState() => _NoteChipState();
}

class _NoteChipState extends ConsumerState<_NoteChip> {
  @override
  Widget build(BuildContext context) => GhostChip(
        icon: Icons.notes_outlined,
        label: widget.hasNote ? 'Note' : 'Note',
        active: widget.hasNote,
        onTap: () => _edit(context),
      );

  Future<void> _edit(BuildContext context) async {
    final controller =
        TextEditingController(text: widget.exercise.notes ?? '');
    final saved = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppMetrics.gapCard,
          right: AppMetrics.gapCard,
          top: AppMetrics.gapCard,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom +
              AppMetrics.gapCard,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Note',
                style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: AppMetrics.gap),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              minLines: 2,
              style: const TextStyle(
                  color: AppPalette.textSecondary, fontSize: 15),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppPalette.mutedSurface,
                hintText: 'Cues, tempo, a link to a form video',
                hintStyle:
                    const TextStyle(color: AppPalette.textMuted, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppMetrics.radiusField),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppMetrics.gapCard),
            FilledButton(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(<String>[controller.text]),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.accentStrong,
                foregroundColor: AppPalette.onAccent,
                minimumSize:
                    const Size.fromHeight(AppMetrics.controlHeight),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppMetrics.radiusControl),
                ),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == null) return;
    await ref.read(routineListProvider.notifier).setExerciseNotes(
          routineExerciseId: widget.exercise.id,
          notes: saved.first,
        );
  }
}

/// One planned set. **No column headings above it** — each cell names its own
/// unit, so the table does not need a header repeated under every exercise.
class _TargetRow extends ConsumerStatefulWidget {
  const _TargetRow({
    required this.index,
    required this.set,
    required this.loadType,
    super.key,
  });

  final int index;
  final RoutineSet set;
  final LoadType loadType;

  @override
  ConsumerState<_TargetRow> createState() => _TargetRowState();
}

class _TargetRowState extends ConsumerState<_TargetRow> {
  late final TextEditingController _first = TextEditingController(
    text: widget.loadType == LoadType.timed
        ? (widget.set.targetDurationSec == null
            ? ''
            : formatDuration(widget.set.targetDurationSec!))
        : (widget.set.targetWeightKg == null
            ? ''
            : formatWeight(widget.set.targetWeightKg)),
  );
  late final TextEditingController _second = TextEditingController(
    text: widget.set.targetReps?.toString() ?? '',
  );

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _commit() {
    final isTimed = widget.loadType == LoadType.timed;
    ref.read(routineListProvider.notifier).updateSet(
          setId: widget.set.id,
          targetWeightKg: isTimed ? null : double.tryParse(_first.text),
          targetReps: int.tryParse(_second.text),
          targetDurationSec: isTimed ? _parseDuration(_first.text) : null,
        );
  }

  static int? _parseDuration(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (!text.contains(':')) return int.tryParse(text);
    final parts = text.split(':');
    if (parts.length != 2) return null;
    final m = int.tryParse(parts[0]);
    final s = int.tryParse(parts[1]);
    return (m == null || s == null) ? null : m * 60 + s;
  }

  /// What the first cell holds, in the unit the load type measures.
  String get _firstUnit => switch (widget.loadType) {
        LoadType.weighted => 'kg',
        LoadType.bodyweight => '+kg',
        LoadType.assisted => 'assist',
        LoadType.timed => 'time',
      };

  @override
  Widget build(BuildContext context) {
    final showsReps = widget.loadType != LoadType.timed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppMetrics.gapTight),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 26,
            child: Text('${widget.index + 1}',
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 13,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                )),
          ),
          Expanded(
            child: _cell(
              _first,
              fieldKey: RoutineScreen.targetFieldKey(widget.set.id, 0),
              unit: _firstUnit,
              allowsColon: !showsReps,
            ),
          ),
          if (showsReps) ...<Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppMetrics.gapSnug),
              child: Text('×',
                  style:
                      TextStyle(color: AppPalette.textMuted, fontSize: 14)),
            ),
            Expanded(
              child: _cell(
                _second,
                fieldKey: RoutineScreen.targetFieldKey(widget.set.id, 1),
                unit: 'reps',
              ),
            ),
          ],
          SizedBox(
            width: AppMetrics.touchTarget,
            height: AppMetrics.touchTarget,
            child: IconButton(
              tooltip: 'Remove set ${widget.index + 1}',
              icon: const Icon(Icons.close,
                  size: 17, color: AppPalette.textMuted),
              onPressed: () =>
                  ref.read(routineListProvider.notifier).deleteSet(widget.set.id),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(
    TextEditingController controller, {
    required Key fieldKey,
    required String unit,
    bool allowsColon = false,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      onChanged: (_) => _commit(),
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(
            RegExp(allowsColon ? r'[0-9:]' : r'[0-9.]')),
      ],
      style: const TextStyle(
        color: AppPalette.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 11, horizontal: AppMetrics.gapSnug),
        filled: true,
        fillColor: AppPalette.mutedSurface,
        // The unit is the hint, so an empty cell says what it wants rather
        // than showing a dash and making the user guess.
        hintText: unit,
        hintStyle: const TextStyle(color: AppPalette.textMuted, fontSize: 13),
        suffixText: controller.text.isEmpty ? null : unit,
        suffixStyle:
            const TextStyle(color: AppPalette.textMuted, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppMetrics.radiusField),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppMetrics.radiusField),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppMetrics.radiusField),
          borderSide:
              const BorderSide(color: AppPalette.accentStrong, width: 1.5),
        ),
      ),
    );
  }
}
