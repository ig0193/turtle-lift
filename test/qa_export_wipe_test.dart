import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/ui/week_strip.dart';
import 'package:turtle_lift/main.dart' as app;
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/custom_exercises.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/data_export.dart';
import 'package:turtle_lift/src/data/data_reset.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_ticks.dart';
import 'package:turtle_lift/src/data/diet_plan_store.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/glass_tab_bar.dart';
import 'package:turtle_lift/src/ui/l0_shell.dart';
import 'package:turtle_lift/src/ui/muscles_root.dart';
import 'package:turtle_lift/src/ui/profile_root.dart';
import 'package:turtle_lift/src/ui/schedule_pane.dart';
import 'package:turtle_lift/src/ui/workout_root.dart';

import 'support/fake_reminder_scheduler.dart';

/// QA: the export after a realistic workout of all four load types, and Delete
/// all data followed by a walk of every tab's empty state on the real boot.
///
/// `data_export_reset_test.dart` proves the export shape on one weighted set
/// and that every table empties; `boot_test.dart` proves the reboot's
/// Profile segment. This adds the per-load-type columns in the file and the
/// whole-app empty walk after the wipe.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late ExerciseIndex index;

  setUpAll(() async {
    final boot = ProviderContainer();
    addTearDown(boot.dispose);
    index = ExerciseIndex.fromJson(
      await boot.read(exerciseLibraryProvider.future),
    );
  });

  group('export after a workout of every load type', () {
    late AppDatabase database;
    late SessionStore store;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      store = SessionStore(database);
    });
    tearDown(() => database.close());

    Future<Map<String, Object?>> exportOf() async => jsonDecode(
      buildExportJson(
        sessions: await store.readSavedSessions(),
        bodyweight: const <BodyweightEntry>[],
        customTemplates: const <WorkoutTemplate>[],
        trainingPlan: const <TrainingPlanEntry>[],
        gender: BodyGender.male,
        index: index,
        dietPlan: const <DietPlanVersion>[],
        mealTicks: const <MealTick>[],
        proteinTargetG: null,
        foods: FoodIndex.unavailable(),
        exportedAt: DateTime.utc(2026, 11, 8),
      ),
    ) as Map<String, Object?>;

    test(
      'each exercise carries its own columns, unsigned, completed only',
      () async {
        final session = await store.createSession(
          performedOn: LocalDate(2026, 11, 2),
        );
        Future<String> add(String id, LoadType type) => store.addExercise(
          sessionId: session.id,
          exerciseId: id,
          loadType: type,
        );

        final bench = await add('barbell-bench-press', LoadType.weighted);
        await store.writeSet(
          sessionExerciseId: bench,
          position: 0,
          completed: true,
          weightKg: 60,
          reps: 8,
        );
        // Typed and never ticked: never exported.
        await store.writeSet(
          sessionExerciseId: bench,
          position: 1,
          weightKg: 100,
          reps: 1,
        );

        final pushUp = await add('push-up', LoadType.bodyweight);
        await store.writeSet(
          sessionExerciseId: pushUp,
          position: 0,
          completed: true,
          reps: 15,
          addedKg: 10,
        );

        final assisted = await add(
          'assisted-pull-up-machine',
          LoadType.assisted,
        );
        await store.writeSet(
          sessionExerciseId: assisted,
          position: 0,
          completed: true,
          assistKg: 25,
          reps: 8,
        );

        final carry = await add('farmer-s-carry', LoadType.timed);
        await store.writeSet(
          sessionExerciseId: carry,
          position: 0,
          completed: true,
          durationSec: 45,
          weightKg: 24,
        );
        await store.saveOpenSession();

        final json = await exportOf();
        final workout = (json['workouts']! as List).single as Map;
        expect(workout['performedOn'], '2026-11-02');
        final byId = <String, Map>{
          for (final e in workout['exercises'] as List)
            (e as Map)['exerciseId'] as String: e,
        };
        expect(byId['barbell-bench-press']!['loadType'], 'weighted');
        expect(byId['barbell-bench-press']!['sets'], [
          {'weightKg': 60.0, 'reps': 8},
        ]);
        expect(byId['push-up']!['loadType'], 'bodyweight');
        expect(byId['push-up']!['sets'], [
          {'reps': 15, 'addedKg': 10.0},
        ]);
        expect(byId['assisted-pull-up-machine']!['loadType'], 'assisted');
        expect(byId['assisted-pull-up-machine']!['sets'], [
          {'reps': 8, 'assistKg': 25.0},
        ]);
        expect(byId['farmer-s-carry']!['loadType'], 'timed');
        expect(byId['farmer-s-carry']!['sets'], [
          {'weightKg': 24.0, 'durationSec': 45},
        ]);

        // Unsigned everywhere: the sign is carried by the load type.
        void noNegatives(Object? node) {
          if (node is num) expect(node, greaterThanOrEqualTo(0));
          if (node is Map) node.values.forEach(noNegatives);
          if (node is List) node.forEach(noNegatives);
        }

        noNegatives(json);
      },
    );

    test(
      'an edited workout exports the correction, a deleted one nothing',
      () async {
        final keep = await store.createSession(
          performedOn: LocalDate(2026, 11, 2),
        );
        final row = await store.addExercise(
          sessionId: keep.id,
          exerciseId: 'barbell-bench-press',
          loadType: LoadType.weighted,
        );
        final setId = await store.writeSet(
          sessionExerciseId: row,
          position: 0,
          completed: true,
          weightKg: 60,
          reps: 8,
        );
        await store.saveOpenSession();

        final drop = await store.createSession(
          performedOn: LocalDate(2026, 11, 3),
        );
        final dropRow = await store.addExercise(
          sessionId: drop.id,
          exerciseId: 'push-up',
          loadType: LoadType.bodyweight,
        );
        await store.writeSet(
          sessionExerciseId: dropRow,
          position: 0,
          completed: true,
          reps: 10,
        );
        await store.saveOpenSession();

        await store.writeSet(
          sessionExerciseId: row,
          position: 0,
          setId: setId,
          completed: true,
          weightKg: 62.5,
          reps: 8,
        );
        await store.deleteSession(drop.id);

        final workouts = (await exportOf())['workouts']! as List;
        expect(workouts, hasLength(1));
        final sets =
            (((workouts.single as Map)['exercises'] as List).single
                as Map)['sets'];
        expect(sets, [
          {'weightKg': 62.5, 'reps': 8},
        ]);
      },
    );
  });

  group('Delete all data, then every tab', () {
    setUp(() => app.prepareReminders = () async => null);
    tearDown(() => app.prepareReminders = pluginReminderScheduler.initialize);

    ProviderContainer shellContainer(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(L0Shell)));

    Future<void> tapTab(WidgetTester tester, int i) async {
      await tester.tap(find.byKey(GlassTabBar.itemKey(i)));
      await tester.pumpAndSettle();
    }

    testWidgets('the reboot is empty on Workout, Muscles, History and all '
        'three Profile segments', (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      app.openAppDatabase = () => database;
      addTearDown(() async {
        app.openAppDatabase = AppDatabase.new;
        await database.close();
      });

      // A debug main() seeds sample workouts and a sample diet, so there is
      // something real to delete.
      await tester.runAsync(app.main);
      await tester.pumpAndSettle();
      expect(
        shellContainer(tester).read(savedSessionsProvider),
        isNotEmpty,
        reason: 'precondition: the debug seed gave the wipe data to remove',
      );

      final restart = shellContainer(tester).read(appRestartProvider);
      final reminders = FakeReminderScheduler();
      await tester.runAsync(() async {
        await wipeAllData(database, reminders: reminders);
        await restart();
      });
      await tester.pumpAndSettle();

      // Workout: the landing, with no template of the user's own (the rail
      // holds only New template) and no session.
      expect(find.byKey(WorkoutLandingBody.startWorkoutKey), findsOneWidget);
      expect(shellContainer(tester).read(customTemplatesProvider), isEmpty);
      expect(shellContainer(tester).read(customExerciseListProvider), isEmpty);
      expect(shellContainer(tester).read(activeSessionProvider), isNull);
      // No training days in force, and no last workout to point at (ADR 0008).
      expect(find.text(WeekStrip.pickDaysLabel), findsOneWidget);
      expect(find.byKey(LastWorkoutLine.lineKey), findsNothing);

      // Muscles: pure reference, renders the same with or without data.
      await tapTab(tester, 1);
      expect(find.byType(MusclesRoot), findsOneWidget);

      // History: the empty state.
      await tapTab(tester, 2);
      expect(find.text('No workouts yet'), findsOneWidget);

      // Profile: opens on Personal.
      await tapTab(tester, 3);
      expect(
        shellContainer(tester).read(profileSegmentProvider),
        ProfileSegment.personal,
      );

      // Schedule: no training days in force.
      await tester.tap(
        find.byKey(ProfileRoot.segmentKey(ProfileSegment.schedule)),
      );
      await tester.pumpAndSettle();
      expect(
        shellContainer(tester).read(todayPlanWeekdaysProvider),
        isEmpty,
      );
      expect(find.byKey(SchedulePane.dayChipKey(0)), findsOneWidget);

      // Diet: the first-time state.
      await tester.tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.diet)));
      await tester.pumpAndSettle();
      expect(find.byKey(DietPane.emptyStateKey), findsOneWidget);
      expect(find.text(DietPane.emptyHeading), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
