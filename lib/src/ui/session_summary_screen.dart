import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
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
              const SizedBox(height: 18),
              const Text('WHAT YOU DID', style: kLandingSectionLabelStyle),
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
              const SizedBox(height: 24),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
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
            style: const TextStyle(fontSize: 11.5, color: AppPalette.textMuted),
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
          const SizedBox(height: 10),
          // Only the views that carry trained muscles; never an empty second
          // diagram beside a filled one.
          SizedBox(
            height: 190,
            child: Row(
              children: <Widget>[
                for (final view in views)
                  Expanded(child: BodyDiagram(view: view, fill: fill.colorFor)),
              ],
            ),
          ),
          if (records > 0) ...<Widget>[
            const SizedBox(height: 12),
            Center(
              child: Container(
                key: SessionSummaryScreen.pbPillKey,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppPalette.mutedSurface,
                  border: Border.all(color: AppPalette.accentStrong),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  records == 1 ? '1 personal best' : '$records personal bests',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.accentStrong,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _Stat(value: '${setCountOf(session)}', label: 'Sets'),
              _Stat(value: '${exerciseCountOf(session)}', label: 'Exercises'),
              _Stat(value: '$streak', label: 'Day streak'),
              _CalorieStat(calories: calories),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              kAppDisplayName.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
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

/// The app's display name, as it appears on a card meant to be posted.
const String kAppDisplayName = 'TurtleLift';

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppPalette.textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10.5, color: AppPalette.textMuted),
            ),
          ],
        ),
      );
}

/// Calories, or the prompt that stands in for them.
///
/// **A prompt rather than a hidden slot or a wrong number.** A workout logged
/// before the user ever weighed in cannot have an honest estimate, and adding a
/// weight later does not back-fill it.
class _CalorieStat extends StatelessWidget {
  const _CalorieStat({required this.calories});

  final double? calories;

  @override
  Widget build(BuildContext context) {
    if (calories == null) {
      return Expanded(
        child: Semantics(
          button: true,
          label: 'Add your weight to see calories',
          excludeSemantics: true,
          child: Text(
            key: SessionSummaryScreen.addWeightKey,
            'add weight\nto see kcal',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: AppPalette.textMuted),
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            '${calories!.round()}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppPalette.textPrimary,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('kcal',
                  style: TextStyle(
                      fontSize: 10.5, color: AppPalette.textMuted)),
              const SizedBox(width: 3),
              Builder(
                builder: (context) => Semantics(
                  button: true,
                  label: 'How the calorie estimate works',
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: SessionSummaryScreen.calorieInfoKey,
                    onTap: () => _explain(context),
                    child: const Icon(Icons.info_outline,
                        size: 12, color: AppPalette.textMuted),
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
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppPalette.border),
        ),
        title: const Text(
          'How this is estimated',
          style: TextStyle(fontSize: 16, color: AppPalette.textPrimary),
        ),
        content: const Text(
          'Estimated from the sets you logged and your body weight, using '
          'standard exercise-science averages for resistance training. Actual '
          'calories burned vary by person and effort.',
          style: TextStyle(fontSize: 13.5, color: AppPalette.textSecondary),
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
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
          const SizedBox(height: 3),
          Text(
            sets,
            style:
                const TextStyle(fontSize: 12, color: AppPalette.textSecondary),
          ),
        ],
      ),
      ),
    );
  }
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
              style: TextStyle(fontSize: 14, color: AppPalette.danger),
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
