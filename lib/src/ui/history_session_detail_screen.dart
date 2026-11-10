import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart' show savedSessionsProvider;
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/history_preview_data.dart' show sessionRecordsProvider;
import '../data/personal_best.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'exercise_history_screen.dart' show pushExerciseHistory;
import 'ghost_button.dart';
import 'session_card.dart';
import 'session_entry.dart' show doAgain;
import 'session_summary_screen.dart' show pushSessionSummary;

/// One logged session, opened from a History row.
///
/// **This is the read half.** Editing (title, `performedOn`, sets) and delete
/// live on `SessionSummaryScreen`; the Edit workout button at the foot of the
/// log opens it, so there is one editor and nothing for two of them to
/// disagree about.
///
/// **The card is [SessionCard], the same widget the editor shows** (audit
/// B3): the same muscles (primaries amber, secondaries steel, at sub-muscle
/// precision), the same figures and labels, the same date. Share in the
/// header sends that card as an image, as prototype 22 draws it: revisiting a
/// workout is "just as shareable" as finishing it (`docs/04`).
///
/// **The log is the reason to scroll past the card**, and each exercise in it
/// opens that exercise's history (audit B9): progress lives one tap from
/// wherever an exercise appears.
class HistorySessionDetailScreen extends ConsumerStatefulWidget {
  const HistorySessionDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  /// Finds one exercise block in the log.
  @visibleForTesting
  static Key exerciseKey(String name) => ValueKey<String>('log-$name');

  /// The route name a History row pushes this screen under, so a delete of
  /// [sessionId] can pop it too (`SessionSummaryScreen`).
  static String routeNameFor(String sessionId) => 'history-session/$sessionId';

  /// The button that opens the editable summary: title, date, sets, delete.
  static const Key editKey = ValueKey<String>('session-edit');

  /// The button that starts a new workout with this one's exercises.
  static const Key doAgainKey = ValueKey<String>('session-do-again');

  /// The header button that shares the card.
  static const Key shareKey = ValueKey<String>('session-detail-share');

  /// Finds the calorie figure.
  @visibleForTesting
  static const Key calorieKey = SessionCard.calorieKey;

  @override
  ConsumerState<HistorySessionDetailScreen> createState() =>
      _HistorySessionDetailScreenState();
}

class _HistorySessionDetailScreenState
    extends ConsumerState<HistorySessionDetailScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share(String name) async {
    if (_sharing) return;
    _sharing = true;
    try {
      await shareSessionCard(context, ref, boundaryKey: _cardKey, name: name);
    } finally {
      _sharing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedSessionsProvider);
    final session =
        saved.where((s) => s.id == widget.sessionId).firstOrNull;

    // The session can genuinely be gone — a delete elsewhere, or a stale route.
    // Popping would be worse than saying so.
    if (session == null) {
      return AppScreen.pushed(
        title: 'Workout',
        body: ListView(
          padding: screenScrollPadding(context),
          children: const <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'This workout is no longer in your history.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppPalette.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final index = ref.watch(exerciseIndexProvider);
    final name = resolvedTitle(session, index);
    final records =
        ref.watch(sessionRecordsProvider)[session.id] ?? SessionRecords.none;

    return AppScreen.pushed(
      title: name,
      actions: <Widget>[
        Semantics(
          container: true,
          button: true,
          label: 'Share card',
          onTap: () => _share(name),
          excludeSemantics: true,
          child: GestureDetector(
            key: HistorySessionDetailScreen.shareKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => _share(name),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.ios_share_rounded,
                size: 20,
                color: AppPalette.textPrimary,
              ),
            ),
          ),
        ),
      ],
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 10),
          RepaintBoundary(
            key: _cardKey,
            child: SessionCard(session: session),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: const Text('What you did', style: kLandingSectionLabelStyle),
          ),
          const SizedBox(height: 4),
          for (final exercise in session.exercises)
            if (exercise.sets.any((s) => isSetComplete(exercise.loadType, s)))
              _ExerciseBlock(
                key: HistorySessionDetailScreen.exerciseKey(
                    index.byId(exercise.exerciseId)?.name ??
                        'Unknown exercise'),
                exercise: exercise,
                name: index.byId(exercise.exerciseId)?.name ??
                    'Unknown exercise',
                recordSetId: records.recordSetIds[exercise.id],
                onTap: () => pushExerciseHistory(context, exercise.exerciseId),
              ),
          const SizedBox(height: 24),
          GhostButton(
            buttonKey: HistorySessionDetailScreen.doAgainKey,
            label: 'Do again',
            leadingIcon: Icons.replay_rounded,
            onTap: () => doAgain(context, ref, session),
          ),
          GhostButton(
            buttonKey: HistorySessionDetailScreen.editKey,
            label: 'Edit workout',
            leadingIcon: Icons.edit_outlined,
            onTap: () =>
                pushSessionSummary(context, widget.sessionId, editing: true),
          ),
        ],
      ),
    );
  }
}

/// One exercise and every set performed, with the record-setting set marked.
/// A link to that exercise's history.
class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({
    required this.exercise,
    required this.name,
    required this.recordSetId,
    required this.onTap,
    super.key,
  });

  final SessionExercise exercise;
  final String name;

  /// The set that beat the previous best, or null.
  final String? recordSetId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mark = recordSetId != null ? pbMarkLabel(exercise.loadType) : null;
    final note = exercise.note;
    return Semantics(
      container: true,
      button: true,
      label: <String>[name, ?mark, formatSetList(exercise), ?note].join('\n'),
      hint: 'See history',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppPalette.border)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppPalette.textPrimary,
                            ),
                          ),
                        ),
                        if (mark != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Text(mark, style: kPbMarkStyle),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    SessionSetLine(exercise: exercise, recordSetId: recordSetId),
                    if (note != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        note,
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppPalette.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppPalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
