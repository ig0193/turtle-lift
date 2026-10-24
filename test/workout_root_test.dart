import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/exercise_detail_screen.dart';
import 'package:turtle_lift/src/ui/set_logging_screen.dart';
import 'package:turtle_lift/src/ui/session_overview_body.dart';
import 'package:turtle_lift/src/ui/template_library_screen.dart';
import 'package:turtle_lift/src/ui/template_preview_sheet.dart';
import 'package:turtle_lift/src/ui/workout_root.dart';

/// The Workout landing: what it lists, how search works, and what starting a
/// workout does.
///
/// `test/tab_roots_test.dart` owns this root's geometry — the clearance, the
/// scrollable and the safe-area inset it shares with the other roots. This file
/// owns its behaviour.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // `exerciseLibraryProvider` reaches `rootBundle`, which needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseIndex index;

  setUpAll(() async {
    final boot = ProviderContainer();
    addTearDown(boot.dispose);
    index = ExerciseIndex.fromJson(
      await boot.read(exerciseLibraryProvider.future),
    );
  });

  late AppDatabase database;
  late SessionStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = SessionStore(database);
  });
  tearDown(() => database.close());

  /// Hosts the root as the shell does, over a real in-memory database.
  Future<void> pumpRoot(
    WidgetTester tester, {
    List<WorkoutTemplate> custom = const <WorkoutTemplate>[],
    WorkoutSession? open,
    List<WorkoutSession> saved = const <WorkoutSession>[],
  }) async {
    // Tall enough that the whole tile grid is on screen, so a test taps what
    // it means to rather than first scrolling to it.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialCustomTemplatesProvider.overrideWithValue(custom),
          initialActiveSessionProvider.overrideWithValue(open),
          initialSavedSessionsProvider.overrideWithValue(saved),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: WorkoutRoot()),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
  }

  final mine = <WorkoutTemplate>[
    const WorkoutTemplate(
      id: 'my-arms',
      name: 'My arm blaster',
      exerciseIds: <String>['barbell-curl', 'cable-rope-pushdown'],
      isPredefined: false,
    ),
  ];

  group('what it lists', () {
    testWidgets('every template that ships, as one flat list', (tester) async {
      await pumpRoot(tester);

      for (final template in kPredefinedTemplates) {
        expect(
          find.byKey(WorkoutLandingBody.templateKey(template.id)),
          findsOneWidget,
          reason: template.name,
        );
      }
      expect(find.text(WorkoutLandingBody.predefinedGroupLabel), findsOneWidget);
    });

    testWidgets('has no split filter', (tester) async {
      await pumpRoot(tester);

      for (final label in const <String>[
        'Multi Split',
        'Push-Pull-Legs',
        '1 Muscle per day',
      ]) {
        expect(find.text(label), findsNothing,
            reason: 'the split filter was dropped (docs/adr/0006)');
      }
    });

    testWidgets('shows what each template trains and how many exercises it has',
        (tester) async {
      await pumpRoot(tester);

      expect(find.text('Chest, shoulders, triceps'), findsOneWidget,
          reason: 'Push day, derived from its exercises');
      expect(find.text('6 exercises'), findsWidgets);
      expect(find.text('A mix across all major groups'), findsOneWidget,
          reason: 'Full body day carries its own line');
    });

    testWidgets('renders no empty state', (tester) async {
      await pumpRoot(tester);

      expect(find.byKey(WorkoutLandingBody.templateKey('push')), findsOneWidget,
          reason: 'eleven templates ship, so day one has content');
    });
  });

  group('the user\'s own templates', () {
    testWidgets('are absent entirely when there are none', (tester) async {
      await pumpRoot(tester);

      expect(find.text(WorkoutLandingBody.customGroupLabel), findsNothing,
          reason: 'a heading standing over nothing reads as broken');
    });

    testWidgets('appear above the ready-made ones when there are some',
        (tester) async {
      await pumpRoot(tester, custom: mine);

      expect(find.text(WorkoutLandingBody.customGroupLabel), findsOneWidget);
      expect(
        find.byKey(WorkoutLandingBody.templateKey('my-arms')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text(WorkoutLandingBody.customGroupLabel)).dy,
        lessThan(
          tester.getTopLeft(find.text(WorkoutLandingBody.predefinedGroupLabel)).dy,
        ),
        reason: 'what the user made is what they run most, so it leads',
      );
    });

    testWidgets('show the muscles their exercises train', (tester) async {
      await pumpRoot(tester, custom: mine);

      expect(find.text('Biceps, triceps'), findsWidgets);
    });
  });

  group('search', () {
    testWidgets('finds templates by name', (tester) async {
      await pumpRoot(tester);

      await tester.enterText(find.byType(TextField), 'chest and');
      await tester.pump();

      expect(find.byKey(WorkoutLandingBody.templateKey('chest-triceps')),
          findsOneWidget);
      expect(find.byKey(WorkoutLandingBody.templateKey('leg')), findsNothing);
    });

    testWidgets('finds your own templates too', (tester) async {
      await pumpRoot(tester, custom: mine);

      await tester.enterText(find.byType(TextField), 'blaster');
      await tester.pump();

      expect(find.byKey(WorkoutLandingBody.templateKey('my-arms')),
          findsOneWidget);
    });

    testWidgets('finds exercises by name, below the templates', (tester) async {
      await pumpRoot(tester);

      await tester.enterText(find.byType(TextField), 'push');
      await tester.pump();

      expect(find.byKey(WorkoutLandingBody.templateKey('push')), findsOneWidget);
      expect(find.byKey(WorkoutLandingBody.exerciseResultKey('push-up')),
          findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(WorkoutLandingBody.templateKey('push'))).dy,
        lessThan(tester
            .getTopLeft(find.byKey(WorkoutLandingBody.exerciseResultKey('push-up')))
            .dy),
      );
    });

    testWidgets('says so when nothing matches', (tester) async {
      await pumpRoot(tester);

      await tester.enterText(find.byType(TextField), 'zzzzzz');
      await tester.pump();

      expect(find.text('Nothing matches that name.'), findsOneWidget);
    });

    testWidgets('clearing it brings the lists back', (tester) async {
      await pumpRoot(tester);
      await tester.enterText(find.byType(TextField), 'push');
      await tester.pump();

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(find.text(WorkoutLandingBody.predefinedGroupLabel), findsOneWidget);
    });

    testWidgets('an exercise result starts an ad-hoc workout', (tester) async {
      await pumpRoot(tester);
      await tester.enterText(find.byType(TextField), 'push-up');
      await tester.pump();

      await act(tester, () async {
        await tester
            .tap(find.byKey(WorkoutLandingBody.exerciseResultKey('push-up')));
      });

      final open = await tester.runAsync(() => store.readOpenSession());
      expect(open, isNotNull);
      expect(open!.templateId, isNull, reason: 'it is an ad-hoc workout');
      expect(find.byType(ExerciseDetailScreen), findsOneWidget,
          reason: 'the user has never done a push-up, so its page comes first');
    });

    testWidgets('and goes straight to logging for an exercise already done',
        (tester) async {
      late List<WorkoutSession> saved;
      await tester.runAsync(() async {
        final past = await store.createSession();
        final row = await store.addExercise(
          sessionId: past.id,
          exerciseId: 'push-up',
          loadType: LoadType.bodyweight,
        );
        await store.writeSet(
            sessionExerciseId: row, position: 0, reps: 12, completed: true);
        await store.saveOpenSession();
        saved = await store.readSavedSessions();
      });
      await pumpRoot(tester, saved: saved);
      await tester.enterText(find.byType(TextField), 'push-up');
      await tester.pump();

      await act(tester, () async {
        await tester
            .tap(find.byKey(WorkoutLandingBody.exerciseResultKey('push-up')));
      });

      final open = await tester.runAsync(() => store.readOpenSession());
      expect(open!.exercises.map((e) => e.exerciseId), <String>['push-up']);
      expect(find.byType(SetLoggingScreen), findsOneWidget);
    });
  });

  group('starting a workout from the bar', () {
    testWidgets('is always on screen, whatever has been scrolled to',
        (tester) async {
      await pumpRoot(tester);

      expect(find.byKey(WorkoutLandingBody.startWorkoutKey), findsOneWidget);
      expect(find.text('Add exercises as you go'), findsOneWidget);
    });

    testWidgets('starts an empty workout in place', (tester) async {
      await pumpRoot(tester);

      await act(tester, () async {
        await tester.tap(find.byKey(WorkoutLandingBody.startWorkoutKey));
      });

      final open = await tester.runAsync(() => store.readOpenSession());
      expect(open, isNotNull);
      expect(open!.templateId, isNull);
      expect(open.title, isNull);
      expect(open.exercises, isEmpty);
      expect(find.byType(SessionOverviewBody), findsOneWidget,
          reason: 'the landing is replaced, not covered');
      expect(find.byKey(SessionOverviewBody.startLoggingKey), findsOneWidget,
          reason: 'it opens on the ready view');
    });
  });

  group('starting a template', () {
    testWidgets('a tile previews the exercises before anything starts',
        (tester) async {
      await pumpRoot(tester);

      await tester.tap(find.byKey(WorkoutLandingBody.templateKey('chest')));
      await tester.pumpAndSettle();

      expect(find.byKey(TemplatePreviewSheet.startKey), findsOneWidget);
      expect(find.byKey(TemplatePreviewSheet.rowKey(0)), findsOneWidget);
      expect(find.text('Barbell bench press'), findsOneWidget);
      final count = await tester.runAsync(() => store.sessionCount());
      expect(count, 0, reason: 'looking at a template starts nothing');
    });

    testWidgets('cancelling the preview starts nothing', (tester) async {
      await pumpRoot(tester);
      await tester.tap(find.byKey(WorkoutLandingBody.templateKey('chest')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final count = await tester.runAsync(() => store.sessionCount());
      expect(count, 0);
      expect(find.byType(SessionOverviewBody), findsNothing);
    });

    testWidgets('starting it copies its exercises into the workout',
        (tester) async {
      await pumpRoot(tester);
      await tester.tap(find.byKey(WorkoutLandingBody.templateKey('chest')));
      await tester.pumpAndSettle();

      await act(tester, () async {
        await tester.tap(find.byKey(TemplatePreviewSheet.startKey));
      });

      final open = await tester.runAsync(() => store.readOpenSession());
      final chest =
          kPredefinedTemplates.firstWhere((t) => t.id == 'chest');
      expect(open!.templateId, 'chest');
      expect(open.title, 'Chest day');
      expect(open.exercises.map((e) => e.exerciseId), chest.exerciseIds);
      expect(find.byType(SessionOverviewBody), findsOneWidget);
      expect(find.text('5 exercises planned'), findsOneWidget);
    });

    testWidgets('your own template starts the same way', (tester) async {
      await pumpRoot(tester, custom: mine);
      await tester.tap(find.byKey(WorkoutLandingBody.templateKey('my-arms')));
      await tester.pumpAndSettle();

      await act(tester, () async {
        await tester.tap(find.byKey(TemplatePreviewSheet.startKey));
      });

      final open = await tester.runAsync(() => store.readOpenSession());
      expect(open!.templateId, 'my-arms');
      expect(open.exercises.map((e) => e.exerciseId),
          <String>['barbell-curl', 'cable-rope-pushdown']);
    });
  });

  group('starting while one is already open', () {
    /// An open workout with one completed set, handed to the app as the session
    /// it launched with.
    Future<WorkoutSession> openWithWork(WidgetTester tester) async {
      late WorkoutSession open;
      await tester.runAsync(() async {
        open = await store.createSession(templateName: 'Old day');
        final row = await store.addExercise(
          sessionId: open.id,
          exerciseId: 'barbell-bench-press',
          loadType: LoadType.weighted,
        );
        await store.writeSet(
          sessionExerciseId: row,
          position: 0,
          weightKg: 60,
          reps: 8,
          completed: true,
        );
        open = (await store.readOpenSession())!;
      });
      return open;
    }

    testWidgets('saves the old one when it has a completed set, and says so',
        (tester) async {
      final open = await openWithWork(tester);

      // The landing is what an open workout's header pushes; host it directly,
      // with the old workout still open underneath it.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            exerciseIndexProvider.overrideWithValue(index),
            initialActiveSessionProvider.overrideWithValue(open),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const AppScreen.pushed(
              title: 'Browse',
              body: WorkoutLandingBody(isPushed: true),
            ),
          ),
        ),
      );

      await act(tester, () async {
        await tester.tap(find.byKey(WorkoutLandingBody.startWorkoutKey));
      });

      expect(find.text('Old day saved'), findsOneWidget);
      final saved = await tester.runAsync(() => store.readSavedSessions());
      expect(saved, hasLength(1),
          reason: 'work is never lost to starting something else');
      final now = await tester.runAsync(() => store.readOpenSession());
      expect(now, isNotNull);
      expect(now!.id, isNot(open.id));
    });

    testWidgets('drops the old one silently when nothing was completed',
        (tester) async {
      late WorkoutSession open;
      await tester.runAsync(() async {
        open = await store.createSession(templateName: 'Empty day');
      });

      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            exerciseIndexProvider.overrideWithValue(index),
            initialActiveSessionProvider.overrideWithValue(open),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const AppScreen.pushed(
              title: 'Browse',
              body: WorkoutLandingBody(isPushed: true),
            ),
          ),
        ),
      );

      await act(tester, () async {
        await tester.tap(find.byKey(WorkoutLandingBody.startWorkoutKey));
      });

      final saved = await tester.runAsync(() => store.readSavedSessions());
      expect(saved, isEmpty,
          reason: 'an empty session would count toward the streak');
      expect(find.textContaining('saved'), findsNothing);
    });
  });

  testWidgets('manage templates opens the template library', (tester) async {
    await pumpRoot(tester);

    await tester.ensureVisible(find.byKey(WorkoutRoot.manageTemplatesKey));
    await tester.tap(find.byKey(WorkoutRoot.manageTemplatesKey));
    await tester.pumpAndSettle();

    expect(find.byType(TemplateLibraryScreen), findsOneWidget);
  });

  testWidgets('the pinned header does not move when the landing scrolls',
      (tester) async {
    // The app-wide contract, re-asserted against this body specifically --
    // this root is the one most likely to grow a header-shaped thing inside
    // its own scroll view.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [exerciseIndexProvider.overrideWithValue(index)],
        child: MaterialApp(
          home: AppScreen.root(
            title: 'Workout',
            body: const WorkoutRoot(),
          ),
        ),
      ),
    );

    final before = tester.getRect(find.text('Workout'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pump();

    expect(tester.getRect(find.text('Workout')), before);
  });
}
