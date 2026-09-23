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
import 'package:turtle_lift/src/ui/exercise_picker_screen.dart';

/// The picker both the routine builder and a live workout add exercises
/// through (`adr/0004`).
///
/// **It writes nothing, and that is the design.** It pops with the chosen ids
/// and the caller decides whether they join a routine or a session — which is
/// what lets one screen serve both. A change that made it write directly would
/// pass a naive render test and quietly couple it to one caller.
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

  Exercise entry(
    String id, {
    required String name,
    required String equipment,
    required List<String> primary,
  }) =>
      Exercise(
        id: id,
        name: name,
        equipment: equipment,
        loadType: 'weighted',
        primary: primary,
        secondary: const <String>[],
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
      );

  final index = ExerciseIndex(<Exercise>[
    entry('bench',
        name: 'Barbell bench press',
        equipment: 'Barbell',
        primary: <String>['chest/mid']),
    entry('fly',
        name: 'Cable fly',
        equipment: 'Cable',
        primary: <String>['chest/mid']),
    entry('curl',
        name: 'Barbell curl',
        equipment: 'Barbell',
        primary: <String>['biceps/biceps']),
    entry('row',
        name: 'Cable row',
        equipment: 'Cable',
        primary: <String>['back/lats']),
  ]);

  /// What the picker popped with, readable after the route closes.
  ///
  /// A one-slot box rather than a return value: the pop happens later in the
  /// test than the pump does, so the result cannot be returned from the helper
  /// that opened the screen.
  final popped = <List<String>?>[];

  Future<void> pumpPicker(
    WidgetTester tester, {
    List<String>? groups,
    Future<void> Function(SessionStore store)? history,
  }) async {
    popped.clear();
    late List<WorkoutSession> saved;
    await tester.runAsync(() async {
      if (history != null) await history(store);
      saved = await store.readSavedSessions();
    });

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialActiveSessionProvider.overrideWithValue(null),
          initialSavedSessionsProvider.overrideWithValue(saved),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped.add(await Navigator.of(context).push<List<String>>(
                  MaterialPageRoute<List<String>>(
                    builder: (_) =>
                        ExercisePickerScreen(preselectedGroupIds: groups),
                  ),
                ));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('what it lists', () {
    testWidgets('every exercise, counted', (tester) async {
      await pumpPicker(tester);

      expect(find.text('ALL EXERCISES (4)'), findsOneWidget);
      expect(find.text('Barbell bench press'), findsOneWidget);
      expect(find.text('Cable row'), findsOneWidget);
    });

    testWidgets('search narrows by name', (tester) async {
      await pumpPicker(tester);

      await tester.enterText(
          find.byKey(ExercisePickerScreen.searchKey), 'cable');
      await tester.pump();

      expect(find.text('ALL EXERCISES (2)'), findsOneWidget);
      expect(find.text('Barbell bench press'), findsNothing);
    });

    testWidgets('offers no way to invent an exercise', (tester) async {
      await pumpPicker(tester);

      // `exercises.json` is generated content with reviewed injury-risk copy
      // per entry; a user-typed row would have none of it. See `CLAUDE.md`.
      expect(find.text('Create'), findsNothing);
    });

    testWidgets('recent exercises come from logged sessions, not a stored list',
        (tester) async {
      await pumpPicker(
        tester,
        history: (store) async {
          final session = await store.createSession();
          final rowId = await store.addExercise(
            sessionId: session.id,
            exerciseId: 'row',
            loadType: LoadType.weighted,
          );
          await store.writeSet(
            sessionExerciseId: rowId,
            position: 0,
            completed: true,
            weightKg: 60,
            reps: 10,
          );
          await store.saveOpenSession();
        },
      );

      expect(find.text('RECENT'), findsOneWidget);
      // Listed twice: once under RECENT, once in the full list it still
      // belongs to. Removing it from the list below would make the picker
      // lie about what it contains.
      expect(find.text('Cable row'), findsNWidgets(2));
    });
  });

  group('filtering', () {
    testWidgets('equipment narrows the list and says how far', (tester) async {
      await pumpPicker(tester);

      await tester.tap(find.byKey(ExercisePickerScreen.equipmentFilterKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cable'));
      await tester.pumpAndSettle();

      expect(find.text('Show 2 results'), findsOneWidget);
      await tester.tap(find.text('Show 2 results'));
      await tester.pumpAndSettle();

      expect(find.text('ALL EXERCISES (2)'), findsOneWidget);
      expect(find.text('Barbell curl'), findsNothing);
    });

    testWidgets('a muscle group narrows on primary muscles', (tester) async {
      await pumpPicker(tester);

      await tester.tap(find.byKey(ExercisePickerScreen.muscleFilterKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chest'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Show '));
      await tester.pumpAndSettle();

      expect(find.text('ALL EXERCISES (2)'), findsOneWidget);
      expect(find.text('Cable row'), findsNothing);
    });

    testWidgets('a template opens it already narrowed, and clearable',
        (tester) async {
      // What a template does now: it narrows the picker, it does not lock the
      // session (`adr/0004`).
      await pumpPicker(tester, groups: <String>['biceps']);

      expect(find.text('ALL EXERCISES (1)'), findsOneWidget);
      expect(find.text('Barbell curl'), findsOneWidget);

      await tester.tap(find.byKey(ExercisePickerScreen.muscleFilterKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Show '));
      await tester.pumpAndSettle();

      expect(find.text('ALL EXERCISES (4)'), findsOneWidget);
    });
  });

  group('choosing', () {
    testWidgets('nothing is offered until something is ticked', (tester) async {
      await pumpPicker(tester);

      expect(find.byKey(ExercisePickerScreen.addKey), findsNothing);
    });

    testWidgets('the button counts what is ticked, singular and plural',
        (tester) async {
      await pumpPicker(tester);

      await tester.tap(find.byKey(ExercisePickerScreen.rowKey('bench')));
      await tester.pump();
      expect(find.text('Add 1 exercise'), findsOneWidget);

      await tester.tap(find.byKey(ExercisePickerScreen.rowKey('curl')));
      await tester.pump();
      expect(find.text('Add 2 exercises'), findsOneWidget);
    });

    testWidgets('pops with the ids, in the order they were ticked',
        (tester) async {
      await pumpPicker(tester);

      await tester.tap(find.byKey(ExercisePickerScreen.rowKey('curl')));
      await tester.pump();
      await tester.tap(find.byKey(ExercisePickerScreen.rowKey('bench')));
      await tester.pump();
      await tester.tap(find.byKey(ExercisePickerScreen.addKey));
      await tester.pumpAndSettle();

      // Tick order, not library order: the user is naming a sequence, and the
      // caller writes them into the routine or session in exactly this order.
      expect(popped.single, <String>['curl', 'bench']);
    });

    testWidgets('backing out pops nothing rather than an empty list',
        (tester) async {
      await pumpPicker(tester);

      await tester.tap(find.byKey(ExercisePickerScreen.rowKey('bench')));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Null is "cancelled"; an empty list would be "confirmed with nothing",
      // and a caller that treated them alike would add nothing either way but
      // for the wrong reason.
      expect(popped.single, isNull);
    });

    testWidgets('unticking removes it again', (tester) async {
      await pumpPicker(tester);

      await tester.tap(find.byKey(ExercisePickerScreen.rowKey('bench')));
      await tester.pump();
      await tester.tap(find.byKey(ExercisePickerScreen.rowKey('bench')));
      await tester.pump();

      expect(find.byKey(ExercisePickerScreen.addKey), findsNothing);
    });
  });
}
