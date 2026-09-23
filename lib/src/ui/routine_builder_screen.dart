import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise_index.dart';
import '../data/load_type.dart';
import '../data/routine_store.dart';
import '../data/routines.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'exercise_picker_screen.dart';

/// Build or edit one routine.
///
/// **It writes as you go, and Save is only the way out.** A builder that held
/// the whole routine in memory until Save would lose fifteen minutes of work to
/// a phone call; every add, every target and every note goes to disk as it
/// happens, following `RoutineStore`'s rule. Cancel therefore leaves the
/// routine as edited rather than reverting it — which is why a *new* routine is
/// created up front and deleted on Cancel if nothing was added to it.
class RoutineBuilderScreen extends ConsumerStatefulWidget {
  const RoutineBuilderScreen({this.routineId, super.key});

  /// Null creates a new routine; a value edits that one.
  final String? routineId;

  static const Key titleKey = ValueKey<String>('routine-title');
  static const Key saveKey = ValueKey<String>('routine-save');
  static const Key addExerciseKey = ValueKey<String>('routine-add-exercise');
  static Key addSetKey(String routineExerciseId) =>
      ValueKey<String>('routine-add-set-$routineExerciseId');

  /// A planned set's input. [column] is 0 for the first field (weight, assist
  /// or time) and 1 for reps — the same order the headings read in.
  static Key targetFieldKey(String setId, int column) =>
      ValueKey<String>('routine-target-$setId-$column');

  @override
  ConsumerState<RoutineBuilderScreen> createState() =>
      _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends ConsumerState<RoutineBuilderScreen> {
  final TextEditingController _title = TextEditingController();
  String? _routineId;
  bool _creating = false;

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
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// Creates the routine on the first thing added to it, not on arrival.
  ///
  /// Same rule the ad-hoc session path follows: a user who opens the builder
  /// and backs straight out should not find an empty routine waiting for them
  /// on the landing.
  Future<String> _ensureRoutine() async {
    final existing = _routineId;
    if (existing != null) return existing;
    _creating = true;
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

    return AppScreen.pushed(
      title: widget.routineId == null ? 'Create routine' : 'Edit routine',
      actions: <Widget>[
        TextButton(
          key: RoutineBuilderScreen.saveKey,
          onPressed: () async {
            final id = _routineId;
            final name = _title.text.trim();
            if (id != null) {
              await ref
                  .read(routineListProvider.notifier)
                  .rename(id, name.isEmpty ? 'New routine' : name);
            }
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Save',
              style: TextStyle(
                  color: AppPalette.accentLight, fontWeight: FontWeight.w600)),
        ),
      ],
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          TextField(
            key: RoutineBuilderScreen.titleKey,
            controller: _title,
            style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Routine title',
              hintStyle:
                  TextStyle(color: AppPalette.textMuted, fontSize: 22),
            ),
          ),
          const Divider(color: AppPalette.border),
          if (routine == null || routine.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Get started by adding an exercise to your routine.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppPalette.textSecondary),
              ),
            )
          else
            for (final exercise in routine.exercises)
              _BuilderExerciseBlock(
                exercise: exercise,
                loadType: LoadType.fromName(
                      index.byId(exercise.exerciseId)?.loadType ?? '',
                    ) ??
                    LoadType.weighted,
                name: index.byId(exercise.exerciseId)?.name ??
                    exercise.exerciseId,
              ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: RoutineBuilderScreen.addExerciseKey,
            onPressed: _addExercises,
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.accentStrong,
              foregroundColor: AppPalette.onAccent,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add exercise'),
          ),
        ],
      ),
    );
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
      // A new exercise opens with one planned set, as Hevy's does — an
      // exercise with no sets is a plan that says nothing.
      await ref
          .read(routineListProvider.notifier)
          .addSet(routineExerciseId: rowId);
    }
    if (_creating) _creating = false;
  }
}

class _BuilderExerciseBlock extends ConsumerWidget {
  const _BuilderExerciseBlock({
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
    final headings = switch (loadType) {
      LoadType.weighted => const <String>['KG', 'REPS'],
      LoadType.bodyweight => const <String>['+KG', 'REPS'],
      LoadType.assisted => const <String>['ASSIST', 'REPS'],
      LoadType.timed => const <String>['TIME'],
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        color: AppPalette.accentLight,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppPalette.textSecondary),
                onPressed: () => notifier.removeExercise(exercise.id),
              ),
            ],
          ),
          _RoutineNotesField(exercise: exercise),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const SizedBox(
                width: 34,
                child: Text('SET',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppPalette.textMuted, fontSize: 11)),
              ),
              for (final heading in headings)
                Expanded(
                  child: Text(heading,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppPalette.textMuted, fontSize: 11)),
                ),
              const SizedBox(width: 40),
            ],
          ),
          for (final (i, set) in exercise.sets.indexed)
            _TargetRow(
              key: ValueKey<String>('target-${set.id}'),
              index: i,
              set: set,
              loadType: loadType,
            ),
          TextButton.icon(
            key: RoutineBuilderScreen.addSetKey(exercise.id),
            onPressed: () => notifier.addSet(routineExerciseId: exercise.id),
            icon: const Icon(Icons.add,
                size: 18, color: AppPalette.textSecondary),
            label: const Text('Add set',
                style: TextStyle(color: AppPalette.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _RoutineNotesField extends ConsumerStatefulWidget {
  const _RoutineNotesField({required this.exercise});

  final RoutineExercise exercise;

  @override
  ConsumerState<_RoutineNotesField> createState() => _RoutineNotesFieldState();
}

class _RoutineNotesFieldState extends ConsumerState<_RoutineNotesField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.exercise.notes ?? '');
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        ref.read(routineListProvider.notifier).setExerciseNotes(
              routineExerciseId: widget.exercise.id,
              notes: _controller.text,
            );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        focusNode: _focus,
        maxLines: null,
        style:
            const TextStyle(color: AppPalette.textSecondary, fontSize: 14),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: 'Add routine notes here',
          hintStyle: TextStyle(color: AppPalette.textMuted, fontSize: 14),
        ),
      );
}

/// One planned set. Blank is a legitimate value — see [RoutineSets].
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

  @override
  Widget build(BuildContext context) {
    final showsSecond = widget.loadType != LoadType.timed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Text('${widget.index + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppPalette.textPrimary)),
          ),
          Expanded(
            child: _field(
              _first,
              fieldKey: RoutineBuilderScreen.targetFieldKey(widget.set.id, 0),
              allowsColon: !showsSecond,
            ),
          ),
          if (showsSecond)
            Expanded(
              child: _field(
                _second,
                fieldKey: RoutineBuilderScreen.targetFieldKey(widget.set.id, 1),
              ),
            ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.close,
                  size: 18, color: AppPalette.textMuted),
              onPressed: () =>
                  ref.read(routineListProvider.notifier).deleteSet(widget.set.id),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    required Key fieldKey,
    bool allowsColon = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        key: fieldKey,
        controller: controller,
        onChanged: (_) => _commit(),
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(
              RegExp(allowsColon ? r'[0-9:]' : r'[0-9.]')),
        ],
        style: const TextStyle(color: AppPalette.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          filled: true,
          fillColor: AppPalette.mutedSurface,
          hintText: '-',
          hintStyle: const TextStyle(color: AppPalette.textMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppPalette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppPalette.border),
          ),
        ),
      ),
    );
  }
}
