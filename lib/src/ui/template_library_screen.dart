import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/custom_templates.dart';
import '../data/workout_templates.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'template_row.dart';

/// The only place templates are authored (`docs/00-build-spec.md` §11).
///
/// **Three verbs, and the absence of a fourth is a decision.** A predefined
/// template can be duplicated; the copy can be renamed and deleted. There is no
/// way to build one from scratch and no way to change which muscle groups a
/// copy contains — both are deferred (KD4), which means a duplicate currently
/// differs from its original only in its name. That is a real limitation and
/// `docs/04` records it rather than implying otherwise.
///
/// **Predefined templates are immutable and the screen never offers to change
/// one.** They are the reliable reference a user compares their own against; a
/// rename or delete action on one of those rows would be the bug, not a missing
/// guard. So the two groups carry different trailing actions rather than one
/// row type that hides buttons based on a flag.
class TemplateLibraryScreen extends ConsumerWidget {
  const TemplateLibraryScreen({super.key});

  /// The heading over the eleven templates that ship with the app.
  @visibleForTesting
  static const String predefinedGroupLabel = 'PREDEFINED';

  /// The heading over the user's own copies.
  @visibleForTesting
  static const String customGroupLabel = 'YOURS';

  /// What the custom group says before the user has duplicated anything.
  ///
  /// Not an [EmptyState]: the screen is not empty — eleven predefined rows sit
  /// above this line — so the full-screen treatment would be wrong. It is one
  /// muted line naming the action that fills the group.
  @visibleForTesting
  static const String noCustomTemplatesLabel =
      'Duplicate one above to make it yours.';

  /// Finds a row by the template id it renders. Ids are stable across renames,
  /// which is exactly what a test needs to hold on to.
  @visibleForTesting
  static Key rowKey(String templateId) => ValueKey<String>('template-$templateId');

  /// Finds the duplicate button on a predefined row.
  @visibleForTesting
  static Key duplicateKey(String templateId) =>
      ValueKey<String>('duplicate-$templateId');

  /// Finds the rename button on a custom row.
  @visibleForTesting
  static Key renameKey(String templateId) =>
      ValueKey<String>('rename-$templateId');

  /// Finds the delete button on a custom row.
  @visibleForTesting
  static Key deleteKey(String templateId) =>
      ValueKey<String>('delete-$templateId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = ref.watch(customTemplatesProvider);

    return AppScreen.pushed(
      title: templatesRowTitleForHeader,
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const _GroupLabel(predefinedGroupLabel),
          for (final template in kPredefinedTemplates)
            _LibraryRow(
              key: rowKey(template.id),
              template: template,
              actions: <Widget>[
                _RowAction(
                  key: duplicateKey(template.id),
                  icon: Icons.content_copy_rounded,
                  semanticsLabel: 'Duplicate ${template.name}',
                  onTap: () => _duplicate(context, ref, template),
                ),
              ],
            ),
          const _GroupLabel(customGroupLabel),
          if (custom.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                noCustomTemplatesLabel,
                style: kTemplateRowSubtitleStyle,
              ),
            )
          else
            for (final template in custom)
              _LibraryRow(
                key: rowKey(template.id),
                template: template,
                actions: <Widget>[
                  _RowAction(
                    key: renameKey(template.id),
                    icon: Icons.edit_outlined,
                    semanticsLabel: 'Rename ${template.name}',
                    onTap: () => _rename(context, ref, template),
                  ),
                  _RowAction(
                    key: deleteKey(template.id),
                    icon: Icons.delete_outline_rounded,
                    semanticsLabel: 'Delete ${template.name}',
                    destructive: true,
                    onTap: () => _confirmDelete(context, ref, template),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    WorkoutTemplate source,
  ) async {
    final existing = ref
        .read(customTemplatesProvider)
        .map((template) => template.name)
        .toSet();

    await ref.read(customTemplateListProvider.notifier).add(
          name: duplicateName(source.name, existing),
          groupIds: source.groupIds,
          sourceTemplateId: source.id,
        );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    WorkoutTemplate template,
  ) async {
    final name = await _promptForName(context, initial: template.name);
    if (name == null) return;
    await ref.read(customTemplateListProvider.notifier).rename(
          template.id,
          name,
        );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WorkoutTemplate template,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'Delete ${template.name}?',
      body: 'This cannot be undone. The predefined template it came from is '
          'not affected.',
      confirmLabel: 'Delete',
    );
    if (confirmed != true) return;
    await ref.read(customTemplateListProvider.notifier).delete(template.id);
  }
}

/// The header copy, kept here so the row that opens this screen and the screen
/// itself cannot drift apart. Mirrors `profile_screen.dart`'s row title.
const String templatesRowTitleForHeader = 'My workout templates';

/// The name a duplicate of [sourceName] gets, avoiding everything in [taken].
///
/// **`docs/04` gives one worked example — "Push day (mine)" — and no rule for
/// the second one.** That gap was left to implementation deliberately, so the
/// convention is: the first copy takes the documented suffix, and each
/// subsequent copy appends an ascending integer — "Push day (mine) 2", then
/// "Push day (mine) 3". Numbering only from the second copy keeps the common
/// case matching the doc exactly, and a user who only ever duplicates once
/// never sees a number at all.
///
/// Uniqueness is by name rather than by count, so deleting "(mine) 2" and
/// duplicating again reuses that name instead of skipping to 4 and leaving a
/// gap the user cannot explain.
String duplicateName(String sourceName, Set<String> taken) {
  final base = '$sourceName (mine)';
  if (!taken.contains(base)) return base;
  for (var n = 2;; n++) {
    final candidate = '$base $n';
    if (!taken.contains(candidate)) return candidate;
  }
}

/// A template row that can carry actions on its right.
///
/// **Not `TemplateRow`, and not because of styling.** `TemplateRow` wraps its
/// whole body in one `GestureDetector` under a single `onTap` and reports
/// itself to the semantics tree as one button, so it structurally cannot expose
/// rename *and* delete — the second action has nowhere to live and a screen
/// reader would have no way to reach it. `DividerRow` has the same shape. This
/// follows their visual pattern with a trailing slot instead, the same way
/// those two generalised the pattern for their own screens.
class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    required this.template,
    required this.actions,
    super.key,
  });

  final WorkoutTemplate template;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: TemplateRow.minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppPalette.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(template.name, style: kTemplateRowTitleStyle),
                const SizedBox(height: 2),
                Text(template.subtitle, style: kTemplateRowSubtitleStyle),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ...actions,
        ],
      ),
    );
  }
}

/// One tappable glyph on the right of a row.
///
/// Its own tap target rather than a slice of the row's, so each action is
/// separately reachable — the thing `TemplateRow` cannot do. 44pt square keeps
/// two of them inside the row's 48pt band while staying tappable.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String semanticsLabel;
  final VoidCallback onTap;

  /// Paints the glyph [AppPalette.danger]. Only delete passes this: the palette
  /// reserves that colour for destruction, and `accentStrong` would read as
  /// approval because it means "this has been worked" everywhere else.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
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
            color: destructive ? AppPalette.danger : AppPalette.textMuted,
          ),
        ),
      ),
    );
  }
}

/// A section heading, matching `ProfileScreen` and `MusclesRoot`.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(label, style: kLandingSectionLabelStyle),
      ),
    );
  }
}

/// Asks for a new template name, returning null when the user backs out.
///
/// Built from the palette rather than Material's `AlertDialog` defaults, for
/// the reason `template_row.dart` gives about `ListTile`: this app has no
/// Material text theme, so a stock dialog would arrive with a density and a
/// colour scheme that exist nowhere else in it.
Future<String?> _promptForName(
  BuildContext context, {
  required String initial,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(initial: initial),
  );
}

/// The rename prompt, stateful **so that it owns its controller**.
///
/// A controller created by the caller and disposed when `showDialog` returns is
/// disposed too early: the dialog's exit animation is still running and still
/// rebuilding the field, which throws. Owning it here ties its lifetime to the
/// widget that actually uses it.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// An emptied name is refused rather than saved: a blank row would be
  /// unidentifiable both here and in the Workout landing.
  void _save() {
    final name = _controller.text.trim();
    Navigator.of(context).pop(name.isEmpty ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    return _PaletteDialog(
      title: 'Rename template',
      body: TextField(
        controller: _controller,
        autofocus: true,
        style: kTemplateRowTitleStyle,
        cursorColor: AppPalette.accentStrong,
        onSubmitted: (_) => _save(),
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: AppPalette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppPalette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppPalette.accentStrong),
          ),
        ),
      ),
      confirmLabel: 'Save',
      onConfirm: _save,
    );
  }
}

/// Asks the user to confirm a destructive action.
Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => _PaletteDialog(
      title: title,
      body: Text(body, style: kTemplateRowSubtitleStyle),
      confirmLabel: confirmLabel,
      destructive: true,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
}

/// The one dialog shell both prompts use, painted from [AppPalette].
class _PaletteDialog extends StatelessWidget {
  const _PaletteDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.onConfirm,
    this.destructive = false,
  });

  final String title;
  final Widget body;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppPalette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: kTemplateRowTitleStyle),
            const SizedBox(height: 10),
            body,
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _DialogButton(
                    label: 'Cancel',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DialogButton(
                    label: confirmLabel,
                    destructive: destructive,
                    onTap: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: destructive ? AppPalette.danger : AppPalette.mutedSurface,
            border: Border.all(
              color: destructive ? AppPalette.danger : AppPalette.border,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: destructive ? AppPalette.onAccent : AppPalette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
