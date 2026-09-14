import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/custom_templates.dart';
import '../data/template_filter.dart';
import '../data/workout_templates.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'exercise_search_screen.dart';
import 'template_filter_control.dart';
import 'template_row.dart';
import 'workout_overview_screen.dart';

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
  const WorkoutRoot({super.key, this.hasSession = false});

  /// Placeholder for "a session is open right now".
  ///
  /// A parameter rather than a `const false` so the branch below is real code
  /// rather than something the analyzer folds away. Build-order step 4 swaps it
  /// for a read of the active-session provider; nothing else about this file
  /// has to move.
  final bool hasSession;

  /// The group heading over the user's own templates.
  @visibleForTesting
  static const String customGroupLabel = 'YOUR TEMPLATES';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hasSession) {
      // TODO(build order step 4 — workout flow): an in-progress session
      // replaces the landing entirely, with its own header. Add that body
      // here.
      return const SizedBox.shrink();
    }

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
            onTap: () => _openTemplate(context, template),
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
              onTap: () => _openTemplate(context, template),
            ),
        ],

        const SizedBox(height: 7),
        TemplateRow(
          key: const ValueKey<String>('ad-hoc-entry'),
          title: 'Ad-hoc workout',
          subtitle: 'Search and add as you go',
          // A different kind of thing from a template, so a different surface.
          background: AppPalette.mutedSurface,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ExerciseSearchScreen(),
            ),
          ),
        ),
      ],
    );
  }

  void _openTemplate(BuildContext context, WorkoutTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutOverviewScreen(template: template),
      ),
    );
  }

  static String _countLabel(int count) =>
      '$count template${count == 1 ? '' : 's'}';
}
