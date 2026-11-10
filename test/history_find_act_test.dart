import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/date_labels.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart'
    show BodyweightEntry, initialBodyweightLogProvider;
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/all_sessions_screen.dart';
import 'package:turtle_lift/src/ui/destructive_confirmation.dart';
import 'package:turtle_lift/src/ui/exercise_picker_sheet.dart';
import 'package:turtle_lift/src/ui/history_calendar_card.dart';
import 'package:turtle_lift/src/ui/history_root.dart';
import 'package:turtle_lift/src/ui/history_session_row.dart';
import 'package:turtle_lift/src/ui/session_summary_screen.dart';
import 'package:turtle_lift/src/ui/tab_index.dart';
import 'package:turtle_lift/src/ui/tab_routes.dart' show kWorkoutTabIndex;

/// Slice 6 of the History build: find a workout (search and muscle filter),
/// act on it from the list (swipe to delete), correct it fully (add an
/// exercise, clear affordances), and log a day that was missed (backfill from
/// the calendar).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  DateTime day(int daysAgo) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - daysAgo);
  }

  HistorySession row(
    String id,
    int daysAgo, {
    String? title,
    String exercise = 'Bench',
    String group = 'chest',
    String? note,
  }) =>
      HistorySession(
        id: id,
        performedOn: day(daysAgo),
        title: title,
        exercises: <HistoryExercise>[
          HistoryExercise(
            name: exercise,
            primaryGroupIds: <String>[group],
            setScores: const <double>[60],
            note: note,
          ),
        ],
      );

  Widget fixtureHost(List<HistorySession> sessions, Widget home) =>
      ProviderScope(
        key: UniqueKey(),
        overrides: [historySessionsProvider.overrideWithValue(sessions)],
        child: MaterialApp(theme: buildAppTheme(), home: home),
      );

  group('All workouts: search and filter', () {
    final sessions = <HistorySession>[
      row('push', 1, title: 'Push day', exercise: 'Barbell bench press'),
      row('pull', 3, title: 'Pull day', exercise: 'Barbell row', group: 'back'),
      row('legs', 5,
          title: 'Leg day',
          exercise: 'Back squat',
          group: 'quads',
          note: 'Knee felt good'),
    ];

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(fixtureHost(sessions, const AllSessionsScreen()));
      await tester.pumpAndSettle();
    }

    Iterable<String> shown(WidgetTester tester) => <String>[
          for (final id in <String>['push', 'pull', 'legs'])
            if (find
                .byKey(AllSessionsScreen.rowKey(id))
                .evaluate()
                .isNotEmpty)
              id,
        ];

    testWidgets('by exercise name', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(AllSessionsScreen.searchKey), 'bench');
      await tester.pumpAndSettle();
      expect(shown(tester), <String>['push']);
    });

    testWidgets('by title, ignoring case', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(AllSessionsScreen.searchKey), 'PULL');
      await tester.pumpAndSettle();
      expect(shown(tester), <String>['pull']);
    });

    testWidgets('by a note', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(AllSessionsScreen.searchKey), 'knee');
      await tester.pumpAndSettle();
      expect(shown(tester), <String>['legs']);
    });

    testWidgets('by muscle chip, and nothing matching says so',
        (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(AllSessionsScreen.muscleKey('back')));
      await tester.pumpAndSettle();
      expect(shown(tester), <String>['pull']);

      await tester.enterText(find.byKey(AllSessionsScreen.searchKey), 'squat');
      await tester.pumpAndSettle();
      expect(shown(tester), isEmpty);
      expect(find.text('No workouts match.'), findsOneWidget);
    });

    testWidgets('month headings carry their count', (tester) async {
      await pump(tester);
      final heading = find.byWidgetPredicate((w) =>
          w is HistoryMonthLabel && w.label.contains(' · '));
      expect(heading, findsWidgets);
    });

    testWidgets('the list is built lazily', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(fixtureHost(<HistorySession>[
        for (var i = 0; i < 300; i++) row('s$i', i),
      ], const AllSessionsScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(AllSessionsScreen.rowKey('s0')), findsOneWidget);
      expect(find.byKey(AllSessionsScreen.rowKey('s299')), findsNothing,
          reason: 'a row far below the fold is not built (B16)');
    });
  });

  group('acting on saved workouts', () {
    late AppDatabase database;
    late SessionStore store;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      store = SessionStore(database);
    });
    tearDown(() => database.close());

    final index = ExerciseIndex(const <Exercise>[
      Exercise(
        id: 'bench',
        name: 'Barbell bench press',
        equipment: 'barbell',
        loadType: 'weighted',
        primary: <String>['chest/mid'],
        secondary: <String>[],
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
      ),
      Exercise(
        id: 'row',
        name: 'Barbell row',
        equipment: 'barbell',
        loadType: 'weighted',
        primary: <String>['back/lats'],
        secondary: <String>[],
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
      ),
    ]);

    Future<String> save(WidgetTester tester, {LocalDate? on}) async {
      late String id;
      await tester.runAsync(() async {
        final s = await store.createSession(performedOn: on);
        id = s.id;
        final r = await store.addExercise(
            sessionId: id, exerciseId: 'bench', loadType: LoadType.weighted);
        await store.writeSet(
            sessionExerciseId: r,
            position: 0,
            weightKg: 60,
            reps: 8,
            completed: true);
        await store.saveOpenSession();
      });
      return id;
    }

    Future<ProviderContainer> pump(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saved = await tester.runAsync(() => store.readSavedSessions());
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialSavedSessionsProvider.overrideWithValue(saved!),
          initialBodyweightLogProvider
              .overrideWithValue(const <BodyweightEntry>[]),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: home),
      ));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byWidget(home)));
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pumpAndSettle();
    }

    testWidgets('swiping a row asks first; Cancel keeps it, Delete removes it',
        (tester) async {
      await save(tester);
      await pump(tester, const Scaffold(body: HistoryRoot()));

      await tester.drag(find.byType(HistorySessionRow), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(HistorySessionRow), findsOneWidget);

      await tester.drag(find.byType(HistorySessionRow), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(confirmDestructiveKey));
      await settle(tester);
      expect(await tester.runAsync(() => store.readSavedSessions()), isEmpty);
      expect(find.text('No workouts yet'), findsOneWidget);
    });

    testWidgets('a row offers Delete to VoiceOver as a custom action',
        (tester) async {
      final handle = tester.ensureSemantics();
      await save(tester);
      await pump(tester, const Scaffold(body: HistoryRoot()));
      final node = tester.getSemantics(
          find.bySemanticsLabel(RegExp('^Barbell bench press, quick log')));
      expect(node.getSemanticsData().customSemanticsActionIds, isNotEmpty);
      handle.dispose();
    });

    testWidgets('editor rows are buttons with a hint', (tester) async {
      final handle = tester.ensureSemantics();
      final id = await save(tester);
      await pump(tester, SessionSummaryScreen(sessionId: id, editing: true));
      expect(find.text('Edit workout'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Barbell bench press\n')),
        findsOneWidget,
      );
      final node = tester.getSemantics(
          find.bySemanticsLabel(RegExp('^Barbell bench press\n')));
      expect(node.hint, 'Edit sets');
      expect(node.getSemanticsData().customSemanticsActionIds, isNotEmpty,
          reason: 'Remove is offered as an action, not a long-press only');
      handle.dispose();
    });

    testWidgets('a past workout can take another exercise', (tester) async {
      final id = await save(tester);
      final container =
          await pump(tester, SessionSummaryScreen(sessionId: id, editing: true));
      expect(find.byKey(SessionSummaryScreen.addExerciseKey), findsOneWidget);
      await tester.tap(find.byKey(SessionSummaryScreen.addExerciseKey));
      await tester.pumpAndSettle();
      expect(find.byType(ExercisePickerSheet), findsOneWidget);
      await tester.tapAt(const Offset(10, 10)); // dismiss
      await tester.pumpAndSettle();

      // The write path the picker ends in.
      late String? rowId;
      await tester.runAsync(() async {
        rowId = await container.read(activeSessionProvider.notifier)
            .addSavedExercise(
                sessionId: id, exerciseId: 'row', loadType: LoadType.weighted);
      });
      await tester.pumpAndSettle();
      expect(rowId, isNotNull);
      final saved = await tester.runAsync(() => store.readSavedSessions());
      expect(saved!.single.exercises.map((e) => e.exerciseId),
          <String>['bench', 'row']);
      expect(saved.single.isOpen, isFalse,
          reason: 'adding to a saved workout never reopens it');
    });

    testWidgets('the empty state starts a workout on the Workout tab',
        (tester) async {
      final container = await pump(tester, const Scaffold(body: HistoryRoot()));
      expect(find.text('No workouts yet'), findsOneWidget);
      await tester.tap(find.byKey(HistoryRoot.startWorkoutKey));
      await tester.pumpAndSettle();
      expect(container.read(tabIndexProvider), kWorkoutTabIndex);
    });

    testWidgets('an empty past day offers to log a workout dated that day',
        (tester) async {
      await save(tester);
      final today = LocalDate.today();
      // A past day in this month with no workout, or skip on the 1st.
      if (today.day == 1) return;
      final target = LocalDate(today.year, today.month, 1);
      final container = await pump(tester, const Scaffold(body: HistoryRoot()));

      await tester.tap(find.byKey(HistoryCalendarCard.dayKey(target.toDateTime())));
      await tester.pumpAndSettle();
      expect(find.text('Log a workout for ${weekdayDateLabel(target)}?'),
          findsOneWidget);
      await tester.tap(find.byKey(HistoryRoot.backfillConfirmKey));
      await settle(tester);

      final open = container.read(activeSessionProvider);
      expect(open, isNotNull);
      expect(open!.performedOn, target);
      expect(container.read(tabIndexProvider), kWorkoutTabIndex);
    });
  });
}
