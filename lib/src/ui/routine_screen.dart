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

/// One routine: read it, change it, start it. **One screen, not two.**
///
/// There used to be a detail screen and a builder. The detail screen's only
/// unique element was the Start button — everything else it showed, it showed
/// *worse*: `1 set` where the builder shows the actual targets. A read-only
/// view that is a poorer rendering of the editable one is a tap the user pays
/// for nothing.
///
/// The app already had the precedent. `SessionSummaryScreen` is explicitly
/// "not a read-only viewer": the screen you land on after finishing and the
/// one you open from History are the same component. This is that rule applied
/// to routines.
///
/// **It writes as you go, so there is no Save.** Every add, every target and
/// every note reaches disk as it happens — a builder holding fifteen minutes of
/// work in memory loses it to a phone call. Back is the only way out it needs,
/// and the title commits when it loses focus.
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

  /// A planned set's input. [column] is 0 for the first field (weight, assist
  /// or time) and 1 for reps — the same order the headings read in.
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

  /// Creates the routine on the first thing added to it, not on arrival.
  ///
  /// The same rule the ad-hoc session path follows: a user who opens this and
  /// backs straight out should not find an empty routine on their landing.
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
      title: widget.routineId == null ? 'New routine' : 'Routine',
      actions: <Widget>[
        if (routine != null) _RoutineScreenMenu(routine: routine),
      ],
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: AppMetrics.gapSnug),
          const _SectionLabel('ROUTINE NAME'),
          TextField(
            key: RoutineScreen.titleKey,
            controller: _title,
            focusNode: _titleFocus,
            maxLength: 40,
            onSubmitted: (_) => _titleFocus.unfocus(),
            style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: AppPalette.mutedSurface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppMetrics.gap, vertical: AppMetrics.gap),
              hintText: 'Push day',
              hintStyle:
                  const TextStyle(color: AppPalette.textMuted, fontSize: 17),
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
                borderSide: const BorderSide(
                    color: AppPalette.accentStrong, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppMetrics.gapCard),
          // **Start leads, even on a screen you can edit.** Running the routine
          // is what it is for; changing it is what you do on the way past.
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
          if (routine != null && !routine.isEmpty) ...<Widget>[
            const SizedBox(height: AppMetrics.gapSnug),
            Center(
              child: Text(
                _meta(routine),
                style: const TextStyle(
                    color: AppPalette.textMuted, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: AppMetrics.gapSection),
          if (isEmpty)
            const Padding(
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
                      style: TextStyle(
                          color: AppPalette.textSecondary, fontSize: 14)),
                ],
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
      // A new exercise opens with one planned set, as Hevy's does — an
      // exercise with no sets is a plan that says nothing.
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
              SizedBox(
                width: AppMetrics.touchTarget,
                height: AppMetrics.touchTarget,
                child: IconButton(
                  tooltip: 'Remove $name',
                  icon: const Icon(Icons.close,
                      size: 20, color: AppPalette.textSecondary),
                  onPressed: () => notifier.removeExercise(exercise.id),
                ),
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
              const SizedBox(width: AppMetrics.touchTarget),
            ],
          ),
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
    _focus.addListener(_commitOnBlur);
  }

  void _commitOnBlur() {
    if (_focus.hasFocus || !mounted) return;
    ref.read(routineListProvider.notifier).setExerciseNotes(
          routineExerciseId: widget.exercise.id,
          notes: _controller.text,
        );
  }

  /// **Removed before the node is disposed, and guarded on `mounted`.**
  /// Disposing a `FocusNode` that currently has focus notifies its listeners,
  /// and a listener that reaches for `ref` at that moment is reading the
  /// element tree while it is being torn down — which throws "Looking up a
  /// deactivated widget's ancestor is unsafe". The commit has to happen while
  /// the widget is still alive, so it happens on blur and the teardown path is
  /// made silent.
  @override
  void dispose() {
    _focus.removeListener(_commitOnBlur);
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
      padding: const EdgeInsets.symmetric(vertical: AppMetrics.gapTight),
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
              fieldKey: RoutineScreen.targetFieldKey(widget.set.id, 0),
              allowsColon: !showsSecond,
            ),
          ),
          if (showsSecond)
            Expanded(
              child: _field(
                _second,
                fieldKey: RoutineScreen.targetFieldKey(widget.set.id, 1),
              ),
            ),
          SizedBox(
            width: AppMetrics.touchTarget,
            height: AppMetrics.touchTarget,
            child: IconButton(
              tooltip: 'Remove set ${widget.index + 1}',
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
              const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          filled: true,
          fillColor: AppPalette.mutedSurface,
          hintText: '—',
          hintStyle: const TextStyle(color: AppPalette.textMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppMetrics.radiusField),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppMetrics.radiusField),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}


/// A section label, shared by the builder's fields.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppMetrics.gapLabel),
        child: Text(text,
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            )),
      );
}
