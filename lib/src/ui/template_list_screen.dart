import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/custom_templates.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/template_filter.dart';
import '../data/workout_templates.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'destructive_confirmation.dart';
import 'exercise_picker_screen.dart';
import 'template_filter_control.dart';
import 'template_library_screen.dart';
import 'template_row.dart' show TemplateRow, kLandingCountStyle;

/// The eleven shipped templates, plus the user's own.
///
/// **A template is a starting point, not a routine** (`CONTEXT.md`). It names
/// parent muscle groups and carries no exercises, so picking one cannot fill a
/// workout — it opens an empty one with the exercise picker already narrowed to
/// those muscles. That is the whole of what the old "template lock" is now:
/// a filter the user can clear, rather than a rule that refused an add.
///
/// **This used to be the Workout landing.** The landing lists routines since
/// `adr/0004`; the template list moved here, behind the `Templates` button, and
/// kept its split filter and its route to the authoring screen.
class TemplateListScreen extends ConsumerWidget {
  const TemplateListScreen({super.key});

  /// The group heading over the user's own templates.
  @visibleForTesting
  static const String customGroupLabel = 'YOUR TEMPLATES';

  /// The row that opens the template library.
  @visibleForTesting
  static const Key manageTemplatesKey = ValueKey<String>('manage-templates');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(templateFilterProvider);
    final templates = templatesFor(filter);
    final custom = ref.watch(customTemplatesProvider);

    return AppScreen.pushed(
      title: 'Templates',
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: const Text('TEMPLATES',
                      style: kLandingSectionLabelStyle),
                ),
              ),
              TemplateFilterControl(
                current: filter,
                onSelected: (chosen) =>
                    ref.read(templateFilterProvider.notifier).select(chosen),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child:
                Text(_countLabel(templates.length), style: kLandingCountStyle),
          ),
          for (final template in templates)
            TemplateRow(
              key: ValueKey<String>('template-${template.id}'),
              template: template,
              onTap: () => _start(context, ref, template),
            ),
          // Absent entirely when the user has none — not a heading standing
          // over nothing.
          if (custom.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Semantics(
              header: true,
              child: const Text(customGroupLabel,
                  style: kLandingSectionLabelStyle),
            ),
            const SizedBox(height: 10),
            for (final template in custom)
              TemplateRow(
                key: ValueKey<String>('custom-template-${template.id}'),
                template: template,
                onTap: () => _start(context, ref, template),
              ),
          ],
          const SizedBox(height: 4),
          _ManageTemplatesLink(),
        ],
      ),
    );
  }

  /// Starts an empty workout narrowed to [template]'s muscles, then hands the
  /// user straight to the picker — the template's whole contribution.
  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    WorkoutTemplate template,
  ) async {
    if (!await _closeOpenWorkout(context, ref)) return;
    await ref.read(activeSessionProvider.notifier).startFromTemplate(
          templateId: template.id,
          templateName: template.name,
          groupIds: template.groupIds,
        );
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  /// Saves or drops the workout already running. Returns false when the user
  /// backed out, in which case nothing else should happen.
  ///
  /// **Starting a new workout never loses the old one.** One with at least one
  /// completed set is saved exactly as if Finish had been tapped — keeping its
  /// own date, so a Monday workout abandoned on Wednesday still files as
  /// Monday — and the user is told. One with nothing completed is dropped, and
  /// asked about first when values were typed but never ticked.
  Future<bool> _closeOpenWorkout(BuildContext context, WidgetRef ref) async {
    final open = ref.read(activeSessionProvider);
    if (open == null) return true;

    final notifier = ref.read(activeSessionProvider.notifier);
    final index = ref.read(exerciseIndexProvider);

    if (setCountOf(open) > 0) {
      final name = resolvedTitle(open, index);
      await notifier.finish();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$name saved')));
      }
      return true;
    }

    if (open.hasAnyWrittenSets) {
      final confirmed = await confirmDestructive(
        context,
        title: 'Discard the workout in progress?',
        message: 'It has values typed but no sets ticked, so there is nothing '
            'to save.',
        confirmLabel: 'Discard',
      );
      if (!confirmed) return false;
    }
    await notifier.discard();
    return true;
  }

  static String _countLabel(int count) =>
      '$count template${count == 1 ? '' : 's'}';
}

/// The visible route to template authoring, which otherwise sits behind an
/// unlabelled disc in the header (`adr/0003`).
///
/// **A link, not a card.** It is navigation to an admin surface; as a full card
/// it claimed the same weight as "Full body day" while being the one row here
/// that starts no workout at all.
class _ManageTemplatesLink extends StatelessWidget {
  const _ManageTemplatesLink();

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Manage templates',
        excludeSemantics: true,
        child: GestureDetector(
          key: TemplateListScreen.manageTemplatesKey,
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const TemplateLibraryScreen(),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: <Widget>[
                Text('Manage templates',
                    style: TextStyle(
                        color: AppPalette.textSecondary, fontSize: 14)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppPalette.textMuted),
              ],
            ),
          ),
        ),
      );
}

/// Pushes the template list.
Future<void> pushTemplateList(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const TemplateListScreen()));

/// After a template starts a workout, the picker opens narrowed to its muscles.
Future<void> pushPickerForGroups(
  BuildContext context,
  List<String> groupIds,
) =>
    Navigator.of(context).push(
      MaterialPageRoute<List<String>>(
        builder: (_) => ExercisePickerScreen(preselectedGroupIds: groupIds),
      ),
    );
