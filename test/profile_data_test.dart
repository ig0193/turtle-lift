import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/data_export.dart';
import 'package:turtle_lift/src/data/diet_plan_store.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/meal_ticks.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/reminder_prefs.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/data_screens.dart';

/// Profile audit B9, B10 and ADR 0014 §6: export is enabled for any entered
/// data, carries the reminder settings, adds a spreadsheet CSV of every
/// completed set, and Delete all data offers Export first.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final index = ExerciseIndex(const <Exercise>[
    Exercise(
      id: 'bench',
      name: 'Bench press, "flat"',
      equipment: 'barbell',
      loadType: 'weighted',
      primary: <String>[],
      secondary: <String>[],
      setup: '',
      posture: '',
      execution: '',
      commonMistakes: '',
    ),
    Exercise(
      id: 'plank',
      name: 'Plank',
      equipment: 'bodyweight',
      loadType: 'timed',
      primary: <String>[],
      secondary: <String>[],
      setup: '',
      posture: '',
      execution: '',
      commonMistakes: '',
    ),
  ]);

  final session = WorkoutSession(
    id: 's1',
    title: null,
    performedOn: const LocalDate(2026, 11, 3),
    loggedAt: DateTime(2026, 11, 3, 18),
    templateId: 'push',
    templateName: 'Push day',
    isOpen: false,
    exercises: const <SessionExercise>[
      SessionExercise(
        id: 'e1',
        exerciseId: 'bench',
        position: 0,
        loadType: LoadType.weighted,
        markedDone: true,
        note: 'felt, good',
        sets: <SetEntry>[
          SetEntry(id: 'a', position: 0, completed: true, weightKg: 60, reps: 8),
          SetEntry(id: 'b', position: 1, completed: false, weightKg: 62.5, reps: 5),
        ],
      ),
      SessionExercise(
        id: 'e2',
        exerciseId: 'plank',
        position: 1,
        loadType: LoadType.timed,
        markedDone: false,
        sets: <SetEntry>[
          SetEntry(id: 'c', position: 0, completed: true, durationSec: 45),
        ],
      ),
    ],
  );

  group('CSV', () {
    test('one row per completed set, units in the headers, quoted fields', () {
      final lines = const LineSplitter()
          .convert(buildSetsCsv(sessions: <WorkoutSession>[session], index: index));
      expect(lines.first,
          'date,title,template,exercise,exercise_id,load_type,set,weight_kg,'
          'reps,added_kg,assist_kg,duration_sec,note');
      expect(lines, hasLength(3), reason: 'the uncompleted set is left out');
      expect(lines[1],
          '2026-11-03,,Push day,"Bench press, ""flat""",bench,weighted,1,60,8,'
          ',,,"felt, good"');
      expect(lines[2], '2026-11-03,,Push day,Plank,plank,timed,1,,,,,45,');
    });

    test('an open workout is not exported', () {
      final open = WorkoutSession(
        id: 'o',
        title: 'Now',
        performedOn: session.performedOn,
        loggedAt: session.loggedAt,
        templateId: null,
        templateName: null,
        isOpen: true,
        exercises: session.exercises,
      );
      expect(
        const LineSplitter()
            .convert(buildSetsCsv(sessions: <WorkoutSession>[open], index: index)),
        hasLength(1),
      );
    });

    test('file name', () {
      expect(setsCsvFileName(DateTime(2026, 11, 3)),
          'turtlelift-sets-2026-11-03.csv');
    });
  });

  test('B10: the JSON carries the reminder settings', () {
    final prefs = ReminderPreferences.defaults
        .copyWith(scheduleOn: true, dietOn: true)
        .withSlot(MealSlot.lunch, const SlotReminder(on: true, minute: 780));
    final json = jsonDecode(buildExportJson(
      sessions: const <WorkoutSession>[],
      bodyweight: const <BodyweightEntry>[],
      customTemplates: const <WorkoutTemplate>[],
      trainingPlan: const <TrainingPlanEntry>[],
      gender: BodyGender.male,
      index: index,
      dietPlan: const <DietPlanVersion>[],
      mealTicks: const <MealTick>[],
      proteinTargetG: null,
      foods: FoodIndex.unavailable(),
      exportedAt: DateTime.utc(2026, 11, 7),
      reminders: prefs,
    )) as Map<String, Object?>;
    final r = json['reminders']! as Map<String, Object?>;
    expect(r['training'], <String, Object?>{'on': true, 'time': '18:30'});
    final diet = r['diet']! as Map<String, Object?>;
    expect(diet['on'], isTrue);
    expect((diet['lunch']! as Map)['on'], isTrue);
    expect((diet['lunch']! as Map)['time'], '13:00');
  });

  late AppDatabase database;
  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Widget host(Widget screen, {List<TrainingPlanEntry> plan = const []}) =>
      ProviderScope(
        overrides: [
          planTodayProvider.overrideWithValue(const LocalDate(2026, 11, 4)),
          initialTrainingPlanProvider.overrideWithValue(plan),
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          customTemplatesProvider.overrideWithValue(const []),
          initialBodyweightLogProvider.overrideWithValue(const []),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: screen),
      );

  testWidgets('B9: a schedule alone is something to export, and it is counted',
      (tester) async {
    await tester.pumpWidget(host(const ExportScreen(), plan: <TrainingPlanEntry>[
      TrainingPlanEntry(
          effectiveFrom: const LocalDate(2026, 11, 2), weekdays: <int>{0, 2, 4}),
    ]));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(ExportScreen.exportKey)).onPressed,
      isNotNull,
    );
    final row = find.ancestor(
        of: find.text('Training days'), matching: find.byType(Row));
    expect(find.descendant(of: row, matching: find.text('3 a week')),
        findsOneWidget);
  });

  testWidgets('Export says it also writes a CSV for spreadsheets',
      (tester) async {
    await tester.pumpWidget(host(const ExportScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('CSV'), findsOneWidget);
  });

  testWidgets('Delete all data offers Export first, and says exported files '
      'are not touched', (tester) async {
    await tester.pumpWidget(host(const DeleteAllDataScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('already exported or shared'), findsOneWidget);
    await tester.tap(find.byKey(DeleteAllDataScreen.exportFirstKey));
    await tester.pumpAndSettle();
    expect(find.byType(ExportScreen), findsOneWidget);
  });
}
