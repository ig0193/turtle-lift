import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/destructive_confirmation.dart';
import 'package:turtle_lift/src/ui/history_session_detail_screen.dart';
import 'package:turtle_lift/src/ui/tab_index.dart';
import 'package:turtle_lift/src/ui/tab_routes.dart';

/// "Do again": a past workout's exercise list copied into a new open session,
/// started by the user from History. The exercises only -- never its numbers,
/// which arrive as each row's "last time" line -- and never suggested.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SessionStore store;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = SessionStore(database);
  });
  tearDown(() => database.close());

  Exercise ex(String id, String name) => Exercise(
        id: id,
        name: name,
        equipment: 'Barbell',
        loadType: 'weighted',
        primary: const <String>['chest/mid'],
        secondary: const <String>[],
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
      );
  final index = ExerciseIndex(<Exercise>[
    ex('bench', 'Barbell bench press'),
    ex('fly', 'Cable fly'),
    ex('dip', 'Dip'),
  ]);

  /// A saved Push day: bench and fly logged, dip added and never done.
  Future<WorkoutSession> savePushDay(WidgetTester tester) async {
    late WorkoutSession saved;
    await tester.runAsync(() async {
      final s = await store.createSession(
        templateId: 'push',
        templateName: 'Push day',
        performedOn: LocalDate.today().addDays(-2),
      );
      for (final id in <String>['fly', 'bench', 'dip']) {
        final row = await store.addExercise(
            sessionId: s.id, exerciseId: id, loadType: LoadType.weighted);
        if (id != 'dip') {
          await store.writeSet(
              sessionExerciseId: row,
              position: 0,
              weightKg: 60,
              reps: 8,
              completed: true);
        }
      }
      await store.saveOpenSession();
      saved = (await store.readSavedSessions()).single;
    });
    return saved;
  }

  late ProviderContainer container;

  Future<void> pumpDetail(WidgetTester tester, WorkoutSession saved,
      {WorkoutSession? open}) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final all = (await tester.runAsync(() => store.readSavedSessions()))!;
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        exerciseIndexProvider.overrideWithValue(index),
        initialSavedSessionsProvider.overrideWithValue(all),
        initialActiveSessionProvider.overrideWithValue(open),
        initialBodyweightLogProvider.overrideWithValue(const []),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: Text('shell')),
      ),
    ));
    container = ProviderScope.containerOf(tester.element(find.text('shell')));
    container.read(tabIndexProvider.notifier).select(2);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(
      builder: (_) => HistorySessionDetailScreen(sessionId: saved.id),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('starts a new workout with the exercises that were logged, in '
      'order, and no numbers', (tester) async {
    final saved = await savePushDay(tester);
    await pumpDetail(tester, saved);

    await tester.ensureVisible(find.byKey(HistorySessionDetailScreen.doAgainKey));
    await act(tester,
        () => tester.tap(find.byKey(HistorySessionDetailScreen.doAgainKey)));

    final open = (await tester.runAsync(() => store.readOpenSession()))!;
    expect(open.id, isNot(saved.id));
    expect(open.exercises.map((e) => e.exerciseId), <String>['fly', 'bench'],
        reason: 'the dip was never done, so it is not part of the workout');
    expect(open.exercises.every((e) => e.sets.isEmpty), isTrue,
        reason: 'last time arrives as each row\'s line, never as values');
    expect(open.templateName, 'Push day');
    expect(open.performedOn, LocalDate.today());

    expect(container.read(tabIndexProvider), kWorkoutTabIndex,
        reason: 'it opens where the workout now is');
    expect(find.text('shell'), findsOneWidget, reason: 'popped to the root');
  });

  testWidgets('with a workout open, it asks first; Cancel changes nothing',
      (tester) async {
    final saved = await savePushDay(tester);
    late WorkoutSession open;
    await tester.runAsync(() async {
      final s = await store.createSession();
      final row = await store.addExercise(
          sessionId: s.id, exerciseId: 'dip', loadType: LoadType.weighted);
      await store.writeSet(
          sessionExerciseId: row, position: 0, reps: 10, completed: true);
      open = (await store.readOpenSession())!;
    });
    await pumpDetail(tester, saved, open: open);

    await tester.ensureVisible(find.byKey(HistorySessionDetailScreen.doAgainKey));
    await tester.tap(find.byKey(HistorySessionDetailScreen.doAgainKey));
    await tester.pumpAndSettle();
    expect(find.byKey(confirmDestructiveKey), findsOneWidget);
    expect(find.text('Replace the workout in progress?'), findsOneWidget);

    await act(tester, () => tester.tap(find.byKey(confirmCancelKey)));
    final still = (await tester.runAsync(() => store.readOpenSession()))!;
    expect(still.id, open.id);
  });

  testWidgets('confirming saves the open workout first, then starts the copy',
      (tester) async {
    final saved = await savePushDay(tester);
    late WorkoutSession open;
    await tester.runAsync(() async {
      final s = await store.createSession();
      final row = await store.addExercise(
          sessionId: s.id, exerciseId: 'dip', loadType: LoadType.weighted);
      await store.writeSet(
          sessionExerciseId: row, position: 0, reps: 10, completed: true);
      open = (await store.readOpenSession())!;
    });
    await pumpDetail(tester, saved, open: open);

    await tester.ensureVisible(find.byKey(HistorySessionDetailScreen.doAgainKey));
    await tester.tap(find.byKey(HistorySessionDetailScreen.doAgainKey));
    await tester.pumpAndSettle();
    await act(tester, () => tester.tap(find.byKey(confirmDestructiveKey)));

    final savedNow = (await tester.runAsync(() => store.readSavedSessions()))!;
    expect(savedNow.map((s) => s.id), contains(open.id),
        reason: 'completed work is never lost to a new start');
    final newOpen = (await tester.runAsync(() => store.readOpenSession()))!;
    expect(newOpen.exercises.map((e) => e.exerciseId), <String>['fly', 'bench']);
  });
}
