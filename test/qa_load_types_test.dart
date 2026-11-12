import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/personal_best.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/set_logging_screen.dart';
import 'package:turtle_lift/src/ui/set_row.dart';

/// QA: every load type logged through the real set-logging screen, against
/// the shipped exercise library and a real (in-memory) database, and the
/// assisted record read the right way round once the workout is saved.
///
/// `set_logging_test.dart` proves the screen's mechanics on weighted and
/// bodyweight; this proves each type's fields land in the right column, which
/// is where an assisted set stored as `addedKg` would silently invert a record.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseIndex index;
  late AppDatabase database;
  late SessionStore store;

  setUpAll(() async {
    final boot = ProviderContainer();
    addTearDown(boot.dispose);
    index = ExerciseIndex.fromJson(
      await boot.read(exerciseLibraryProvider.future),
    );
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = SessionStore(database);
  });
  tearDown(() => database.close());

  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }

  /// Saves one past workout holding a single completed set of [exerciseId].
  Future<void> savePast(
    WidgetTester tester, {
    required String exerciseId,
    required LoadType loadType,
    required int daysAgo,
    double? weightKg,
    int? reps,
    double? addedKg,
    double? assistKg,
    int? durationSec,
  }) async {
    await tester.runAsync(() async {
      final past = await store.createSession(
        performedOn: LocalDate.today().addDays(-daysAgo),
      );
      final row = await store.addExercise(
        sessionId: past.id,
        exerciseId: exerciseId,
        loadType: loadType,
      );
      await store.writeSet(
        sessionExerciseId: row,
        position: 0,
        completed: true,
        weightKg: weightKg,
        reps: reps,
        addedKg: addedKg,
        assistKg: assistKg,
        durationSec: durationSec,
      );
      await store.saveOpenSession();
    });
  }

  /// Opens a workout today with [exerciseId] and pumps its logging screen.
  Future<void> pumpLogging(
    WidgetTester tester, {
    required String exerciseId,
  }) async {
    final loadType = LoadType.fromName(index.byId(exerciseId)!.loadType)!;
    late String rowId;
    late WorkoutSession? open;
    late List<WorkoutSession> saved;
    await tester.runAsync(() async {
      final session = await store.createSession();
      rowId = await store.addExercise(
        sessionId: session.id,
        exerciseId: exerciseId,
        loadType: loadType,
      );
      open = await store.readOpenSession();
      saved = await store.readSavedSessions();
    });
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exerciseIndexProvider.overrideWithValue(index),
          initialActiveSessionProvider.overrideWithValue(open),
          initialSavedSessionsProvider.overrideWithValue(saved),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: SetLoggingScreen(sessionExerciseId: rowId),
        ),
      ),
    );
    await tester.pump();
  }

  // The set row's number fields; the note field below Add set is not one.
  Finder numberFields() => find.byWidgetPredicate(
      (w) => w is TextField && w.key != SetLoggingScreen.noteKey);
  Finder field(int i) => numberFields().at(i);

  Future<SetEntry> onlySet(WidgetTester tester) async {
    final open = await tester.runAsync(() => store.readOpenSession());
    return open!.exercises.single.sets.single;
  }

  Future<void> tapAddWeight(WidgetTester tester) async {
    final chip = find.bySemanticsLabel('Add weight');
    expect(chip, findsOneWidget, reason: 'the optional weight is collapsed');
    await tester.tap(chip);
    await tester.pump();
  }

  group('each load type stores its own fields', () {
    testWidgets('weighted: kg and reps', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpLogging(tester, exerciseId: 'barbell-bench-press');
      expect(find.text('Weight × reps'), findsOneWidget);

      await act(tester, () => tester.enterText(field(0), '62.5'));
      await act(tester, () => tester.enterText(field(1), '8'));
      await act(tester, () => tester.tap(find.byKey(SetRow.checkKey(0))));

      final set = await onlySet(tester);
      expect(set.completed, isTrue);
      expect(set.weightKg, 62.5);
      expect(set.reps, 8);
      expect(set.addedKg, isNull);
      expect(set.assistKg, isNull);
      expect(set.durationSec, isNull);
      semantics.dispose();
    });

    testWidgets('bodyweight: reps, and the optional added weight as addedKg', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpLogging(tester, exerciseId: 'push-up');

      expect(
        numberFields(),
        findsOneWidget,
        reason: 'reps only until the weight chip is opened',
      );
      await act(tester, () => tester.enterText(field(0), '15'));
      await tapAddWeight(tester);
      await act(tester, () => tester.enterText(field(1), '10'));
      await act(tester, () => tester.tap(find.byKey(SetRow.checkKey(0))));

      final set = await onlySet(tester);
      expect(set.completed, isTrue);
      expect(set.reps, 15);
      expect(set.addedKg, 10);
      expect(
        set.weightKg,
        isNull,
        reason: 'added weight is its own field, not weightKg',
      );
      expect(set.assistKg, isNull);
      semantics.dispose();
    });

    testWidgets('assisted: assistance as a positive assistKg, never addedKg', (
      tester,
    ) async {
      await pumpLogging(tester, exerciseId: 'assisted-pull-up-machine');
      expect(find.textContaining('Less assistance is better'), findsOneWidget);

      await act(tester, () => tester.enterText(field(0), '25'));
      await act(tester, () => tester.enterText(field(1), '8'));
      await act(tester, () => tester.tap(find.byKey(SetRow.checkKey(0))));

      final set = await onlySet(tester);
      expect(set.completed, isTrue);
      expect(set.assistKg, 25);
      expect(set.reps, 8);
      expect(set.addedKg, isNull);
      expect(set.weightKg, isNull);
    });

    testWidgets('timed: duration in seconds, optional weight as weightKg', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpLogging(tester, exerciseId: 'farmer-s-carry');

      await act(tester, () => tester.enterText(field(0), '45'));
      await tapAddWeight(tester);
      await act(tester, () => tester.enterText(field(1), '24'));
      await act(tester, () => tester.tap(find.byKey(SetRow.checkKey(0))));

      final set = await onlySet(tester);
      expect(set.completed, isTrue);
      expect(set.durationSec, 45);
      expect(set.weightKg, 24);
      expect(set.reps, isNull);
      semantics.dispose();
    });

    testWidgets('timed: a set with no duration cannot complete', (
      tester,
    ) async {
      await pumpLogging(tester, exerciseId: 'farmer-s-carry');
      await act(tester, () => tester.tap(find.byKey(SetRow.checkKey(0))));
      final open = await tester.runAsync(() => store.readOpenSession());
      expect(open!.completedSets, isEmpty);
    });
  });

  group('the assisted record is inverted, end to end', () {
    Future<int> logAndSave(WidgetTester tester, String assist) async {
      await pumpLogging(tester, exerciseId: 'assisted-pull-up-machine');
      // The row opens prefilled from the last session; overwrite both fields.
      await act(tester, () => tester.enterText(field(0), assist));
      await act(tester, () => tester.enterText(field(1), '8'));
      await act(tester, () => tester.tap(find.byKey(SetRow.checkKey(0))));
      late List<WorkoutSession> saved;
      await tester.runAsync(() async {
        await store.saveOpenSession();
        saved = await store.readSavedSessions();
      });
      final today = saved.firstWhere(
        (s) => s.performedOn == LocalDate.today(),
        orElse: () => fail('the workout logged today was not saved'),
      );
      return pbCountFor(today, saved);
    }

    testWidgets('less assistance than last time is a personal best', (
      tester,
    ) async {
      await savePast(
        tester,
        exerciseId: 'assisted-pull-up-machine',
        loadType: LoadType.assisted,
        daysAgo: 3,
        assistKg: 30,
        reps: 8,
      );
      expect(await logAndSave(tester, '25'), 1);
    });

    testWidgets('more assistance than last time is not', (tester) async {
      await savePast(
        tester,
        exerciseId: 'assisted-pull-up-machine',
        loadType: LoadType.assisted,
        daysAgo: 3,
        assistKg: 30,
        reps: 8,
      );
      expect(
        await logAndSave(tester, '35'),
        0,
        reason: 'a bigger assistance number is a weaker set',
      );
    });

    testWidgets('the first-ever assisted session earns no record', (
      tester,
    ) async {
      expect(await logAndSave(tester, '10'), 0);
    });
  });

  group('the other three records read upwards, end to end', () {
    Future<int> pbAfter(
      WidgetTester tester, {
      required String exerciseId,
      required LoadType loadType,
      required SetEntry past,
      required SetEntry now,
    }) async {
      await savePast(
        tester,
        exerciseId: exerciseId,
        loadType: loadType,
        daysAgo: 2,
        weightKg: past.weightKg,
        reps: past.reps,
        addedKg: past.addedKg,
        durationSec: past.durationSec,
      );
      late List<WorkoutSession> saved;
      await tester.runAsync(() async {
        final s = await store.createSession();
        final row = await store.addExercise(
          sessionId: s.id,
          exerciseId: exerciseId,
          loadType: loadType,
        );
        await store.writeSet(
          sessionExerciseId: row,
          position: 0,
          completed: true,
          weightKg: now.weightKg,
          reps: now.reps,
          addedKg: now.addedKg,
          durationSec: now.durationSec,
        );
        await store.saveOpenSession();
        saved = await store.readSavedSessions();
      });
      return pbCountFor(saved.first, saved);
    }

    SetEntry e({double? w, int? r, double? a, int? d}) => SetEntry(
      id: '',
      position: 0,
      completed: true,
      weightKg: w,
      reps: r,
      addedKg: a,
      durationSec: d,
    );

    testWidgets('timed: a longer hold at the same weight is a record', (
      tester,
    ) async {
      expect(
        await pbAfter(
          tester,
          exerciseId: 'farmer-s-carry',
          loadType: LoadType.timed,
          past: e(w: 24, d: 40),
          now: e(w: 24, d: 60),
        ),
        1,
      );
    });

    testWidgets('timed: a shorter hold is not', (tester) async {
      expect(
        await pbAfter(
          tester,
          exerciseId: 'farmer-s-carry',
          loadType: LoadType.timed,
          past: e(w: 24, d: 60),
          now: e(w: 24, d: 40),
        ),
        0,
      );
    });

    testWidgets('bodyweight: adding weight at the same reps is a record', (
      tester,
    ) async {
      expect(
        await pbAfter(
          tester,
          exerciseId: 'push-up',
          loadType: LoadType.bodyweight,
          past: e(r: 15),
          now: e(r: 15, a: 5),
        ),
        1,
      );
    });
  });
}
