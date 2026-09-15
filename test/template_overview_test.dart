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
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/template_overview_body.dart';

/// Proves the template path's muscle list.
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

  final index = ExerciseIndex(<Exercise>[
    Exercise(
      id: 'incline-press',
      name: 'Incline dumbbell press',
      equipment: 'dumbbell',
      loadType: 'weighted',
      primary: const <String>['chest/upper'],
      secondary: const <String>['triceps/triceps'],
      setup: '',
      posture: '',
      execution: '',
      commonMistakes: '',
    ),
  ]);

  Future<WorkoutSession> openTemplate(
    WidgetTester tester,
    List<String> groupIds,
  ) async {
    late WorkoutSession session;
    await tester.runAsync(() async {
      session = await store.createSession(
        templateId: 'tpl',
        templateName: 'Chest and triceps day',
        groupIds: groupIds,
      );
    });
    return session;
  }

  Future<void> pump(WidgetTester tester, WorkoutSession session) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialActiveSessionProvider.overrideWithValue(session),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: TemplateOverviewBody(onFinished: (_) {})),
        ),
      ),
    );
    await tester.pump();
  }

  group('the muscle list', () {
    testWidgets('names every sub-group of a multi-group parent',
        (tester) async {
      final session = await openTemplate(tester, <String>['chest', 'triceps']);

      await pump(tester, session);

      // The taxonomy stores bare sub-group names against a parent; the labels
      // live under full `group/sub` ids. Composing the id wrong renders the
      // raw name and silently breaks every tick, which is what this pins.
      expect(find.text('Upper chest'), findsOneWidget);
      expect(find.text('Mid chest'), findsOneWidget);
      expect(find.text('Lower chest'), findsOneWidget);
      expect(find.text('upper'), findsNothing);
    });

    testWidgets('renders a single-sub-group parent as one flat row',
        (tester) async {
      final session = await openTemplate(tester, <String>['biceps', 'triceps']);

      await pump(tester, session);

      expect(find.text('Biceps'), findsOneWidget);
      expect(find.text('Triceps'), findsOneWidget);
      expect(
        find.byKey(groupHeaderKey('biceps')),
        findsNothing,
        reason: 'an accordion hiding one identical child is a tap that buys '
            'nothing',
      );
    });

    testWidgets('gives a multi-group parent an accordion header',
        (tester) async {
      final session = await openTemplate(tester, <String>['chest']);

      await pump(tester, session);

      expect(find.byKey(groupHeaderKey('chest')), findsOneWidget);
    });

    testWidgets('collapses and reopens on the header', (tester) async {
      final session = await openTemplate(tester, <String>['chest']);
      await pump(tester, session);

      expect(find.text('Upper chest'), findsOneWidget);

      await tester.tap(find.byKey(groupHeaderKey('chest')));
      await tester.pumpAndSettle();
      expect(find.text('Upper chest'), findsNothing);

      await tester.tap(find.byKey(groupHeaderKey('chest')));
      await tester.pumpAndSettle();
      expect(find.text('Upper chest'), findsOneWidget);
    });

    testWidgets('side delt gets its own row on a shoulders day',
        (tester) async {
      final session = await openTemplate(tester, <String>['shoulders']);

      await pump(tester, session);

      expect(
        find.text('Side delt'),
        findsOneWidget,
        reason: 'it shares the front-delt artwork on the map, but the list is '
            'driven by the taxonomy and only the map has that exception',
      );
    });
  });

  group('the trained tick', () {
    testWidgets('appears on the muscle a logged lift trains directly',
        (tester) async {
      var session = await openTemplate(tester, <String>['chest', 'triceps']);
      await tester.runAsync(() async {
        final row = await store.addExercise(
          sessionId: session.id,
          exerciseId: 'incline-press',
          loadType: LoadType.weighted,
        );
        await store.writeSet(
            sessionExerciseId: row,
            position: 0,
            weightKg: 24,
            reps: 10,
            completed: true);
        session = (await store.readOpenSession())!;
      });

      await pump(tester, session);

      expect(find.byKey(trainedTickKey('chest/upper')), findsOneWidget);
      expect(
        find.byKey(trainedTickKey('triceps/triceps')),
        findsNothing,
        reason: 'an incline press is not a triceps movement, so the triceps '
            'row stays unticked even though the map fills it',
      );
      expect(find.byKey(trainedTickKey('chest/mid')), findsNothing);
    });

    testWidgets('a ticked row is still tappable', (tester) async {
      var session = await openTemplate(tester, <String>['chest']);
      await tester.runAsync(() async {
        final row = await store.addExercise(
          sessionId: session.id,
          exerciseId: 'incline-press',
          loadType: LoadType.weighted,
        );
        await store.writeSet(
            sessionExerciseId: row,
            position: 0,
            weightKg: 24,
            reps: 10,
            completed: true);
        session = (await store.readOpenSession())!;
      });

      await pump(tester, session);

      await tester.tap(find.byKey(subGroupTileKey('chest/upper')));
      await tester.pumpAndSettle();

      expect(
        find.text('Upper chest'),
        findsWidgets,
        reason: 'this is the only route back in to add a fourth set or fix a '
            'mistyped weight',
      );
    });
  });
}
