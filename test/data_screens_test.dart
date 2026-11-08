import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/data_reset.dart';
import 'package:turtle_lift/src/data/diet_plan.dart';
import 'package:turtle_lift/src/data/diet_plan_store.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart'
    show reminderSchedulerProvider;
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/data/training_plan.dart'
    show planTodayProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/data_screens.dart';
import 'package:turtle_lift/src/ui/destructive_confirmation.dart';

import 'support/fake_reminder_scheduler.dart';

/// The two Profile data screens: what they say before acting, and that delete
/// asks first, wipes, then reboots.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Widget host(
    Widget screen, {
    Future<void> Function()? restart,
    List<DietPlanVersion> dietPlan = const <DietPlanVersion>[],
    FakeReminderScheduler? reminders,
  }) =>
      ProviderScope(
        overrides: [
          planTodayProvider.overrideWithValue(LocalDate(2026, 11, 4)),
          initialDietPlanProvider.overrideWithValue(dietPlan),
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider
              .overrideWithValue(ExerciseIndex(const <Exercise>[])),
          customTemplatesProvider.overrideWithValue(const []),
          initialBodyweightLogProvider.overrideWithValue(const []),
          if (restart != null) appRestartProvider.overrideWithValue(restart),
          if (reminders != null)
            reminderSchedulerProvider.overrideWithValue(reminders),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: screen),
      );

  group('export', () {
    testWidgets('with nothing logged, the button is off and says why',
        (tester) async {
      await tester.pumpWidget(host(const ExportScreen()));
      await tester.pumpAndSettle();

      final button =
          tester.widget<FilledButton>(find.byKey(ExportScreen.exportKey));
      expect(button.onPressed, isNull);
      expect(find.text('Nothing to export yet. Log a workout first.'),
          findsOneWidget);
      expect(find.text('Workouts'), findsOneWidget);
    });
  });

  group('counts', () {
    DietPlanItem item(int weekday, String foodId) => DietPlanItem(
          id: '$weekday-$foodId',
          weekday: weekday,
          slot: MealSlot.lunch,
          foodId: foodId,
          servingsHalves: 2,
          position: 0,
        );

    testWidgets('foods planned counts the items in this week\'s plan only, '
        'and diet alone makes something to export', (tester) async {
      await tester.pumpWidget(host(
        const ExportScreen(),
        dietPlan: <DietPlanVersion>[
          DietPlanVersion(
            effectiveFrom: LocalDate(2026, 10, 26),
            items: <DietPlanItem>[
              for (var d = 0; d < 5; d++) item(d, 'old'),
            ],
          ),
          DietPlanVersion(
            effectiveFrom: LocalDate(2026, 11, 2),
            items: <DietPlanItem>[item(0, 'a'), item(2, 'b'), item(4, 'c')],
          ),
        ],
      ));
      await tester.pumpAndSettle();

      final row = find.ancestor(
        of: find.text('Foods planned'),
        matching: find.byType(Row),
      );
      expect(
          find.descendant(of: row, matching: find.text('3')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(ExportScreen.exportKey))
            .onPressed,
        isNotNull,
      );
      expect(find.textContaining('your diet plan'), findsOneWidget);
    });
  });

  group('delete all data', () {
    testWidgets('the confirmation names the diet plan', (tester) async {
      await tester.pumpWidget(host(const DeleteAllDataScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DeleteAllDataScreen.deleteKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('and your diet plan will be removed'),
          findsOneWidget);
    });

    testWidgets('cancelling the confirmation deletes nothing and stays put',
        (tester) async {
      var restarted = false;
      final reminders = FakeReminderScheduler();
      await tester.pumpWidget(host(const DeleteAllDataScreen(),
          restart: () async => restarted = true, reminders: reminders));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DeleteAllDataScreen.deleteKey));
      await tester.pumpAndSettle();
      expect(find.text('Delete all data?'), findsOneWidget);
      await tester.tap(find.byKey(confirmCancelKey));
      await tester.pumpAndSettle();

      expect(restarted, isFalse);
      expect(reminders.cancelAllCount, 0);
      expect(find.byType(DeleteAllDataScreen), findsOneWidget);
    });

    testWidgets('confirming wipes the database, then reboots the app',
        (tester) async {
      await tester.runAsync(() => PersonalDetailsStore(database)
          .appendBodyweightEntry('2026-11-01', 80));
      var restarted = false;
      final reminders = FakeReminderScheduler();
      await tester.pumpWidget(host(const DeleteAllDataScreen(),
          restart: () async => restarted = true, reminders: reminders));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DeleteAllDataScreen.deleteKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(confirmDestructiveKey));
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 100),
          ));
      await tester.pumpAndSettle();

      expect(restarted, isTrue);
      expect(reminders.cancelAllCount, 1,
          reason: 'Delete all data cancels every notification (R25)');
      final count = await tester.runAsync(() => database
          .customSelect('SELECT COUNT(*) AS n FROM bodyweight_entries')
          .getSingle());
      expect(count!.read<int>('n'), 0);
    });
  });
}
