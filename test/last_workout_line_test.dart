import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/today.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/history_session_detail_screen.dart';
import 'package:turtle_lift/src/ui/last_workout_line.dart';
import 'package:turtle_lift/src/ui/workout_root.dart';

/// The last workout line on the Workout landing
/// (`docs/adr/0008-the-week-lives-on-the-workout-landing.md`). The week strip
/// that used to sit above it went with the Schedule (ADR 0015). "Today" is
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

  late ProviderContainer container;
  final pushed = <String?>[];

  Future<void> pumpLanding(
    WidgetTester tester, {
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

  group('the last workout line', () {
    testWidgets('is absent with no history', (tester) async {
      await pumpLanding(tester);
      expect(find.byKey(LastWorkoutLine.lineKey), findsNothing);
    });

    testWidgets('sits above the search field, with no week strip before it',
        (tester) async {
      await pumpLanding(tester, sessions: <HistorySession>[
        session('new', 19, title: 'Push day'),
      ]);

      final line = tester.getTopLeft(find.byKey(LastWorkoutLine.lineKey)).dy;
      final search = tester.getTopLeft(find.byType(TextField)).dy;
      expect(line, lessThan(search));
      expect(find.text('Pick training days'), findsNothing);
      expect(find.textContaining('this week'), findsNothing);
    });

    testWidgets('is absent on the landing pushed over an open workout',
        (tester) async {
      await pumpLanding(
        tester,
        sessions: <HistorySession>[session('new', 19, title: 'Push day')],
        isPushed: true,
      );

      expect(find.byKey(LastWorkoutLine.lineKey), findsNothing);
    });

    testWidgets('is announced as one button naming the workout',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLanding(tester, sessions: <HistorySession>[
        session('new', 19, title: 'Push day'),
      ]);

      expect(
        find.bySemanticsLabel(RegExp(r'^Last workout: .*Push day · 3 sets$')),
        findsOneWidget,
      );
      handle.dispose();
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

    testWidgets('lastWorkoutProvider is the same line the widget shows',
        (tester) async {
      await pumpLanding(tester, sessions: <HistorySession>[
        session('old', 12, title: 'Leg day'),
        session('new', 19, title: 'Push day'),
      ]);

      final last = container.read(lastWorkoutProvider)!;
      expect(last.id, 'new');
      expect(last.line, endsWith('Push day · 3 sets'));
      expect(
        find.descendant(
            of: find.byKey(LastWorkoutLine.lineKey),
            matching: find.text(last.line)),
        findsOneWidget,
      );
    });

    testWidgets('lastWorkoutProvider is null with no history',
        (tester) async {
      await pumpLanding(tester);
      expect(container.read(lastWorkoutProvider), isNull);
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
