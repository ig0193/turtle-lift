import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/custom_exercises.dart';
import '../data/exercise.dart';
import '../data/exercise_index.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../data/load_type.dart';
import '../data/session_store.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'body_diagram.dart';
import 'destructive_confirmation.dart';
import 'editor_parts.dart';
import 'exercise_detail_screen.dart'
    show
        ExerciseDetailEntry,
        MuscleFill,
        bodyViewsForExercise,
        exerciseFactsLabel,
        kExerciseDiagramHeight,
        kMuscleChipPrimaryStyle,
        kMuscleChipSecondaryStyle,
        startLoggingFromDetail;
import 'ghost_button.dart';
import 'muscle_exercise_list_screen.dart'
    show ExerciseRow, exerciseEquipmentLabel;

/// The user's own exercises (`docs/adr/0009-custom-exercises-and-template-editing.md`): the editor
/// that makes and changes one, the page that shows one, and the list of them.
///
/// **A custom exercise has no form guide, and every screen here says so
/// rather than filling the gap.** The library's setup, posture, execution and
/// common-mistakes copy is reviewed because it carries injury risk; the app
/// writes none for an exercise it has never seen.

/// What a load type means to someone choosing it, in a few words.
String loadTypeChoiceLabel(LoadType type) => switch (type) {
      LoadType.weighted => 'Weight and reps',
      LoadType.bodyweight => 'Bodyweight reps',
      LoadType.assisted => 'Assisted reps',
      LoadType.timed => 'Time',
    };

/// The line under the load-type choice, so the choice is never a guess.
String loadTypeChoiceCaption(LoadType type) => switch (type) {
      LoadType.weighted => 'Log kg × reps for each set.',
      LoadType.bodyweight =>
        'Log reps, with optional added weight (a vest or a belt).',
      LoadType.assisted =>
        'Log reps and the assistance in kg. Less assistance is the record.',
      LoadType.timed => 'Log how long you held it, with optional weight.',
    };

/// The plain statement on a custom exercise's page.
const String kCustomExerciseNote =
    'You made this exercise, so it has no form guide. Setup, posture and '
    'execution notes exist only for the built-in exercises, where they have '
    'been reviewed.';

/// Opens the editor; returns the saved exercise, or null when backed out.
Future<Exercise?> showCustomExerciseEditor(
  BuildContext context, {
  Exercise? existing,
  String initialName = '',
}) =>
    Navigator.of(context).push<Exercise>(
      MaterialPageRoute<Exercise>(
        builder: (_) => CustomExerciseEditorScreen(
          existing: existing,
          initialName: initialName,
        ),
      ),
    );

/// Makes or changes one of the user's exercises.
class CustomExerciseEditorScreen extends ConsumerStatefulWidget {
  const CustomExerciseEditorScreen({
    this.existing,
    this.initialName = '',
    super.key,
  });

  final Exercise? existing;

  /// Prefills the name, e.g. with what the user searched the picker for.
  final String initialName;

  static const Key saveKey = ValueKey<String>('custom-exercise-save');
  static const Key deleteKey = ValueKey<String>('custom-exercise-delete');

  /// Hide from picker / Show in picker, for an exercise a workout logs.
  static const Key hideKey = ValueKey<String>('custom-exercise-hide');

  static Key equipmentKey(String value) =>
      ValueKey<String>('custom-equipment-$value');
  static Key loadTypeKey(LoadType type) =>
      ValueKey<String>('custom-load-${type.name}');
  static Key primaryKey(String id) => ValueKey<String>('custom-primary-$id');
  static Key secondaryKey(String id) =>
      ValueKey<String>('custom-secondary-$id');

  @override
  ConsumerState<CustomExerciseEditorScreen> createState() =>
      _CustomExerciseEditorScreenState();
}

class _CustomExerciseEditorScreenState
    extends ConsumerState<CustomExerciseEditorScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? widget.initialName,
  );
  late String _equipment = widget.existing?.equipment ?? 'machine';
  late LoadType _loadType =
      LoadType.fromName(widget.existing?.loadType) ?? LoadType.weighted;
  late final List<String> _primary = <String>[...?widget.existing?.primary];
  late final List<String> _secondary = <String>[
    ...?widget.existing?.secondary,
  ];

  /// Whether a workout logs this exercise, which fixes its load type and
  /// rules out deleting it. Null until read.
  bool? _logged;
  String? _problem;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  /// Read live, so the action's label flips the moment it is tapped.
  bool get _hidden {
    final id = widget.existing?.id;
    if (id == null) return false;
    return ref
            .watch(customExerciseListProvider)
            .where((e) => e.id == id)
            .firstOrNull
            ?.hidden ??
        false;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      ref
          .read(customExerciseListProvider.notifier)
          .isLogged(existing.id)
          .then((logged) {
        if (mounted) setState(() => _logged = logged);
      });
    } else {
      _logged = false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  CustomExerciseDraft get _draft => CustomExerciseDraft(
        name: _name.text,
        equipment: _equipment,
        loadType: _loadType,
        primary: _primary,
        secondary: _secondary,
      );

  Future<void> _save() async {
    final problem = _draft.problem;
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() => _saving = true);
    final list = ref.read(customExerciseListProvider.notifier);
    final saved = _isEdit
        ? await list.edit(widget.existing!.id, _draft)
        : await list.add(_draft);
    if (!mounted) return;
    Navigator.of(context).pop(saved);
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete ${existing.name}?',
      message: 'It is removed from your templates too. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;
    final deleted =
        await ref.read(customExerciseListProvider.notifier).delete(existing.id);
    if (!mounted) return;
    if (deleted) {
      // Back past the exercise's own page, which shows what was deleted.
      Navigator.of(context)
        ..pop()
        ..maybePop();
    } else {
      setState(() => _logged = true);
    }
  }

  void _togglePrimary(String id) => setState(() {
        _problem = null;
        if (_primary.remove(id)) return;
        _secondary.remove(id);
        _primary.add(id);
      });

  void _toggleSecondary(String id) => setState(() {
        if (_primary.contains(id)) return;
        if (!_secondary.remove(id)) _secondary.add(id);
      });

  @override
  Widget build(BuildContext context) {
    final equipmentValues = ref.watch(libraryIndexProvider).equipmentValues;
    final loadLocked = _logged ?? true;

    return AppScreen.pushed(
      title: _isEdit ? 'Edit exercise' : 'New exercise',
      bottomBar: PinnedActionBar(
        child: FilledButton(
          key: CustomExerciseEditorScreen.saveKey,
          onPressed: _saving ? null : _save,
          child: Text(_isEdit ? 'Save changes' : 'Save exercise'),
        ),
      ),
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const EditorSectionLabel('Name'),
          EditorTextField(
            controller: _name,
            hint: 'e.g. Hack squat machine',
            maxLength: kCustomExerciseNameMax,
            autofocus: !_isEdit && widget.initialName.isEmpty,
            semanticsIdentifier: 'custom-exercise-name',
            onChanged: (_) {
              if (_problem != null) setState(() => _problem = null);
            },
          ),
          const EditorSectionLabel('Equipment'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final value in equipmentValues)
                SelectChip(
                  key: CustomExerciseEditorScreen.equipmentKey(value),
                  label: exerciseEquipmentLabel(value),
                  selected: _equipment == value,
                  onTap: () => setState(() => _equipment = value),
                ),
            ],
          ),
          EditorSectionLabel(
            'How you log it',
            caption: loadLocked && _isEdit && _logged == true
                ? 'Fixed, because this exercise is already in your workouts: '
                    'changing it would change what those sets mean.'
                : loadTypeChoiceCaption(_loadType),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final type in LoadType.values)
                SelectChip(
                  key: CustomExerciseEditorScreen.loadTypeKey(type),
                  label: loadTypeChoiceLabel(type),
                  selected: _loadType == type,
                  enabled: !loadLocked || _loadType == type,
                  onTap: () => setState(() => _loadType = type),
                ),
            ],
          ),
          const EditorSectionLabel(
            'Main muscles',
            caption: 'What it trains directly. Pick at least one.',
          ),
          _MuscleChoice(
            selected: _primary,
            disabled: const <String>[],
            keyFor: CustomExerciseEditorScreen.primaryKey,
            semanticsPrefix: 'Main muscle',
            onTap: _togglePrimary,
          ),
          const EditorSectionLabel(
            'Also works',
            caption: 'Optional. Muscles it works less.',
          ),
          _MuscleChoice(
            selected: _secondary,
            disabled: _primary,
            keyFor: CustomExerciseEditorScreen.secondaryKey,
            semanticsPrefix: 'Also works',
            onTap: _toggleSecondary,
          ),
          if (_problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _problem!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppPalette.danger,
                  ),
                ),
              ),
            ),
          if (_isEdit) ...<Widget>[
            const SizedBox(height: 24),
            if (_logged == false)
              EditorTextAction(
                actionKey: CustomExerciseEditorScreen.deleteKey,
                label: 'Delete exercise',
                destructive: true,
                onTap: _delete,
              )
            else if (_logged == true) ...<Widget>[
              // A logged exercise cannot be deleted, so hiding is how it is
              // retired (`docs/adr/0011-combined-build-decisions.md`).
              EditorTextAction(
                actionKey: CustomExerciseEditorScreen.hideKey,
                label: _hidden ? 'Show in picker' : 'Hide from picker',
                onTap: () => ref
                    .read(customExerciseListProvider.notifier)
                    .setHidden(widget.existing!.id, !_hidden),
              ),
              const SizedBox(height: 4),
              Text(
                _hidden
                    ? 'Hidden from the exercise picker. It stays in History, '
                        'your records and export.'
                    : 'It is in your workouts, so it cannot be deleted: its '
                        'sets would lose their name. Hide it from the picker '
                        'instead.',
                style:
                    const TextStyle(fontSize: 13, color: AppPalette.textMuted),
              ),
            ],
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// The 19 sub-muscle groups as chips, under their parent group's name.
class _MuscleChoice extends StatelessWidget {
  const _MuscleChoice({
    required this.selected,
    required this.disabled,
    required this.keyFor,
    required this.semanticsPrefix,
    required this.onTap,
  });

  final List<String> selected;
  final List<String> disabled;
  final Key Function(String id) keyFor;
  final String semanticsPrefix;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final group in kMuscleTaxonomy.entries)
          for (final sub in group.value)
            if (kSubMuscleGroups['${group.key}/$sub'] case final muscle?)
              SelectChip(
                key: keyFor(muscle.id),
                label: muscle.label,
                semanticsLabel: '$semanticsPrefix: ${muscle.label}',
                selected: selected.contains(muscle.id),
                enabled: !disabled.contains(muscle.id),
                onTap: () => onTap(muscle.id),
              ),
      ],
    );
  }
}

/// A custom exercise's page: what the user told the app, the muscles on the
/// body, and a plain note that there is no form guide.
///
/// **Reached through `pushExerciseDetail`**, which sends a custom exercise
/// here instead of to the library page, so every route that opens an exercise
/// — the picker's first-time gate, the logging screen's info button, the
/// Muscles tab — lands on the right one.
class CustomExerciseScreen extends ConsumerWidget {
  const CustomExerciseScreen({
    required this.exerciseId,
    this.entry = ExerciseDetailEntry.reference,
    super.key,
  });

  final String exerciseId;
  final ExerciseDetailEntry entry;

  static const Key editKey = ValueKey<String>('custom-exercise-edit');
  static const Key noteKey = ValueKey<String>('custom-exercise-note');
  static const Key startLoggingKey = ValueKey<String>('start-logging');
  static const Key addToWorkoutKey = ValueKey<String>('add-to-workout');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read live, so an edit made from this page shows on return.
    final exercise = ref.watch(exerciseIndexProvider).byId(exerciseId);
    if (exercise == null) {
      return AppScreen.pushed(
        title: 'Exercise',
        body: ListView(
          padding: screenScrollPadding(context),
          children: const <Widget>[
            SizedBox(height: 24),
            Text('This exercise was deleted.',
                style: TextStyle(fontSize: 15, color: AppPalette.textMuted)),
          ],
        ),
      );
    }
    final session = ref.watch(activeSessionProvider);
    final views = bodyViewsForExercise(exercise);
    final fill = _fillFor(exercise);

    return AppScreen.pushed(
      title: exercise.name,
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              exerciseFactsLabel(exercise),
              style: kLandingSectionLabelStyle,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            key: noteKey,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppPalette.border),
            ),
            child: const Text(
              kCustomExerciseNote,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppPalette.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: const Text('Muscles', style: kLandingSectionLabelStyle),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: <Widget>[
              for (final id in exercise.primary) _Legend(id: id, primary: true),
              for (final id in exercise.secondary)
                _Legend(id: id, primary: false),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: kExerciseDiagramHeight,
            child: Row(
              children: <Widget>[
                for (final view in views) ...<Widget>[
                  if (view != views.first) const SizedBox(width: 10),
                  Expanded(child: BodyDiagram(view: view, fill: fill.colorFor)),
                ],
              ],
            ),
          ),
          ..._action(context, ref, exercise, session),
          const SizedBox(height: 8),
          GhostButton(
            buttonKey: editKey,
            label: 'Edit exercise',
            leadingIcon: Icons.edit_outlined,
            onTap: () => showCustomExerciseEditor(context, existing: exercise),
          ),
        ],
      ),
    );
  }

  List<Widget> _action(
    BuildContext context,
    WidgetRef ref,
    Exercise exercise,
    WorkoutSession? session,
  ) {
    switch (entry) {
      case ExerciseDetailEntry.fromLogging:
        return const <Widget>[];
      case ExerciseDetailEntry.workoutStart:
        return <Widget>[
          const SizedBox(height: 16),
          FilledButton(
            key: startLoggingKey,
            onPressed: () => startLoggingFromDetail(context, ref, exercise),
            child: const Text('Start logging'),
          ),
        ];
      case ExerciseDetailEntry.reference:
        if (session == null) return const <Widget>[];
        return <Widget>[
          const SizedBox(height: 16),
          FilledButton(
            key: addToWorkoutKey,
            onPressed: () async {
              final loadType = LoadType.fromName(exercise.loadType);
              if (loadType == null) return;
              await ref.read(activeSessionProvider.notifier).addExercise(
                    exerciseId: exercise.id,
                    loadType: loadType,
                  );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${exercise.name} added')),
              );
            },
            child: const Text('Add to current workout'),
          ),
        ];
    }
  }

  /// One fill per muscle set, so the painter's identity-based repaint guard
  /// holds across rebuilds, and an edit to the muscles gets a new one.
  static MuscleFill _fillFor(Exercise exercise) => _fills.putIfAbsent(
        '${exercise.primary.join(',')}|${exercise.secondary.join(',')}',
        () => MuscleFill.forExercise(exercise),
      );

  static final Map<String, MuscleFill> _fills = <String, MuscleFill>{};
}

class _Legend extends StatelessWidget {
  const _Legend({required this.id, required this.primary});

  final String id;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final label = kSubMuscleGroups[id]?.label ?? id;
    return Semantics(
      container: true,
      label: primary ? 'Primary muscle: $label' : 'Also works: $label',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary ? AppPalette.accentStrong : AppPalette.accentLight,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style:
                  primary ? kMuscleChipPrimaryStyle : kMuscleChipSecondaryStyle,
            ),
          ],
        ),
      ),
    );
  }
}

/// Every exercise the user made, and the way to make another.
class MyExercisesScreen extends ConsumerWidget {
  const MyExercisesScreen({super.key});

  static const Key newKey = ValueKey<String>('my-exercises-new');

  static Key rowKey(String id) => ValueKey<String>('my-exercise-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(customExerciseListProvider);
    return AppScreen.pushed(
      title: 'My exercises',
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 12),
          GhostButton(
            buttonKey: newKey,
            label: 'New exercise',
            leadingIcon: Icons.add_rounded,
            onTap: () => showCustomExerciseEditor(context),
          ),
          const SizedBox(height: 8),
          if (mine.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'None yet. Make one for a machine or a movement the library '
                'does not have; it works everywhere a built-in one does.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppPalette.textMuted,
                ),
              ),
            )
          else
            for (final exercise in mine)
              KeyedSubtree(
                key: rowKey(exercise.id),
                child: ExerciseRow(
                  name: exercise.name,
                  equipment: exercise.equipment,
                  subtitle: '${loadTypeChoiceLabel(
                    LoadType.fromName(exercise.loadType) ?? LoadType.weighted,
                  )}${exercise.hidden ? ' · Hidden from picker' : ''}',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CustomExerciseScreen(exerciseId: exercise.id),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
