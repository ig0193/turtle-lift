import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise.dart';
import '../data/exercise_index.dart';
import '../data/load_type.dart';
import '../data/personal_best.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'exercise_detail_screen.dart';
import 'exercise_history_screen.dart';
import 'ghost_button.dart';
import 'haptics.dart';
import 'muscle_exercise_list_screen.dart'
    show RowTagChip, exerciseEquipmentLabel;
import 'set_row.dart';

/// Where sets are logged. The app's most-used screen.
///
/// **The order is fixed, and it puts the inputs first**: sets, then Add set,
/// then Mark exercise done, then the last two sessions, then the link to the
/// full history. An earlier draft put a "Last time" line above the sets and it
/// pushed the actual inputs down for information the muted prefills already
/// carry inline.
///
/// **Reference material sits below the actions, and the (i) button is the way
/// to more of it.** Routing every logging action through the exercise's page
/// would tax the majority who already know the lift.
class SetLoggingScreen extends ConsumerStatefulWidget {
  const SetLoggingScreen({
    required this.sessionExerciseId,
    this.savedSessionId,
    super.key,
  });

  /// The row this screen logs.
  final String sessionExerciseId;

  /// Set when correcting a workout that is already saved.
  ///
  /// **The same screen, pointed at a past session.** `docs/01` is explicit that
  /// session detail is not a separate read-only viewer that would drift from
  /// the live one — so the screen that logs a set is the screen that fixes a
  /// mistyped one, months later.
  final String? savedSessionId;

  /// Whether this is correcting history rather than logging now.
  bool get isEditingSaved => savedSessionId != null;

  /// The key a test taps to add a set.
  static const Key addSetKey = ValueKey<String>('add-set');

  /// The key a test taps to mark the exercise done.
  static const Key markDoneKey = ValueKey<String>('mark-exercise-done');

  /// The pinned bar that holds [markDoneKey].
  static const Key markDoneBarKey = ValueKey<String>('mark-done-bar');

  /// The key a test taps to open the full history.
  static const Key seeAllKey = ValueKey<String>('see-all-sessions');

  @override
  ConsumerState<SetLoggingScreen> createState() => _SetLoggingScreenState();
}

class _SetLoggingScreenState extends ConsumerState<SetLoggingScreen> {
  /// Rows the user asked for beyond what history suggests.
  int _addedRows = 0;

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(exerciseIndexProvider);
    final saved = ref.watch(savedSessionsProvider);
    final session = widget.isEditingSaved
        ? saved.where((s) => s.id == widget.savedSessionId).firstOrNull
        : ref.watch(activeSessionProvider);

    final sessionExercise = session?.exercises
        .where((e) => e.id == widget.sessionExerciseId)
        .firstOrNull;
    if (session == null || sessionExercise == null) {
      // The session ended underneath this screen — finished from elsewhere, or
      // the exercise was removed. Nothing to log against.
      return const AppScreen.pushed(title: 'Log', body: SizedBox.shrink());
    }

    final library = index.byId(sessionExercise.exerciseId);
    final loadType = sessionExercise.loadType ?? LoadType.weighted;

    return AppScreen.pushed(
      title: library?.name ?? 'Exercise',
      actions: <Widget>[
        if (library != null) _InfoButton(exercise: library),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: ListView(
              // With the pinned bar below, the bar owns the bottom inset and
              // the list only needs its own air.
              padding: widget.isEditingSaved
                  ? screenScrollPadding(context)
                  : screenScrollPadding(context)
                      .copyWith(bottom: kScreenGutter),
              children: <Widget>[
                if (library != null)
                  _FactsRow(exercise: library, loadType: loadType),
                if (loadType == LoadType.assisted) const _AssistedBanner(),
                const SizedBox(height: 4),
                ..._setRows(session, sessionExercise, loadType, saved),
                GhostButton(
                  buttonKey: SetLoggingScreen.addSetKey,
                  label: 'Add set',
                  leadingIcon: Icons.add_rounded,
                  onTap: () => setState(() => _addedRows++),
                ),
                ..._recentBlock(sessionExercise.exerciseId, saved),
              ],
            ),
          ),
          if (!widget.isEditingSaved)
            _MarkDoneBar(
              child: _MarkDoneButton(
                enabled: sessionExercise.sets
                    .any((s) => isSetComplete(loadType, s)),
                markedDone: sessionExercise.markedDone,
                onTap: () async {
                  await ref
                      .read(activeSessionProvider.notifier)
                      .markExerciseDone(widget.sessionExerciseId, true);
                  AppHaptics.success();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  /// The rows on screen: every set already written, then as many prefilled
  /// guesses as history suggests, then whatever the user added.
  ///
  /// **A row that exists in storage is the user's; one that does not is a
  /// guess.** That is the whole of the touched rule — a separate flag would be
  /// lost on navigating away and on restart.
  List<Widget> _setRows(
    WorkoutSession session,
    SessionExercise exercise,
    LoadType loadType,
    List<WorkoutSession> saved,
  ) {
    final stored = exercise.sets;
    // Both derived on every build from history, never stored (research items
    // 3 and 5). Correcting a saved workout compares it with what came before
    // it, never with itself.
    final pbIndex = personalBestSetIndex(exercise, session.performedOn, saved);
    final before = widget.isEditingSaved ? session.performedOn : null;
    final suggested = openingRowCount(exercise.exerciseId, saved);
    final total = <int>[stored.length, suggested].reduce((a, b) => a > b ? a : b) +
        _addedRows;

    return <Widget>[
      for (var i = 0; i < total; i++)
        Builder(
          builder: (context) {
            final isStored = i < stored.length;
            final entry = isStored
                ? stored[i]
                : _ghostFor(exercise.exerciseId, i, loadType, saved, stored);
            final last =
                lastTimeSetAt(exercise.exerciseId, i, saved, before: before);
            return SetRow(
              lastTime: last?.label,
              // Copied only when it was logged under the same load type, so
              // an assistance figure can never land in a weight field.
              onUseLast: last == null || last.loadType != loadType
                  ? null
                  : () => _write(
                        exercise,
                        i,
                        SetEntry(
                          id: entry.id,
                          position: entry.position,
                          completed: entry.completed,
                          weightKg: last.set.weightKg,
                          reps: last.set.reps,
                          addedKg: last.set.addedKg,
                          assistKg: last.set.assistKg,
                          durationSec: last.set.durationSec,
                        ),
                        isStored,
                      ),
              isPersonalBest: isStored && pbIndex == i,
              key: ValueKey<String>('row-${exercise.id}-$i'),
              index: i,
              loadType: loadType,
              entry: entry,
              isPrefill: !isStored,
              onChanged: (next) => _write(exercise, i, next, isStored),
              onToggleComplete: () => _write(
                exercise,
                i,
                _toggled(entry),
                isStored,
              ),
              onDelete: () => isStored
                  ? (widget.isEditingSaved
                      ? ref
                          .read(activeSessionProvider.notifier)
                          .deleteSavedSet(entry.id)
                      : ref
                          .read(activeSessionProvider.notifier)
                          .deleteSet(entry.id))
                  : setState(() {
                      if (_addedRows > 0) _addedRows--;
                    }),
            );
          },
        ),
    ];
  }

  SetEntry _toggled(SetEntry entry) => SetEntry(
        id: entry.id,
        position: entry.position,
        completed: !entry.completed,
        weightKg: entry.weightKg,
        reps: entry.reps,
        addedKg: entry.addedKg,
        assistKg: entry.assistKg,
        durationSec: entry.durationSec,
      );

  /// A guess for row [i]: the same set index of the last session of this
  /// exercise, or the previous row of this session once the user is past what
  /// history covers.
  SetEntry _ghostFor(
    String exerciseId,
    int i,
    LoadType loadType,
    List<WorkoutSession> saved,
    List<SetEntry> stored,
  ) {
    final fromHistory = prefillFor(exerciseId, i, saved);
    final fromThisSession = stored.isNotEmpty ? stored.last : null;
    final source = stored.isNotEmpty ? fromThisSession : fromHistory;
    return SetEntry(
      id: 'ghost-$i',
      position: i,
      completed: false,
      weightKg: source?.weightKg,
      reps: source?.reps,
      addedKg: source?.addedKg,
      assistKg: source?.assistKg,
      durationSec: source?.durationSec,
    );
  }

  Future<void> _write(
    SessionExercise exercise,
    int position,
    SetEntry value,
    bool isStored,
  ) async {
    final notifier = ref.read(activeSessionProvider.notifier);
    if (widget.isEditingSaved) {
      await notifier.editSavedSet(
        sessionExerciseId: exercise.id,
        position: position,
        setId: isStored ? value.id : null,
        completed: value.completed,
        weightKg: value.weightKg,
        reps: value.reps,
        addedKg: value.addedKg,
        assistKg: value.assistKg,
        durationSec: value.durationSec,
      );
      if (!isStored && _addedRows > 0) setState(() => _addedRows--);
      return;
    }
    await notifier.writeSet(
          sessionExerciseId: exercise.id,
          position: position,
          setId: isStored ? value.id : null,
          completed: value.completed,
          weightKg: value.weightKg,
          reps: value.reps,
          addedKg: value.addedKg,
          assistKg: value.assistKg,
          durationSec: value.durationSec,
        );
    // The row now exists in storage, so it stops being a guess and the ghost
    // that stood in for it is no longer needed.
    if (!isStored && _addedRows > 0) setState(() => _addedRows--);
  }

  /// The last two sessions, each with all of its sets.
  ///
  /// **Absent entirely when there are none**, following the landing's rule that
  /// an empty group is no group rather than a heading over nothing. Every
  /// exercise is in this state the first time it is logged, so this is the
  /// common case rather than an edge one.
  List<Widget> _recentBlock(String exerciseId, List<WorkoutSession> saved) {
    final history = saved
        .where((s) => s.exercises.any((e) =>
            e.exerciseId == exerciseId &&
            e.sets.any((set) => isSetComplete(e.loadType, set))))
        .toList();
    if (history.isEmpty) return const <Widget>[];

    final recent = history.take(2);
    return <Widget>[
      const SizedBox(height: 24),
      const Text('Recent', style: kLandingSectionLabelStyle),
      const SizedBox(height: 8),
      for (final session in recent)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _shortDate(session),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppPalette.textMuted,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
              Flexible(
                child: Text(
                  formatSetList(session.exercises
                      .firstWhere((e) => e.exerciseId == exerciseId)),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppPalette.textSecondary,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 4),
      GhostButton(
        buttonKey: SetLoggingScreen.seeAllKey,
        label: 'See all ${history.length} '
            '${history.length == 1 ? 'session' : 'sessions'}',
        trailingIcon: Icons.chevron_right_rounded,
        onTap: () => pushExerciseHistory(context, exerciseId),
      ),
    ];
  }

  static String _shortDate(WorkoutSession session) {
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final date = session.performedOn;
    return '${date.day} ${months[date.month - 1]}';
  }
}

/// Equipment and what a set of this exercise consists of.
class _FactsRow extends StatelessWidget {
  const _FactsRow({required this.exercise, required this.loadType});

  final Exercise exercise;
  final LoadType loadType;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Wrap(
          children: <Widget>[
            RowTagChip(label: exerciseEquipmentLabel(exercise.equipment)),
            const RowTagChip(label: ' · '),
            RowTagChip(label: _shape),
          ],
        ),
      );

  String get _shape => switch (loadType) {
        LoadType.weighted => 'Weight × reps',
        LoadType.bodyweight => 'Reps',
        LoadType.assisted => 'Assist × reps',
        LoadType.timed => 'Duration',
      };
}

/// The one place the inverted record is explained rather than only encoded.
class _AssistedBanner extends StatelessWidget {
  const _AssistedBanner();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppPalette.mutedSurface,
          border: Border.all(color: AppPalette.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Less assistance is better. Your record is the lightest assist '
          'you’ve used.',
          style: TextStyle(fontSize: 13, color: AppPalette.textSecondary),
        ),
      );
}

class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.exercise});

  final Exercise exercise;

  // From here the page offers nothing: the user is already logging it.
  void _open(BuildContext context) => pushExerciseDetail(context, exercise,
      entry: ExerciseDetailEntry.fromLogging);

  /// The key a test taps to open the exercise's page.
  static const Key infoKey = ValueKey<String>('exercise-info');

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: 'How to do it',
        onTap: () => _open(context),
        excludeSemantics: true,
        child: GestureDetector(
          key: infoKey,
          behavior: HitTestBehavior.opaque,
          onTap: () => _open(context),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.info_outline,
                size: 20, color: AppPalette.textSecondary),
          ),
        ),
      );
}

/// Available only once something has actually been logged.
///
/// Marking an exercise done with nothing recorded would fill the map and tick
/// the muscle for work the session would then discard at Finish.
class _MarkDoneButton extends StatelessWidget {
  const _MarkDoneButton({
    required this.enabled,
    required this.markedDone,
    required this.onTap,
  });

  final bool enabled;
  final bool markedDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        enabled: enabled,
        // The label the button shows, so VoiceOver does not say "Mark
        // exercise done" over a button reading "Done".
        label: markedDone ? 'Done' : 'Mark exercise done',
        onTap: enabled ? onTap : null,
        excludeSemantics: true,
        child: FilledButton(
          key: SetLoggingScreen.markDoneKey,
          onPressed: enabled ? onTap : null,
          child: Text(markedDone ? 'Done' : 'Mark exercise done'),
        ),
      );
}

/// The bottom bar Mark exercise done is pinned in.
///
/// **In thumb reach, always.** Between sets the phone is in one hand and the
/// thumb lives at the bottom; in the scroll the button sat at about 43% of a
/// Pro Max and drifted lower with every set. A pushed screen covers the tab
/// bar, so nothing hides behind this, and it clears the home indicator itself.
class _MarkDoneBar extends StatelessWidget {
  const _MarkDoneBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    return Container(
      key: SetLoggingScreen.markDoneBarKey,
      padding: EdgeInsets.fromLTRB(
        kScreenGutter + inset.left,
        8,
        kScreenGutter + inset.right,
        8 + inset.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppPalette.pageBackground,
        border: Border(top: BorderSide(color: AppPalette.border)),
      ),
      child: child,
    );
  }
}

