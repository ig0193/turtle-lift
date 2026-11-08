import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/main.dart' show RefreshTodayOnResume;
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/diet_plan.dart';
import 'package:turtle_lift/src/data/diet_plan_store.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/meal_ticks.dart';
import 'package:turtle_lift/src/data/reminder_prefs.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/diet_reminders_screen.dart';
import 'package:turtle_lift/src/ui/diet_slot_card.dart';
import 'package:turtle_lift/src/ui/reminder_controls.dart';

import 'protein_target_screen_test.dart' show expectNoBannedCopy;
import 'support/fake_reminder_scheduler.dart';

/// A scheduler on a platform without notifications (R23).
class _UnsupportedScheduler extends FakeReminderScheduler {
  @override
  bool get isSupported => false;
}

/// Diet's Reminders screen and its row on the pane (U17, R21, R23). "Today"
/// is Wednesday 4 November 2026; Monday is the 2nd.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LocalDate nov(int day) => LocalDate(2026, 11, day);

  late AppDatabase database;
  late FakeReminderScheduler reminders;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    reminders = FakeReminderScheduler();
  });

  /// A tall phone, so every row of the screen is built at once.
  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }
  tearDown(() => database.close());

  Map<String, Object?> food(String id, String name, double protein) =>
      <String, Object?>{
        'id': id,
        'name': name,
        'aliases': const <String>[],
        'dietType': 'veg',
        'servingLabel': '1 katori, 150 g',
        'gramsPerServing': 150,
        'proteinPerServingG': protein,
        'proteinPer100g': protein,
        'ifctCode': 'X001',
        'reviewedBy': 'pending-owner-review',
      };

  final foods = FoodIndex.fromJson(<Map<String, Object?>>[
    food('rajma', 'Rajma', 9.0),
    food('curd', 'Curd', 11.0),
  ]);

  /// Wednesday lunch: Rajma, Curd.
  final plan = <DietPlanVersion>[
    DietPlanVersion(effectiveFrom: nov(2), items: const <DietPlanItem>[
      DietPlanItem(
          id: 'a',
          weekday: 2,
          slot: MealSlot.lunch,
          foodId: 'rajma',
          servingsHalves: 2,
          position: 0),
      DietPlanItem(
          id: 'b',
          weekday: 2,
          slot: MealSlot.lunch,
          foodId: 'curd',
          servingsHalves: 2,
          position: 1),
    ]),
  ];

  final allOn = ReminderPreferences.defaults
      .copyWith(dietOn: true, summaryOn: true)
      .withSlot(MealSlot.breakfast,
          const SlotReminder(on: true, minute: 8 * 60))
      .withSlot(MealSlot.lunch, const SlotReminder(on: true, minute: 13 * 60))
      .withSlot(MealSlot.dinner,
          const SlotReminder(on: true, minute: 20 * 60 + 30));

  /// The app's providers under [RefreshTodayOnResume], which holds both
  /// reminder syncs, so a test sees what the OS would be asked.
  Widget host(
    Widget home, {
    ReminderPreferences prefs = ReminderPreferences.defaults,
    ReminderScheduler? scheduler,
    List<TrainingPlanEntry> training = const <TrainingPlanEntry>[],
  }) =>
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          dietPlanStoreProvider
              .overrideWithValue(DietPlanStore(database, today: () => nov(4))),
          mealTickStoreProvider
              .overrideWithValue(MealTickStore(database, today: () => nov(4))),
          foodIndexProvider.overrideWithValue(foods),
          planTodayProvider.overrideWithValue(nov(4)),
          initialDietPlanProvider.overrideWithValue(plan),
          initialReminderPrefsProvider.overrideWithValue(prefs),
          initialTrainingPlanProvider.overrideWithValue(training),
          reminderSchedulerProvider.overrideWithValue(scheduler ?? reminders),
        ],
        child: RefreshTodayOnResume(
          child: MaterialApp(theme: buildAppTheme(), home: home),
        ),
      );

  Widget pane() => AppScreen.root(
        title: 'Profile',
        body: Builder(
          builder: (context) => ListView(
            padding: screenScrollPadding(context),
            children: const <Widget>[DietPane()],
          ),
        ),
      );

  SwitchRow switchRow(WidgetTester tester, Key key) => tester.widget<SwitchRow>(
      find.ancestor(of: find.byKey(key), matching: find.byType(SwitchRow)));

  Future<void> tap(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  final childSwitches = <Key>[
    DietRemindersScreen.summarySwitchKey,
    for (final s in MealSlot.values) DietRemindersScreen.slotSwitchKey(s),
  ];
  final childTimes = <Key>[
    DietRemindersScreen.summaryTimeKey,
    for (final s in MealSlot.values) DietRemindersScreen.slotTimeKey(s),
  ];

  group('the screen', () {
    testWidgets('a pushed screen: master, summary and four slots at the A7 '
        'defaults', (tester) async {
      tallView(tester);
      await tester.pumpWidget(host(const DietRemindersScreen()));
      await tester.pumpAndSettle();

      expect(find.text(DietRemindersScreen.title), findsOneWidget);
      expect(find.byType(AppScreen), findsOneWidget);
      expect(find.byKey(DietRemindersScreen.masterKey), findsOneWidget);
      for (final k in <Key>[...childSwitches, ...childTimes]) {
        expect(find.byKey(k), findsOneWidget);
      }
      expect(find.text('7:30 AM'), findsOneWidget);
      expect(find.text('8:00 AM'), findsOneWidget);
      expect(find.text('1:00 PM'), findsOneWidget);
      expect(find.text('5:00 PM'), findsOneWidget);
      expect(find.text('8:30 PM'), findsOneWidget);
      expectNoBannedCopy(DietRemindersScreen.explainBody);
      expectNoBannedCopy(DietRemindersScreen.disabledReason);
    });

    testWidgets('with the master off, the summary and slot rows are disabled '
        'and say why', (tester) async {
      tallView(tester);
      await tester.pumpWidget(host(const DietRemindersScreen()));
      await tester.pumpAndSettle();

      expect(switchRow(tester, DietRemindersScreen.masterKey).value, isFalse);
      for (final k in childSwitches) {
        final row = switchRow(tester, k);
        expect(row.onTap, isNull);
        expect(row.subtitle, 'Turn on reminders to set times');
      }
      for (final k in childTimes) {
        expect(tester.widget<TimeRow>(find.byKey(k)).onTap, isNull);
      }

      await tester.tap(find.byKey(DietRemindersScreen.summarySwitchKey),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(await ReminderPrefsStore(database).read(),
          ReminderPreferences.defaults);
    });

    testWidgets('first enable shows the explain-first sheet before any prompt',
        (tester) async {
      tallView(tester);
      await tester.pumpWidget(host(const DietRemindersScreen()));
      await tester.pumpAndSettle();

      await tap(tester, DietRemindersScreen.masterKey);

      expect(find.byType(ExplainSheet), findsOneWidget);
      expect(find.text(DietRemindersScreen.explainTitle), findsOneWidget);
      expect(reminders.calls, isNot(contains('request')));
    });

    testWidgets('Allow, granted: stored on, children enabled, reminders '
        'scheduled from the plan', (tester) async {
      tallView(tester);
      await tester.pumpWidget(host(const DietRemindersScreen(),
          prefs: allOn.copyWith(dietOn: false)));
      await tester.pumpAndSettle();

      await tap(tester, DietRemindersScreen.masterKey);
      await tap(tester, DietRemindersScreen.allowKey);

      expect(reminders.calls, contains('request'));
      expect((await ReminderPrefsStore(database).read()).dietOn, isTrue);
      expect(switchRow(tester, DietRemindersScreen.masterKey).value, isTrue);
      for (final k in childSwitches) {
        expect(switchRow(tester, k).onTap, isNotNull);
      }
      expect(reminders.pending.keys.toSet(), <int>{
        dietSummaryReminderId(2),
        dietMealReminderId(2, MealSlot.lunch),
      });
      expect(reminders.pending[dietMealReminderId(2, MealSlot.lunch)]!.body,
          'Rajma, 1 katori (9 g). Curd, 1 katori (11 g).');
    });

    testWidgets('denied: the master stays off with the Settings line',
        (tester) async {
      tallView(tester);
      reminders.grantOnRequest = false;
      await tester.pumpWidget(host(const DietRemindersScreen()));
      await tester.pumpAndSettle();

      await tap(tester, DietRemindersScreen.masterKey);
      await tap(tester, DietRemindersScreen.allowKey);

      expect(switchRow(tester, DietRemindersScreen.masterKey).value, isFalse);
      expect(find.text(kNotificationsOffCopy), findsOneWidget);
      expect((await ReminderPrefsStore(database).read()).dietOn, isFalse);
      expect(reminders.pending, isEmpty);
    });

    testWidgets('a slot switch and time are stored and rescheduled',
        (tester) async {
      tallView(tester);
      reminders.permitted = true;
      await tester.pumpWidget(host(const DietRemindersScreen(),
          prefs: allOn.withSlot(
              MealSlot.lunch, const SlotReminder(on: false, minute: 13 * 60))));
      await tester.pumpAndSettle();
      expect(reminders.pending.keys,
          isNot(contains(dietMealReminderId(2, MealSlot.lunch))));

      await tap(tester, DietRemindersScreen.slotSwitchKey(MealSlot.lunch));
      expect((await ReminderPrefsStore(database).read()).lunch.on, isTrue);
      expect(reminders.pending[dietMealReminderId(2, MealSlot.lunch)]!.minute,
          13 * 60);

      await tap(tester, DietRemindersScreen.slotTimeKey(MealSlot.lunch));
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
    });

    testWidgets('turning the master off cancels 200-206 and 300-363 and '
        'nothing else', (tester) async {
      tallView(tester);
      reminders.permitted = true;
      await tester.pumpWidget(host(
        const DietRemindersScreen(),
        prefs: allOn.copyWith(scheduleOn: true),
        training: <TrainingPlanEntry>[
          TrainingPlanEntry(
              effectiveFrom: nov(2), weekdays: const <int>{0, 2, 4}),
        ],
      ));
      await tester.pumpAndSettle();
      expect(reminders.pending.keys.where(kTrainingReminderIds.contains),
          hasLength(3));
      expect(reminders.pending.keys.where(kDietMealReminderIds.contains),
          isNotEmpty);

      await tap(tester, DietRemindersScreen.masterKey);

      expect(find.byType(ExplainSheet), findsNothing);
      expect((await ReminderPrefsStore(database).read()).dietOn, isFalse);
      expect(reminders.pending.keys.toSet(), <int>{100, 102, 104});
      expect(reminders.calls, isNot(contains('cancelAll')));
    });

    testWidgets('permission revoked after enabling: on next open the master '
        'reads off with the Settings line', (tester) async {
      tallView(tester);
      reminders.permitted = false;
      await tester
          .pumpWidget(host(const DietRemindersScreen(), prefs: allOn));
      await tester.pumpAndSettle();

      expect(switchRow(tester, DietRemindersScreen.masterKey).value, isFalse);
      expect(find.text(kNotificationsOffCopy), findsOneWidget);
      for (final k in childSwitches) {
        expect(switchRow(tester, k).onTap, isNull);
      }

      // Turned back on in Settings, then back to the app.
      reminders.permitted = true;
      for (final state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      expect(switchRow(tester, DietRemindersScreen.masterKey).value, isTrue);
      expect(find.text(kNotificationsOffCopy), findsNothing);
    });
  });

  group('the pane', () {
    testWidgets('a Reminders row under Target opens the screen',
        (tester) async {
      tallView(tester);
      await tester.pumpWidget(host(pane()));
      await tester.pumpAndSettle();

      final row = find.byKey(DietPane.remindersRowKey);
      expect(row, findsOneWidget);
      expect(tester.getTopLeft(row).dy,
          greaterThan(tester.getTopLeft(find.byKey(DietPane.targetRowKey)).dy));
      expect(
          find.descendant(of: row, matching: find.text('Off')), findsOneWidget);

      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(DietRemindersScreen), findsOneWidget);
    });

    testWidgets('the row counts the reminders a day while on', (tester) async {
      tallView(tester);
      reminders.permitted = true;
      await tester.pumpWidget(host(pane(), prefs: allOn));
      await tester.pumpAndSettle();

      expect(
          find.descendant(
              of: find.byKey(DietPane.remindersRowKey),
              matching: find.text('4 a day')),
          findsOneWidget);
    });

    testWidgets('the Reminders row is absent where notifications are '
        'unsupported (R23)', (tester) async {
      tallView(tester);
      await tester.pumpWidget(
          host(pane(), prefs: allOn, scheduler: _UnsupportedScheduler()));
      await tester.pumpAndSettle();

      expect(find.byKey(DietPane.targetRowKey), findsOneWidget);
      expect(find.byKey(DietPane.remindersRowKey), findsNothing);
      expect(find.text('1:00 PM'), findsNothing);
    });

    testWidgets('a slot header shows its time only while the master and that '
        'slot reminder are on (A7)', (tester) async {
      tallView(tester);
      await tester.pumpWidget(host(pane(), prefs: allOn));
      await tester.pumpAndSettle();

      Finder inCard(MealSlot slot, String text) => find.descendant(
          of: find.byKey(DietSlotCard.cardKey(slot)),
          matching: find.text(text));
      expect(inCard(MealSlot.lunch, '1:00 PM'), findsOneWidget);
      expect(inCard(MealSlot.breakfast, '8:00 AM'), findsOneWidget);
      expect(inCard(MealSlot.snack, '5:00 PM'), findsNothing,
          reason: 'the snack reminder is off by default');
    });

    testWidgets('no slot time while the master is off', (tester) async {
      tallView(tester);
      await tester.pumpWidget(
          host(pane(), prefs: allOn.copyWith(dietOn: false)));
      await tester.pumpAndSettle();

      expect(find.text('1:00 PM'), findsNothing);
      expect(find.text('8:00 AM'), findsNothing);
    });
  });
}
