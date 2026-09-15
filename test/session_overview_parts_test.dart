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
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart'
    show appDatabaseProvider;
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/body_diagram.dart';
import 'package:turtle_lift/src/ui/destructive_confirmation.dart';
import 'package:turtle_lift/src/ui/exercise_detail_screen.dart' show MuscleFill;
import 'package:turtle_lift/src/ui/session_actions.dart';
import 'package:turtle_lift/src/ui/session_body_map.dart';
import 'package:turtle_lift/src/ui/session_date_control.dart';
import 'package:turtle_lift/src/ui/session_header.dart';

/// Proves the furniture both overview paths share.
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
      equipment: 'Dumbbell',
      loadType: 'weighted',
      primary: const <String>['chest/upper'],
      secondary: const <String>['triceps/triceps'],
      setup: '',
      posture: '',
      execution: '',
      commonMistakes: '',
    ),
  ]);

  Future<void> pump(WidgetTester tester, Widget child,
      {WorkoutSession? session}) async {
    tester.view.physicalSize = const Size(1200, 2400);
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
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
  }

  Future<WorkoutSession> openSession(
    WidgetTester tester, {
    String? templateName,
    LocalDate? performedOn,
  }) async {
    late WorkoutSession session;
    await tester.runAsync(() async {
      session = await store.createSession(
        templateId: templateName == null ? null : 'tpl',
        templateName: templateName,
        performedOn: performedOn,
      );
    });
    return session;
  }

  group('the title field', () {
    testWidgets('shows the template name a template workout started with',
        (tester) async {
      final session = await openSession(tester, templateName: 'Push day');

      await pump(tester, const SessionTitleField(), session: session);

      expect(find.text('Push day'), findsOneWidget);
    });

    testWidgets('shows a placeholder for an unnamed ad-hoc workout',
        (tester) async {
      final session = await openSession(tester);

      await pump(tester, const SessionTitleField(), session: session);

      expect(find.text(SessionTitleField.placeholder), findsOneWidget);
    });

    testWidgets('accepts 40 characters and refuses the 41st', (tester) async {
      final session = await openSession(tester);
      await pump(tester, const SessionTitleField(), session: session);

      await tester.enterText(find.byType(TextField), 'x' * 45);
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text.length, SessionTitleField.maxLength);
    });

    testWidgets('writes the name when editing finishes, not per keystroke',
        (tester) async {
      final session = await openSession(tester);
      await pump(tester, const SessionTitleField(), session: session);

      await tester.enterText(find.byType(TextField), 'Leg day');
      await tester.pump();

      var stored = await tester.runAsync(() => store.readOpenSession());
      expect(
        stored!.title,
        isNull,
        reason: 'writing per keystroke would lose the caret mid-word',
      );

      await act(tester, () => tester.testTextInput.receiveAction(TextInputAction.done));

      stored = await tester.runAsync(() => store.readOpenSession());
      expect(stored!.title, 'Leg day');
    });

    testWidgets('follows a change of workout', (tester) async {
      // The shell hands the same field to every workout, so `initState` runs
      // once. Without a sync the second workout wears the first one's name —
      // or, starting from an unnamed ad-hoc one, shows an empty box where a
      // template's name belongs.
      final first = await openSession(tester, templateName: 'Push day');
      await pump(tester, const SessionTitleField(), session: first);
      expect(find.text('Push day'), findsOneWidget);

      late WorkoutSession second;
      await tester.runAsync(() async {
        second = await store.createSession(
          templateId: 'tpl',
          templateName: 'Leg day',
        );
      });
      await pump(tester, const SessionTitleField(), session: second);

      expect(find.text('Leg day'), findsOneWidget);
      expect(find.text('Push day'), findsNothing);
    });

    testWidgets('carries a name for screen readers', (tester) async {
      final session = await openSession(tester);
      await pump(tester, const SessionTitleField(), session: session);

      expect(
        find.bySemanticsLabel('Workout name'),
        findsOneWidget,
        reason: 'the header wraps this in a header node, which would otherwise '
            'swallow the field and leave typing unannounced',
      );
    });
  });

  group('the date control', () {
    testWidgets('says Today for today, quietly', (tester) async {
      final session = await openSession(tester);

      await pump(tester, const SessionDateControl(), session: session);

      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('spells out any earlier day', (tester) async {
      final monday = LocalDate(2026, 7, 27);
      final session = await openSession(tester, performedOn: monday);

      await pump(tester, const SessionDateControl(), session: session);

      expect(
        find.text('Mon 27 Jul'),
        findsOneWidget,
        reason: 'a backdated workout must be obvious, or the user backdates by '
            'accident and never notices',
      );
    });

    testWidgets('clears the 48pt tap target', (tester) async {
      final session = await openSession(tester);
      await pump(tester, const SessionDateControl(), session: session);

      expect(
        tester.getSize(find.byKey(SessionDateControl.chipKey)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('the picker cannot offer a day after today', (tester) async {
      final session = await openSession(tester);
      await pump(tester, const SessionDateControl(), session: session);

      await tester.tap(find.byKey(SessionDateControl.chipKey));
      await tester.pumpAndSettle();

      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.lastDate, LocalDate.today().toDateTime());
    });
  });

  group('the body map', () {
    testWidgets('starts with nothing filled', (tester) async {
      final session = await openSession(tester);

      await pump(tester, const SessionBodyMap(), session: session);

      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<BodyDiagramPainter>()
          .first;
      expect(painter.fill(<String>{'chest/upper'}), AppPalette.mutedSurface);
    });

    testWidgets('fills a primary strongly and a secondary lightly once logged',
        (tester) async {
      var session = await openSession(tester);
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

      await pump(tester, const SessionBodyMap(), session: session);

      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<BodyDiagramPainter>()
          .first;
      expect(painter.fill(<String>{'chest/upper'}), AppPalette.accentStrong);
      expect(
        painter.fill(<String>{'triceps/triceps'}),
        AppPalette.accentLight,
        reason: 'the map answers "what got worked" and fills secondaries; the '
            'muscle list answers a different question and does not',
      );
    });

    testWidgets('renders both views', (tester) async {
      final session = await openSession(tester);

      await pump(tester, const SessionBodyMap(), session: session);

      expect(find.byType(BodyDiagram), findsNWidgets(2));
    });
  });

  group('the fill object', () {
    test('two fills over the same muscles are equal, so no repaint', () {
      final a = MuscleFill(
        primary: <String>{'chest/upper'},
        secondary: <String>{'triceps/triceps'},
      );
      final b = MuscleFill(
        primary: <String>{'chest/upper'},
        secondary: <String>{'triceps/triceps'},
      );

      expect(a, b);
    });

    test('a changed trained set is a different fill, so it does repaint', () {
      final before = MuscleFill(
        primary: <String>{'chest/upper'},
        secondary: const <String>{},
      );
      final after = MuscleFill(
        primary: <String>{'chest/upper', 'triceps/triceps'},
        secondary: const <String>{},
      );

      expect(before, isNot(after));
    });
  });

  group('finishing', () {
    testWidgets('saves a workout that has completed sets', (tester) async {
      var session = await openSession(tester, templateName: 'Push day');
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
      final finished = <String>[];

      await pump(tester, SessionActions(onFinished: finished.add),
          session: session);
      await act(tester, () => tester.tap(find.byKey(SessionActions.finishKey)));

      expect(await tester.runAsync(() => store.readSavedSessions()),
          hasLength(1));
      expect(finished, hasLength(1));
    });

    testWidgets('drops an untouched workout silently', (tester) async {
      final session = await openSession(tester);
      final finished = <String>[];

      await pump(tester, SessionActions(onFinished: finished.add),
          session: session);
      await act(tester, () => tester.tap(find.byKey(SessionActions.finishKey)));

      expect(await tester.runAsync(() => store.sessionCount()), 0);
      expect(finished, isEmpty);
    });

    testWidgets('asks before dropping typed but unticked work',
        (tester) async {
      var session = await openSession(tester);
      await tester.runAsync(() async {
        final row = await store.addExercise(
          sessionId: session.id,
          exerciseId: 'incline-press',
          loadType: LoadType.weighted,
        );
        // Typed, never ticked — the case the durability rule exists for.
        await store.writeSet(
            sessionExerciseId: row, position: 0, weightKg: 24);
        session = (await store.readOpenSession())!;
      });

      await pump(tester, SessionActions(onFinished: (_) {}),
          session: session);
      await tester.tap(find.byKey(SessionActions.finishKey));
      await tester.pumpAndSettle();

      expect(
        find.byKey(confirmDestructiveKey),
        findsOneWidget,
        reason: 'the app commits every keystroke so typed work survives; '
            'throwing it away unannounced would spend that for nothing',
      );

      await act(tester, () => tester.tap(find.byKey(confirmCancelKey)));
      expect(await tester.runAsync(() => store.sessionCount()), 1);
    });
  });

  group('discarding', () {
    testWidgets('asks first, and cancelling keeps the workout', (tester) async {
      final session = await openSession(tester, templateName: 'Push day');

      await pump(tester, SessionActions(onFinished: (_) {}), session: session);
      await tester.tap(find.byKey(SessionActions.discardKey));
      await tester.pumpAndSettle();

      expect(find.text('Discard workout?'), findsOneWidget);

      await act(tester, () => tester.tap(find.byKey(confirmCancelKey)));
      expect(await tester.runAsync(() => store.sessionCount()), 1);
    });

    testWidgets('confirming drops it and everything in it', (tester) async {
      final session = await openSession(tester, templateName: 'Push day');

      await pump(tester, SessionActions(onFinished: (_) {}), session: session);
      await tester.tap(find.byKey(SessionActions.discardKey));
      await tester.pumpAndSettle();
      await act(
          tester, () => tester.tap(find.byKey(confirmDestructiveKey)));

      expect(await tester.runAsync(() => store.sessionCount()), 0);
    });

    testWidgets('the destructive action is painted in the destructive colour',
        (tester) async {
      final session = await openSession(tester, templateName: 'Push day');

      await pump(tester, SessionActions(onFinished: (_) {}), session: session);
      await tester.tap(find.byKey(SessionActions.discardKey));
      await tester.pumpAndSettle();

      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(confirmDestructiveKey),
          matching: find.byType(Text),
        ),
      );
      expect(
        label.style!.color,
        AppPalette.danger,
        reason: 'the accent means "this has been worked" wherever it appears, '
            'so a delete confirmation painted in it reads as approval',
      );
    });
  });
}
