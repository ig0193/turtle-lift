import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/custom_templates.dart';
import '../data/template_filter.dart';
import '../data/workout_templates.dart';
import '../theme/app_palette.dart';
import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import 'adhoc_overview_body.dart';
import 'app_screen.dart';
import 'destructive_confirmation.dart';
import 'exercise_search_screen.dart';
import 'template_filter_control.dart';
import 'template_library_screen.dart';
import 'session_summary_screen.dart';
import 'template_overview_body.dart';
import 'template_row.dart';

/// The Workout tab's body: the templates you can start, filtered by split.
///
/// **There is no empty state here, by construction.** Eleven templates ship
/// with the app, so this screen has content on the very first launch — which is
/// the whole reason the landing lists them rather than hiding them behind a
/// picker. Day one is the app's fullest screen, not its emptiest.
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
/// **Nothing here suggests a workout.** The filter says which templates are
/// listed; it never says which one to do, never advances, and does not know
/// what day it is. That is the line `docs/02-workout-tab-userflow.md` draws,
/// and the reason the split control is a view filter rather than a declared
/// programme.
///
/// This is the one root that grows a second *structural* body: build-order
/// step 4 replaces the landing entirely while a session is open. That is why
/// [build] branches first and lays out second.
class WorkoutRoot extends ConsumerWidget {
  const WorkoutRoot({super.key});

  /// The group heading over the user's own templates.
  @visibleForTesting
  static const String customGroupLabel = 'YOUR TEMPLATES';

  /// The row that opens the template library from the Workout tab.
  @visibleForTesting
  static const Key manageTemplatesKey = ValueKey<String>('manage-templates');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session != null) {
      // An open workout replaces the landing entirely, at stack depth zero.
      // Which body it is follows from the session itself, not from a flag:
      // a template run answers "which muscles have I trained", an ad-hoc one
      // answers "which exercises have I done", and those are different lists.
      return session.isTemplateSession
          ? TemplateOverviewBody(onFinished: (id) => _openSummary(context, id))
          : AdHocOverviewBody(onFinished: (id) => _openSummary(context, id));
    }

    return const WorkoutLandingBody();
  }

  /// Where a finished workout lands.
  ///
  /// **Pushed, and only then is the tab root rebuilt.** The overview *is* this
  /// tab, so clearing the workout before the push would rebuild the landing
  /// underneath the outgoing transition.
  void _openSummary(BuildContext context, String sessionId) {
    pushSessionSummary(context, sessionId, celebrate: true);
  }
}

/// The templates you can start, filtered by split.
///
/// **Its own widget because it has two homes.** It is the Workout tab's landing
/// when nothing is open, and it is also what the open workout's header pushes
/// when the user wants to start a different one. Two copies would drift on the
/// filter, the groups and the ad-hoc entry alike.
class WorkoutLandingBody extends ConsumerWidget {
  const WorkoutLandingBody({super.key, this.isPushed = false});

  /// Whether this is the pushed list reached from an open workout, in which
  /// case choosing something has to close the workout that is already running
  /// and then return to the root.
  final bool isPushed;

  /// The group heading over the user's own templates.
  @visibleForTesting
  static const String customGroupLabel = 'YOUR TEMPLATES';

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final filter = ref.watch(templateFilterProvider);
    final templates = templatesFor(filter);
    final custom = ref.watch(customTemplatesProvider);

    return ListView(
      padding: screenScrollPadding(context),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                header: true,
                child: const Text(
                  'TEMPLATES',
                  style: kLandingSectionLabelStyle,
                ),
              ),
            ),
            TemplateFilterControl(
              current: filter,
              onSelected: (chosen) =>
                  ref.read(templateFilterProvider.notifier).select(chosen),
            ),
          ],
        ),
        Padding(
          // Says how many templates this filter yields. With no unfiltered
          // value to fall back to, this line is part of how the user can tell
          // the list is a subset rather than everything the app has.
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_countLabel(templates.length), style: kLandingCountStyle),
        ),
        for (final template in templates)
          TemplateRow(
            key: ValueKey<String>('template-${template.id}'),
            title: template.name,
            subtitle: template.subtitle,
            onTap: () => _openTemplate(context, ref, template),
          ),

        // Absent entirely when the user has none -- not a heading standing over
        // nothing. `docs/03-muscle-groups-tab-userflow.md` makes the same call
        // for the muscle grid: an empty group reads as broken, one line reads
        // as a state, and no group at all reads as nothing to say.
        if (custom.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Semantics(
            header: true,
            child: const Text(
              customGroupLabel,
              style: kLandingSectionLabelStyle,
            ),
          ),
          const SizedBox(height: 10),
          for (final template in custom)
            TemplateRow(
              key: ValueKey<String>('custom-template-${template.id}'),
              title: template.name,
              subtitle: template.subtitle,
              onTap: () => _openTemplate(context, ref, template),
            ),
        ],

        const SizedBox(height: 7),
        // **Outside the `custom.isNotEmpty` block above, deliberately.** This
        // row is the visible route to template authoring, which otherwise sits
        // behind an unlabelled disc in the header (KD2). Nested inside that
        // conditional it would be invisible to everyone who has never made a
        // custom template — which is exactly the user who needs to find it.
        //
        // It does not break "only place templates are authored"
        // (`docs/00-build-spec.md` §11): this is navigation, not authoring. The
        // Workout tab still only selects and runs.
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
        const SizedBox(height: 7),
        TemplateRow(
          key: const ValueKey<String>('ad-hoc-entry'),
          title: 'Ad-hoc workout',
          subtitle: 'Search and add as you go',
          // A different kind of thing from a template, so a different surface.
          background: AppPalette.mutedSurface,
          onTap: () async {
            // The ad-hoc workout is created by the first exercise added, so
            // closing the running one waits until then too — backing out of
            // search must not have cost the user their workout.
            if (!context.mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ExerciseSearchScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Starts [template]'s workout, closing whatever was already running.
  ///
  /// **Starting a new workout never loses the old one.** One with at least one
  /// completed set is saved exactly as if Finish had been tapped — keeping its
  /// own date, so a Monday workout abandoned on Wednesday still files as
  /// Monday — and the user is told. One with nothing completed is dropped, and
  /// asked about first when values were typed but never ticked.
  Future<void> _openTemplate(
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
    if (isPushed && context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Saves or drops the workout already running. Returns false when the user
  /// backed out, in which case nothing else should happen.
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
