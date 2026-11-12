import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/custom_exercises.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/session_progress.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/custom_exercise_screens.dart';
import 'package:turtle_lift/src/ui/exercise_picker_sheet.dart';
import 'package:turtle_lift/src/ui/history_session_detail_screen.dart';
import 'package:turtle_lift/src/ui/session_overview_body.dart';
import 'package:turtle_lift/src/ui/set_logging_screen.dart';
import 'package:turtle_lift/src/ui/template_editor_screen.dart';
import 'package:turtle_lift/src/ui/workout_root.dart';

/// Swap in place, notes, and Hide from picker, at widget level
/// (`docs/adr/0011-combined-build-decisions.md`).
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
  late SessionStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = SessionStore(database);
  });
  tearDown(() => database.close());

  Future<void> pump(
    WidgetTester tester, {
    Widget home = const Scaffold(body: WorkoutRoot()),
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
          initialCustomTemplatesProvider
              .overrideWithValue(const <WorkoutTemplate>[]),
          initialCustomExercisesProvider.overrideWithValue(customExercises),
          initialActiveSessionProvider.overrideWithValue(open),
          initialSavedSessionsProvider.overrideWithValue(saved),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: home),
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

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  Future<WorkoutSession> openWith(List<String> ids) =>
      Future<WorkoutSession>(() async {
        await store.createSession(templateId: null, templateName: null);
        final open = (await store.readOpenSession())!;
        for (final id in ids) {
          await store.addExercise(
            sessionId: open.id,
            exerciseId: id,
            loadType: LoadType.fromName(library.byId(id)!.loadType)!,
          );
        }
        return (await store.readOpenSession())!;
      });

  Future<void> startLogging(WidgetTester tester, WorkoutSession open) =>
      act(tester, () async {
        containerOf(tester).read(loggingStartedProvider.notifier).start(open.id);
      });

  Future<void> pickFromSheet(WidgetTester tester, String exerciseId) async {
    await tester.enterText(
        find.descendant(
            of: find.byType(ExercisePickerSheet),
            matching: find.byType(TextField)),
        library.byId(exerciseId)!.name);
    await tester.pump();
    await act(tester, () async {
      await tester.tap(find.byKey(ExercisePickerSheet.rowKey(exerciseId)));
    });
  }

  group('swap in place', () {
    testWidgets('Edit list swaps an untouched exercise at its position',
        (tester) async {
      late WorkoutSession open;
      await tester.runAsync(() async {
        open = await openWith(<String>['barbell-bench-press', 'push-up']);
      });
      await pump(tester, open: open);
      await startLogging(tester, open);

      await tester.tap(find.byKey(SessionOverviewBody.editListKey));
      await tester.pump();
      await tester.tap(find.byKey(sessionSwapKey('barbell-bench-press')));
      await tester.pumpAndSettle();
      expect(find.byType(ExercisePickerSheet), findsOneWidget);
      await pickFromSheet(tester, 'dumbbell-bench-press');

      expect(
        containerOf(tester)
            .read(activeSessionProvider)!
            .exercises
            .map((e) => e.exerciseId),
        <String>['dumbbell-bench-press', 'push-up'],
      );
    });

    testWidgets('an exercise with logged sets is not swapped; Add is offered',
        (tester) async {
      late WorkoutSession open;
      await tester.runAsync(() async {
        open = await openWith(<String>['barbell-bench-press', 'push-up']);
        await store.writeSet(
          sessionExerciseId: open.exercises.first.id,
          position: 0,
          completed: true,
          weightKg: 60,
          reps: 8,
        );
        open = (await store.readOpenSession())!;
      });
      await pump(tester, open: open);
      await startLogging(tester, open);

      await tester.tap(find.byKey(SessionOverviewBody.editListKey));
      await tester.pump();
      await tester.tap(find.byKey(sessionSwapKey('barbell-bench-press')));
      await tester.pumpAndSettle();

      expect(find.byType(ExercisePickerSheet), findsNothing);
      expect(find.text(kSwapRefusedMessage), findsOneWidget);
      expect(find.text('Add instead'), findsOneWidget);

      // A reason, not a question: it times out instead of sitting over
      // Discard workout until dismissed, and its action is readable on the
      // light (inverse) snackbar surface.
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.persist, isFalse);
      expect(bar.action!.textColor, AppPalette.pageBackground);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(kSwapRefusedMessage), findsNothing);
    });

    testWidgets('the template editor swaps a row in place', (tester) async {
      await pump(
        tester,
        home: const TemplateEditorScreen(
          initialName: 'Mine',
          initialExerciseIds: <String>['barbell-curl', 'plank'],
        ),
      );

      await tester.tap(find.byKey(TemplateEditorScreen.swapKey('barbell-curl')));
      await tester.pumpAndSettle();
      await pickFromSheet(tester, 'hammer-curl');

      expect(find.byKey(TemplateEditorScreen.rowKey('hammer-curl')),
          findsOneWidget);
      expect(find.byKey(TemplateEditorScreen.rowKey('barbell-curl')),
          findsNothing);
      final rows = tester
          .widgetList(find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>)
                  .value
                  .startsWith('template-editor-row-')))
          .map((w) => (w.key! as ValueKey<String>).value)
          .toList();
      expect(rows, <String>[
        'template-editor-row-hammer-curl',
        'template-editor-row-plank',
      ]);
    });
  });

  group('notes', () {
    testWidgets('typed in set logging, stored on the exercise',
        (tester) async {
      late WorkoutSession open;
      await tester.runAsync(() async {
        open = await openWith(<String>['leg-press']);
      });
      await pump(
        tester,
        open: open,
        home: SetLoggingScreen(sessionExerciseId: open.exercises.single.id),
      );

      await tester.ensureVisible(find.byKey(SetLoggingScreen.noteKey));
      await tester.enterText(find.byKey(SetLoggingScreen.noteKey), 'Seat 4');
      await act(tester, () async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
      });

      expect(
        containerOf(tester).read(activeSessionProvider)!.exercises.single.note,
        'Seat 4',
      );
    });

    testWidgets('last time\'s note is shown as a hint', (tester) async {
      late WorkoutSession open;
      late List<WorkoutSession> saved;
      await tester.runAsync(() async {
        final past = await openWith(<String>['leg-press']);
        await store.setNote(past.exercises.single.id, 'Seat 5');
        await store.writeSet(
          sessionExerciseId: past.exercises.single.id,
          position: 0,
          completed: true,
          weightKg: 100,
          reps: 10,
        );
        await store.saveOpenSession();
        saved = await store.readSavedSessions();
        open = await openWith(<String>['leg-press']);
      });
      await pump(
        tester,
        open: open,
        saved: saved,
        home: SetLoggingScreen(sessionExerciseId: open.exercises.single.id),
      );

      expect(find.byKey(SetLoggingScreen.lastNoteKey), findsOneWidget);
      expect(find.text('Last time: Seat 5'), findsOneWidget);
    });

    testWidgets('History detail shows the note under the exercise',
        (tester) async {
      late List<WorkoutSession> saved;
      await tester.runAsync(() async {
        final past = await openWith(<String>['leg-press']);
        await store.setNote(past.exercises.single.id, 'Seat 5');
        await store.writeSet(
          sessionExerciseId: past.exercises.single.id,
          position: 0,
          completed: true,
          weightKg: 100,
          reps: 10,
        );
        await store.saveOpenSession();
        saved = await store.readSavedSessions();
      });
      await pump(
        tester,
        saved: saved,
        home: HistorySessionDetailScreen(sessionId: saved.single.id),
      );

      expect(find.text('Seat 5'), findsOneWidget);
    });
  });

  group('hide from picker', () {
    const hackSquat = Exercise(
      id: 'custom-hack',
      name: 'Gym hack squat',
      equipment: 'machine',
      loadType: 'weighted',
      primary: <String>['quads/quads'],
      secondary: <String>[],
      setup: '',
      posture: '',
      execution: '',
      commonMistakes: '',
      isCustom: true,
      hidden: true,
    );

    testWidgets('a hidden exercise is not in the picker', (tester) async {
      await pump(
        tester,
        customExercises: const <Exercise>[hackSquat],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showExercisePicker(context, title: 'Pick'),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(ExercisePickerSheet.rowKey('custom-hack')),
          findsNothing);
    });

    testWidgets('a logged exercise offers Hide from picker, not Delete',
        (tester) async {
      const shown = Exercise(
        id: 'custom-hack',
        name: 'Gym hack squat',
        equipment: 'machine',
        loadType: 'weighted',
        primary: <String>['quads/quads'],
        secondary: <String>[],
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
        isCustom: true,
      );
      await tester.runAsync(() async {
        await CustomExerciseStore(database).upsert(shown);
        await openWith(<String>[]);
        final open = (await store.readOpenSession())!;
        await store.addExercise(
            sessionId: open.id,
            exerciseId: shown.id,
            loadType: LoadType.weighted);
      });
      await pump(
        tester,
        customExercises: const <Exercise>[shown],
        home: const CustomExerciseEditorScreen(existing: shown),
      );
      await act(tester, () async {});

      expect(find.byKey(CustomExerciseEditorScreen.deleteKey), findsNothing);
      await tester.ensureVisible(find.byKey(CustomExerciseEditorScreen.hideKey));
      await act(tester, () async {
        await tester.tap(find.byKey(CustomExerciseEditorScreen.hideKey));
      });

      expect(containerOf(tester).read(customExerciseListProvider).single.hidden,
          isTrue);
      expect(find.text('Show in picker'), findsOneWidget);
    });
  });
}
