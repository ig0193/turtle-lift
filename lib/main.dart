import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/data/active_session.dart';
import 'src/data/app_database.dart';
import 'src/data/body_gender.dart';
import 'src/data/custom_templates.dart';
import 'src/data/data_reset.dart';
import 'src/data/diet_plan.dart';
import 'src/data/diet_reminders.dart';
import 'src/data/exercise_index.dart';
import 'src/data/exercise_library.dart';
import 'src/data/food_index.dart';
import 'src/data/personal_details_store.dart';
import 'src/data/reminder_prefs.dart';
import 'src/data/reminder_scheduler.dart';
import 'src/data/sample_history_seed.dart';
import 'src/data/session_store.dart';
import 'src/data/settings_store.dart' show appDatabaseProvider;
import 'src/data/training_plan.dart';
import 'src/data/training_reminders.dart';
import 'src/theme/app_theme.dart';
import 'src/ui/glance_sync.dart';
import 'src/ui/l0_shell.dart';
import 'src/ui/reminder_tap_listener.dart';
import 'src/ui/session_summary_screen.dart' show kAppDisplayName;

/// Boots the app with its stored preferences already resolved.
///
/// **The await before `runApp` is deliberate, and it is what makes the Workout
/// tab honest.** The open session and the user's own templates are small reads;
/// resolving them here means the first frame the user sees is already the right
/// one — the session they were in, not a landing that is replaced by it a frame
/// later. Moving those reads inside providers would be the more familiar shape
/// and would cost a visible swap on every cold start, plus a loading state on
/// the app's most opened screen. See `initialActiveSessionProvider`.
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
///
/// **The Diet food list joins the record too, but it is the one read allowed
/// to fail.** It is an asset like the exercise library and loads concurrently
/// with it; a load or parse failure is reported and becomes
/// [FoodIndex.unavailable], so Diet shows its unavailable state and every other
/// tab keeps working (KTD11). The exercise library stays fail-loud.
///
/// **The Diet plan, ticks and target are the last read**, grouped into one
/// future (`readStoredDiet`) because a record `.wait` stops at nine fields.
/// Seeded for the same reason as the training plan: a Diet pane that flashed
/// its empty state at someone with a plan would say something false.
///
/// **Reminders start before the first boot, and only here** (KTD17). The
/// notification plugin and the zone database are set up once per process by
/// [prepareReminders], which also reports the target a notification launched
/// the app with. That target goes to the first [_bootFrom] only: the plugin
/// reports the same launch for the whole process, so the reboot after Delete
/// all data must not see it, or a wiped app would reopen on Diet (AE8).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = openAppDatabase();
  final launchTarget = await _startReminders();

  // **Debug-only, temporary.** Seeds a few weeks of plausible workouts so the
  // History tab's calendar and Recent list have something real to render on
  // a fresh install while that redesign is being reviewed on-device. No-ops
  // once any real session exists, and `kDebugMode` keeps it out of release
  // builds entirely. See `sample_history_seed.dart` for removal notes.
  // The sample diet (a target, a planned week, one tick today) rides along
  // for the Diet pane's on-device review, and no-ops once any diet exists.
  //
  // `--dart-define=TURTLE_NO_SEED=true` skips it, so the Maestro flows
  // (`.maestro/`) can start a debug build from a truly empty install.
  if (kDebugMode && !kSkipSampleSeed) {
    await seedSampleHistoryIfEmpty(database);
    await seedSampleDietIfEmpty(database);
  }

  await _bootFrom(database, launchTarget: launchTarget);
}

/// True when the build was made with `--dart-define=TURTLE_NO_SEED=true`: the
/// debug sample seed is skipped. Release builds never seed either way.
const bool kSkipSampleSeed = bool.fromEnvironment('TURTLE_NO_SEED');

/// Runs [prepareReminders], and lets nothing it throws stop the app booting.
///
/// Reminders are an opt-in extra; a plugin that fails to start must cost the
/// user their reminders, not the app. The failure is reported, as the food
/// list's is (KTD11), and the scheduler stays inert.
Future<ReminderTarget?> _startReminders() async {
  try {
    return await prepareReminders();
  } on Object catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'turtle_lift',
      context: ErrorDescription('while starting reminders'),
    ));
    return null;
  }
}

/// Reads everything the first frame needs and runs the app on it.
///
/// Called once by [main], and again by `appRestartProvider` after "Delete all
/// data" -- a second `runApp` replaces the whole tree, `ProviderScope`
/// included, so every notifier is re-seeded from the (now empty) database and
/// no screen can keep showing what was deleted. The sample seed is not re-run:
/// a user who deleted everything must land on an empty app, debug or not.
///
/// [launchTarget] is where a notification that launched the app points; only
/// [main] passes one. The reboot passes none (see [main]).
Future<void> _bootFrom(
  AppDatabase database, {
  ReminderTarget? launchTarget,
}) async {
  // A throwaway container, because `exerciseLibraryProvider` is where the
  // asset read and the decode live and there must not be a second copy of
  // either. It is disposed before the scope below is built, so the raw maps are
  // collected once the index has been folded out of them.
  final boot = ProviderContainer();
  final personalDetails = PersonalDetailsStore(database);
  // Started before the record below and awaited after it, so it runs
  // alongside the rest: the record `.wait` stops at nine fields.
  final reminderPrefs = ReminderPrefsStore(database).read();
  final (
    exercises,
    initialGender,
    initialBodyweight,
    initialCustomTemplates,
    initialSession,
    initialSavedSessions,
    initialTrainingPlan,
    foods,
    initialDiet,
  ) = await (
    boot.read(exerciseLibraryProvider.future),
    readStoredBodyGender(personalDetails),
    readStoredBodyweightLog(personalDetails),
    readStoredCustomTemplates(CustomTemplateStore(database)),
    readOpenSession(SessionStore(database)),
    readSavedSessions(SessionStore(database)),
    readStoredTrainingPlan(TrainingPlanStore(database)),
    loadFoodIndex(readFoodListAsset),
    readStoredDiet(database),
  ).wait;
  final initialReminderPrefs = await reminderPrefs;
  boot.dispose();

  runApp(
    ProviderScope(
      // A fresh key per boot, so a restart is a new scope rather than an
      // update of the old one.
      key: UniqueKey(),
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        appRestartProvider.overrideWithValue(() => _bootFrom(database)),
        initialBodyGenderProvider.overrideWithValue(initialGender),
        initialBodyweightLogProvider.overrideWithValue(initialBodyweight),
        initialTrainingPlanProvider.overrideWithValue(initialTrainingPlan),
        initialActiveSessionProvider.overrideWithValue(initialSession),
        initialSavedSessionsProvider.overrideWithValue(initialSavedSessions),
        initialCustomTemplatesProvider
            .overrideWithValue(initialCustomTemplates),
        exerciseIndexProvider.overrideWithValue(
          ExerciseIndex.fromJson(exercises),
        ),
        foodIndexProvider.overrideWithValue(foods),
        initialDietPlanProvider.overrideWithValue(initialDiet.versions),
        initialMealTicksProvider.overrideWithValue(initialDiet.ticks),
        initialProteinTargetProvider
            .overrideWithValue(initialDiet.proteinTargetG),
        initialReminderPrefsProvider.overrideWithValue(initialReminderPrefs),
        ...reminderLaunchOverrides(launchTarget),
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
/// It is one of two mutable top-levels in the app, and it is restored by the
/// test that sets it.
@visibleForTesting
AppDatabase Function() openAppDatabase = AppDatabase.new;

/// How boot reads the food list asset.
///
/// **The second test seam, for the same reason as [openAppDatabase]:** the
/// failure-tolerant boot (KTD11) is only proven if the real `main()` runs over
/// a broken asset, and `rootBundle` offers no clean way to serve one. The boot
/// test swaps this for a stub returning malformed JSON and restores it.
@visibleForTesting
Future<String> Function() readFoodListAsset = readShippedFoodList;

/// How [main] starts reminders: loads the zone database, sets the device's
/// zone, initialises the notification plugin (asking for nothing), and
/// returns the [ReminderTarget] a notification launched the app with, or null.
///
/// **The third seam, for the reason [openAppDatabase] is one:** the plugin and
/// `flutter_timezone` reach platform channels that do not exist under
/// `flutter test`, so `test/boot_test.dart` swaps in a stub returning a fixed
/// target and runs the real `main()`. It is restored by the test that sets it.
@visibleForTesting
Future<ReminderTarget?> Function() prepareReminders =
    pluginReminderScheduler.initialize;

class TurtleLiftApp extends StatelessWidget {
  const TurtleLiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppDisplayName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Honour the system text size, up to 1.3x. Past that the set-logging row
      // (two steppers, units and a checkmark on one line) cannot fit a phone's
      // width, and a row that overflows is less readable than one that stops
      // growing. Smaller-than-default settings pass through untouched.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return RefreshTodayOnResume(
          // The Live Activity and the home-screen widget follow the app's
          // derived state from boot (ADR 0008).
          child: GlanceSync(
            child: MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(maxScaleFactor: 1.3),
            ),
            child: child!,
          ),
          ),
        );
      },
      // Straight into the shell, with no splash route ahead of it. Anything
      // that later pops back to an L0 root should predicate on the shell route
      // rather than `isFirst`: a splash added in front would otherwise become
      // the pop target without a single test noticing.
      //
      // The tap listener sits on the shell route so it can pop back to it
      // when a reminder is tapped (KTD17).
      home: const ReminderTapListener(child: L0Shell()),
    );
  }
}

/// Re-reads "today" whenever the app returns to the foreground (KTD13).
///
/// `planTodayProvider` caches the date, so a phone that sat on the Schedule
/// or Diet pane from Sunday evening into Monday morning would still show
/// Sunday as today: last week's summary, last week's ticks. Invalidating the
/// clock on resume moves every figure that watches it at once. It wraps the
/// whole app, so there is one listener for the life of the scope.
///
/// **It also holds the training-reminder sync** (KTD15, U16): reschedule at
/// boot, after every plan or preference change, and on resume.
class RefreshTodayOnResume extends ConsumerStatefulWidget {
  const RefreshTodayOnResume({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RefreshTodayOnResume> createState() =>
      _RefreshTodayOnResumeState();
}

class _RefreshTodayOnResumeState extends ConsumerState<RefreshTodayOnResume> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    // Holds the training-reminder sync for the life of the scope: it
    // reschedules now (boot), on every plan or preference change, and on
    // resume, because the invalidation below moves the plan in force today.
    ref.listenManual(trainingReminderSyncProvider, (_, _) {});
    // Diet's reminders the same way (U17): a plan edit, a preference change
    // or a resume reschedules them.
    ref.listenManual(dietReminderSyncProvider, (_, _) {});
    _listener = AppLifecycleListener(
      onResume: () {
        ref.invalidate(planTodayProvider);
        // Rebuilt even when today has not moved, so the resume reschedule
        // runs every time rather than only across midnight.
        ref.invalidate(trainingRemindersProvider);
        ref.invalidate(dietRemindersProvider);
      },
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
