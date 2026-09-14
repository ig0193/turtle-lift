import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/generated/muscle_taxonomy.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/equipment_exercise_list_screen.dart';
import 'package:turtle_lift/src/ui/exercise_detail_screen.dart';
import 'package:turtle_lift/src/ui/muscle_exercise_list_screen.dart';
import 'package:turtle_lift/src/ui/muscle_search_field.dart';
import 'package:turtle_lift/src/ui/muscle_search_screen.dart';
import 'package:turtle_lift/src/ui/sub_group_row.dart';

/// One field over three vocabularies, and where each kind of result goes.
///
/// What is asserted here is mostly what a screenshot would not show:
///
/// * **which kind a result is** (R12) — "Kettlebell swing" and the equipment
///   `kettlebell` are a hair apart on screen and lead to entirely different
///   screens, so the tag is the whole difference.
/// * **that a query matching no exercise name still lands somewhere** (R14) —
///   an empty result list renders as a blank screen that looks like a bug
///   rather than like an answer.
/// * **that the route is opaque** — the only mechanism that covers the
///   floating tab bar (KTD9), and indistinguishable from a transparent one in
///   a screenshot.
/// * **that nothing on these screens is derived from training history** — the
///   prototype ranks results by what the user has logged and writes "not
///   logged yet" under every row; there is no session table, so both would be
///   invented.
void main() {
  // The shipped library is read off `rootBundle`.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The real 260 exercises, indexed as `main()` indexes them.
  ///
  /// **Not fixtures**, for the reason `muscle_exercise_list_test.dart` gives:
  /// the matcher is matching against the shipped names, labels and equipment
  /// values, and a hand-written index would let it and the data drift apart
  /// and still pass.
  late ExerciseIndex index;

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    index = ExerciseIndex.fromJson(
      await container.read(exerciseLibraryProvider.future),
    );
  });

  /// A viewport tall enough to build the fallback in full — 19 muscle rows and
  /// 8 equipment rows under their headings. A `ListView` builds only what is
  /// near the viewport, so on the default 800x600 surface "the row is there"
  /// would be a claim about laziness rather than about the list.
  void useTallScreen(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 3000);
    addTearDown(tester.view.reset);
  }

  /// Every route pushed after [routes] was last cleared, so a test can say
  /// "one screen, not two".
  final routes = <Route<dynamic>>[];
  final observer = _RecordingObserver(routes);
  setUp(routes.clear);

  Widget host() => ProviderScope(
        // A fresh scope per pump, for the reason `workout_root_test.dart`
        // gives: re-pumping otherwise reuses the container and the override
        // silently becomes a no-op.
        key: UniqueKey(),
        overrides: [exerciseIndexProvider.overrideWithValue(index)],
        child: MaterialApp(
          theme: buildAppTheme(),
          navigatorObservers: <NavigatorObserver>[observer],
          home: const MuscleSearchScreen(),
        ),
      );

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byKey(MuscleSearchField.fieldKey), query);
    await tester.pumpAndSettle();
  }

  Finder resultRow(SearchResultKind kind, String id) =>
      find.byKey(searchResultKey(kind, id));

  Finder kindTag(Finder row, SearchResultKind kind) =>
      find.descendant(of: row, matching: find.text(kind.tag));

  group('matching the three vocabularies', () {
    testWidgets('AE4: "lats" returns a result marked as a muscle, and it '
        'opens the Lats exercise list', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await search(tester, 'lats');

      expect(index.searchByName('lats'), isEmpty,
          reason: 'the premise: no exercise in the library is named "lats", '
              'so this result can only have come from the muscle vocabulary');
      final row = resultRow(SearchResultKind.muscle, 'back/lats');
      expect(row, findsOneWidget);
      expect(kindTag(row, SearchResultKind.muscle), findsOneWidget,
          reason: 'R12: the row says which of the three kinds it is');

      routes.clear();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(
        tester.widget<MuscleExerciseListScreen>(
          find.byType(MuscleExerciseListScreen),
        ).subGroupId,
        'back/lats',
        reason: 'R13: a muscle result opens that muscle\'s exercise list',
      );
      expect(routes, hasLength(1), reason: 'one push, no screen in between');
      expect(
        ModalRoute.of(tester.element(find.byType(MuscleExerciseListScreen)))!
            .opaque,
        isTrue,
        reason: 'KTD9: only an opaque route covers the floating tab bar',
      );
    });

    testWidgets('AE5: "kettlebell" returns a result marked as equipment, and '
        'it opens the 12 kettlebell exercises', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await search(tester, 'kettlebell');

      final row = resultRow(SearchResultKind.equipment, 'kettlebell');
      expect(row, findsOneWidget);
      expect(kindTag(row, SearchResultKind.equipment), findsOneWidget,
          reason: 'R12: the equipment and the twelve exercises named after it '
              'are a hair apart on screen and lead to different places');

      routes.clear();
      await tester.tap(row);
      await tester.pumpAndSettle();

      final expected = index.withEquipment('kettlebell');
      expect(expected, hasLength(12),
          reason: 'the premise: the shipped library has 12 kettlebell lifts');
      expect(
        tester.widget<EquipmentExerciseListScreen>(
          find.byType(EquipmentExerciseListScreen),
        ).equipment,
        'kettlebell',
      );
      expect(find.byType(ExerciseRow), findsNWidgets(expected.length));
      for (final exercise in expected) {
        expect(find.byKey(exerciseRowKey(exercise.id)), findsOneWidget);
      }
      expect(routes, hasLength(1));
      expect(
        ModalRoute.of(
          tester.element(find.byType(EquipmentExerciseListScreen)),
        )!.opaque,
        isTrue,
      );
    });

    testWidgets('part of an exercise name returns that exercise, marked as an '
        'exercise, and opens its page', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await search(tester, 'swing');

      final matches = index.searchByName('swing');
      expect(matches, hasLength(1),
          reason: 'the premise: one shipped exercise is a swing');
      final row = resultRow(SearchResultKind.exercise, matches.single.id);
      expect(row, findsOneWidget);
      expect(kindTag(row, SearchResultKind.exercise), findsOneWidget);

      routes.clear();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(
        tester.widget<ExerciseDetailScreen>(
          find.byType(ExerciseDetailScreen),
        ).exercise.id,
        matches.single.id,
        reason: 'R13: an exercise result opens that exercise\'s page',
      );
      expect(routes, hasLength(1));
      expect(
        ModalRoute.of(tester.element(find.byType(ExerciseDetailScreen)))!
            .opaque,
        isTrue,
      );
    });

    testWidgets('a query matching all three kinds returns all three, each '
        'labelled', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // "ds" is the narrowest query in the shipped data that reaches all three
      // vocabularies at once: the muscle "Quads", the equipment "bands", and
      // one exercise, "Hands-elevated push-up".
      await search(tester, 'ds');

      expect(resultRow(SearchResultKind.muscle, 'quads/quads'), findsOneWidget);
      expect(resultRow(SearchResultKind.equipment, 'bands'), findsOneWidget);
      final named = index.searchByName('ds');
      expect(named, hasLength(1), reason: 'the premise for this query');
      expect(
        resultRow(SearchResultKind.exercise, named.single.id),
        findsOneWidget,
      );

      for (final kind in SearchResultKind.values) {
        expect(find.text(kind.tag), findsOneWidget,
            reason: 'R12: each of the three is labelled with its own kind');
      }
    });

    testWidgets('matching ignores case', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await search(tester, 'LATS');
      expect(resultRow(SearchResultKind.muscle, 'back/lats'), findsOneWidget);

      await search(tester, 'KettleBell');
      expect(
        resultRow(SearchResultKind.equipment, 'kettlebell'),
        findsOneWidget,
      );
      expect(resultRow(SearchResultKind.muscle, 'back/lats'), findsNothing,
          reason: 'sanity: the screen is re-matching on each query rather '
              'than accumulating rows');
      expect(
        resultRow(
          SearchResultKind.exercise,
          index.searchByName('kettlebell swing').single.id,
        ),
        findsOneWidget,
        reason: 'the twelve names starting with the equipment value match it '
            'too, and are not swallowed by the equipment row',
      );

      await search(tester, 'ZZZQ');
      expect(find.byType(SubGroupRow), findsNWidgets(kSubMuscleGroups.length),
          reason: 'no vocabulary carries that string in any casing, so the '
              'fallback takes over');
      expect(find.text(noSearchMatchNote('ZZZQ')), findsOneWidget,
          reason: 'the note quotes what was typed, not a lower-cased copy of '
              'it -- a user who typed in caps did not mistype');
    });
  });

  group('never a dead end', () {
    testWidgets('AE6: a query matching no name still renders the full muscle '
        'and equipment lists, each headed', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await search(tester, 'zzzq');

      expect(index.searchByName('zzzq'), isEmpty);
      expect(find.text(kSearchMusclesHeading), findsOneWidget,
          reason: 'R14: the muscle list is headed, so its rows are not '
              'mistaken for results');
      expect(find.text(kSearchEquipmentHeading), findsOneWidget,
          reason: 'R14 names equipment as well as muscles; the prototype\'s '
              'fallback shows only muscles');
      expect(find.byType(SubGroupRow), findsNWidgets(kSubMuscleGroups.length));
      for (final value in index.equipmentValues) {
        expect(resultRow(SearchResultKind.equipment, value), findsOneWidget,
            reason: '$value is one of the 8 shipped values');
      }
      expect(find.text(noSearchMatchNote('zzzq')), findsOneWidget,
          reason: 'without this the two lists read as results for "zzzq"');
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty query does not throw and shows a usable starting '
        'state', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SubGroupRow), findsNWidgets(kSubMuscleGroups.length),
          reason: 'the same 19 rows the landing carries');
      for (final value in index.equipmentValues) {
        expect(resultRow(SearchResultKind.equipment, value), findsOneWidget);
      }
      expect(find.textContaining('Nothing matches'), findsNothing,
          reason: 'nothing has been typed, so nothing has failed to match');

      // And typing, then clearing, comes back to it rather than to a blank.
      await search(tester, 'lats');
      await search(tester, '');
      expect(find.byType(SubGroupRow), findsNWidgets(kSubMuscleGroups.length));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a blank query is not a match for everything', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await search(tester, '   ');

      expect(find.byType(SearchResultRow).evaluate().length,
          index.equipmentValues.length,
          reason: 'only the fallback\'s equipment rows -- whitespace must not '
              'return all 260 exercises');
    });

    testWidgets('the fallback rows go where their kind implies',
        (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await search(tester, 'zzzq');

      await tester.tap(resultRow(SearchResultKind.equipment, 'bands'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EquipmentExerciseListScreen>(
          find.byType(EquipmentExerciseListScreen),
        ).equipment,
        'bands',
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(subGroupRowKey('shoulders/side-delt')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MuscleExerciseListScreen>(
          find.byType(MuscleExerciseListScreen),
        ).subGroupId,
        'shoulders/side-delt',
        reason: 'R5: the row list is side-delt\'s only route, and a failed '
            'search must not be where it dead-ends',
      );
    });
  });

  group('what the results say', () {
    testWidgets('the category rows count their own list', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await search(tester, 'kettlebell');

      expect(
        find.descendant(
          of: resultRow(SearchResultKind.equipment, 'kettlebell'),
          matching: find.text(searchResultCountLine(12)),
        ),
        findsOneWidget,
      );

      await search(tester, 'lats');
      expect(
        find.descendant(
          of: resultRow(SearchResultKind.muscle, 'back/lats'),
          matching: find.text(
            searchResultCountLine(index.withPrimary('back/lats').length),
          ),
        ),
        findsOneWidget,
        reason: 'R10\'s count again: primary involvement, the same number the '
            'landing row shows',
      );
    });

    testWidgets('says nothing about the user\'s training', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await search(tester, 'kettlebell');

      // The prototype ranks exercise hits by what the user has logged and
      // writes "not logged yet" under every row that is not. There is no
      // session table in this slice, so either would be fabricated.
      for (final forbidden in const <String>[
        'Last',
        'logged',
        'PB',
        'sessions',
        'recent',
      ]) {
        expect(find.textContaining(forbidden, findRichText: true), findsNothing,
            reason: '"$forbidden" implies a history this slice cannot have');
      }
    });

    testWidgets('the equipment screen names and counts its list',
        (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [exerciseIndexProvider.overrideWithValue(index)],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const EquipmentExerciseListScreen(equipment: 'bands'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(EquipmentExerciseListScreen.titleFor('bands')),
        findsWidgets,
      );
      expect(
        find.text(MuscleExerciseListScreen.countLabel(
          index.withEquipment('bands').length,
        )),
        findsOneWidget,
        reason: 'the sibling screen\'s own header, not a second spelling',
      );

      await tester.tap(find.byKey(
        exerciseRowKey(index.withEquipment('bands').first.id),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseDetailScreen), findsOneWidget,
          reason: 'a row on this list opens the exercise, like every other '
              'exercise row in the tab');
    });

    testWidgets('an equipment value the library does not use renders empty '
        'rather than throwing', (tester) async {
      // Not reachable from search, which only offers the values the library
      // reports -- but a screen that throws on one turns a stale route
      // argument into a crash.
      useTallScreen(tester);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [exerciseIndexProvider.overrideWithValue(index)],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const EquipmentExerciseListScreen(equipment: 'sandbag'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ExerciseRow), findsNothing);
    });
  });

  group('the matcher itself', () {
    test('returns muscles, then equipment, then exercises', () {
      final kinds = muscleSearchResults(index, 'ds')
          .map((result) => result.kind)
          .toList();
      expect(kinds, <SearchResultKind>[
        SearchResultKind.muscle,
        SearchResultKind.equipment,
        SearchResultKind.exercise,
      ], reason: 'a category hit must not be buried under the exercise names '
          'that share its spelling');
    });

    test('matches sub-group labels rather than their ids', () {
      // "back/lats", "back/upper" and "back/lower" all carry "back" in the id;
      // only two of the 19 labels do. Matching ids would return a third row
      // for a user who typed a word they can see on screen.
      final labels = muscleSearchResults(index, 'back')
          .where((result) => result.kind == SearchResultKind.muscle)
          .map((result) => result.label)
          .toList();
      expect(labels, <String>['Upper back & traps', 'Lower back']);
    });

    test('every exercise whose name contains the query is returned, uncapped',
        () {
      final results = muscleSearchResults(index, 'press')
          .where((result) => result.kind == SearchResultKind.exercise);
      expect(results, hasLength(index.searchByName('press').length));
      expect(results.length, greaterThan(30),
          reason: 'the prototype slices to 30; a cap hides a match the user '
              'typed enough letters to find');
    });

    test('a blank query matches nothing at all', () {
      for (final query in const <String>['', '   ']) {
        expect(muscleSearchResults(index, query), isEmpty);
      }
    });
  });
}

/// Records every route pushed after the last clear.
class _RecordingObserver extends NavigatorObserver {
  _RecordingObserver(this.pushed);

  final List<Route<dynamic>> pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}
