import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/active_session.dart';
import '../data/body_gender.dart';
import '../data/custom_exercises.dart';
import '../data/custom_templates.dart';
import '../data/data_export.dart';
import '../data/data_reset.dart';
import '../data/diet_derived.dart' show versionInEffectOn;
import '../data/diet_plan.dart';
import '../data/exercise_index.dart';
import '../data/food_index.dart';
import '../data/personal_details_store.dart';
import '../data/reminder_prefs.dart';
import '../data/reminder_scheduler.dart' show reminderSchedulerProvider;
import '../data/settings_store.dart' show appDatabaseProvider;
import '../data/training_plan.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'destructive_confirmation.dart';

/// The two Profile data actions: take everything with you, or remove it.
///
/// They share a file because they share a shape -- one paragraph saying exactly
/// what the action covers, the counts it covers, and one button -- and because
/// a reader checking what "everything" means in one should see the other.

/// What the user has entered, counted, so both screens can say what they act
/// on rather than gesturing at "your data".
class _DataCounts {
  const _DataCounts({
    required this.workouts,
    required this.sets,
    required this.weighIns,
    required this.templates,
    required this.exercises,
    required this.foodsPlanned,
    required this.hasDiet,
    required this.trainingDays,
    required this.hasSchedule,
    required this.hasReminders,
  });

  factory _DataCounts.read(WidgetRef ref) {
    final sessions =
        ref.watch(savedSessionsProvider).where((s) => !s.isOpen).toList();
    final dietPlan = ref.watch(dietPlanLogProvider);
    return _DataCounts(
      workouts: sessions.length,
      sets: sessions.fold(0, (n, s) => n + s.completedSets.length),
      weighIns: ref.watch(bodyweightLogProvider).length,
      templates: ref.watch(customTemplatesProvider).length,
      exercises: ref.watch(customExerciseListProvider).length,
      // The plan the user is looking at: this week's version in effect.
      foodsPlanned: versionInEffectOn(dietPlan, ref.watch(planTodayProvider))
              ?.items
              .length ??
          0,
      hasDiet:
          dietPlan.isNotEmpty || ref.watch(proteinTargetProvider) != null,
      // This week's plan, the one the Schedule pane shows (profile audit B9).
      trainingDays: ref.watch(todayPlanWeekdaysProvider).length,
      hasSchedule: ref.watch(trainingPlanLogProvider).isNotEmpty,
      hasReminders:
          ref.watch(reminderPrefsProvider) != ReminderPreferences.defaults,
    );
  }

  final int workouts;
  final int sets;
  final int weighIns;
  final int templates;

  /// Exercises the user created (ADR 0009).
  final int exercises;

  /// Items in this week's plan, every day and slot.
  final int foodsPlanned;

  /// Any plan version or a target exists, even if this week is empty.
  final bool hasDiet;

  /// Days in this week's training plan.
  final int trainingDays;

  /// Any training plan was ever saved.
  final bool hasSchedule;

  /// A reminder setting differs from the defaults.
  final bool hasReminders;

  /// Nothing the user entered, so nothing to export (B9: a schedule or a
  /// reminder setting alone is entered data and is in the file).
  bool get isEmpty =>
      workouts == 0 &&
      weighIns == 0 &&
      templates == 0 &&
      exercises == 0 &&
      !hasDiet &&
      !hasSchedule &&
      !hasReminders;

  /// Label and count. The label already names the unit, so the count stands
  /// alone ("Workouts 12", not "Workouts 12 workouts").
  List<(String, String)> get rows => <(String, String)>[
        ('Workouts', '$workouts'),
        ('Completed sets', '$sets'),
        ('Bodyweight entries', '$weighIns'),
        ('Your templates', '$templates'),
        if (exercises > 0) ('Your exercises', '$exercises'),
        ('Foods planned', '$foodsPlanned'),
        ('Training days', trainingDays == 0 ? 'None' : '$trainingDays a week'),
      ];
}

class _CountsCard extends StatelessWidget {
  const _CountsCard({required this.counts});

  final _DataCounts counts;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          border: Border.all(color: AppPalette.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: <Widget>[
            for (final (label, value) in counts.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppPalette.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.textPrimary,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

const TextStyle _bodyStyle = TextStyle(
  fontSize: 15,
  height: 1.5,
  color: AppPalette.textSecondary,
);

/// Writes the export file and opens the share sheet on it.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  static const Key exportKey = ValueKey<String>('export-button');
  static const Key statusKey = ValueKey<String>('export-status');

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _busy = false;
  String? _status;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final now = DateTime.now();
      final json = buildExportJson(
        sessions: ref.read(savedSessionsProvider),
        bodyweight: ref.read(bodyweightLogProvider),
        customTemplates: ref.read(customTemplatesProvider),
        customExercises: ref.read(customExerciseListProvider),
        trainingPlan: ref.read(trainingPlanLogProvider),
        gender: ref.read(bodyGenderProvider),
        index: ref.read(exerciseIndexProvider),
        dietPlan: ref.read(dietPlanLogProvider),
        mealTicks: ref.read(mealTicksProvider),
        proteinTargetG: ref.read(proteinTargetProvider),
        foods: ref.read(foodIndexProvider),
        exportedAt: now,
        reminders: ref.read(reminderPrefsProvider),
      );
      final csv = buildSetsCsv(
        sessions: ref.read(savedSessionsProvider),
        index: ref.read(exerciseIndexProvider),
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${exportFileName(now)}');
      await file.writeAsString(json);
      final csvFile = File('${dir.path}/${setsCsvFileName(now)}');
      await csvFile.writeAsString(csv);
      if (!mounted) return;
      // The share sheet anchors to the button on iPad; on a phone it is
      // ignored.
      final box = context.findRenderObject() as RenderBox?;
      final result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile(file.path, mimeType: 'application/json'),
            XFile(csvFile.path, mimeType: 'text/csv'),
          ],
          subject: 'TurtleLift export',
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (!mounted) return;
      setState(() {
        _status = switch (result.status) {
          ShareResultStatus.success => 'Exported ${exportFileName(now)}.',
          ShareResultStatus.dismissed => 'Export cancelled. Nothing was sent.',
          ShareResultStatus.unavailable => 'Exported ${exportFileName(now)}.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = 'Could not create the export file. Try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = _DataCounts.read(ref);
    return AppScreen.pushed(
      title: 'Export everything',
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 8),
          const Text(
            'Saves every finished workout, set, bodyweight entry, template, '
            'your schedule, your reminders and your diet plan as one JSON file, '
            'plus a CSV of your sets for a spreadsheet. Choose where they go: '
            'Files, Mail, or another app.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 16),
          _CountsCard(counts: counts),
          const SizedBox(height: 20),
          FilledButton(
            key: ExportScreen.exportKey,
            onPressed: _busy || counts.isEmpty ? null : _export,
            child: Text(_busy ? 'Preparing file' : 'Export'),
          ),
          if (counts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Nothing to export yet. Log a workout first.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppPalette.textMuted),
              ),
            ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _status!,
                  key: ExportScreen.statusKey,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppPalette.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Deletes everything, after saying exactly what that covers and asking once.
class DeleteAllDataScreen extends ConsumerStatefulWidget {
  const DeleteAllDataScreen({super.key});

  static const Key deleteKey = ValueKey<String>('delete-all-button');

  /// The softer exit, inside the flow (ADR 0014 §6).
  static const Key exportFirstKey = ValueKey<String>('delete-export-first');

  @override
  ConsumerState<DeleteAllDataScreen> createState() =>
      _DeleteAllDataScreenState();
}

class _DeleteAllDataScreenState extends ConsumerState<DeleteAllDataScreen> {
  bool _busy = false;

  void _exportFirst() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ExportScreen()),
      );

  Future<void> _delete() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete all data?',
      message: 'Every workout, set, bodyweight entry, template, your '
          'schedule and your diet plan will be removed from this phone. This '
          'cannot be undone.',
      confirmLabel: 'Delete all',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final restart = ref.read(appRestartProvider);
    await wipeAllData(ref.read(appDatabaseProvider),
        reminders: ref.read(reminderSchedulerProvider));
    // Reboots onto the empty database; this screen and its route go with the
    // old tree, so nothing after this line touches widget state.
    await restart();
  }

  @override
  Widget build(BuildContext context) {
    final counts = _DataCounts.read(ref);
    return AppScreen.pushed(
      title: 'Delete all data',
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 8),
          const Text(
            'Removes everything you have entered from this phone. There is no '
            'cloud copy, so it cannot be recovered. Files you already exported '
            'or shared are not touched.',
            style: _bodyStyle,
          ),
          Semantics(
            container: true,
            button: true,
            label: 'Export first',
            excludeSemantics: true,
            onTap: _exportFirst,
            child: GestureDetector(
              key: DeleteAllDataScreen.exportFirstKey,
              behavior: HitTestBehavior.opaque,
              onTap: _exportFirst,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Export first',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textPrimary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppPalette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _CountsCard(counts: counts),
          const SizedBox(height: 20),
          Semantics(
            container: true,
            button: true,
            enabled: !_busy,
            label: 'Delete all data',
            onTap: _busy ? null : _delete,
            excludeSemantics: true,
            child: GestureDetector(
              key: DeleteAllDataScreen.deleteKey,
              behavior: HitTestBehavior.opaque,
              onTap: _busy ? null : _delete,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppPalette.mutedSurface,
                  border: Border.all(color: AppPalette.danger),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _busy ? 'Deleting' : 'Delete all data',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.danger,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
