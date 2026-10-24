import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/custom_templates.dart';
import '../data/derived.dart';
import '../data/exercise.dart';
import '../data/exercise_index.dart';
import '../data/workout_templates.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'destructive_confirmation.dart';
import 'muscle_exercise_list_screen.dart' show ExerciseRow;
import 'muscle_search_field.dart';
import 'session_entry.dart';
import 'session_overview_body.dart';
import 'session_summary_screen.dart';
import 'template_library_screen.dart';
import 'template_preview_sheet.dart';
import 'template_row.dart';

/// The Workout tab's body: start a workout, or carry on with the one that is
/// open.
///
/// **A body, never a `Scaffold`.** The shell owns the Scaffold and the pinned
/// header (`AppScreen`); a root that grew its own would nest two of each and
/// swallow the floating tab bar's inset on the way.
///
/// **The scrollable is this widget's, and so is its padding.** A `ListView`
/// with no `padding` quietly absorbs the bottom inset for you; the moment it
/// passes any padding of its own that automatic behaviour is skipped and the
/// last row slides under the tab bar with nothing failing. So every root passes
/// [screenScrollPadding] — the one rule, applied at the scrollable.
///
/// **Nothing here suggests a workout.** The landing lists what there is and
/// never says which one to do, never advances, and does not know what day it is.
/// That is the line `docs/02-workout-tab-userflow.md` draws.
///
/// This is the one root that has a second *structural* body: an open session
/// replaces the landing entirely. That is why [build] branches first and lays
/// out second.
class WorkoutRoot extends ConsumerWidget {
  const WorkoutRoot({super.key});

  /// The row that opens the template library from the Workout tab.
  @visibleForTesting
  static const Key manageTemplatesKey = ValueKey<String>('manage-templates');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen =
        ref.watch(activeSessionProvider.select((session) => session != null));
    if (isOpen) {
      // An open workout replaces the landing entirely, at stack depth zero.
      return SessionOverviewBody(
        onFinished: (id) => pushSessionSummary(context, id, celebrate: true),
      );
    }
    return const WorkoutLandingBody();
  }
}

/// Where a workout starts: the templates, a search over templates and
/// exercises, and the Start workout bar.
///
/// **Its own widget because it has two homes.** It is the Workout tab's landing
/// when nothing is open, and it is also what the open workout's header pushes
/// when the user wants to start a different one. Two copies would drift on the
/// groups and the start bar alike.
///
/// **There is no empty state, by construction.** Eleven templates ship, so the
/// screen has content on the very first launch.
///
/// **Start workout is pinned above the tab bar, not scrolled with the list.**
/// It is the one action every visit to this screen might want, and it belongs
/// where a thumb already rests, whichever template the user has scrolled to.
class WorkoutLandingBody extends ConsumerStatefulWidget {
  const WorkoutLandingBody({super.key, this.isPushed = false});

  /// Whether this is the pushed list reached from an open workout, in which
  /// case choosing something has to close the workout that is already running
  /// and then return to the root.
  final bool isPushed;

  /// The heading over the user's own templates.
  @visibleForTesting
  static const String customGroupLabel = 'MY TEMPLATES';

  /// The heading over the templates that ship with the app.
  @visibleForTesting
  static const String predefinedGroupLabel = 'READY-MADE';

  /// The pinned bar's button.
  @visibleForTesting
  static const Key startWorkoutKey = ValueKey<String>('start-workout');

  /// The tile for [templateId] — predefined or the user's own.
  @visibleForTesting
  static Key templateKey(String templateId) =>
      ValueKey<String>('template-$templateId');

  /// The exercise result for [exerciseId].
  @visibleForTesting
  static Key exerciseResultKey(String exerciseId) =>
      ValueKey<String>('landing-exercise-$exerciseId');

  @override
  ConsumerState<WorkoutLandingBody> createState() => _WorkoutLandingBodyState();
}

class _WorkoutLandingBodyState extends ConsumerState<WorkoutLandingBody> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(exerciseIndexProvider);
    final custom = ref.watch(customTemplatesProvider);
    final query = _query.trim();
    final inset = MediaQuery.paddingOf(context);
    final base = screenScrollPadding(context);

    return Stack(
      children: <Widget>[
        ListView(
          // Clears the pinned bar as well as whatever the system is intruding
          // on the bottom edge, or the last row would end up under the button.
          padding: base.copyWith(
            bottom: inset.bottom + kWorkoutStartBarClearance,
          ),
          children: <Widget>[
            const SizedBox(height: 4),
            MuscleSearchField.editable(
              controller: _controller,
              autofocus: false,
              hint: 'Search templates or exercises',
              onChanged: (value) => setState(() => _query = value),
            ),
            if (query.isEmpty)
              ..._browse(context, index, custom)
            else
              ..._results(context, index, custom, query),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: inset.bottom,
          child: _StartBar(onTap: () => _startEmpty(context)),
        ),
      ],
    );
  }

  List<Widget> _browse(
    BuildContext context,
    ExerciseIndex index,
    List<WorkoutTemplate> custom,
  ) =>
      <Widget>[
        if (custom.isNotEmpty) ...<Widget>[
          const _GroupLabel(WorkoutLandingBody.customGroupLabel),
          SizedBox(
            height: _kTileHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: <Widget>[
                for (final template in custom)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 150,
                      child: _TemplateTile(
                        key: WorkoutLandingBody.templateKey(template.id),
                        template: template,
                        subtitle: templateSubtitle(template, index),
                        onTap: () => _openTemplate(context, template),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const _GroupLabel(WorkoutLandingBody.predefinedGroupLabel),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: _kTileHeight,
          ),
          children: <Widget>[
            for (final template in kPredefinedTemplates)
              _TemplateTile(
                key: WorkoutLandingBody.templateKey(template.id),
                template: template,
                subtitle: templateSubtitle(template, index),
                onTap: () => _openTemplate(context, template),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // **Outside the groups above, deliberately.** This is the visible route
        // to template management, which a user with no templates of their own
        // is exactly the person who needs to find. It is navigation, not
        // authoring: the Workout tab still only starts workouts.
        TemplateRow(
          key: WorkoutRoot.manageTemplatesKey,
          title: 'Manage templates',
          subtitle: 'Duplicate, rename or delete your own',
          background: AppPalette.mutedSurface,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const TemplateLibraryScreen(),
            ),
          ),
        ),
      ];

  /// The search results: templates by name, then exercises by name.
  List<Widget> _results(
    BuildContext context,
    ExerciseIndex index,
    List<WorkoutTemplate> custom,
    String query,
  ) {
    final needle = query.toLowerCase();
    final templates = <WorkoutTemplate>[
      for (final template in <WorkoutTemplate>[...custom, ...kPredefinedTemplates])
        if (template.name.toLowerCase().contains(needle)) template,
    ];
    final exercises = index.searchByName(query);

    if (templates.isEmpty && exercises.isEmpty) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Text(
            'Nothing matches that name.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppPalette.textMuted),
          ),
        ),
      ];
    }

    return <Widget>[
      if (templates.isNotEmpty) ...<Widget>[
        const _GroupLabel('TEMPLATES'),
        for (final template in templates)
          TemplateRow(
            key: WorkoutLandingBody.templateKey(template.id),
            title: template.name,
            subtitle: templateSubtitle(template, index),
            onTap: () => _openTemplate(context, template),
          ),
      ],
      if (exercises.isNotEmpty) ...<Widget>[
        const _GroupLabel('EXERCISES · TAP TO START LOGGING'),
        for (final exercise in exercises)
          KeyedSubtree(
            key: WorkoutLandingBody.exerciseResultKey(exercise.id),
            child: ExerciseRow(
              name: exercise.name,
              equipment: exercise.equipment,
              onTap: () => _startWithExercise(context, exercise),
            ),
          ),
      ],
    ];
  }

  /// Previews [template], and on a yes starts it, closing whatever was already
  /// running.
  ///
  /// **Starting a new workout never loses the old one.** One with at least one
  /// completed set is saved exactly as if Finish had been tapped — keeping its
  /// own date, so a Monday workout abandoned on Wednesday still files as
  /// Monday — and the user is told. One with nothing completed is dropped, and
  /// asked about first when values were typed but never ticked.
  Future<void> _openTemplate(
    BuildContext context,
    WorkoutTemplate template,
  ) async {
    if (!await showTemplatePreview(context, template)) return;
    if (!context.mounted) return;
    if (!await _closeOpenWorkout(context)) return;
    await ref.read(activeSessionProvider.notifier).startFromTemplate(
          templateId: template.id,
          templateName: template.name,
          exerciseIds: template.exerciseIds,
        );
    _returnToRoot();
  }

  /// Starts an empty workout, which opens on its ready view.
  Future<void> _startEmpty(BuildContext context) async {
    if (!await _closeOpenWorkout(context)) return;
    await ref.read(activeSessionProvider.notifier).startAdHoc();
    _returnToRoot();
  }

  /// A search result is a workout in one tap: it starts one with that exercise.
  Future<void> _startWithExercise(
    BuildContext context,
    Exercise exercise,
  ) async {
    if (!await _closeOpenWorkout(context)) return;
    if (!context.mounted) return;
    await openExerciseForLogging(context, ref, exercise);
    _returnToRoot();
  }

  void _returnToRoot() {
    if (widget.isPushed && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Saves or drops the workout already running. Returns false when the user
  /// backed out, in which case nothing else should happen.
  Future<bool> _closeOpenWorkout(BuildContext context) async {
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
}

/// How tall a template tile stands.
const double _kTileHeight = 112;

/// How tall the pinned Start workout bar is, including its own padding.
const double kWorkoutStartBarHeight = 72;

/// What the landing's scrollable keeps clear at the bottom, beyond the system
/// inset: the pinned bar, and a little air above it for the last row.
const double kWorkoutStartBarClearance = kWorkoutStartBarHeight + 12;

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Semantics(
          header: true,
          child: Text(text, style: kLandingSectionLabelStyle),
        ),
      );
}

/// One template: its name, the muscles its exercises train, and how many there
/// are.
class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final WorkoutTemplate template;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = template.exerciseIds.length;
    return Semantics(
      button: true,
      label: '${template.name}. $subtitle. $count '
          'exercise${count == 1 ? '' : 's'}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppPalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                template.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: kTemplateRowTitleStyle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 3),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: kTemplateRowSubtitleStyle,
                ),
              ),
              Text(
                '$count exercise${count == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppPalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pinned Start workout bar.
class _StartBar extends StatelessWidget {
  const _StartBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(kScreenGutter, 8, kScreenGutter, 10),
        decoration: const BoxDecoration(
          color: AppPalette.pageBackground,
          border: Border(top: BorderSide(color: AppPalette.border)),
        ),
        child: FilledButton(
          key: WorkoutLandingBody.startWorkoutKey,
          onPressed: onTap,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Start workout',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
              Text(
                'Add exercises as you go',
                style: TextStyle(
                  fontSize: 11,
                  color: AppPalette.onAccent.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      );
}
