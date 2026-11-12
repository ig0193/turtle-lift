import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/custom_exercises.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/session_progress.dart';
import 'package:turtle_lift/src/ui/custom_exercise_screens.dart';
import 'package:turtle_lift/src/ui/exercise_detail_screen.dart';
import 'package:turtle_lift/src/ui/exercise_picker_sheet.dart';
import 'package:turtle_lift/src/ui/session_overview_body.dart';
import 'package:turtle_lift/src/ui/set_logging_screen.dart';
import 'package:turtle_lift/src/ui/template_editor_screen.dart';
import 'package:turtle_lift/src/ui/template_library_screen.dart';
import 'package:turtle_lift/src/ui/template_preview_sheet.dart';
import 'package:turtle_lift/src/ui/workout_root.dart';

/// The workout-gaps pass (`docs/research/workout-tab-functional-audit.md`):
/// templates from scratch, custom exercises, editing, live reorder, and the
/// bugs the audit found, at widget level.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseIndex library;

  setUpAll(() async {
    final boot = ProviderContainer();
    addTearDown(boot.dispose);
    library = ExerciseIndex.fromJson(
      await boot.read(exerciseLibraryProvider.future),
    );
  });

  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> pump(
    WidgetTester tester, {
    Widget home = const Scaffold(body: WorkoutRoot()),
    List<WorkoutTemplate> custom = const <WorkoutTemplate>[],
    List<Exercise> customExercises = const <Exercise>[],
    WorkoutSession? open,
    List<WorkoutSession> saved = const <WorkoutSession>[],
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          libraryIndexProvider.overrideWithValue(library),
          initialCustomTemplatesProvider.overrideWithValue(custom),
          initialCustomExercisesProvider.overrideWithValue(customExercises),
          initialActiveSessionProvider.overrideWithValue(open),
          initialSavedSessionsProvider.overrideWithValue(saved),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: home),
      ),
    );
    await tester.pump();
  }

  const mine = WorkoutTemplate(
    id: 'my-arms',
    name: 'My arm blaster',
    exerciseIds: <String>['barbell-curl', 'cable-rope-pushdown'],
    isPredefined: false,
  );

  group('audit bugs', () {
    // The My templates rail was a lazy horizontal ListView, and its tiles
    // never reached the accessibility tree: VoiceOver (and Maestro) could not
    // find or open the user's own templates.
    testWidgets('a My templates tile is reachable by its label',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, custom: const <WorkoutTemplate>[mine]);

      expect(
        find.bySemanticsLabel(RegExp(r'^My arm blaster\. ')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) => act(tester, () async {});

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  const hackSquat = Exercise(
    id: 'custom-hack',
    name: 'Gym hack squat',
    equipment: 'machine',
    loadType: 'weighted',
    primary: <String>['quads/quads'],
    secondary: <String>['glutes/glutes'],
    setup: '',
    posture: '',
    execution: '',
    commonMistakes: '',
    isCustom: true,
  );

  group('a template from scratch', () {
    testWidgets('name, pick two, reorder, save: the list keeps that order',
        (tester) async {
      await pump(tester, home: const TemplateLibraryScreen());

      await tester.tap(find.byKey(TemplateLibraryScreen.newTemplateKey));
      await settle(tester);
      expect(find.text('New template'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, 'Monday upper');
      await tester.tap(find.byKey(TemplateEditorScreen.addKey));
      await settle(tester);

      await tester.enterText(
          find.descendant(
              of: find.byType(ExercisePickerSheet),
              matching: find.byType(TextField)),
          'bench press');
      await tester.pump();
      await tester
          .tap(find.byKey(ExercisePickerSheet.rowKey('barbell-bench-press')));
      await tester.pump();
      await tester.enterText(
          find.descendant(
              of: find.byType(ExercisePickerSheet),
              matching: find.byType(TextField)),
          'push-up');
      await tester.pump();
      await tester.tap(find.byKey(ExercisePickerSheet.rowKey('push-up')));
      await tester.pump();
      expect(find.text('Add 2 exercises'), findsOneWidget);
      await tester.tap(find.byKey(ExercisePickerSheet.addSelectedKey));
      await settle(tester);

      expect(find.byKey(TemplateEditorScreen.rowKey('barbell-bench-press')),
          findsOneWidget);
      await tester
          .tap(find.byKey(TemplateEditorScreen.moveDownKey('barbell-bench-press')));
      await tester.pump();

      await act(tester,
          () async => tester.tap(find.byKey(TemplateEditorScreen.saveKey)));

      final saved = containerOf(tester).read(customTemplatesProvider).single;
      expect(saved.name, 'Monday upper');
      expect(saved.exerciseIds, <String>['push-up', 'barbell-bench-press']);
      // Back on the library, the new row is there and opens the editor.
      expect(find.byKey(TemplateLibraryScreen.rowKey(saved.id)), findsOneWidget);
    });

    testWidgets('save is refused with no name or no exercises', (tester) async {
      await pump(tester, home: const TemplateEditorScreen());
      await tester.tap(find.byKey(TemplateEditorScreen.saveKey));
      await tester.pump();
      expect(find.text('Give the template a name.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Empty');
      await tester.tap(find.byKey(TemplateEditorScreen.saveKey));
      await tester.pump();
      expect(find.text('Add at least one exercise.'), findsOneWidget);
    });

    testWidgets('editing a custom template removes an exercise and deletes',
        (tester) async {
      await pump(tester,
          home: const TemplateEditorScreen(existing: mine),
          custom: const <WorkoutTemplate>[mine]);
      await tester.tap(find.byKey(TemplateEditorScreen.removeKey('barbell-curl')));
      await tester.pump();
      await act(tester,
          () async => tester.tap(find.byKey(TemplateEditorScreen.saveKey)));
      // The store's row was never written (seeded in memory), so read memory.
      expect(
        containerOf(tester).read(customTemplatesProvider).single.exerciseIds,
        <String>['cable-rope-pushdown'],
      );
    });

    testWidgets('the preview offers Edit on your own template only',
        (tester) async {
      await pump(tester, custom: const <WorkoutTemplate>[mine]);
      await tester.tap(find.byKey(WorkoutLandingBody.templateKey('my-arms')));
      await tester.pumpAndSettle();
      expect(find.byKey(TemplatePreviewSheet.editKey), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // A user with a template of their own sees Ready-made folded.
      await tester.tap(find.byKey(WorkoutLandingBody.readyMadeToggleKey));
      await tester.pump();
      await tester.tap(find.byKey(WorkoutLandingBody.templateKey('push')));
      await tester.pumpAndSettle();
      expect(find.byKey(TemplatePreviewSheet.editKey), findsNothing);
    });
  });

  group('custom exercises', () {
    testWidgets('created from the picker, it goes straight to logging',
        (tester) async {
      await pump(tester);
      await act(tester, () async {
        await tester.tap(find.byKey(WorkoutLandingBody.startWorkoutKey));
      });
      await tester.tap(find.byKey(SessionOverviewBody.startLoggingKey));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.descendant(
              of: find.byType(ExercisePickerSheet),
              matching: find.byType(TextField)),
          'Hack squat machine');
      await tester.pump();
      expect(find.text('Create “Hack squat machine”'), findsOneWidget);
      await tester.tap(find.byKey(ExercisePickerSheet.createKey));
      await tester.pumpAndSettle();

      // The name is prefilled from the search; pick a main muscle and save.
      expect(find.text('Hack squat machine'), findsWidgets);
      await tester
          .ensureVisible(find.byKey(CustomExerciseEditorScreen.primaryKey('quads/quads')));
      await tester
          .tap(find.byKey(CustomExerciseEditorScreen.primaryKey('quads/quads')));
      await tester.pump();
      await act(tester, () async {
        await tester.tap(find.byKey(CustomExerciseEditorScreen.saveKey));
      });
      await settle(tester);

      expect(find.byType(SetLoggingScreen), findsOneWidget,
          reason: 'no form guide exists, so no first-time detour');
      final container = containerOf(tester);
      final made = container.read(customExerciseListProvider).single;
      expect(made.id, startsWith('custom-'));
      expect(container.read(activeSessionProvider)!.exercises.single.exerciseId,
          made.id);
    });

    testWidgets('the editor refuses a save with no main muscle',
        (tester) async {
      await pump(tester, home: const CustomExerciseEditorScreen());
      await tester.enterText(find.byType(TextField).first, 'Ring dips');
      await tester.tap(find.byKey(CustomExerciseEditorScreen.saveKey));
      await tester.pump();
      expect(find.text('Pick at least one main muscle.'), findsOneWidget);
    });

    testWidgets('its page says there is no form guide, and shows no content',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester,
          customExercises: const <Exercise>[hackSquat],
          home: const CustomExerciseScreen(exerciseId: 'custom-hack'));

      expect(find.byKey(CustomExerciseScreen.noteKey), findsOneWidget);
      expect(find.text(kCustomExerciseNote), findsOneWidget);
      for (final label in <String>[
        'Common mistakes',
        'Setup',
        'Posture',
        'Execution',
      ]) {
        expect(find.text(label), findsNothing, reason: label);
      }
      expect(find.text('Primary muscle: Quads'), findsNothing);
      expect(find.bySemanticsLabel('Primary muscle: Quads'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('pushExerciseDetail sends a custom exercise to its own page',
        (tester) async {
      await pump(
        tester,
        customExercises: const <Exercise>[hackSquat],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => pushExerciseDetail(context, hackSquat),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomExerciseScreen), findsOneWidget);
      expect(find.byType(ExerciseDetailScreen), findsNothing);
    });

    testWidgets('the picker lists your exercises under their own heading',
        (tester) async {
      await pump(
        tester,
        customExercises: const <Exercise>[hackSquat],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showExercisePicker(context, title: 'Pick'),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Your exercises'), findsOneWidget);
      expect(find.byKey(ExercisePickerSheet.rowKey('custom-hack')),
          findsOneWidget);
    });

    testWidgets('picker search matches a muscle, not only a name',
        (tester) async {
      await pump(
        tester,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showExercisePicker(context, title: 'Pick'),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'hamstrings');
      await tester.pump();
      expect(find.textContaining('No exercise called'), findsNothing);
      expect(find.byKey(ExercisePickerSheet.rowKey('barbell-romanian-deadlift')),
          findsOneWidget);
    });
  });

  group('audit bugs, live', () {
    // Start logging on a template workout opened the picker, but the ready
    // view that asked for it was gone by the time the user chose, so the
    // choice was silently dropped: nothing opened and nothing was added.
    testWidgets('a template workout: Start logging, pick, and it opens',
        (tester) async {
      await pump(tester, customExercises: const <Exercise>[hackSquat]);
      await act(tester, () async {
        await containerOf(tester)
            .read(activeSessionProvider.notifier)
            .startFromTemplate(
          templateId: 'push',
          templateName: 'Push day',
          exerciseIds: <String>['push-up'],
        );
      });
      await tester.tap(find.byKey(SessionOverviewBody.startLoggingKey));
      await tester.pumpAndSettle();
      await act(tester, () async {
        await tester.tap(find.byKey(ExercisePickerSheet.rowKey('custom-hack')));
      });
      await settle(tester);
      await settle(tester);

      expect(find.byType(SetLoggingScreen), findsOneWidget);
      expect(
        containerOf(tester)
            .read(activeSessionProvider)!
            .exercises
            .map((e) => e.exerciseId),
        <String>['push-up', 'custom-hack'],
      );
    });
  });

  group('the live list', () {
    testWidgets('Edit list moves a row and removes one', (tester) async {
      await pump(tester);
      await act(tester, () async {
        await containerOf(tester)
            .read(activeSessionProvider.notifier)
            .startFromTemplate(
          templateId: 'push',
          templateName: 'Push day',
          exerciseIds: <String>['barbell-bench-press', 'push-up', 'plank'],
        );
        final container = containerOf(tester);
        final id = container.read(activeSessionProvider)!.id;
        container.read(loggingStartedProvider.notifier).start(id);
      });

      await tester.tap(find.byKey(SessionOverviewBody.editListKey));
      await tester.pump();
      await act(tester, () async {
        await tester.tap(find.byKey(sessionMoveDownKey('barbell-bench-press')));
      });
      await act(tester, () async {
        await tester.tap(find.byKey(sessionRemoveKey('plank')));
      });

      expect(
        containerOf(tester)
            .read(activeSessionProvider)!
            .exercises
            .map((e) => e.exerciseId),
        <String>['push-up', 'barbell-bench-press'],
      );
      expect(LoadType.weighted, isNotNull);
    });
  });
}
