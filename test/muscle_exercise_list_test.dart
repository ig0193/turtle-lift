import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/generated/muscle_taxonomy.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/body_diagram.dart';
import 'package:turtle_lift/src/ui/muscle_exercise_list_screen.dart';
import 'package:turtle_lift/src/ui/muscle_search_field.dart';
import 'package:turtle_lift/src/ui/muscle_segment_sheet.dart';
import 'package:turtle_lift/src/ui/muscles_root.dart';
import 'package:turtle_lift/src/ui/sub_group_row.dart';

/// Browsing from the landing to a muscle's exercises: the two entry points, the
/// one segment that has to ask first, and what the list itself says.
///
/// What is asserted here is mostly what a screenshot would not show:
///
/// * **how many routes a tap pushes**, not just where it ends up — R9 deletes
///   the muscle-group and sub-muscle-group pickers `docs/03` specified, and a
///   picker slipped back in between the map and the list would still leave the
///   right screen on top at the end of a `pumpAndSettle`.
/// * **that the route is opaque** — the only mechanism that covers the floating
///   tab bar (KTD9). A transparent one renders identically in a test and leaves
///   "Workout" tappable over the list on a device.
/// * **that the list counts primary involvement only** (R10) — a list folding
///   in secondary links looks entirely plausible and is simply wrong.
/// * **that nothing on either screen is derived from training history** — there
///   is no session table, so any such line would be fabricated.
void main() {
  // The shipped library is read off `rootBundle`.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The real 260 exercises, indexed as `main()` indexes them.
  ///
  /// **Not fixtures.** Every row on these screens is the library's own, so a
  /// hand-written index would let the screens and the shipped data drift apart
  /// and still pass.
  late ExerciseIndex index;

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    index = ExerciseIndex.fromJson(
      await container.read(exerciseLibraryProvider.future),
    );
  });

  /// A viewport tall enough to build the whole landing — a full-height body map
  /// plus 19 rows — and the longest exercise list beneath it. A `ListView`
  /// builds only what is near the viewport, so on the default 800x600 surface
  /// "the row is there" would be a claim about laziness rather than the list.
  void useTallScreen(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 2400);
    addTearDown(tester.view.reset);
  }

  /// Every route pushed after [routes] was last cleared, so a test can say "one
  /// screen, not two" rather than only "the right screen is on top".
  final routes = <Route<dynamic>>[];
  final observer = _RecordingObserver(routes);
  setUp(routes.clear);

  /// The landing, hosted as the shell mounts it, under a Navigator so that a
  /// tap has somewhere to push.
  Widget host() => ProviderScope(
        // A fresh scope per pump, for the reason `workout_root_test.dart`
        // gives: re-pumping otherwise reuses the container and the override
        // silently becomes a no-op.
        key: UniqueKey(),
        overrides: [exerciseIndexProvider.overrideWithValue(index)],
        child: MaterialApp(
          theme: buildAppTheme(),
          navigatorObservers: <NavigatorObserver>[observer],
          home: const Scaffold(body: MusclesRoot()),
        ),
      );

  /// One exercise list, pushed directly — for the assertions that are about the
  /// screen rather than about the way in.
  Widget listHost(String subGroupId) => ProviderScope(
        key: UniqueKey(),
        overrides: [exerciseIndexProvider.overrideWithValue(index)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: MuscleExerciseListScreen(subGroupId: subGroupId),
        ),
      );

  /// The painter actually driving the map, rather than the widget that asked
  /// for it: the geometry lives on the painter, and a tap has to be aimed at
  /// what was painted.
  BodyDiagramPainter painterOf(WidgetTester tester) =>
      tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(BodyDiagram),
          matching: find.byType(CustomPaint),
        ),
      ).painter! as BodyDiagramPainter;

  /// Taps the point on the rendered map that visibly lands on [segmentId].
  Future<void> tapSegment(WidgetTester tester, String segmentId) async {
    final painter = painterOf(tester);
    final size = tester.getSize(find.byType(BodyDiagram));
    final topLeft = tester.getTopLeft(find.byType(BodyDiagram));
    await tester.tapAt(topLeft + _pointHitting(painter, size, segmentId));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  MuscleExerciseListScreen openedList(WidgetTester tester) =>
      tester.widget<MuscleExerciseListScreen>(
        find.byType(MuscleExerciseListScreen),
      );

  group('reaching a list from the map', () {
    testWidgets('AE1: tapping the lats on the back view opens the Lats list, '
        'with no screen in between', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      await tester.tap(find.byKey(bodyViewButtonKey(BodyView.back)));
      await tester.pumpAndSettle();

      routes.clear();
      await tapSegment(tester, 'back/lats');

      expect(find.byType(MuscleExerciseListScreen), findsOneWidget,
          reason: 'R6: a segment tap opens that sub-group\'s exercise list');
      expect(openedList(tester).subGroupId, 'back/lats');
      expect(find.byType(MuscleSegmentSheet), findsNothing,
          reason: 'R7: only a segment carrying two sub-groups asks, and the '
              'lats carry one');
      expect(routes, hasLength(1),
          reason: 'R9: one push, so there is no picker between the map and '
              'the list. A second route here is exactly the screen this unit '
              'deletes, and it would still settle on the right list');
    });

    testWidgets('the pushed list is opaque, so it covers the floating tab bar',
        (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      await tapSegment(tester, 'chest/mid');

      final route = ModalRoute.of(
        tester.element(find.byType(MuscleExerciseListScreen)),
      )!;
      expect(route.opaque, isTrue,
          reason: 'KTD9: only an opaque route covers the floating tab bar; a '
              'sheet or transparent route leaves "Workout" painted over the '
              'exercises');
    });

    testWidgets('AE2: the front-delt segment asks which delt, and the answer '
        'opens that list', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      routes.clear();
      await tapSegment(tester, 'shoulders/front-delt');

      expect(find.byType(MuscleSegmentSheet), findsOneWidget,
          reason: 'R7: this segment carries two sub-groups, so it asks');
      expect(find.byType(MuscleExerciseListScreen), findsNothing,
          reason: 'nothing is opened until the question is answered -- '
              'picking one for the user is the bug this prompt exists to stop');
      expect(find.text(muscleSegmentSheetTitle(2)), findsOneWidget);

      for (final id in const ['shoulders/front-delt', 'shoulders/side-delt']) {
        expect(find.byKey(muscleSegmentOptionKey(id)), findsOneWidget,
            reason: '$id is one of the two the segment carries');
      }

      await tester.tap(find.byKey(muscleSegmentOptionKey('shoulders/side-delt')));
      await tester.pumpAndSettle();

      expect(find.byType(MuscleSegmentSheet), findsNothing,
          reason: 'the prompt closes behind the answer');
      expect(openedList(tester).subGroupId, 'shoulders/side-delt');
    });

    testWidgets('the two options are derived from the segment, never a '
        'hard-coded pair', (tester) async {
      // The premise, read off the taxonomy rather than assumed: exactly one
      // segment in the whole app carries more than one sub-group. If a
      // regenerated taxonomy adds a second, this sheet must serve it too --
      // which it does only because the widget is fed the reported set.
      final ambiguous = <String>{
        for (final view in BodyView.values)
          for (final group in kSubMuscleGroups.values)
            for (final placement in group.segments)
              if (placement.view == view.taxonomyView &&
                  subMuscleGroupsForSegment(view, placement.segment).length > 1)
                '${view.name}:${placement.segment}',
      };
      expect(ambiguous, {'front:shoulders/front-delt'},
          reason: 'front-delt is the only ambiguous segment today; the code '
              'must not know that');

      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();
      await tapSegment(tester, 'shoulders/front-delt');

      expect(
        tester.widget<MuscleSegmentSheet>(find.byType(MuscleSegmentSheet))
            .subGroupIds,
        subMuscleGroupsForSegment(BodyView.front, 'shoulders/front-delt')
            .toList()
          ..sort((a, b) => kSubMuscleGroups.keys
              .toList()
              .indexOf(a)
              .compareTo(kSubMuscleGroups.keys.toList().indexOf(b))),
        reason: 'the sheet lists what the diagram reported for the tapped '
            'segment, in the taxonomy\'s own order',
      );
    });

    testWidgets('dismissing the prompt opens nothing', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      await tapSegment(tester, 'shoulders/front-delt');
      expect(find.byType(MuscleSegmentSheet), findsOneWidget);

      // The scrim above the sheet: a modal barrier dismiss, which is what a
      // user who tapped the wrong polygon does.
      await tester.tapAt(const Offset(195, 40));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.byType(MuscleSegmentSheet), findsNothing);
      expect(find.byType(MuscleExerciseListScreen), findsNothing,
          reason: 'backing out of the question must not pick an answer');
    });
  });

  group('reaching a list from the row', () {
    testWidgets('AE3: the Side delt row opens the same screen the prompt '
        'reaches', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      routes.clear();
      await tester.tap(find.byKey(subGroupRowKey('shoulders/side-delt')));
      await tester.pumpAndSettle();

      expect(openedList(tester).subGroupId, 'shoulders/side-delt',
          reason: 'R5/R8: the list row is side-delt\'s only route, and it '
              'lands where the front-delt prompt lands');
      expect(routes, hasLength(1), reason: 'R9: one push, no picker');
      expect(
        ModalRoute.of(tester.element(find.byType(MuscleExerciseListScreen)))!
            .opaque,
        isTrue,
      );
    });

    testWidgets('the search screen\'s rows reach it too', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      await tester.tap(find.byType(MuscleSearchField));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(subGroupRowKey('back/lats')));
      await tester.pumpAndSettle();

      expect(openedList(tester).subGroupId, 'back/lats',
          reason: 'R8: the same 19 rows, wherever they are rendered, reach '
              'the same 19 lists');
    });
  });

  group('what the list shows', () {
    testWidgets('every exercise whose primary muscle is this sub-group, and '
        'nothing linked only as secondary', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(listHost('back/lats'));
      await tester.pumpAndSettle();

      final expected = index.withPrimary('back/lats');
      expect(expected, isNotEmpty, reason: 'the shipped library trains lats');
      expect(find.byType(ExerciseRow), findsNWidgets(expected.length));

      for (final exercise in expected) {
        expect(find.byKey(exerciseRowKey(exercise.id)), findsOneWidget,
            reason: '${exercise.id} names back/lats as primary');
      }

      final secondaryOnly = index.all.where(
        (e) =>
            e.secondary.contains('back/lats') &&
            !e.primary.contains('back/lats'),
      );
      expect(secondaryOnly, isNotEmpty,
          reason: 'the premise: the library links lats as secondary too');
      for (final exercise in secondaryOnly) {
        expect(find.byKey(exerciseRowKey(exercise.id)), findsNothing,
            reason: 'R10: the list is what to do to train the muscle, not '
                'everything that happens to touch it -- ${exercise.id} only '
                'works lats as a secondary');
      }
    });

    testWidgets('each row names the exercise and its equipment',
        (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(listHost('back/lats'));
      await tester.pumpAndSettle();

      for (final exercise in index.withPrimary('back/lats')) {
        final row = find.byKey(exerciseRowKey(exercise.id));
        expect(find.descendant(of: row, matching: find.text(exercise.name)),
            findsOneWidget,
            reason: '${exercise.id} must be named as the library names it');
        expect(
          find.descendant(
            of: row,
            matching: find.text(exerciseEquipmentLabel(exercise.equipment)),
          ),
          findsOneWidget,
          reason: 'R10: the equipment is on the row, because "lat pulldown" '
              'and "pull-up" are answers to different questions in a gym',
        );
      }

      expect(tester.getSize(find.byKey(exerciseRowKey(
              index.withPrimary('back/lats').first.id))).height,
          greaterThanOrEqualTo(ExerciseRow.minHeight),
          reason: 'a row read standing, one-handed');
    });

    testWidgets('the header names the sub-group and counts the list',
        (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(listHost('quads/quads'));
      await tester.pumpAndSettle();

      expect(find.text('Quads'), findsWidgets,
          reason: 'titled with the taxonomy\'s own label');
      expect(
        find.text(MuscleExerciseListScreen.countLabel(
          index.withPrimary('quads/quads').length,
        )),
        findsOneWidget,
      );
    });

    testWidgets('says nothing about the user\'s training', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(listHost('glutes/glutes'));
      await tester.pumpAndSettle();

      // The prototype's row carries a "Last: 60kg x 8" line and a
      // "not logged yet" placeholder. Both belong to the deferred personal
      // layer; there is no session table, so either would be invented.
      for (final forbidden in const <String>[
        'Last',
        'not logged yet',
        'sets',
        'PB',
        'sessions',
      ]) {
        expect(find.textContaining(forbidden, findRichText: true), findsNothing,
            reason: '"$forbidden" implies a history this slice cannot have');
      }
    });

    testWidgets('every sub-group in the taxonomy opens a list', (tester) async {
      useTallScreen(tester);

      for (final group in kSubMuscleGroups.values) {
        await tester.pumpWidget(listHost(group.id));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: '${group.id} must open');
        expect(find.byType(ExerciseRow),
            findsNWidgets(index.withPrimary(group.id).length),
            reason: '${group.id} lists its own primary exercises -- including '
                'the thinnest of the 19, which is where an off-by-one or an '
                'empty bucket would show');
      }
    });

    testWidgets('an id the library trains with nothing renders an empty list '
        'rather than throwing', (tester) async {
      // Not reachable from either entry point today, but a list screen that
      // throws on an unknown id turns a stale route argument into a crash.
      useTallScreen(tester);
      await tester.pumpWidget(listHost('nonexistent/muscle'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ExerciseRow), findsNothing);
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

/// A point, in the widget's local coordinates, that visibly lands on
/// [segmentId].
///
/// Copied in spirit from `body_diagram_test.dart`: scanned rather than taken
/// from the bounding-box centre, because most segments are two lobes and their
/// centre falls in the gap between them — and derived from the painted geometry
/// only, never by asking `segmentAt`, so a broken hit-test cannot hand this
/// helper a point it agrees with.
Offset _pointHitting(
  BodyDiagramPainter painter,
  Size size,
  String segmentId,
) {
  final segments = painter.segmentPathsFor(size);
  final index = segments.indexWhere((s) => s.id == segmentId);
  expect(index, isNot(-1), reason: '$segmentId is not in this asset');
  final segment = segments[index];
  final bounds = segment.path.getBounds();
  final origin = painter.originFor(size);

  for (var i = 1; i < 60; i++) {
    for (var j = 1; j < 60; j++) {
      final point = Offset(
        bounds.left + bounds.width * i / 60,
        bounds.top + bounds.height * j / 60,
      );
      if (!segment.path.contains(point)) continue;
      if (segments.skip(index + 1).any((s) => s.path.contains(point))) continue;
      return point + origin;
    }
  }
  fail('no visible point found inside $segmentId');
}
