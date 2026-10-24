import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise_index.dart';
import '../data/workout_templates.dart';
import '../theme/app_palette.dart';
import 'muscle_exercise_list_screen.dart' show exerciseEquipmentLabel;

/// Shows what [template] would put in a workout, and returns true when the user
/// chose to start it.
///
/// **Starting a template is two taps, and this is the second.** The preview is
/// the one look at the exercises before committing: a template is recognised by
/// its lifts far more than by its name, and starting one copies the list into a
/// workout that then replaces the landing.
///
/// A sheet, in the same shape as the app's other sheets (`showMuscleSegmentSheet`):
/// every visual is passed explicitly because `app_theme.dart` sets no
/// `bottomSheetTheme`.
Future<bool> showTemplatePreview(
  BuildContext context,
  WorkoutTemplate template,
) async {
  final started = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppPalette.surface,
    elevation: 0,
    barrierColor: const Color(0x8C000000),
    showDragHandle: false,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      side: BorderSide(color: AppPalette.border),
    ),
    builder: (_) => TemplatePreviewSheet(template: template),
  );
  return started ?? false;
}

/// The sheet's contents.
class TemplatePreviewSheet extends ConsumerWidget {
  const TemplatePreviewSheet({required this.template, super.key});

  final WorkoutTemplate template;

  /// The key a test taps to start the template.
  static const Key startKey = ValueKey<String>('template-preview-start');

  /// The row for the exercise at [position], zero-based.
  static Key rowKey(int position) =>
      ValueKey<String>('template-preview-row-$position');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(exerciseIndexProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                template.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: AppPalette.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              templateSubtitle(template, index),
              style: const TextStyle(fontSize: 12, color: AppPalette.textMuted),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: template.exerciseIds.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        'No exercises yet. Add them once the workout is '
                        'running.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppPalette.textSecondary,
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: <Widget>[
                        for (final (i, id) in template.exerciseIds.indexed)
                          _PreviewRow(
                            key: rowKey(i),
                            number: i + 1,
                            name: index.byId(id)?.name ?? 'Unknown exercise',
                            equipment: index.byId(id)?.equipment,
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              key: startKey,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start workout'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: AppPalette.textSecondary,
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.number,
    required this.name,
    required this.equipment,
    super.key,
  });

  final int number;
  final String name;
  final String? equipment;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 44),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppPalette.border)),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 22,
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppPalette.textMuted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppPalette.textPrimary,
                ),
              ),
            ),
            if (equipment != null)
              Text(
                exerciseEquipmentLabel(equipment!),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppPalette.textMuted,
                ),
              ),
          ],
        ),
      );
}
