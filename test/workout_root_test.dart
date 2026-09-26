import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/template_filter.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/template_filter_control.dart';
import 'package:turtle_lift/src/ui/template_list_screen.dart';
import 'package:turtle_lift/src/ui/template_row.dart';
import 'package:turtle_lift/src/ui/workout_root.dart';

/// The Workout landing: what it lists, what the filter changes, and where a tap
/// goes.
///
/// `test/tab_roots_test.dart` owns this root's geometry — the clearance, the
/// scrollable and the safe-area inset it shares with the other two roots. This
/// file owns its behaviour.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  /// Gives the test a phone-tall viewport instead of the 800x600 default.
  ///
  /// **Because the landing's rows are cards now, and a `ListView` only builds
  /// what fits.** At the old row height the whole list happened to fall inside
  /// 600pt, so every "is it listed" assertion was also, silently, a "does it
  /// fit on one screen" assertion. It is not one on a real device either --
  /// `flutter run` shows five template cards plus the call to action without
  /// scrolling -- so the tests that ask what the screen lists are given room
  /// to list it, and the ones that genuinely care about geometry say so.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Hosts the landing as the shell does, with the filter seeded the way
  /// `main()` seeds it.
  Widget host({
    TemplateFilter initial = TemplateFilter.multiSplit,
    List<WorkoutTemplate> custom = const <WorkoutTemplate>[],
    AppDatabase? database,
  }) {
    return ProviderScope(
      // A fresh scope per pump. The filter notifier reads its seed once in
      // build(), which is right for the app -- `main()` sets it at boot and it
      // never changes underneath -- but it means re-pumping with a different
      // override would otherwise reuse the container and keep the old filter,
      // quietly turning every "switch the filter" test into a no-op.
      key: UniqueKey(),
      overrides: [
        initialTemplateFilterProvider.overrideWithValue(initial),
        customTemplatesProvider.overrideWithValue(custom),
        // The ad-hoc entry now pushes a real search screen rather than the
        // one-line placeholder it used to, so reaching it needs the library
        // the app seeds at boot.
        exerciseIndexProvider.overrideWithValue(ExerciseIndex(const <Exercise>[])),
        if (database != null) appDatabaseProvider.overrideWithValue(database),
      ],
      // **The template list left the landing with `adr/0004`.** The landing
      // lists routines now; these tests follow the templates to the screen
      // behind the `Templates` button, which is where the split filter, the
      // custom group and the manage link went with them.
      child: const MaterialApp(home: TemplateListScreen()),
    );
  }

  Iterable<String> renderedTemplateNames(WidgetTester tester) => tester
      .widgetList<TemplateRow>(find.byType(TemplateRow))
      .map((row) => row.title);

  group('what it lists', () {
    testWidgets('shows exactly the selected filter\'s templates',
        (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(host());

      expect(
        renderedTemplateNames(tester),
        <String>[
          'Upper body day',
          'Full body day',
          'Chest and triceps day',
          'Back and biceps day',
        ],
        reason: 'only templates are cards now -- the ad-hoc entry is the '
            'primary action above the list and Manage templates is a link '
            'below it, and neither is a template',
      );
      expect(
        find.text('Push day'),
        findsNothing,
        reason: 'Push day belongs to Push-Pull-Legs only',
      );
    });

    testWidgets('carries the ad-hoc action and the manage link either side of '
        'the list', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(host());

      // The route to template authoring sits outside the custom-group
      // conditional on purpose, so it is here even with no custom templates --
      // see TemplateListScreen.manageTemplatesKey.
      expect(find.byKey(TemplateListScreen.manageTemplatesKey), findsOneWidget);
      expect(
        find.byType(TemplateRow),
        findsNWidgets(4),
        reason: 'the manage link is not a template card',
      );
    });

    testWidgets('counts what the current filter yields', (tester) async {
      await tester.pumpWidget(host());
      expect(find.text('4 templates'), findsOneWidget);

      await tester.pumpWidget(host(initial: TemplateFilter.pushPullLegs));
      await tester.pump();
      expect(find.text('3 templates'), findsOneWidget);
    });

    testWidgets('lists leg day under both of the filters it belongs to',
        (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(host(initial: TemplateFilter.singleMuscle));
      expect(find.text('Leg day'), findsOneWidget);

      await tester.pumpWidget(host(initial: TemplateFilter.pushPullLegs));
      await tester.pump();
      expect(find.text('Leg day'), findsOneWidget);
    });

    testWidgets('renders no empty state under any filter', (tester) async {
      for (final filter in TemplateFilter.values) {
        await tester.pumpWidget(host(initial: filter));
        await tester.pump();

        expect(
          find.byType(TemplateRow),
          findsWidgets,
          reason: '${filter.label} must never render an empty list -- there is '
              'no unfiltered value to escape to',
        );
      }
    });

    testWidgets('is already showing the stored filter on the first frame',
        (tester) async {
      // One pump, no settle. If the filter were resolved asynchronously this
      // would catch either a loading placeholder or Multi Split's rows about
      // to be swapped out.
      await tester.pumpWidget(host(initial: TemplateFilter.pushPullLegs));

      expect(find.text('Push day'), findsOneWidget);
      expect(find.text('3 templates'), findsOneWidget);
      expect(find.text('Upper body day'), findsNothing);
    });
  });

  group('the custom group', () {
    final custom = <WorkoutTemplate>[
      const WorkoutTemplate(
        id: 'my-arms',
        name: 'My arm blaster',
        groupIds: <String>['biceps'],
        filters: <TemplateFilter>{},
        isPredefined: false,
      ),
    ];

    testWidgets('is absent entirely when the user has none', (tester) async {
      await tester.pumpWidget(host());

      expect(
        find.text(TemplateListScreen.customGroupLabel),
        findsNothing,
        reason: 'a heading standing over nothing reads as broken',
      );
    });

    testWidgets('renders when the user has one', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(host(custom: custom));

      expect(find.text(TemplateListScreen.customGroupLabel), findsOneWidget);
      expect(find.text('My arm blaster'), findsOneWidget);
    });

    testWidgets('is unaffected by the filter', (tester) async {
      // The whole point of keeping custom templates outside the filter: with
      // no unfiltered value, a classified custom template would be reachable
      // from exactly one split and invisible from the other two.
      for (final filter in TemplateFilter.values) {
        useTallViewport(tester);
        await tester.pumpWidget(host(initial: filter, custom: custom));
        await tester.pump();

        expect(
          find.text('My arm blaster'),
          findsOneWidget,
          reason: 'still listed under ${filter.label}',
        );
      }
    });

    testWidgets('sits between the predefined templates and the manage link',
        (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(host(custom: custom));

      final customRow = tester.getRect(find.text('My arm blaster'));
      expect(
        customRow.top,
        greaterThan(tester.getRect(find.text('Upper body day')).bottom),
      );
      expect(
        customRow.bottom,
        lessThan(
          tester.getRect(find.byKey(TemplateListScreen.manageTemplatesKey)).top,
        ),
        reason: 'the ad-hoc action leads the screen now, so the group the '
            'custom templates close is the one the manage link follows',
      );
    });
  });

  group('changing the filter', () {
    testWidgets('swaps the rendered rows and persists the choice',
        (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await tester.pumpWidget(host(database: database));
      expect(find.text('Upper body day'), findsOneWidget);

      await tester.tap(find.byKey(TemplateFilterControl.tapTargetKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(templateFilterOptionKey(TemplateFilter.pushPullLegs)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Push day'), findsOneWidget);
      expect(find.text('Upper body day'), findsNothing);
      expect(find.text('3 templates'), findsOneWidget);

      expect(
        await SettingsStore(database).readWorkoutTemplateFilter(),
        'ppl',
        reason: 'the choice has to survive the next launch',
      );
    });

    testWidgets('names the current filter on the control', (tester) async {
      await tester.pumpWidget(host(initial: TemplateFilter.singleMuscle));

      expect(
        find.text('1 Muscle per day'),
        findsOneWidget,
        reason: 'the list is always a subset, so the control has to say which',
      );
    });
  });

  group('where a tap goes', () {
    // This used to assert that a template row *pushed* an overview screen
    // carrying the template. An open workout is now the tab root itself
    // (`docs/adr/0003`), so the row starts the workout in place and the
    // landing is replaced rather than covered.
    testWidgets('a template row starts that workout in place', (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await tester.pumpWidget(host(database: database));

      await tester.runAsync(() async {
        await tester.tap(find.text('Chest and triceps day'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();

      // `adr/0004`: a template no longer *is* a session shape — it starts an
      // empty workout narrowed to its muscles and gets out of the way. The
      // proof is the open session, not what replaced this screen.
      final open = await tester.runAsync(
        () => SessionStore(database).readOpenSession(),
      );
      expect(open!.templateId, 'chest-triceps');
      expect(open.title, 'Chest and triceps day');
    });

  });

  testWidgets('the pinned header does not move when the landing scrolls',
      (tester) async {
    // The app-wide contract, re-asserted against this body specifically --
    // this root is the one most likely to grow a header-shaped thing inside
    // its own scroll view.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AppScreen.root(
            title: 'Workout',
            body: const WorkoutRoot(),
          ),
        ),
      ),
    );

    final before = tester.getRect(find.text('Workout'));
    await tester.drag(find.byType(Scrollable), const Offset(0, -120));
    await tester.pump();

    expect(tester.getRect(find.text('Workout')), before);
  });
}
