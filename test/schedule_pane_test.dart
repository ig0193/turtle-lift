import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/profile_root.dart';
import 'package:turtle_lift/src/ui/schedule_pane.dart';

/// The Schedule pane, driven through the Profile root the way the app mounts
/// it. "Today" is pinned to Wednesday 21 October 2026.
void main() {
  late AppDatabase database;
  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  HistorySession session(String id, int day) => HistorySession(
        id: id,
        performedOn: DateTime(2026, 10, day),
        exercises: const <HistoryExercise>[],
      );

  final monWedFri = TrainingPlanEntry(
    effectiveFrom: LocalDate(2026, 10, 1),
    weekdays: const <int>{0, 2, 4},
  );

  Widget host({
    List<TrainingPlanEntry> plan = const <TrainingPlanEntry>[],
    List<HistorySession> sessions = const <HistorySession>[],
  }) =>
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          planTodayProvider.overrideWithValue(LocalDate(2026, 10, 21)),
          initialTrainingPlanProvider.overrideWithValue(plan),
          historySessionsProvider.overrideWithValue(sessions),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: AppScreen.root(title: 'Profile', body: const ProfileRoot()),
        ),
      );

  Future<void> openSchedule(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.schedule)));
    await tester.pumpAndSettle();
  }

  group('the week summary', () {
    testWidgets('no plan: a prompt, not "0 of 0"', (tester) async {
      await openSchedule(tester, host());

      expect(find.text(SchedulePane.emptySummary), findsOneWidget);
      expect(find.byKey(SchedulePane.heroKey), findsNothing);
      expect(find.textContaining('0 of 0'), findsNothing);
    });

    testWidgets('mid-week it states the count and what is left',
        (tester) async {
      await openSchedule(
        tester,
        host(
          plan: <TrainingPlanEntry>[monWedFri],
          sessions: <HistorySession>[
            session('a', 19),
            session('b', 12),
            session('c', 16),
          ],
        ),
      );

      expect(find.byKey(SchedulePane.heroKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(SchedulePane.heroKey),
          matching: find.textContaining('1 of 3', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(find.text('2 more to go — next is Wednesday'), findsOneWidget);
      expect(find.byKey(SchedulePane.lastWeekKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(SchedulePane.lastWeekKey),
          matching: find.text('2 of 3'),
        ),
        findsOneWidget,
        reason: 'last week: Monday and Friday were hit, Wednesday was not',
      );
    });

    testWidgets('the hero is announced as one sentence', (tester) async {
      final handle = tester.ensureSemantics();
      await openSchedule(
        tester,
        host(
          plan: <TrainingPlanEntry>[monWedFri],
          sessions: <HistorySession>[session('a', 19)],
        ),
      );

      expect(
        find.bySemanticsLabel(
          'This week: 1 of 3 plan days. 2 more to go — next is Wednesday',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a plan with no day left this week says when it starts',
        (tester) async {
      // Saved on Wednesday for Mondays only: nothing left in this week.
      await openSchedule(
        tester,
        host(
          plan: <TrainingPlanEntry>[
            TrainingPlanEntry(
              effectiveFrom: LocalDate(2026, 10, 21),
              weekdays: const <int>{0},
            ),
          ],
        ),
      );

      expect(find.text('Your first plan day is Monday.'), findsOneWidget);
      expect(find.text(SchedulePane.emptySummary), findsNothing,
          reason: 'they just picked days, so do not ask them to pick');
    });
  });

  group('the training-day chips', () {
    testWidgets('show the plan in force today', (tester) async {
      final handle = tester.ensureSemantics();
      await openSchedule(tester, host(plan: <TrainingPlanEntry>[monWedFri]));

      for (var d = 0; d < kWeekdayCount; d++) {
        expect(
          tester.getSemantics(find.byKey(SchedulePane.dayChipKey(d))),
          isSemantics(isButton: true, isSelected: monWedFri.weekdays.contains(d)),
          reason: 'weekday $d',
        );
      }
      handle.dispose();
    });

    testWidgets('tapping one saves a dated plan and the summary appears',
        (tester) async {
      await openSchedule(tester, host());
      expect(find.byKey(SchedulePane.heroKey), findsNothing);

      await tester.tap(find.byKey(SchedulePane.dayChipKey(4))); // Friday
      await tester.pumpAndSettle();

      expect(find.byKey(SchedulePane.heroKey), findsOneWidget);
      expect(find.text('1 more to go — next is Friday'), findsOneWidget);

      final stored = await readStoredTrainingPlan(TrainingPlanStore(database));
      expect(stored, <TrainingPlanEntry>[
        TrainingPlanEntry(
          effectiveFrom: LocalDate(2026, 10, 19),
          weekdays: const <int>{4},
        ),
      ]);
    });

    testWidgets('turning the last day off clears the plan from today',
        (tester) async {
      await openSchedule(
        tester,
        host(
          plan: <TrainingPlanEntry>[
            TrainingPlanEntry(
              effectiveFrom: LocalDate(2026, 10, 1),
              weekdays: const <int>{4},
            ),
          ],
        ),
      );

      await tester.tap(find.byKey(SchedulePane.dayChipKey(4)));
      await tester.pumpAndSettle();

      expect(find.text(SchedulePane.emptySummary), findsOneWidget);
      final stored = await readStoredTrainingPlan(TrainingPlanStore(database));
      expect(stored.single.weekdays, isEmpty);
    });
  });

  group('the reminder row (inert until notifications ship)', () {
    testWidgets('the switch opens the explain-first sheet', (tester) async {
      await openSchedule(tester, host(plan: <TrainingPlanEntry>[monWedFri]));

      await tester.tap(find.byKey(SchedulePane.remindSwitchKey));
      await tester.pumpAndSettle();

      expect(find.text('Remind you on training days?'), findsOneWidget);
      expect(find.textContaining('Mon, Wed, Fri'), findsOneWidget);
      expect(find.textContaining('no "you missed a day"'), findsOneWidget);
    });

    testWidgets('Not now leaves the switch off; Allow turns it on, then off',
        (tester) async {
      final handle = tester.ensureSemantics();
      await openSchedule(tester, host(plan: <TrainingPlanEntry>[monWedFri]));

      bool toggled() => tester
          .getSemantics(find.byKey(SchedulePane.remindSwitchKey))
          .getSemanticsData()
          .flagsCollection
          .isToggled
          .name ==
      'isTrue';

      await tester.tap(find.byKey(SchedulePane.remindSwitchKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SchedulePane.notNowKey));
      await tester.pumpAndSettle();
      expect(toggled(), isFalse);

      await tester.tap(find.byKey(SchedulePane.remindSwitchKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SchedulePane.allowKey));
      await tester.pumpAndSettle();
      expect(toggled(), isTrue);

      await tester.tap(find.byKey(SchedulePane.remindSwitchKey));
      await tester.pumpAndSettle();
      expect(toggled(), isFalse, reason: 'turning off needs no sheet');
      handle.dispose();
    });

    testWidgets('the switch persists nothing and schedules nothing',
        (tester) async {
      await openSchedule(tester, host(plan: <TrainingPlanEntry>[monWedFri]));
      await tester.tap(find.byKey(SchedulePane.remindSwitchKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SchedulePane.allowKey));
      await tester.pumpAndSettle();

      final stored = await readStoredTrainingPlan(TrainingPlanStore(database));
      expect(stored, isEmpty,
          reason: 'the reminder switch must not touch the plan series');
    });
  });
}
