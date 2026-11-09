import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/history_session_detail_screen.dart';
import 'package:turtle_lift/src/ui/profile_root.dart';
import 'package:turtle_lift/src/ui/tab_index.dart';
import 'package:turtle_lift/src/ui/tab_routes.dart';
import 'package:turtle_lift/src/ui/week_strip.dart';
import 'package:turtle_lift/src/ui/workout_root.dart';

/// The week and the last workout on the Workout landing
/// (`docs/adr/0008-the-week-lives-on-the-workout-landing.md`). "Today" is
/// pinned to Wednesday 21 October 2026.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseIndex index;
  setUpAll(() async {
    final boot = ProviderContainer();
    addTearDown(boot.dispose);
    index = ExerciseIndex.fromJson(
      await boot.read(exerciseLibraryProvider.future),
    );
  });

  HistorySession session(String id, int day, {String? title}) =>
      HistorySession(
        id: id,
        performedOn: DateTime(2026, 10, day),
        title: title,
        exercises: const <HistoryExercise>[
          HistoryExercise(
            name: 'Barbell bench press',
            primaryGroupIds: <String>['chest'],
            setScores: <double>[60, 60, 60],
          ),
        ],
      );

  final monWedFri = TrainingPlanEntry(
    effectiveFrom: LocalDate(2026, 10, 1),
    weekdays: const <int>{0, 2, 4},
  );

  late ProviderContainer container;
  final pushed = <String?>[];

  Future<void> pumpLanding(
    WidgetTester tester, {
    List<TrainingPlanEntry> plan = const <TrainingPlanEntry>[],
    List<HistorySession> sessions = const <HistorySession>[],
    bool isPushed = false,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    pushed.clear();

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          exerciseIndexProvider.overrideWithValue(index),
          customTemplatesProvider.overrideWithValue(const <WorkoutTemplate>[]),
          planTodayProvider.overrideWithValue(LocalDate(2026, 10, 21)),
          initialTrainingPlanProvider.overrideWithValue(plan),
          historySessionsProvider.overrideWithValue(sessions),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          navigatorObservers: <NavigatorObserver>[
            _Recorder((route) => pushed.add(route.settings.name)),
          ],
          home: Scaffold(body: WorkoutLandingBody(isPushed: isPushed)),
        ),
      ),
    );
    await tester.pump();
    container =
        ProviderScope.containerOf(tester.element(find.byType(WorkoutLandingBody)));
  }

  group('the this-week strip', () {
    testWidgets('sits above the search field', (tester) async {
      await pumpLanding(tester, plan: <TrainingPlanEntry>[monWedFri]);

      final strip = tester.getTopLeft(find.byKey(WeekStrip.stripKey)).dy;
      final search = tester.getTopLeft(find.byType(TextField)).dy;
      expect(strip, lessThan(search));
    });

    testWidgets('states the count, the days, and what is left',
        (tester) async {
      await pumpLanding(
        tester,
        plan: <TrainingPlanEntry>[monWedFri],
        sessions: <HistorySession>[session('a', 19), session('b', 12)],
      );

      final strip = find.byKey(WeekStrip.stripKey);
      expect(
        find.descendant(of: strip, matching: find.text('1 of 3 this week')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: strip, matching: find.text('2 more to go. Next is Wednesday')),
        findsOneWidget,
      );
      for (final day in <String>['Mon', 'Wed', 'Fri']) {
        expect(find.descendant(of: strip, matching: find.text(day)),
            findsOneWidget);
      }
    });

    testWidgets('is announced as one sentence that says where it goes',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLanding(
        tester,
        plan: <TrainingPlanEntry>[monWedFri],
        sessions: <HistorySession>[session('a', 19)],
      );

      expect(
        find.bySemanticsLabel('This week: 1 of 3 plan days. 2 more to go. '
            'Next is Wednesday. Edit training days'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('never names a workout, an exercise or a template '
        '(ADR 0005 rule 1)', (tester) async {
      await pumpLanding(
        tester,
        plan: <TrainingPlanEntry>[monWedFri],
        sessions: <HistorySession>[session('a', 19, title: 'Push day')],
      );

      final texts = tester
          .widgetList<Text>(find.descendant(
              of: find.byKey(WeekStrip.stripKey), matching: find.byType(Text)))
          .map((t) => t.data ?? '')
          .join(' | ')
          .toLowerCase();
      for (final template in kPredefinedTemplates) {
        expect(texts, isNot(contains(template.name.toLowerCase())));
      }
      for (final exercise in index.all) {
        expect(texts, isNot(contains(exercise.name.toLowerCase())),
            reason: exercise.name);
      }
      for (final word in <String>['missed', 'behind', 'today\'s workout']) {
        expect(texts, isNot(contains(word)));
      }
    });

    testWidgets('with no plan, one quiet line instead of "0 of 0"',
        (tester) async {
      await pumpLanding(tester);

      expect(find.text(WeekStrip.pickDaysLabel), findsOneWidget);
      expect(find.textContaining('0 of 0'), findsNothing);
    });

    testWidgets('a plan with no day left this week says when it starts',
        (tester) async {
      await pumpLanding(tester, plan: <TrainingPlanEntry>[
        TrainingPlanEntry(
          effectiveFrom: LocalDate(2026, 10, 21),
          weekdays: const <int>{0},
        ),
      ]);

      expect(find.text('Your first plan day is Monday.'), findsOneWidget);
      expect(find.text(WeekStrip.pickDaysLabel), findsNothing);
    });

    testWidgets('a tap opens Profile, Schedule', (tester) async {
      await pumpLanding(tester, plan: <TrainingPlanEntry>[monWedFri]);

      await tester.tap(find.byKey(WeekStrip.stripKey));
      await tester.pump();

      expect(container.read(tabIndexProvider), kProfileTabIndex);
      expect(container.read(profileSegmentProvider), ProfileSegment.schedule);
    });

    testWidgets('the no-plan line opens Profile, Schedule too',
        (tester) async {
      await pumpLanding(tester);

      await tester.tap(find.text(WeekStrip.pickDaysLabel));
      await tester.pump();

      expect(container.read(tabIndexProvider), kProfileTabIndex);
      expect(container.read(profileSegmentProvider), ProfileSegment.schedule);
    });

    testWidgets('is absent on the landing pushed over an open workout',
        (tester) async {
      await pumpLanding(tester,
          plan: <TrainingPlanEntry>[monWedFri], isPushed: true);

      expect(find.byKey(WeekStrip.stripKey), findsNothing);
      expect(find.text(WeekStrip.pickDaysLabel), findsNothing);
    });
  });

  group('the last workout line', () {
    testWidgets('is absent with no history', (tester) async {
      await pumpLanding(tester);
      expect(find.byKey(LastWorkoutLine.lineKey), findsNothing);
    });

    testWidgets('names the newest workout, its day and its sets',
        (tester) async {
      await pumpLanding(tester, sessions: <HistorySession>[
        session('old', 12, title: 'Leg day'),
        session('new', 19, title: 'Push day'),
      ]);

      final line = find.byKey(LastWorkoutLine.lineKey);
      expect(
        find.descendant(
            of: line, matching: find.textContaining('Push day · 3 sets')),
        findsOneWidget,
      );
      expect(find.descendant(of: line, matching: find.textContaining('Leg day')),
          findsNothing);
    });

    testWidgets('a tap opens that workout in History', (tester) async {
      await pumpLanding(tester, sessions: <HistorySession>[
        session('new', 19, title: 'Push day'),
      ]);

      await tester.tap(find.byKey(LastWorkoutLine.lineKey));
      await tester.pumpAndSettle();

      expect(pushed, contains(HistorySessionDetailScreen.routeNameFor('new')));
    });
  });
}

class _Recorder extends NavigatorObserver {
  _Recorder(this.onPush);

  final void Function(Route<dynamic>) onPush;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onPush(route);
}
