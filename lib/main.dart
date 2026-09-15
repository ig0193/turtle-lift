import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/data/active_session.dart';
import 'src/data/app_database.dart';
import 'src/data/body_gender.dart';
import 'src/data/custom_templates.dart';
import 'src/data/exercise_index.dart';
import 'src/data/exercise_library.dart';
import 'src/data/personal_details_store.dart';
import 'src/data/session_store.dart';
import 'src/data/settings_store.dart';
import 'src/data/template_filter.dart';
import 'src/theme/app_theme.dart';
import 'src/ui/l0_shell.dart';
import 'src/ui/session_summary_screen.dart' show kAppDisplayName;

/// Boots the app with its stored preferences already resolved.
///
/// **The await before `runApp` is deliberate, and it is what makes the Workout
/// landing honest.** The split filter is a one-row read; resolving it here
/// means the first frame the user sees is already the filter they chose last
/// time. Moving that read inside a provider would be the more familiar shape
/// and would cost a visible swap on every cold start — Multi Split's rows
/// rendering and then being replaced — plus a loading state on the app's most
/// opened screen. See `initialTemplateFilterProvider`.
///
/// The database is constructed here rather than left to
/// `appDatabaseProvider`'s own creator so that one instance serves both the
/// pre-frame read and the running app.
///
/// **The exercise library is read here for the same reason and a sharper
/// one.** The Muscles landing needs a per-sub-group exercise count for all 19
/// rows before it can draw one of them, and no tab root in this app renders an
/// `AsyncValue`. The two awaits run concurrently because neither needs the
/// other — the asset read does not touch the database — so the boot cost is the
/// slower of the pair rather than their sum. See [exerciseIndexProvider], which
/// throws rather than defaulting if this wiring is ever dropped — and
/// `test/boot_test.dart`, which runs this function so that dropping it fails
/// there rather than on a device.
///
/// **The personal details join the same list for the same reason.** The Muscles
/// tab paints a body map on the first frame, so a gender resolved a frame later
/// is a user watching the wrong artwork get replaced; and the calorie estimate's
/// "add your weight" prompt is a real state for someone who has never weighed
/// in, so flashing it at someone who has is not a cosmetic glitch — it says
/// something false. Both are small reads off the one database handle, and they
/// join the `.wait` rather than being awaited in turn because the boot cost
/// should stay the slowest read rather than their sum.
///
/// **The user's own templates are the fifth read, and the most visible.** The
/// Workout landing is what the app opens on, and its custom group is absent
/// entirely when the user has none — so resolving that list a frame late means
/// the group appears after the first paint and pushes the ad-hoc entry down
/// under a thumb already on its way to it. See [initialCustomTemplatesProvider].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = openAppDatabase();
  // A throwaway container, because `exerciseLibraryProvider` is where the
  // asset read and the decode live and there must not be a second copy of
  // either. It is disposed before the scope below is built, so the raw maps are
  // collected once the index has been folded out of them.
  final boot = ProviderContainer();
  final personalDetails = PersonalDetailsStore(database);
  final (
    initialFilter,
    exercises,
    initialGender,
    initialBodyweight,
    initialCustomTemplates,
    initialSession,
    initialSavedSessions,
  ) = await (
    readStoredTemplateFilter(SettingsStore(database)),
    boot.read(exerciseLibraryProvider.future),
    readStoredBodyGender(personalDetails),
    readStoredBodyweightLog(personalDetails),
    readStoredCustomTemplates(CustomTemplateStore(database)),
    readOpenSession(SessionStore(database)),
    readSavedSessions(SessionStore(database)),
  ).wait;
  boot.dispose();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        initialTemplateFilterProvider.overrideWithValue(initialFilter),
        initialBodyGenderProvider.overrideWithValue(initialGender),
        initialBodyweightLogProvider.overrideWithValue(initialBodyweight),
        initialActiveSessionProvider.overrideWithValue(initialSession),
        initialSavedSessionsProvider.overrideWithValue(initialSavedSessions),
        initialCustomTemplatesProvider
            .overrideWithValue(initialCustomTemplates),
        exerciseIndexProvider.overrideWithValue(
          ExerciseIndex.fromJson(exercises),
        ),
      ],
      child: const TurtleLiftApp(),
    ),
  );
}

/// How [main] opens the database.
///
/// **A seam, and the narrowest one that leaves `main()` itself runnable in a
/// test.** [AppDatabase]'s own constructor reaches `path_provider`, which has
/// no platform channel under `flutter test`, so a test that called this
/// entrypoint as written would die on its first line — which is why no test
/// called it at all, and why deleting the `exerciseIndexProvider` override
/// below would have killed the Muscles tab on the first frame with the whole
/// suite still green. `test/boot_test.dart` swaps this one function for an
/// in-memory database and runs the real `main()`: the awaits, the override
/// list and the `runApp` call are all the shipped ones.
///
/// **Not a parameter on `main()`.** The entrypoint's signature belongs to the
/// platform launchers, and a test passing `main(database: ...)` would be
/// exercising an overload nothing on a device ever takes — which is the
/// failure this seam exists to stop, wearing a different hat.
///
/// It is the only mutable top-level in the app, and it is restored by the test
/// that sets it.
@visibleForTesting
AppDatabase Function() openAppDatabase = AppDatabase.new;

class TurtleLiftApp extends StatelessWidget {
  const TurtleLiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Placeholder name -- see CLAUDE.md "Still undecided".
      title: kAppDisplayName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Straight into the shell, with no splash route ahead of it. Anything
      // that later pops back to an L0 root should predicate on the shell route
      // rather than `isFirst`: a splash added in front would otherwise become
      // the pop target without a single test noticing.
      home: const L0Shell(),
    );
  }
}
