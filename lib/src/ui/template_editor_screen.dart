import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/custom_templates.dart';
import '../data/exercise_index.dart';
import '../data/exercise_notes.dart' show swapInList;
import '../data/workout_templates.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'destructive_confirmation.dart';
import 'editor_parts.dart';
import 'exercise_picker_sheet.dart';
import 'ghost_button.dart';
import 'muscle_exercise_list_screen.dart' show exerciseEquipmentLabel;

/// Builds a template from scratch, or changes one of the user's own: its name,
/// which exercises, and their order (`docs/adr/0009-custom-exercises-and-template-editing.md`,
/// which also records this screen).
///
/// **The template is written only on Save.** Everything here is a draft held
/// in widget state, so backing out leaves the template exactly as it was —
/// asked first when there are unsaved changes.
///
/// **A predefined template is never edited here.** It is the immutable
/// reference; Duplicate makes a copy this screen can change.
Future<WorkoutTemplate?> showTemplateEditor(
  BuildContext context, {
  WorkoutTemplate? existing,
  List<String> initialExerciseIds = const <String>[],
  String initialName = '',
}) =>
    Navigator.of(context).push<WorkoutTemplate>(
      MaterialPageRoute<WorkoutTemplate>(
        builder: (_) => TemplateEditorScreen(
          existing: existing,
          initialExerciseIds: initialExerciseIds,
          initialName: initialName,
        ),
      ),
    );

class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({
    this.existing,
    this.initialExerciseIds = const <String>[],
    this.initialName = '',
    super.key,
  });

  final WorkoutTemplate? existing;
  final List<String> initialExerciseIds;
  final String initialName;

  static const Key saveKey = ValueKey<String>('template-editor-save');
  static const Key addKey = ValueKey<String>('template-editor-add');
  static const Key deleteKey = ValueKey<String>('template-editor-delete');

  static Key swapKey(String exerciseId) =>
      ValueKey<String>('template-editor-swap-$exerciseId');

  static Key rowKey(String exerciseId) =>
      ValueKey<String>('template-editor-row-$exerciseId');
  static Key removeKey(String exerciseId) =>
      ValueKey<String>('template-editor-remove-$exerciseId');
  static Key moveUpKey(String exerciseId) =>
      ValueKey<String>('template-editor-up-$exerciseId');
  static Key moveDownKey(String exerciseId) =>
      ValueKey<String>('template-editor-down-$exerciseId');

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? widget.initialName,
  );
  late final List<String> _ids = <String>[
    ...(widget.existing?.exerciseIds ?? widget.initialExerciseIds),
  ];
  late final String _startName = _name.text;
  late final List<String> _startIds = <String>[..._ids];
  String? _problem;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  bool get _dirty =>
      _name.text != _startName ||
      _ids.length != _startIds.length ||
      Iterable<int>.generate(_ids.length).any((i) => _ids[i] != _startIds[i]);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    // Put the keyboard away first, so the name field does not take focus
    // back (and the keyboard back over Save) when the sheet closes.
    FocusScope.of(context).unfocus();
    final chosen = await showMultiExercisePicker(
      context,
      title: 'Add exercises',
      alreadyChosen: List<String>.unmodifiable(_ids),
    );
    if (!mounted) return;
    // A closing sheet hands focus back to the field it took it from, once its
    // exit transition ends; take it away again after that, or the keyboard
    // comes back over the pinned Save bar.
    FocusScope.of(context).unfocus();
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    });
    if (chosen == null) return;
    setState(() {
      for (final exercise in chosen) {
        if (!_ids.contains(exercise.id)) _ids.add(exercise.id);
      }
      _problem = null;
    });
  }

  /// Swap in place: the picked exercise takes this row's position. A
  /// template has no sets, so unlike a live workout nothing can refuse it.
  Future<void> _swap(int i) async {
    final name =
        ref.read(exerciseIndexProvider).byId(_ids[i])?.name ?? 'exercise';
    final chosen = await showExercisePicker(
      context,
      title: 'Swap $name for',
      alreadyChosen: List<String>.unmodifiable(_ids),
    );
    if (!mounted || chosen == null) return;
    FocusScope.of(context).unfocus();
    final next = swapInList(_ids, i, chosen.id);
    setState(() {
      _ids
        ..clear()
        ..addAll(next);
      _problem = null;
    });
  }

  void _move(int from, int to) {
    if (to < 0 || to >= _ids.length || from == to) return;
    setState(() {
      final id = _ids.removeAt(from);
      _ids.insert(to, id);
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _problem = 'Give the template a name.');
      return;
    }
    if (_ids.isEmpty) {
      setState(() => _problem = 'Add at least one exercise.');
      return;
    }
    setState(() => _saving = true);
    final list = ref.read(customTemplateListProvider.notifier);
    final WorkoutTemplate saved;
    if (_isEdit) {
      await list.update(widget.existing!.id, name: name, exerciseIds: _ids);
      saved = ref
          .read(customTemplatesProvider)
          .firstWhere((t) => t.id == widget.existing!.id);
    } else {
      saved = await list.add(name: name, exerciseIds: _ids);
    }
    if (!mounted) return;
    Navigator.of(context).pop(saved);
  }

  Future<void> _delete() async {
    final template = widget.existing!;
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete ${template.name}?',
      message: 'Workouts you already did from it are kept. This cannot be '
          'undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;
    await ref.read(customTemplateListProvider.notifier).delete(template.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty || _saving) return true;
    return confirmDestructive(
      context,
      title: 'Discard your changes?',
      message: _isEdit
          ? 'The template stays as it was.'
          : 'The template is not saved.',
      confirmLabel: 'Discard',
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(exerciseIndexProvider);
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          setState(() => _saving = true);
          Navigator.of(context).pop();
        }
      },
      child: AppScreen.pushed(
        title: _isEdit ? 'Edit template' : 'New template',
        bottomBar: PinnedActionBar(
          child: FilledButton(
            key: TemplateEditorScreen.saveKey,
            onPressed: _saving ? null : _save,
            child: const Text('Save template'),
          ),
        ),
        body: ListView(
          padding: screenScrollPadding(context),
          children: <Widget>[
            const EditorSectionLabel('Name'),
            EditorTextField(
              controller: _name,
              hint: 'e.g. Monday upper',
              maxLength: 40,
              autofocus: !_isEdit && widget.initialName.isEmpty,
              semanticsIdentifier: 'template-name',
              onChanged: (_) => setState(() => _problem = null),
            ),
            EditorSectionLabel(
              _ids.isEmpty
                  ? 'Exercises'
                  : 'Exercises · ${_ids.length}',
              caption: _ids.isEmpty
                  ? 'Pick them in the order you do them.'
                  : 'In the order the workout lists them. Use the arrows to '
                      'move one.',
            ),
            for (final (i, id) in _ids.indexed)
              _EditorRow(
                key: TemplateEditorScreen.rowKey(id),
                exerciseId: id,
                number: i + 1,
                name: index.byId(id)?.name ?? 'Unknown exercise',
                detail: switch (index.byId(id)) {
                  final e? => e.isCustom
                      ? '${exerciseEquipmentLabel(e.equipment)} · Yours'
                      : exerciseEquipmentLabel(e.equipment),
                  null => 'No longer available',
                },
                isFirst: i == 0,
                isLast: i == _ids.length - 1,
                onUp: () => _move(i, i - 1),
                onDown: () => _move(i, i + 1),
                onSwap: () => _swap(i),
                onRemove: () => setState(() => _ids.removeAt(i)),
              ),
            const SizedBox(height: 8),
            GhostButton(
              buttonKey: TemplateEditorScreen.addKey,
              label: _ids.isEmpty ? 'Add exercises' : 'Add more exercises',
              leadingIcon: Icons.add_rounded,
              onTap: _add,
            ),
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _problem!,
                    style:
                        const TextStyle(fontSize: 13, color: AppPalette.danger),
                  ),
                ),
              ),
            if (_isEdit) ...<Widget>[
              const SizedBox(height: 24),
              EditorTextAction(
                actionKey: TemplateEditorScreen.deleteKey,
                label: 'Delete template',
                destructive: true,
                onTap: _delete,
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// One exercise in the draft: number, name, and move / remove controls.
///
/// **Arrows, not drag.** A drag handle needs a long-press or a precise grab,
/// both hard one-handed in a gym and invisible to VoiceOver without custom
/// actions; two 44pt buttons are neither.
class _EditorRow extends StatelessWidget {
  const _EditorRow({
    required this.exerciseId,
    required this.number,
    required this.name,
    required this.detail,
    required this.isFirst,
    required this.isLast,
    required this.onUp,
    required this.onDown,
    required this.onSwap,
    required this.onRemove,
    super.key,
  });

  final String exerciseId;
  final int number;
  final String name;
  final String detail;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onSwap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppPalette.border)),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 24,
              child: Text(
                '$number',
                style:
                    const TextStyle(fontSize: 12, color: AppPalette.textMuted),
              ),
            ),
            Expanded(
              child: Semantics(
                container: true,
                label: '$number. $name. $detail',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppPalette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            RowIconAction(
              key: TemplateEditorScreen.moveUpKey(exerciseId),
              icon: Icons.arrow_upward_rounded,
              semanticsLabel: 'Move $name up',
              onTap: isFirst ? null : onUp,
            ),
            RowIconAction(
              key: TemplateEditorScreen.moveDownKey(exerciseId),
              icon: Icons.arrow_downward_rounded,
              semanticsLabel: 'Move $name down',
              onTap: isLast ? null : onDown,
            ),
            RowIconAction(
              key: TemplateEditorScreen.swapKey(exerciseId),
              icon: Icons.swap_horiz_rounded,
              semanticsLabel: 'Swap $name for another exercise',
              onTap: onSwap,
            ),
            RowIconAction(
              key: TemplateEditorScreen.removeKey(exerciseId),
              icon: Icons.close_rounded,
              semanticsLabel: 'Remove $name',
              onTap: onRemove,
            ),
          ],
        ),
      );
}

/// A 44pt glyph button on a row, its own semantics node with its own tap.
/// Disabled (null [onTap]) draws it faint and leaves it out of the actions.
class RowIconAction extends StatelessWidget {
  const RowIconAction({
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        enabled: onTap != null,
        label: semanticsLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 18,
              color: onTap == null
                  ? AppPalette.border
                  : destructive
                      ? AppPalette.danger
                      : AppPalette.textSecondary,
            ),
          ),
        ),
      );
}
