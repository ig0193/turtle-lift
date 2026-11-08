import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/custom_templates.dart';
import '../data/body_gender.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../data/local_date.dart';
import '../data/personal_best.dart';
import '../data/personal_details_store.dart' show bodyweightLogProvider;
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'body_diagram.dart';
import 'destructive_confirmation.dart';
import 'exercise_detail_screen.dart' show MuscleFill;
import 'finish_celebration.dart';
import 'session_date_control.dart';
import 'set_logging_screen.dart';
import 'template_library_screen.dart' show promptForTemplateName;

/// The card a finished workout lands on, and the record of it ever after.
///
/// **Composed to be screenshotted, with no export step.** The muscle map is the
/// hero, the numbers are large, and the chrome is one back control — someone
/// who has just finished can post this exactly as it appears.
///
/// **The same component opens a saved workout.** Session detail is not a
/// read-only viewer that would drift from this one; it is this screen, pointed
/// at a session that is already saved.
class SessionSummaryScreen extends ConsumerStatefulWidget {
  const SessionSummaryScreen({
    required this.sessionId,
    this.celebrate = false,
    super.key,
  });

  /// The saved workout this shows.
  final String sessionId;

  /// Whether to play the finish moment before the card settles.
  final bool celebrate;

  /// The key a test taps to delete the workout.
  static const Key deleteKey = ValueKey<String>('delete-workout');

  /// The key a test taps to save the workout as a template.
  static const Key saveAsTemplateKey = ValueKey<String>('save-as-template');

  /// The key a test finds the personal-best pill by.
  static const Key pbPillKey = ValueKey<String>('pb-pill');

  /// The key a test finds the add-weight prompt by.
  static const Key addWeightKey = ValueKey<String>('add-weight-prompt');

  /// The key a test taps for the calorie explanation.
  static const Key calorieInfoKey = ValueKey<String>('calorie-info');

  @override
  ConsumerState<SessionSummaryScreen> createState() =>
      _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  late final TextEditingController _title;
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    _celebrating = widget.celebrate;
    _title = TextEditingController();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedSessionsProvider);
    final index = ref.watch(exerciseIndexProvider);
    final weights = ref.watch(bodyweightLogProvider);

    final session =
        saved.where((s) => s.id == widget.sessionId).firstOrNull;
    if (session == null) {
      // Deleted from here, or from somewhere else while this was open.
      return const AppScreen.pushed(title: 'Workout', body: SizedBox.shrink());
    }

    final name = resolvedTitle(session, index);
    if (_title.text.isEmpty && (session.title ?? '').isNotEmpty) {
      _title.text = session.title!;
    }

    final worked = workedSubGroups(session, index);
    final views = viewsForMuscles(worked.primary.union(worked.secondary));
    final records = pbCountFor(session, saved);
    final calories = caloriesFor(session, weights);

    return AppScreen.pushed(
      title: name,
      body: Stack(
        children: <Widget>[
          ListView(
            padding: screenScrollPadding(context),
            children: <Widget>[
              const SizedBox(height: 10),
              _ShareCard(
                session: session,
                name: name,
                title: _title,
                views: views,
                fill: MuscleFill(
                  primary: worked.primary,
                  secondary: worked.secondary,
                ),
                records: records,
                calories: calories,
                streak: streakAsOf(session.performedOn, saved),
                onRename: (value) => ref
                    .read(activeSessionProvider.notifier)
                    .renameSaved(session.id, value),
              ),
              const SizedBox(height: 16),
              const Text('What you did', style: kLandingSectionLabelStyle),
              const SizedBox(height: 8),
              for (final exercise in session.exercises)
                _LoggedExercise(
                  exercise: exercise,
                  name: index.byId(exercise.exerciseId)?.name ??
                      'Unknown exercise',
                  isRecord: isPersonalBest(exercise, session, saved),
                  // The screen that logs a set is the screen that corrects
                  // one, months later — never a second read-only viewer that
                  // would drift from it.
                  onEdit: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SetLoggingScreen(
                        sessionExerciseId: exercise.id,
                        savedSessionId: session.id,
                      ),
                    ),
                  ),
                  onRemove: () => _removeExercise(
                    context,
                    exercise.id,
                    index.byId(exercise.exerciseId)?.name ?? 'this exercise',
                  ),
                ),
              const SizedBox(height: 16),
              // Below the screenshot composition, like Delete: it is an action
              // on the record, not part of the card built to be posted.
              _SaveAsTemplateButton(
                onTap: () => _saveAsTemplate(context, session, name),
              ),
              const SizedBox(height: 8),
              // Below the screenshot composition, deliberately: this is the
              // permanent record, and the destructive action does not belong
              // in the part of the screen built to be posted.
              _DeleteButton(
                onTap: () => _delete(context, name),
              ),
            ],
          ),
          if (_celebrating)
            FinishCelebration(
              onDone: () => setState(() => _celebrating = false),
            ),
        ],
      ),
    );
  }

  /// Makes a template of this workout's exercises, in the order they were done.
  ///
  /// **How a user's own templates are made.** The workout they just did is the
  /// routine they want to repeat, so there is no separate authoring step to find
  /// or to build a list in. Only exercises with work in them are kept: an
  /// exercise that was added and never touched is not part of what was done.
  Future<void> _saveAsTemplate(
    BuildContext context,
    WorkoutSession session,
    String name,
  ) async {
    final exerciseIds = <String>[
      for (final exercise in session.exercises)
        if (exercise.completedSets.isNotEmpty) exercise.exerciseId,
    ];
    final chosen = await promptForTemplateName(
      context,
      initial: name,
      title: 'Save as template',
    );
    if (chosen == null) return;
    await ref
        .read(customTemplateListProvider.notifier)
        .add(name: chosen, exerciseIds: exerciseIds);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$chosen saved to My templates')));
  }

  Future<void> _removeExercise(
    BuildContext context,
    String sessionExerciseId,
    String name,
  ) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove $name?',
      message: 'This drops the sets you logged for it in this workout.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    await ref
        .read(activeSessionProvider.notifier)
        .removeSavedExercise(sessionExerciseId);
  }

  Future<void> _delete(BuildContext context, String name) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete $name?',
      message: 'This permanently removes the workout and every set in it.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    await ref.read(activeSessionProvider.notifier).deleteSaved(widget.sessionId);
    if (context.mounted) Navigator.of(context).maybePop();
  }
}

/// The part built to be screenshotted.
class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.session,
    required this.name,
    required this.title,
    required this.views,
    required this.fill,
    required this.records,
    required this.calories,
    required this.streak,
    required this.onRename,
  });

  final WorkoutSession session;
  final String name;
  final TextEditingController title;
  final List<BodyView> views;
  final MuscleFill fill;
  final int records;
  final double? calories;
  final int streak;
  final ValueChanged<String?> onRename;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border.all(color: AppPalette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            session.performedOn == LocalDate.today()
                ? 'Today'
                : longDateLabel(session.performedOn),
            style: const TextStyle(fontSize: 12, color: AppPalette.textMuted),
          ),
          const SizedBox(height: 4),
          // Inline-editable: the workout is already saved, and the name is
          // optional forever.
          TextField(
            controller: title,
            maxLength: 40,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppPalette.textPrimary,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: name,
              hintStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppPalette.textPrimary,
              ),
            ),
            onSubmitted: (value) =>
                onRename(value.trim().isEmpty ? null : value.trim()),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
          ),
          const SizedBox(height: 12),
          // Only the views that carry trained muscles; never an empty second
          // diagram beside a filled one. The map is the card's moment, so it
          // takes the card's width and most of its height.
          SizedBox(
            height: 280,
            child: Row(
              children: <Widget>[
                for (final view in views) ...<Widget>[
                  if (view != views.first) const SizedBox(width: 12),
                  Expanded(child: BodyDiagram(view: view, fill: fill.colorFor)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _Stat(value: '${setCountOf(session)}', label: 'Sets'),
              _Stat(value: '${exerciseCountOf(session)}', label: 'Exercises'),
              _Stat(value: '$streak', label: 'Day streak'),
              // A figure among the figures, in the PB colour -- not an
              // outlined pill under the map. Absent at zero: never "0 PB" on
              // a card built to be screenshotted.
              if (records > 0)
                _Stat(
                  key: SessionSummaryScreen.pbPillKey,
                  value: '$records',
                  label: 'PB',
                  valueColor: AppPalette.accentStrong,
                ),
              if (calories != null) _CalorieStat(calories: calories!),
            ],
          ),
          // A workout logged before the user ever weighed in cannot have an
          // honest estimate, and adding a weight later does not back-fill it.
          // So there is no kcal figure -- and the instruction sits under the
          // row rather than in a figure's slot.
          if (calories == null) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              key: SessionSummaryScreen.addWeightKey,
              kNoWeightKcalNote,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppPalette.textMuted),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: Text(
              kAppDisplayName.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                color: AppPalette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What stands in for the calorie figure when no bodyweight was in effect on
/// the session's day. Shared by the summary card and Session Detail.
const String kNoWeightKcalNote = 'Add your bodyweight in Profile to see kcal';

/// The app's display name, as it appears on a card meant to be posted.
const String kAppDisplayName = 'TurtleLift';

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.valueColor = AppPalette.textPrimary,
    super.key,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: valueColor,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12, color: AppPalette.textMuted),
            ),
          ],
        ),
      );
}

/// Calories, with the way to read how they are estimated.
///
/// Built only when there is an honest figure; the summary shows
/// [kNoWeightKcalNote] under the row otherwise.
class _CalorieStat extends StatelessWidget {
  const _CalorieStat({required this.calories});

  final double calories;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            '${calories.round()}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppPalette.textPrimary,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('kcal',
                  style: TextStyle(
                      fontSize: 12, color: AppPalette.textMuted)),
              const SizedBox(width: 4),
              Builder(
                builder: (context) => Semantics(
                  button: true,
                  label: 'How the calorie estimate works',
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: SessionSummaryScreen.calorieInfoKey,
                    onTap: () => _explain(context),
                    child: const Icon(Icons.info_outline,
                        size: 13, color: AppPalette.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _explain(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppPalette.border),
        ),
        title: const Text(
          'How this is estimated',
          style: TextStyle(fontSize: 17, color: AppPalette.textPrimary),
        ),
        content: const Text(
          'Estimated from the sets you logged and your body weight, using '
          'standard exercise-science averages for resistance training. Actual '
          'calories burned vary by person and effort.',
          style: TextStyle(fontSize: 15, color: AppPalette.textSecondary),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it',
                style: TextStyle(color: AppPalette.textSecondary)),
          ),
        ],
      ),
    );
  }
}

/// One exercise in the log below the card, with its sets and its record badge.
class _LoggedExercise extends StatelessWidget {
  const _LoggedExercise({
    required this.exercise,
    required this.name,
    required this.isRecord,
    required this.onEdit,
    required this.onRemove,
  });

  final SessionExercise exercise;
  final String name;
  final bool isRecord;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  /// The row for [exerciseId], so a test can reach one by name.
  static Key rowKey(String exerciseId) =>
      ValueKey<String>('logged-$exerciseId');

  @override
  Widget build(BuildContext context) {
    final sets = formatSetList(exercise);
    if (sets.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      key: rowKey(exercise.exerciseId),
      behavior: HitTestBehavior.opaque,
      onTap: onEdit,
      onLongPress: onRemove,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppPalette.textPrimary,
                  ),
                ),
              ),
              if (isRecord)
                Text(
                  // Says what kind of record it is, because a badge beside a
                  // smaller number would otherwise read as a bug weeks later.
                  // The logging screen's banner is not on this page.
                  exercise.loadType?.name == 'assisted'
                      ? 'PB · lightest assist'
                      : 'PB',
                  style: kPbMarkStyle,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            sets,
            style: const TextStyle(
              fontSize: 13,
              color: AppPalette.textSecondary,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _SaveAsTemplateButton extends StatelessWidget {
  const _SaveAsTemplateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Save as template',
        excludeSemantics: true,
        child: GestureDetector(
          key: SessionSummaryScreen.saveAsTemplateKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppPalette.surface,
              border: Border.all(color: AppPalette.border),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Save as template',
              style: TextStyle(fontSize: 15, color: AppPalette.textSecondary),
            ),
          ),
        ),
      );
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Delete workout',
        excludeSemantics: true,
        child: GestureDetector(
          key: SessionSummaryScreen.deleteKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            child: const Text(
              'Delete workout',
              style: TextStyle(fontSize: 15, color: AppPalette.danger),
            ),
          ),
        ),
      );
}

/// Which body views to draw for a set of trained muscles.
///
/// Only the views that carry something: never an empty second diagram beside a
/// filled one.
List<BodyView> viewsForMuscles(Set<String> subGroupIds) {
  final views = <BodyView>{};
  for (final id in subGroupIds) {
    for (final placement in kSubMuscleGroups[id]?.segments ??
        const <({String view, String segment})>[]) {
      views.add(placement.view == 'front' ? BodyView.front : BodyView.back);
    }
  }
  if (views.isEmpty) return <BodyView>[BodyView.front];
  return BodyView.values.where(views.contains).toList(growable: false);
}

/// Pushes the summary for [sessionId].
Future<void> pushSessionSummary(
  BuildContext context,
  String sessionId, {
  bool celebrate = false,
}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionSummaryScreen(
          sessionId: sessionId,
          celebrate: celebrate,
        ),
      ),
    );
