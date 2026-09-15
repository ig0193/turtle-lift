import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/body_gender.dart';
import '../data/bodyweight_resolution.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../data/history_preview_data.dart';
import '../data/personal_details_store.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'body_diagram.dart';

/// One logged session, opened from a History row.
///
/// **This is the read half only.** `docs/04` specifies session detail as the
/// *same component as the live workout card* — editable title, editable
/// `performedOn`, editable sets, add and remove, and delete. All of that
/// belongs to the session-flow work
/// (`docs/plans/2026-09-14-2351-feat-workout-session-flow-plan.md`), which owns
/// the session tables and every `session_*.dart` file. Building an editor here
/// would collide with it and would be editing a fixture besides.
///
/// So this screen shows what a session *was*, from the same preview data the
/// History tab lists, and says nothing it cannot back up.
///
/// **The card is the shareable part; the log is the reason to scroll past it.**
/// `docs/04` draws that line explicitly: the card is a summary someone would
/// screenshot, and the exercise-by-exercise log underneath is for the user who
/// actually wants to review what they did. The personal-best count on the card
/// and the trophies in the log come from the same derivation, so the two can
/// never disagree.
class HistorySessionDetailScreen extends ConsumerWidget {
  const HistorySessionDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  /// Finds one exercise block in the log.
  @visibleForTesting
  static Key exerciseKey(String name) => ValueKey<String>('log-$name');

  /// Finds the calorie figure, or the prompt standing in for it.
  @visibleForTesting
  static const Key calorieKey = ValueKey<String>('session-calories');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historySessionsProvider);
    final session = sessions.where((s) => s.id == sessionId).firstOrNull;

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

    final figures = ref.watch(historyProjectionProvider)[session.id]!;
    final title = resolvedTitle(session, figures);

    // Every figure below is derived at this moment from the session rows and
    // the bodyweight series. Nothing is read from a stored counter, which is
    // why editing or deleting a session anywhere makes all of them correct
    // again with no invalidation to remember.
    final streak = streakAsOf(sessions, session.performedOn);
    final weight = weightInEffectOn(
      ref.watch(bodyweightLogProvider),
      session.performedOn,
    );
    final kcal = caloriesFor(
      setCount: figures.setCount,
      weightKg: weight?.weightKg,
    );

    return AppScreen.pushed(
      title: title,
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          _HeroCard(
            session: session,
            figures: figures,
            title: title,
            streak: streak,
            kcal: kcal,
          ),
          const SizedBox(height: 18),
          Semantics(
            header: true,
            child: Text(
              figures.pbCount > 0
                  ? 'LOGGED · ${figures.pbCount} PERSONAL BEST'
                      '${figures.pbCount == 1 ? '' : 'S'}'
                  : 'LOGGED',
              style: kLandingSectionLabelStyle,
            ),
          ),
          const SizedBox(height: 4),
          for (final exercise in session.exercises)
            _ExerciseBlock(
              key: exerciseKey(exercise.name),
              exercise: exercise,
              // Which set set the record, so the log can point at it rather
              // than just saying the session had one.
              recordScore: _recordScoreFor(sessions, session, exercise),
            ),
          const SizedBox(height: 22),
          const _ReadOnlyNote(),
        ],
      ),
    );
  }
}

/// The best score this exercise had ever reached *before* [session], or null
/// when this session did not beat it.
///
/// Recomputed here rather than carried on the projection because it is only
/// ever needed for the handful of exercises on one open screen, and the
/// projection's job is the whole list.
double? _recordScoreFor(
  List<HistorySession> sessions,
  HistorySession session,
  HistoryExercise exercise,
) {
  var previous = 0.0;
  var seen = false;
  for (final other in sessions) {
    if (!other.performedOn.isBefore(session.performedOn)) continue;
    for (final e in other.exercises) {
      if (e.name != exercise.name) continue;
      seen = true;
      for (final score in e.setScores) {
        if (score > previous) previous = score;
      }
    }
  }
  if (!seen) return null; // first-ever occurrence is never a record

  final best = exercise.setScores.fold<double>(0, (a, b) => a > b ? a : b);
  return best > previous ? best : null;
}

/// The **qualified** sub-muscle-group ids belonging to [groupIds].
///
/// **`kMuscleTaxonomy` stores bare sub-names, everything else uses qualified
/// ones.** The taxonomy lists `'chest': ['upper', 'mid', 'lower']`, while
/// `kSubMuscleGroups` and the diagram's fill callback both speak in
/// `'chest/upper'`. Joining the two without re-qualifying compares `'upper'`
/// against `'chest/upper'`, matches nothing, and paints a body that is
/// correctly shaped and entirely unfilled — which is exactly the "two
/// vocabularies for one idea" trap `body_gender.dart` documents, met from the
/// other side.
///
/// Done here once so no caller has to remember it.
Set<String> subMuscleGroupIdsFor(Iterable<String> groupIds) => <String>{
      for (final groupId in groupIds)
        for (final subName in kMuscleTaxonomy[groupId] ?? const <String>[])
          '$groupId/$subName',
    };

/// The screenshot-friendly summary: what was trained, and four figures.
class _HeroCard extends ConsumerWidget {
  const _HeroCard({
    required this.session,
    required this.figures,
    required this.title,
    required this.streak,
    required this.kcal,
  });

  final HistorySession session;
  final HistoryRowFigures figures;
  final String title;
  final int streak;
  final int? kcal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = _viewsFor(figures.trainedGroupIds);
    final fill = _SessionMuscleFill(figures.trainedGroupIds.toSet());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border.all(color: AppPalette.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textPrimary,
                  ),
                ),
              ),
              if (figures.pbCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppPalette.accentStrong.withValues(alpha: 0.17),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${figures.pbCount} PB',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.accentLight,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            _longDate(session.performedOn) +
                (session.isQuickLog ? ' · quick log' : ''),
            style: const TextStyle(fontSize: 11.5, color: AppPalette.textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 168,
            child: Row(
              children: <Widget>[
                for (final view in views) ...<Widget>[
                  if (view != views.first) const SizedBox(width: 10),
                  Expanded(
                    child: BodyDiagram(view: view, fill: fill.colorFor),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 13),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppPalette.border)),
            ),
            child: Row(
              children: <Widget>[
                _Figure(value: '${figures.setCount}', label: 'SETS'),
                _Figure(value: '${figures.exerciseCount}', label: 'EXERCISES'),
                _Figure(value: '$streak', label: 'STREAK'),
                // The calorie slot is a prompt rather than a number when no
                // weight was in effect on this day. A figure derived from
                // today's weight would be the retroactive rewrite the dated
                // series exists to prevent.
                Expanded(
                  key: HistorySessionDetailScreen.calorieKey,
                  child: kcal == null
                      ? const Column(
                          children: <Widget>[
                            Text(
                              '—',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppPalette.textMuted,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'ADD WEIGHT',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 8,
                                letterSpacing: 0.04,
                                color: AppPalette.textMuted,
                              ),
                            ),
                          ],
                        )
                      : _Figure(value: '$kcal', label: 'KCAL'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// **Only the view or views that carry a trained muscle.** `docs/01` is
/// explicit: never render an empty second diagram — a blank back on a session
/// that was all chest reads as missing data rather than as nothing to show.
List<BodyView> _viewsFor(List<String> trainedGroupIds) {
  var front = false;
  var back = false;
  for (final subId in subMuscleGroupIdsFor(trainedGroupIds)) {
    {
      for (final segment in kSubMuscleGroups[subId]?.segments ??
          const <({String view, String segment})>[]) {
        if (segment.view == BodyView.front.taxonomyView) front = true;
        if (segment.view == BodyView.back.taxonomyView) back = true;
      }
    }
  }
  if (front && back) return const <BodyView>[BodyView.front, BodyView.back];
  if (back) return const <BodyView>[BodyView.back];
  return const <BodyView>[BodyView.front];
}

/// Fills a segment accent-strong when the session trained it.
///
/// One instance per build, handed to the diagram, so the painter's repaint
/// guard compares the same tear-off rather than a fresh closure each frame —
/// the reason `ExerciseMuscleFill` exists in the same shape.
@immutable
class _SessionMuscleFill {
  _SessionMuscleFill(Set<String> trainedGroupIds)
      : trainedSubGroups =
            Set<String>.unmodifiable(subMuscleGroupIdsFor(trainedGroupIds));

  final Set<String> trainedSubGroups;

  Color colorFor(Set<String> subMuscleGroupIds) {
    return subMuscleGroupIds.any(trainedSubGroups.contains)
        ? AppPalette.accentStrong
        : AppPalette.mutedSurface;
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              letterSpacing: 0.04,
              color: AppPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// One exercise and every set performed, with the record-setting set marked.
class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({
    required this.exercise,
    required this.recordScore,
    super.key,
  });

  final HistoryExercise exercise;

  /// The score that beat the previous best, or null when this exercise set no
  /// record in this session.
  final double? recordScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppPalette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  exercise.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textPrimary,
                  ),
                ),
              ),
              if (recordScore != null) ...<Widget>[
                const SizedBox(width: 6),
                const Icon(
                  Icons.emoji_events_outlined,
                  size: 14,
                  color: AppPalette.accentLight,
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: <Widget>[
              for (final score in exercise.setScores)
                _SetPill(score: score, isRecord: score == recordScore),
            ],
          ),
        ],
      ),
    );
  }
}

/// One set. The record-setting one is the only thing in the log painted accent.
class _SetPill extends StatelessWidget {
  const _SetPill({required this.score, required this.isRecord});

  final double score;
  final bool isRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isRecord
            ? AppPalette.accentStrong.withValues(alpha: 0.17)
            : AppPalette.mutedSurface,
        border: Border.all(
          color: isRecord
              ? AppPalette.accentStrong.withValues(alpha: 0.42)
              : AppPalette.border,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        score == score.roundToDouble()
            ? '${score.toStringAsFixed(0)} kg'
            : '$score kg',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: isRecord ? FontWeight.w600 : FontWeight.w400,
          color: isRecord ? AppPalette.accentLight : AppPalette.textSecondary,
        ),
      ),
    );
  }
}

/// Says plainly what this screen cannot do, rather than leaving a user hunting
/// for an edit control that is not there yet.
class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppPalette.mutedSurface,
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Text(
        'Editing and deleting a past workout arrive with the session tables. '
        'This history is sample data, so the figures above are real '
        'derivations over it rather than stored numbers.',
        style: TextStyle(
          fontSize: 11.5,
          height: 1.5,
          color: AppPalette.textMuted,
        ),
      ),
    );
  }
}

String _longDate(DateTime date) {
  const months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
