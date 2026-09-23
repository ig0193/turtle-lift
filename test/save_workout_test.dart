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
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/save_workout_screen.dart';

/// The step between Finish and the summary (`adr/0004`).
///
/// **Everything on it is optional, and `00` §9 still binds underneath it**: a
/// session with zero completed sets must not save, however the user arrived
/// here. That rule is the one worth a test, because the screen's whole shape
/// invites "the user pressed Save, so save it".
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
      id: 'bench',
      name: 'Barbell bench press',
      equipment: 'Barbell',
      loadType: 'weighted',
      primary: const <String>['chest/mid'],
      secondary: const <String>[],
      setup: '',
      posture: '',
      execution: '',
      commonMistakes: '',
    ),
  ]);

  /// Opens a session; [completed] decides whether a set is actually ticked.
  Future<void> pumpSave(
    WidgetTester tester, {
    bool completed = true,
    bool writeAnything = true,
    String? title,
  }) async {
    late WorkoutSession? open;
    await tester.runAsync(() async {
      final session = await store.createSession(templateName: title);
      final rowId = await store.addExercise(
        sessionId: session.id,
        exerciseId: 'bench',
        loadType: LoadType.weighted,
      );
      if (writeAnything) {
        await store.writeSet(
          sessionExerciseId: rowId,
          position: 0,
          completed: completed,
          weightKg: 60,
          reps: 10,
        );
      }
      open = await store.readOpenSession();
    });

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialActiveSessionProvider.overrideWithValue(open),
          initialSavedSessionsProvider.overrideWithValue(<WorkoutSession>[]),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const SaveWorkoutScreen(),
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
    await tester.pump();
  }

  group('what it offers', () {
    testWidgets('a title, a note, the date and a way out', (tester) async {
      await pumpSave(tester);

      expect(find.byKey(SaveWorkoutScreen.titleKey), findsOneWidget);
      expect(find.byKey(SaveWorkoutScreen.notesKey), findsOneWidget);
      expect(find.byKey(SaveWorkoutScreen.saveKey), findsOneWidget);
      expect(find.byKey(SaveWorkoutScreen.discardKey), findsOneWidget);
    });

    testWidgets('it asks for nothing an account would be needed for',
        (tester) async {
      await pumpSave(tester);

      // Hevy's version of this screen carries all four. Every one of them
      // needs a network or a login, which `CLAUDE.md` rules out.
      expect(find.textContaining('photo'), findsNothing);
      expect(find.textContaining('Gym'), findsNothing);
      expect(find.textContaining('Visibility'), findsNothing);
      expect(find.textContaining('Share'), findsNothing);
    });

    testWidgets('Discard is painted danger, never accent', (tester) async {
      await pumpSave(tester);

      final label = tester.widget<Text>(find.descendant(
        of: find.byKey(SaveWorkoutScreen.discardKey),
        matching: find.byType(Text),
      ));
      expect(label.style?.color, AppPalette.danger);
    });

    testWidgets('it carries the session stats', (tester) async {
      await pumpSave(tester);

      expect(find.text('Sets'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Volume'), findsOneWidget);
      expect(find.text('600 kg'), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('writes the title and the note, and closes the session',
        (tester) async {
      await pumpSave(tester);

      await tester.enterText(
          find.byKey(SaveWorkoutScreen.titleKey), 'Chest day');
      await tester.enterText(
          find.byKey(SaveWorkoutScreen.notesKey), 'Felt strong');
      await act(tester, () async {
        await tester.tap(find.byKey(SaveWorkoutScreen.saveKey));
      });

      final open = await tester.runAsync(store.readOpenSession);
      expect(open, isNull, reason: 'nothing is still running');

      final saved = await tester.runAsync(store.readSavedSessions);
      expect(saved!.single.title, 'Chest day');
      expect(saved.single.notes, 'Felt strong');
    });

    testWidgets('an untouched title stays empty and is resolved on read',
        (tester) async {
      await pumpSave(tester);

      await act(tester, () async {
        await tester.tap(find.byKey(SaveWorkoutScreen.saveKey));
      });

      // Null, not an invented name: the fallback chain in `00` §6 resolves it
      // for display, and storing a guess here would freeze it.
      final saved = await tester.runAsync(store.readSavedSessions);
      expect(saved!.single.title, isNull);
    });

    testWidgets('typed but unticked values are never filed, and are asked about',
        (tester) async {
      await pumpSave(tester, completed: false);

      await tester.tap(find.byKey(SaveWorkoutScreen.saveKey));
      await tester.pumpAndSettle();

      // Work must not vanish on a press the user read as "keep it".
      expect(find.text('Nothing completed'), findsOneWidget);
      await act(tester, () async {
        await tester.tap(find.widgetWithText(TextButton, 'Discard').last);
      });

      // `00` §9. An empty session would count toward the streak.
      expect(await tester.runAsync(store.readSavedSessions), isEmpty);
      expect(await tester.runAsync(store.readOpenSession), isNull);
    });

    testWidgets('backing out of that question keeps the workout open',
        (tester) async {
      await pumpSave(tester, completed: false);

      await tester.tap(find.byKey(SaveWorkoutScreen.saveKey));
      await tester.pumpAndSettle();
      await act(tester, () async {
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      });

      expect(await tester.runAsync(store.readOpenSession), isNotNull);
    });

    testWidgets('a session with nothing written at all is dropped silently',
        (tester) async {
      await pumpSave(tester, completed: false, writeAnything: false);

      await act(tester, () async {
        await tester.tap(find.byKey(SaveWorkoutScreen.saveKey));
      });

      // Nothing was typed, so there is nothing to ask about.
      expect(find.text('Nothing completed'), findsNothing);
      expect(await tester.runAsync(store.readSavedSessions), isEmpty);
      expect(await tester.runAsync(store.readOpenSession), isNull);
    });

    testWidgets('the workout keeps the date it was performed on',
        (tester) async {
      await pumpSave(tester);
      final before = (await tester.runAsync(store.readOpenSession))!.performedOn;

      await act(tester, () async {
        await tester.tap(find.byKey(SaveWorkoutScreen.saveKey));
      });

      final saved = await tester.runAsync(store.readSavedSessions);
      expect(saved!.single.performedOn, before);
    });

    testWidgets('finishing stamps an end, so the duration stops moving',
        (tester) async {
      await pumpSave(tester);

      await act(tester, () async {
        await tester.tap(find.byKey(SaveWorkoutScreen.saveKey));
      });

      final saved = await tester.runAsync(store.readSavedSessions);
      expect(saved!.single.endedAt, isNotNull);
    });
  });

  group('discarding', () {
    testWidgets('asks first, and drops everything on yes', (tester) async {
      await pumpSave(tester);

      await tester.tap(find.byKey(SaveWorkoutScreen.discardKey));
      await tester.pumpAndSettle();
      expect(find.text('Discard workout?'), findsOneWidget);

      await act(tester, () async {
        await tester.tap(find.widgetWithText(TextButton, 'Discard').last);
      });

      expect(await tester.runAsync(store.readOpenSession), isNull);
      expect(await tester.runAsync(store.readSavedSessions), isEmpty);
    });

    testWidgets('backing out of the confirmation keeps the workout',
        (tester) async {
      await pumpSave(tester);

      await tester.tap(find.byKey(SaveWorkoutScreen.discardKey));
      await tester.pumpAndSettle();
      await act(tester, () async {
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      });

      expect(await tester.runAsync(store.readOpenSession), isNotNull);
    });
  });
}
