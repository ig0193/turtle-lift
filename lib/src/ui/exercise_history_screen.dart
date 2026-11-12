import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/date_labels.dart';
import '../data/exercise_index.dart';
import '../data/exercise_progress.dart';
import '../data/history_preview_data.dart' show sessionRecordsProvider;
import '../data/local_date.dart';
import '../data/personal_best.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'exercise_progress_chart.dart';
import 'history_session_detail_screen.dart';
import 'muscle_exercise_list_screen.dart' show EquipmentChip;
import 'session_card.dart' show SessionSetLine;

/// Every session of one exercise, newest first.
///
/// **Sets are shown individually, never summarised.** `60kg × 10 · 60kg × 8 ·
/// 55kg × 10` shows the drop-off across a session, which a single "last: 60kg ×
/// 8" hides — and the drop-off is the thing someone reading their own history
/// is actually looking for.
///
/// **Records are marked where they happened.** This is the only place the whole
/// progression is visible at once, so marking the sessions that set a record is
/// what turns a log into a story.
class ExerciseHistoryScreen extends ConsumerStatefulWidget {
  const ExerciseHistoryScreen({required this.exerciseId, super.key});

  final String exerciseId;

  /// The key a test taps to load more.
  static const Key seeMoreKey = ValueKey<String>('history-see-more');

  /// One session's block, by session id.
  static Key sessionKey(String sessionId) =>
      ValueKey<String>('exercise-history-$sessionId');

  /// A range chip on the progress chart.
  static Key rangeKey(ProgressRange range) =>
      ValueKey<String>('progress-range-${range.name}');

  /// How many more sessions one tap of See more reveals.
  static const int pageSize = 20;

  @override
  ConsumerState<ExerciseHistoryScreen> createState() =>
      _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState
    extends ConsumerState<ExerciseHistoryScreen> {
  int _shown = ExerciseHistoryScreen.pageSize;

  /// The chart's range. In memory only: every visit opens on All.
  ProgressRange _range = ProgressRange.all;

  /// The trend, then the "Best at" table (audit #7, #8; ADR 0013).
  List<Widget> _progress(
    List<WorkoutSession> saved,
    Map<String, SessionRecords> records,
  ) {
    final series = exerciseProgressSeries(widget.exerciseId, saved, records);
    final shown = series.since(_range.from(LocalDate.today()));
    final bestAt = bestAtTable(widget.exerciseId, series.loadType, saved);
    return <Widget>[
      Semantics(
        header: true,
        child: const Text('Progress', style: kLandingSectionLabelStyle),
      ),
      const SizedBox(height: 8),
      if (series.points.length < 3)
        const Text(
          kTooFewForTrend,
          style: TextStyle(fontSize: 13, color: AppPalette.textMuted),
        )
      else ...<Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final range in ProgressRange.values)
              EquipmentChip(
                key: ExerciseHistoryScreen.rangeKey(range),
                label: range.label,
                selected: range == _range,
                onTap: () => setState(() => _range = range),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (shown.points.isEmpty)
          const Text(
            'Nothing logged in this range.',
            style: TextStyle(fontSize: 13, color: AppPalette.textMuted),
          )
        else
          ExerciseProgressChart(series: shown),
        if (series.inverted) ...<Widget>[
          const SizedBox(height: 6),
          const Text(
            'Less assistance is better, so lighter sits higher.',
            style: TextStyle(fontSize: 12, color: AppPalette.textMuted),
          ),
        ],
      ],
      if (bestAt.isNotEmpty) ...<Widget>[
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: const Text('Best at', style: kLandingSectionLabelStyle),
        ),
        const SizedBox(height: 4),
        for (final row in bestAt)
          Semantics(
            container: true,
            label: '${row.label}, ${row.value}',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppPalette.border)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      row.label,
                      style: const TextStyle(
                          fontSize: 13, color: AppPalette.textSecondary),
                    ),
                  ),
                  Text(
                    row.value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppPalette.textPrimary,
                      fontFeatures: <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      const SizedBox(height: 20),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedSessionsProvider);
    final records = ref.watch(sessionRecordsProvider);
    final index = ref.watch(exerciseIndexProvider);
    final library = index.byId(widget.exerciseId);

    final sessions = saved
        .where((s) => s.exercises.any((e) =>
            e.exerciseId == widget.exerciseId && e.completedSets.isNotEmpty))
        .toList()
      ..sort((a, b) {
        final byDate = b.performedOn.compareTo(a.performedOn);
        return byDate != 0 ? byDate : b.loggedAt.compareTo(a.loggedAt);
      });

    return AppScreen.pushed(
      title: library?.name ?? 'History',
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            // One muted line, not a grid of dashes: an empty grid reads as
            // broken where one line reads as a state.
            const Text(
              'You haven’t logged this yet.',
              style: TextStyle(fontSize: 13, color: AppPalette.textMuted),
            )
          else ...<Widget>[
            _SummaryStrip(sessions: sessions, exerciseId: widget.exerciseId),
            const SizedBox(height: 16),
            ..._progress(saved, records),
            Semantics(
              header: true,
              child: const Text('Sessions', style: kLandingSectionLabelStyle),
            ),
            for (final session in sessions.take(_shown))
              _SessionBlock(
                key: ExerciseHistoryScreen.sessionKey(session.id),
                session: session,
                exerciseId: widget.exerciseId,
                // The same cached projection the History rows and the
                // detail read, so all three mark the same sessions.
                recordSetId: records[session.id]?.recordSetIds[session
                    .exercises
                    .firstWhere((e) => e.exerciseId == widget.exerciseId)
                    .id],
              ),
            if (sessions.length > _shown)
              _SeeMore(
                onTap: () => setState(
                  () => _shown += ExerciseHistoryScreen.pageSize,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Total sessions, best, and when it was first logged.
class _SummaryStrip extends ConsumerWidget {
  const _SummaryStrip({required this.sessions, required this.exerciseId});

  final List<WorkoutSession> sessions;
  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = sessions.last;
    final bestLine = _best();

    return Text(
      '${sessions.length} '
      '${sessions.length == 1 ? 'session' : 'sessions'}'
      '${bestLine == null ? '' : ' · best $bestLine'}'
      // "First logged" is a fact about all time, so it always has its year.
      ' · first logged ${dateWithYearLabel(first.performedOn)}',
      style: const TextStyle(fontSize: 12, color: AppPalette.textMuted),
    );
  }

  String? _best() {
    SetEntry? bestSet;
    SetMetric? bestMetric;
    SessionExercise? holder;
    for (final session in sessions) {
      final exercise =
          session.exercises.firstWhere((e) => e.exerciseId == exerciseId);
      for (final set in exercise.completedSets) {
        final metric = metricFor(exercise.loadType, set);
        if (bestMetric == null || metric.compareTo(bestMetric) > 0) {
          bestMetric = metric;
          bestSet = set;
          holder = exercise;
        }
      }
    }
    if (bestSet == null || holder == null) return null;
    return formatSet(holder.loadType, bestSet);
  }
}

/// One session: when, and every set it held. Opens the read-only detail of
/// the workout it was part of (audit B9): a reader lands somewhere a tap
/// cannot change a set, and set logging → history → editor → set logging no
/// longer nests without end.
class _SessionBlock extends StatelessWidget {
  const _SessionBlock({
    required this.session,
    required this.exerciseId,
    required this.recordSetId,
    super.key,
  });

  final WorkoutSession session;
  final String exerciseId;

  /// The set that set a record in this session, or null.
  final String? recordSetId;

  @override
  Widget build(BuildContext context) {
    final exercise =
        session.exercises.firstWhere((e) => e.exerciseId == exerciseId);
    final mark = recordSetId != null ? pbMarkLabel(exercise.loadType) : null;
    void open() => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: RouteSettings(
              name: HistorySessionDetailScreen.routeNameFor(session.id),
            ),
            builder: (_) => HistorySessionDetailScreen(sessionId: session.id),
          ),
        );

    return Semantics(
      container: true,
      button: true,
      label: '${spokenDateLabel(session.performedOn)}, '
          '${formatSetList(exercise)}'
          '${mark == null ? '' : ', personal best'}',
      onTap: open,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        // A divider row like every other History list, not a bordered card
        // per session.
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
                        Text(
                          shortDateLabel(session.performedOn),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            agoLabel(session.performedOn),
                            style: const TextStyle(
                                fontSize: 12, color: AppPalette.textMuted),
                          ),
                        ),
                        if (mark != null) Text(mark, style: kPbMarkStyle),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SessionSetLine(exercise: exercise, recordSetId: recordSetId),
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

class _SeeMore extends StatelessWidget {
  const _SeeMore({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: 'See more',
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          key: ExerciseHistoryScreen.seeMoreKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'See more',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textPrimary,
                  ),
                ),
                SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppPalette.textSecondary,
                ),
              ],
            ),
          ),
        ),
      );
}

/// Pushes [exerciseId]'s full history.
Future<void> pushExerciseHistory(BuildContext context, String exerciseId) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseHistoryScreen(exerciseId: exerciseId),
      ),
    );
