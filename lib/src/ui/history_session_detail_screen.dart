import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/body_gender.dart';
import '../data/bodyweight_resolution.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../data/history_preview_data.dart';
import '../data/personal_details_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'body_diagram.dart';
import 'ghost_button.dart';
import 'session_summary_screen.dart';

/// One logged session, opened from a History row.
///
/// **This is the read half.** Editing (title, `performedOn`, sets) and delete
/// live on `SessionSummaryScreen`, the screen a workout lands on when it is
/// finished; the Edit workout button at the foot of the log opens it, so there
/// is one editor and nothing for two of them to disagree about.
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

  /// The button that opens the editable summary: title, date, sets, delete.
  static const Key editKey = ValueKey<String>('session-edit');

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
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              figures.pbCount > 0
                  ? 'Logged · ${figures.pbCount} personal best'
                      '${figures.pbCount == 1 ? '' : 's'}'
                  : 'Logged',
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
          const SizedBox(height: 24),
          GhostButton(
            buttonKey: HistorySessionDetailScreen.editKey,
            label: 'Edit workout',
            onTap: () => pushSessionSummary(context, sessionId),
          ),
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
        borderRadius: BorderRadius.circular(16),
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
              // The app's one PB mark: the word in amber, no pill, no icon.
              if (figures.pbCount > 0)
                Text('${figures.pbCount} PB', style: kPbMarkStyle),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _longDate(session.performedOn) +
                (session.isQuickLog ? ' · quick log' : ''),
            style: const TextStyle(fontSize: 12, color: AppPalette.textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: Row(
              children: <Widget>[
                for (final view in views) ...<Widget>[
                  if (view != views.first) const SizedBox(width: 12),
                  Expanded(
                    child: BodyDiagram(view: view, fill: fill.colorFor),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppPalette.border)),
            ),
            child: Row(
              children: <Widget>[
                _Figure(value: '${figures.setCount}', label: 'Sets'),
                _Figure(value: '${figures.exerciseCount}', label: 'Exercises'),
                _Figure(value: '$streak', label: 'Streak'),
                if (kcal != null)
                  _Figure(
                    key: HistorySessionDetailScreen.calorieKey,
                    value: '$kcal',
                    label: 'kcal',
                  ),
              ],
            ),
          ),
          // No weight was in effect on this day, so there is no figure -- and
          // an instruction does not belong in a figure's slot. A figure derived
          // from today's weight would be the retroactive rewrite the dated
          // series exists to prevent.
          if (kcal == null) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              key: HistorySessionDetailScreen.calorieKey,
              kNoWeightKcalNote,
              style: TextStyle(fontSize: 12, color: AppPalette.textMuted),
            ),
          ],
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
  const _Figure({required this.value, required this.label, super.key});

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
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppPalette.textPrimary,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
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
      padding: const EdgeInsets.symmetric(vertical: 12),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppPalette.textPrimary,
                  ),
                ),
              ),
              if (recordScore != null) ...<Widget>[
                const SizedBox(width: 8),
                const Text('PB', style: kPbMarkStyle),
              ],
            ],
          ),
          const SizedBox(height: 4),
          _SetLine(scores: exercise.setScores, recordScore: recordScore),
        ],
      ),
    );
  }
}

/// Every set as one muted line, `77.5kg · 77.5kg · 75kg`, with the
/// record-setting set the only thing in the log painted amber.
///
/// **A line, not a pill per set.** The sets are a record to read, not controls;
/// pills made them look tappable and made the log the loudest part of the
/// screen.
class _SetLine extends StatelessWidget {
  const _SetLine({required this.scores, required this.recordScore});

  final List<double> scores;
  final double? recordScore;

  static const _style = TextStyle(
    fontSize: 13,
    color: AppPalette.textSecondary,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    for (var i = 0; i < scores.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: ' · '));
      final isRecord = scores[i] == recordScore;
      spans.add(TextSpan(
        text: '${formatWeight(scores[i])}kg',
        style: isRecord
            ? const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppPalette.accentStrong,
              )
            : null,
      ));
    }
    return Text.rich(TextSpan(style: _style, children: spans));
  }
}

String _longDate(DateTime date) {
  const months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
