import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/exercise_index.dart';
import '../data/local_date.dart';
import '../data/personal_best.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'session_summary_screen.dart';

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

  /// How many more sessions one tap of See more reveals.
  static const int pageSize = 20;

  @override
  ConsumerState<ExerciseHistoryScreen> createState() =>
      _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState
    extends ConsumerState<ExerciseHistoryScreen> {
  int _shown = ExerciseHistoryScreen.pageSize;

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedSessionsProvider);
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
              style: TextStyle(fontSize: 13.5, color: AppPalette.textMuted),
            )
          else ...<Widget>[
            _SummaryStrip(sessions: sessions, exerciseId: widget.exerciseId),
            const SizedBox(height: 14),
            for (final session in sessions.take(_shown))
              _SessionBlock(
                session: session,
                exerciseId: widget.exerciseId,
                isRecord: isPersonalBest(
                  session.exercises
                      .firstWhere((e) => e.exerciseId == widget.exerciseId),
                  session,
                  saved,
                ),
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
      ' · first logged ${_shortDate(first.performedOn)}',
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

/// One session: when, and every set it held.
class _SessionBlock extends StatelessWidget {
  const _SessionBlock({
    required this.session,
    required this.exerciseId,
    required this.isRecord,
  });

  final WorkoutSession session;
  final String exerciseId;
  final bool isRecord;

  @override
  Widget build(BuildContext context) {
    final exercise =
        session.exercises.firstWhere((e) => e.exerciseId == exerciseId);

    return Semantics(
      button: true,
      label: '${_shortDate(session.performedOn)}, '
          '${formatSetList(exercise)}'
          '${isRecord ? ', personal best' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Opens the whole workout this was part of, so the user can see what
        // else they did that day.
        onTap: () => pushSessionSummary(context, session.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            border: Border.all(color: AppPalette.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    _shortDate(session.performedOn),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _relative(session.performedOn),
                      style: const TextStyle(
                          fontSize: 11, color: AppPalette.textMuted),
                    ),
                  ),
                  if (isRecord)
                    Text(
                      exercise.loadType?.name == 'assisted'
                          ? '★ PB · lightest assist'
                          : '★ PB',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.accentStrong,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final set in exercise.completedSets)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppPalette.mutedSurface,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        formatSet(exercise.loadType, set),
                        style: const TextStyle(
                            fontSize: 11.5, color: AppPalette.textSecondary),
                      ),
                    ),
                ],
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
        button: true,
        label: 'See more',
        excludeSemantics: true,
        child: GestureDetector(
          key: ExerciseHistoryScreen.seeMoreKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            child: const Text(
              'See more ›',
              style: TextStyle(fontSize: 14, color: AppPalette.textSecondary),
            ),
          ),
        ),
      );
}

String _shortDate(LocalDate date) {
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

String _relative(LocalDate date) {
  final days = LocalDate.today().daysAfter(date);
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  if (days < 14) return '1 week ago';
  if (days < 31) return '${days ~/ 7} weeks ago';
  if (days < 62) return '1 month ago';
  return '${days ~/ 30} months ago';
}

/// Pushes [exerciseId]'s full history.
Future<void> pushExerciseHistory(BuildContext context, String exerciseId) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseHistoryScreen(exerciseId: exerciseId),
      ),
    );
