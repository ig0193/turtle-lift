import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_store.dart';
import 'workout_templates.dart';

/// What a user with no stored choice sees.
///
/// Multi Split rather than a first-in-the-enum default: it is the broadest of
/// the three, so a new user meets the most templates before they have any
/// reason to prefer one split over another.
const TemplateFilter kDefaultTemplateFilter = TemplateFilter.multiSplit;

/// The filter the app started with, resolved **before the first frame**.
///
/// **This exists to be overridden, and `main()` is what overrides it.** The
/// alternative — an `AsyncNotifier` that reads the database in `build()` — is
/// the obvious shape and the wrong one: it resolves a frame or more after the
/// widget tree first builds, so a user whose stored filter is Push-Pull-Legs
/// would watch Multi Split's rows render and then swap. "Opens on your last
/// filter" would be false on every cold start, and the landing would need a
/// loading state for a value that is one small row read away.
///
/// Reading it up front costs one await before `runApp` and removes both
/// problems. The default here is what a test — or a missed override — gets.
final initialTemplateFilterProvider = Provider<TemplateFilter>(
  (ref) => kDefaultTemplateFilter,
);

/// Resolves the stored key into a filter, falling back to
/// [kDefaultTemplateFilter].
///
/// Called once from `main()` before `runApp`. The fallback covers both a first
/// launch (nothing stored) and an unreadable value (a downgrade, or a
/// hand-edited database) — neither is worth failing the app's first screen
/// over.
Future<TemplateFilter> readStoredTemplateFilter(SettingsStore store) async {
  final key = await store.readWorkoutTemplateFilter();
  return TemplateFilter.fromKey(key) ?? kDefaultTemplateFilter;
}

/// Which split the Workout landing is filtered to.
///
/// **A `Notifier`, not an `AsyncNotifier`** — see
/// [initialTemplateFilterProvider] for why the read happens before the tree
/// builds rather than inside it. And not a `StateProvider`, which is legacy on
/// Riverpod 3 (see `lib/src/ui/tab_index.dart`).
///
/// **This is view state the user chose, not a training programme.** Nothing
/// here advances, rotates, or suggests; it decides which templates are listed
/// and nothing else.
class TemplateFilterNotifier extends Notifier<TemplateFilter> {
  @override
  TemplateFilter build() => ref.read(initialTemplateFilterProvider);

  /// Show [filter], and remember it for next launch.
  ///
  /// The write is not skipped when [filter] already equals [state]. On first
  /// launch the default is showing but nothing is stored, so choosing it is a
  /// real choice — swallowing that write would leave the user's pick unrecorded
  /// and send them somewhere else next time.
  Future<void> select(TemplateFilter filter) async {
    state = filter;
    await ref
        .read(settingsStoreProvider)
        .writeWorkoutTemplateFilter(filter.key);
  }
}

/// The current split filter. Named for the thing, matching `tabIndexProvider`.
final templateFilterProvider =
    NotifierProvider<TemplateFilterNotifier, TemplateFilter>(
  TemplateFilterNotifier.new,
);
