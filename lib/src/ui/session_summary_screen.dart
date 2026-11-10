import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/custom_templates.dart';
import '../data/date_labels.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/history_preview_data.dart' show sessionRecordsProvider;
import '../data/load_type.dart';
import '../data/personal_best.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'destructive_confirmation.dart';
import 'exercise_picker_sheet.dart' show showExercisePicker;
import 'finish_celebration.dart';
import 'ghost_button.dart';
import 'history_session_detail_screen.dart' show HistorySessionDetailScreen;
import 'session_card.dart';
import 'session_date_control.dart';
import 'set_logging_screen.dart';
import 'template_library_screen.dart' show promptForTemplateName;

export 'session_card.dart'
    show
        CardImageSharer,
        cardImageFileName,
        cardImageSharerProvider,
        kAppDisplayName,
        kNoWeightKcalNote,
        shareCardImage,
        viewsForMuscles;

/// The card a finished workout lands on, and the editor of it ever after.
///
/// **Composed to be screenshotted, and shareable as an image.** The muscle map
/// is the hero, the numbers are large, and the chrome is one back control.
/// Share card renders exactly that card to a PNG and opens the system share
/// sheet (`docs/adr/0008-the-week-lives-on-the-workout-landing.md`): the user's
/// own image, sent wherever they choose. No feed, account, link or upload --
/// "no social features" (`docs/00` §13) still holds.
///
/// **The card is [SessionCard], the same widget the History detail shows**
/// (audit B3). This screen adds what only an editor needs: the inline title,
/// Change date, a tappable exercise list, Save as template and Delete.
class SessionSummaryScreen extends ConsumerStatefulWidget {
  const SessionSummaryScreen({
    required this.sessionId,
    this.celebrate = false,
    this.editing = false,
    super.key,
  });

  /// The saved workout this shows.
  final String sessionId;

  /// Whether to play the finish moment before the card settles.
  final bool celebrate;

  /// Opened from History to correct a saved workout, rather than landed on
  /// after Finish. The header then says "Edit workout", so nothing pretends
  /// this is the moment the workout was saved (audit #13).
  final bool editing;

  /// The key a test taps to delete the workout.
  static const Key deleteKey = ValueKey<String>('delete-workout');

  /// The key a test taps to save the workout as a template.
  static const Key saveAsTemplateKey = ValueKey<String>('save-as-template');

  /// The key a test finds the personal-best count by.
  static const Key pbPillKey = SessionCard.pbKey;

  /// The key a test finds the add-weight prompt by.
  static const Key addWeightKey = SessionCard.addWeightKey;

  /// The key a test taps for the calorie explanation.
  static const Key calorieInfoKey = SessionCard.calorieInfoKey;

  /// The button that shares the card as an image.
  static const Key shareKey = ValueKey<String>('share-card');

  /// The inline title field on the card.
  static const Key titleFieldKey = ValueKey<String>('session-title-field');

  /// The button that moves a saved workout to another day.
  static const Key changeDateKey = ValueKey<String>('session-change-date');

  /// Adds an exercise to this saved workout.
  static const Key addExerciseKey = ValueKey<String>('session-add-exercise');

  /// The card's streak figure.
  static const Key streakKey = SessionCard.streakKey;

  /// The visible remove control on one logged exercise.
  static Key removeKeyFor(String exerciseId) =>
      ValueKey<String>('remove-$exerciseId');

  @override
  ConsumerState<SessionSummaryScreen> createState() =>
      _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  late final TextEditingController _title;
  late final FocusNode _titleFocus;
  late final ActiveSession _sessions;

  /// The title as last written to the store, so a commit only writes a
  /// change. Null until the session has been read once.
  String? _storedTitle;
  bool _titleLoaded = false;
  bool _celebrating = false;

  /// The card's boundary, which is what Share card renders.
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share(BuildContext context, String name) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await shareSessionCard(context, ref, boundaryKey: _cardKey, name: name);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _celebrating = widget.celebrate;
    _title = TextEditingController();
    _titleFocus = FocusNode()..addListener(_onTitleFocus);
    // Held from the start: Riverpod refuses `ref` once the widget is
    // disposed, and leaving the screen is exactly when a typed name has to
    // be saved.
    _sessions = ref.read(activeSessionProvider.notifier);
  }

  void _onTitleFocus() {
    if (!_titleFocus.hasFocus) _commitTitle();
  }

  /// Writes the typed name when it differs from the stored one.
  ///
  /// **Called on Return, when the field loses focus and when the screen
  /// goes away** (B1). Saving only on Return threw a typed name away the
  /// moment the user tapped the map or went back. An emptied field clears
  /// the title, so the resolved name shows again.
  void _commitTitle() {
    if (!_titleLoaded) return;
    final typed = _title.text.trim();
    final value = typed.isEmpty ? null : typed;
    if (value == _storedTitle) return;
    _storedTitle = value;
    _sessions.renameSaved(widget.sessionId, value);
  }

  @override
  void dispose() {
    _commitTitle();
    _titleFocus
      ..removeListener(_onTitleFocus)
      ..dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedSessionsProvider);
    final index = ref.watch(exerciseIndexProvider);

    final session =
        saved.where((s) => s.id == widget.sessionId).firstOrNull;
    if (session == null) {
      // Deleted from here, or from somewhere else while this was open.
      return const AppScreen.pushed(title: 'Workout', body: SizedBox.shrink());
    }

    final name = resolvedTitle(session, index);
    // Filled once from the store. Refilling on every build put a cleared
    // name straight back before it could be saved as "no name".
    if (!_titleLoaded) {
      _titleLoaded = true;
      _storedTitle = (session.title ?? '').trim().isEmpty
          ? null
          : session.title!.trim();
      _title.text = _storedTitle ?? '';
    }

    final records =
        ref.watch(sessionRecordsProvider)[session.id] ?? SessionRecords.none;

    return AppScreen.pushed(
      title: widget.editing ? 'Edit workout' : name,
      body: Stack(
        children: <Widget>[
          ListView(
            padding: screenScrollPadding(context),
            children: <Widget>[
              const SizedBox(height: 10),
              RepaintBoundary(
                key: _cardKey,
                child: SessionCard(
                  session: session,
                  titleField: _TitleField(
                    controller: _title,
                    focusNode: _titleFocus,
                    hint: name,
                    onSubmitted: _commitTitle,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GhostButton(
                buttonKey: SessionSummaryScreen.shareKey,
                label: 'Share card',
                leadingIcon: Icons.ios_share_rounded,
                onTap: () => _share(context, name),
              ),
              // B2: a saved workout's day can be corrected, which is what
              // makes the streak promise true for past mistakes (`docs/04`).
              GhostButton(
                buttonKey: SessionSummaryScreen.changeDateKey,
                label: 'Change date',
                leadingIcon: Icons.event_rounded,
                onTap: () => _changeDate(context, session),
              ),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child:
                    const Text('What you did', style: kLandingSectionLabelStyle),
              ),
              const SizedBox(height: 8),
              for (final exercise in session.exercises)
                _LoggedExercise(
                  exercise: exercise,
                  name: index.byId(exercise.exerciseId)?.name ??
                      'Unknown exercise',
                  recordSetId: records.recordSetIds[exercise.id],
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
                    session,
                    exercise,
                    index.byId(exercise.exerciseId)?.name ?? 'this exercise',
                  ),
                ),
              // Something forgotten when the workout was logged: add it to
              // this saved workout rather than start a second one that day.
              GhostButton(
                buttonKey: SessionSummaryScreen.addExerciseKey,
                label: 'Add exercise',
                leadingIcon: Icons.add_rounded,
                onTap: () => _addExercise(context, session),
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
                onTap: () => _delete(context, name, session),
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

  /// Adds an exercise to this saved workout, then opens it for its sets
  /// (ADR 0013). The same picker as a live workout, and the same set logging
  /// screen that corrects a saved set, so nothing here is a second flow.
  Future<void> _addExercise(BuildContext context, WorkoutSession session) async {
    FocusScope.of(context).unfocus();
    final chosen = await showExercisePicker(
      context,
      title: 'Add exercise',
      alreadyChosen: <String>[for (final e in session.exercises) e.exerciseId],
    );
    if (chosen == null || !context.mounted) return;
    final loadType = LoadType.fromName(chosen.loadType);
    if (loadType == null) return;
    final rowId = await _sessions.addSavedExercise(
      sessionId: session.id,
      exerciseId: chosen.id,
      loadType: loadType,
    );
    if (rowId == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SetLoggingScreen(
          sessionExerciseId: rowId,
          savedSessionId: session.id,
        ),
      ),
    );
  }

  /// Moves this saved workout to the day the user picks (B2).
  ///
  /// The same picker as the live workout, so the same clamp: today or
  /// earlier. Ordering, the streak on every later card and the records all
  /// re-derive from the new date; nothing is stored to update.
  Future<void> _changeDate(BuildContext context, WorkoutSession session) async {
    FocusScope.of(context).unfocus();
    final picked =
        await ref.read(workoutDatePickerProvider)(context, session.performedOn);
    if (picked == null || picked == session.performedOn) return;
    await _sessions.setSavedPerformedOn(session.id, picked);
  }

  Future<void> _removeExercise(
    BuildContext context,
    WorkoutSession session,
    SessionExercise exercise,
    String name,
  ) async {
    // B6: removing the only exercise with work in it would leave a workout
    // of nothing, a row with a calendar dot that claims a trained day. The
    // honest outcome is deleting the workout, so that is what is offered.
    final othersWithWork = session.exercises.where((e) =>
        e.id != exercise.id && e.sets.any((s) => isSetComplete(e.loadType, s)));
    if (othersWithWork.isEmpty) {
      final confirmed = await confirmDestructive(
        context,
        title: 'Delete this workout?',
        message: '$name is the only exercise in it, so removing it deletes '
            'the workout. Records and your streak will update.',
        confirmLabel: 'Delete',
      );
      if (!confirmed || !context.mounted) return;
      await _deleteAndLeave(context);
      return;
    }

    final confirmed = await confirmDestructive(
      context,
      title: 'Remove $name?',
      message: 'This drops the sets you logged for it in this workout.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    await _sessions.removeSavedExercise(exercise.id);
  }

  Future<void> _delete(
    BuildContext context,
    String name,
    WorkoutSession session,
  ) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete $name?',
      message: 'This permanently removes the workout from '
          '${cardDateLabel(session.performedOn)} and every set in it. '
          'Records and your streak will update.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    await _deleteAndLeave(context);
  }

  Future<void> _deleteAndLeave(BuildContext context) async {
    await _sessions.deleteSaved(widget.sessionId);
    if (!context.mounted) return;
    // This screen, then the History detail screen for the same workout if
    // that is what opened it: left open, it is a dead end that can only say
    // the workout is gone (QA, Maestro flow 02).
    final navigator = Navigator.of(context);
    final detail = HistorySessionDetailScreen.routeNameFor(widget.sessionId);
    navigator.pop();
    navigator.popUntil((route) => route.settings.name != detail);
  }
}

/// The card's title, editable in place: the workout is already saved, and
/// the name is optional forever.
class _TitleField extends StatelessWidget {
  const _TitleField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// The resolved name, shown while the field is empty.
  final String hint;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Named for VoiceOver (audit B10): a bare field read as "text field".
      label: 'Workout title',
      identifier: 'workout-title',
      container: true,
      child: TextField(
        key: SessionSummaryScreen.titleFieldKey,
        controller: controller,
        focusNode: focusNode,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
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
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppPalette.textPrimary,
          ),
        ),
        onSubmitted: (_) => onSubmitted(),
        onTapOutside: (_) => focusNode.unfocus(),
      ),
    );
  }
}

/// One exercise in the log below the card, with its sets and its record mark.
class _LoggedExercise extends StatelessWidget {
  const _LoggedExercise({
    required this.exercise,
    required this.name,
    required this.recordSetId,
    required this.onEdit,
    required this.onRemove,
  });

  final SessionExercise exercise;
  final String name;

  /// The set that set a record in this workout, or null.
  final String? recordSetId;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  /// The row for [exerciseId], so a test can reach one by name.
  static Key rowKey(String exerciseId) =>
      ValueKey<String>('logged-$exerciseId');

  @override
  Widget build(BuildContext context) {
    final sets = formatSetList(exercise);
    if (sets.isEmpty) return const SizedBox.shrink();

    final mark = recordSetId != null ? pbMarkLabel(exercise.loadType) : null;
    // The row is a button that opens the sets, and says so; remove is a
    // visible control and a VoiceOver action rather than a long-press only
    // (audit B10, #13). Long-press still works for the one-handed path.
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            container: true,
            button: true,
            label: <String>[name, ?mark, sets].join('\n'),
            hint: 'Edit sets',
            onTap: onEdit,
            onLongPress: onRemove,
            customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
              const CustomSemanticsAction(label: 'Remove'): onRemove,
            },
            excludeSemantics: true,
            child: GestureDetector(
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
                          // Says what kind of record it is, because a badge
                          // beside a smaller number would otherwise read as a
                          // bug weeks later.
                          Text(mark, style: kPbMarkStyle),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    SessionSetLine(
                      exercise: exercise,
                      recordSetId: recordSetId,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Semantics(
          container: true,
          button: true,
          label: 'Remove $name',
          onTap: onRemove,
          excludeSemantics: true,
          child: GestureDetector(
            key: SessionSummaryScreen.removeKeyFor(exercise.exerciseId),
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.remove_circle_outline_rounded,
                size: 20,
                color: AppPalette.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SaveAsTemplateButton extends StatelessWidget {
  const _SaveAsTemplateButton({required this.onTap});

  final VoidCallback onTap;

  /// Text in chalk, like every secondary action, so it reads as available.
  /// The muted outlined capsule it used to be looked disabled (audit #13).
  @override
  Widget build(BuildContext context) => GhostButton(
        buttonKey: SessionSummaryScreen.saveAsTemplateKey,
        label: 'Save as template',
        leadingIcon: Icons.bookmark_add_outlined,
        onTap: onTap,
      );
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: 'Delete workout',
        onTap: onTap,
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

/// Pushes the summary for [sessionId]. [editing] when it is opened from
/// History to correct a saved workout.
Future<void> pushSessionSummary(
  BuildContext context,
  String sessionId, {
  bool celebrate = false,
  bool editing = false,
}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionSummaryScreen(
          sessionId: sessionId,
          celebrate: celebrate,
          editing: editing,
        ),
      ),
    );
