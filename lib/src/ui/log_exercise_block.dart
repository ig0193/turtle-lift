import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/load_type.dart';
import '../data/personal_best.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import 'destructive_confirmation.dart';
import 'exercise_detail_screen.dart';
import 'exercise_picker_screen.dart';
import 'rest_timer.dart';
import 'set_table_row.dart';

/// One exercise, inline on the Log Workout screen.
///
/// **This block is where the pushed set-logging screen went** (`adr/0004`). It
/// carries everything that screen did except its Recent history section: the
/// reference material stayed behind, because a list of past sessions under
/// every exercise would push the next exercise's inputs off a screen the user
/// is scrolling between sets.
class LogExerciseBlock extends ConsumerStatefulWidget {
  const LogExerciseBlock({
    required this.exercise,
    required this.session,
    super.key,
  });

  final SessionExercise exercise;
  final WorkoutSession session;

  static Key addSetKey(String exerciseRowId) =>
      ValueKey<String>('add-set-$exerciseRowId');
  static Key menuKey(String exerciseRowId) =>
      ValueKey<String>('exercise-menu-$exerciseRowId');
  static Key notesKey(String exerciseRowId) =>
      ValueKey<String>('exercise-notes-$exerciseRowId');
  static Key blockKey(String exerciseRowId) =>
      ValueKey<String>('exercise-block-$exerciseRowId');

  @override
  ConsumerState<LogExerciseBlock> createState() => _LogExerciseBlockState();
}

class _LogExerciseBlockState extends ConsumerState<LogExerciseBlock> {
  /// Rows the user has asked for beyond the ones storage and history imply.
  /// They stop being extra the moment one is written, which is why this counts
  /// down as well as up.
  int _addedRows = 0;

  SessionExercise get exercise => widget.exercise;

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(exerciseIndexProvider);
    final library = index.byId(exercise.exerciseId);
    final type = exercise.loadType ?? LoadType.weighted;
    final headings = SetTableRow.headingsFor(type);
    final saved = ref.watch(savedSessionsProvider);
    final previous = lastSessionOf(exercise.exerciseId, saved);
    final previousSets = previous?.exercises
            .where((e) => e.exerciseId == exercise.exerciseId)
            .expand((e) => e.sets)
            .where((s) => s.completed)
            .toList(growable: false) ??
        const <SetEntry>[];

    final stored = exercise.sets;
    final opening = openingRowCount(exercise.exerciseId, saved);
    final rowCount =
        (stored.length > opening ? stored.length : opening) + _addedRows;
    final isBestExercise = isPersonalBest(exercise, widget.session, saved);

    return Padding(
      key: LogExerciseBlock.blockKey(exercise.id),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  onTap: library == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ExerciseDetailScreen(exercise: library),
                            ),
                          ),
                  child: Text(
                    library?.name ?? exercise.exerciseId,
                    style: const TextStyle(
                      color: AppPalette.accentLight,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              _ExerciseMenu(exercise: exercise, session: widget.session),
            ],
          ),
          const SizedBox(height: 6),
          _NotesField(exercise: exercise),
          RestTimerLine(exercise: exercise),
          const SizedBox(height: 8),
          _HeadingRow(headings: headings),
          for (var i = 0; i < rowCount; i++)
            Builder(
              builder: (context) {
                final isStored = i < stored.length;
                final entry = isStored
                    ? stored[i]
                    : _ghostFor(i, type, saved, stored);
                return SetTableRow(
                  key: ValueKey<String>('row-${exercise.id}-$i'),
                  exerciseRowId: exercise.id,
                  index: i,
                  loadType: type,
                  entry: entry,
                  previous: i < previousSets.length
                      ? formatSet(type, previousSets[i])
                      : null,
                  isPersonalBest: isBestExercise && _isBestSet(type, i),
                  onChanged: (value) => _write(value, isStored: isStored),
                  onToggleComplete: () => _write(
                    _toggled(entry),
                    isStored: isStored,
                    startRest: !entry.completed,
                  ),
                  onDelete: () => isStored
                      ? ref
                          .read(activeSessionProvider.notifier)
                          .deleteSet(entry.id)
                      : setState(() {
                          if (_addedRows > 0) _addedRows--;
                        }),
                );
              },
            ),
          const SizedBox(height: 6),
          TextButton.icon(
            key: LogExerciseBlock.addSetKey(exercise.id),
            onPressed: () => setState(() => _addedRows++),
            icon:
                const Icon(Icons.add, size: 18, color: AppPalette.textSecondary),
            label: const Text('Add set',
                style: TextStyle(color: AppPalette.textSecondary)),
          ),
        ],
      ),
    );
  }

  /// A row that is not in storage yet, carrying last time's numbers as a guess.
  ///
  /// **Its id is deterministic, not random**, and that is load-bearing: the
  /// write path passes it straight through as the row's primary key, so two
  /// edits landing back to back update one row instead of inserting two. A
  /// fresh uuid per write would duplicate the set under a fast thumb.
  SetEntry _ghostFor(
    int i,
    LoadType type,
    List<WorkoutSession> saved,
    List<SetEntry> stored,
  ) {
    final source =
        stored.isNotEmpty ? stored.last : prefillFor(exercise.exerciseId, i, saved);
    return SetEntry(
      id: '${exercise.id}#$i',
      position: i,
      completed: false,
      weightKg: source?.weightKg,
      reps: source?.reps,
      addedKg: source?.addedKg,
      assistKg: source?.assistKg,
      durationSec: source?.durationSec,
    );
  }

  /// Whether set [i] is the one carrying the exercise's best metric, so the
  /// medal lands on the set that earned it rather than on every set.
  bool _isBestSet(LoadType type, int i) {
    if (i >= exercise.sets.length) return false;
    final best = bestOf(exercise);
    if (best == null) return false;
    return metricFor(exercise.loadType, exercise.sets[i]).compareTo(best) == 0;
  }

  static SetEntry _toggled(SetEntry entry) => SetEntry(
        id: entry.id,
        position: entry.position,
        completed: !entry.completed,
        weightKg: entry.weightKg,
        reps: entry.reps,
        addedKg: entry.addedKg,
        assistKg: entry.assistKg,
        durationSec: entry.durationSec,
      );

  Future<void> _write(
    SetEntry entry, {
    required bool isStored,
    bool startRest = false,
  }) async {
    // Ticking a set is what starts the rest. Unticking must not — the user is
    // correcting a mistake, not finishing a set.
    final seconds = exercise.restTimerSec;
    if (startRest && seconds != null) {
      ref.read(restTimerProvider.notifier).start(seconds);
    }
    await ref.read(activeSessionProvider.notifier).writeSet(
          sessionExerciseId: exercise.id,
          setId: entry.id,
          position: entry.position,
          completed: entry.completed,
          weightKg: entry.weightKg,
          reps: entry.reps,
          addedKg: entry.addedKg,
          assistKg: entry.assistKg,
          durationSec: entry.durationSec,
        );
    // The row exists in storage now, so the ghost that stood in for it is no
    // longer one of the extra rows.
    if (!isStored && _addedRows > 0 && mounted) {
      setState(() => _addedRows--);
    }
  }
}

class _HeadingRow extends StatelessWidget {
  const _HeadingRow({required this.headings});

  final List<String> headings;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppPalette.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: <Widget>[
          const SizedBox(
              width: 34,
              child: Text('SET', textAlign: TextAlign.center, style: style)),
          const Expanded(
            flex: 3,
            child:
                Text('PREVIOUS', textAlign: TextAlign.center, style: style),
          ),
          for (final heading in headings)
            Expanded(
              flex: 3,
              child:
                  Text(heading, textAlign: TextAlign.center, style: style),
            ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

/// The user's note for this exercise. Commits on blur, not per keystroke — a
/// write per character would be a database round trip per character.
class _NotesField extends ConsumerStatefulWidget {
  const _NotesField({required this.exercise});

  final SessionExercise exercise;

  @override
  ConsumerState<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends ConsumerState<_NotesField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.exercise.notes ?? '');
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        ref.read(activeSessionProvider.notifier).setExerciseNotes(
              sessionExerciseId: widget.exercise.id,
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
  Widget build(BuildContext context) {
    return TextField(
      key: LogExerciseBlock.notesKey(widget.exercise.id),
      controller: _controller,
      focusNode: _focus,
      maxLines: null,
      style: const TextStyle(color: AppPalette.textSecondary, fontSize: 14),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: 'Add notes here…',
        hintStyle: TextStyle(color: AppPalette.textMuted, fontSize: 14),
      ),
    );
  }
}

/// Reorder, replace and remove, as Hevy's per-exercise `⋮` menu.
class _ExerciseMenu extends ConsumerWidget {
  const _ExerciseMenu({required this.exercise, required this.session});

  final SessionExercise exercise;
  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = session.exercises.indexWhere((e) => e.id == exercise.id);
    final isFirst = index <= 0;
    final isLast = index >= session.exercises.length - 1;
    // Replacing re-snapshots the load type, which would reinterpret sets
    // already written against the old shape. Offered only while there are
    // none — see `SessionStore.replaceExercise`.
    final hasLoggedWork = exercise.sets.any((s) => s.completed);

    return PopupMenuButton<String>(
      key: LogExerciseBlock.menuKey(exercise.id),
      icon: const Icon(Icons.more_vert, color: AppPalette.textSecondary),
      color: AppPalette.surface,
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        if (!isFirst)
          const PopupMenuItem<String>(value: 'up', child: Text('Move up')),
        if (!isLast)
          const PopupMenuItem<String>(value: 'down', child: Text('Move down')),
        if (!hasLoggedWork)
          const PopupMenuItem<String>(
              value: 'replace', child: Text('Replace exercise')),
        const PopupMenuItem<String>(
          value: 'remove',
          child: Text('Remove exercise',
              style: TextStyle(color: AppPalette.danger)),
        ),
      ],
      onSelected: (value) async {
        final notifier = ref.read(activeSessionProvider.notifier);
        switch (value) {
          case 'up':
            await notifier.moveExercise(exercise.id, -1);
          case 'down':
            await notifier.moveExercise(exercise.id, 1);
          case 'replace':
            if (context.mounted) await _replace(context, ref);
          case 'remove':
            final confirmed = await confirmDestructive(
              context,
              title: 'Remove exercise?',
              message: 'Its logged sets go with it.',
              confirmLabel: 'Remove',
            );
            if (confirmed) await notifier.removeExercise(exercise.id);
        }
      },
    );
  }

  Future<void> _replace(BuildContext context, WidgetRef ref) async {
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        builder: (_) => const ExercisePickerScreen(),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    final library = ref.read(exerciseIndexProvider).byId(picked.first);
    if (library == null) return;
    await ref.read(activeSessionProvider.notifier).replaceExercise(
          sessionExerciseId: exercise.id,
          exerciseId: library.id,
          loadType: LoadType.fromName(library.loadType) ?? LoadType.weighted,
        );
  }
}
