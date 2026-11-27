import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/data_reset.dart';
import 'package:turtle_lift/src/data/diet_log.dart';
import 'package:turtle_lift/src/data/diet_log_store.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart'
    show reminderSchedulerProvider;
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/data/today.dart'
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
    List<DietLogEntry> dietLog = const <DietLogEntry>[],
    FakeReminderScheduler? reminders,
  }) =>
      ProviderScope(
        overrides: [
          planTodayProvider.overrideWithValue(LocalDate(2026, 11, 4)),
          initialDietLogProvider.overrideWithValue(dietLog),
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
    DietLogEntry entry(int day, String foodId) => DietLogEntry(
          id: '$day-$foodId',
          date: LocalDate(2026, 11, day),
          slot: MealSlot.lunch,
          foodId: foodId,
          servingsHalves: 2,
          position: 0,
        );

    testWidgets('foods logged counts every entry in the log, and a diet log '
        'alone makes something to export', (tester) async {
      await tester.pumpWidget(host(
        const ExportScreen(),
        dietLog: <DietLogEntry>[
          entry(2, 'a'),
          entry(3, 'b'),
          entry(4, 'c'),
        ],
      ));
      await tester.pumpAndSettle();

      final row = find.ancestor(
        of: find.text('Foods logged'),
        matching: find.byType(Row),
      );
      expect(
          find.descendant(of: row, matching: find.text('3')), findsOneWidget);
      expect(find.text('Training days'), findsNothing);
      expect(find.text('Foods planned'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(ExportScreen.exportKey))
            .onPressed,
        isNotNull,
      );
      expect(find.textContaining('your reminders and your diet log'),
          findsOneWidget);
    });
  });

  group('delete all data', () {
    testWidgets('the confirmation names the diet log and the reminders', (tester) async {
      await tester.pumpWidget(host(const DeleteAllDataScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DeleteAllDataScreen.deleteKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('your diet log and your reminders will be removed'),
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
