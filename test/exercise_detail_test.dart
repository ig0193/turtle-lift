import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/generated/muscle_taxonomy.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/body_diagram.dart';
import 'package:turtle_lift/src/ui/disclosure_row.dart';
import 'package:turtle_lift/src/ui/exercise_detail_screen.dart';
import 'package:turtle_lift/src/ui/muscle_exercise_list_screen.dart';

/// The exercise page: reviewed content, the muscles it trains, and nothing
/// about the reader.
///
/// What is asserted here is mostly what a screenshot would not show:
///
/// * **that the reviewed copy is the shipped string, character for character**
///   — a `maxLines` or an ellipsis on one of these four fields renders
///   perfectly plausibly and silently drops the half of a cue that carries the
///   injury risk (`CLAUDE.md`).
/// * **which views the page chose, and that the muscle is actually filled on
///   them** — a page fixed to the front view renders a complete, plausible body
///   with the one muscle it exists to show left grey. 55 of the 260 shipped
///   exercises are covered by the back view alone.
/// * **that the diagram is inert** — a read-only diagram and a live one look
///   identical until something is tapped.
/// * **that nothing on the page is derived from training history** (R15). There
///   is no session table, so any such line would be invented.
void main() {
  // The shipped library is read off `rootBundle`.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The real 260 exercises, indexed as `main()` indexes them.
  ///
  /// **Not fixtures**, for the reason `muscle_exercise_list_test.dart` gives:
  /// every string on this page is the library's own, and hand-written content
  /// would let the screen and the shipped data drift apart and still pass.
  late ExerciseIndex index;

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    index = ExerciseIndex.fromJson(
      await container.read(exerciseLibraryProvider.future),
    );
  });

  /// Taps a content row's label.
  ///
  /// **The label, not the row's centre.** An open row's centre lands in the
  /// revealed copy, and tapping the copy deliberately does not close it — a
  /// reader dragging a finger down the execution cue must not lose it.
  Future<void> tapContentRow(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Exercise byId(String id) {
    final exercise = index.byId(id);
    expect(exercise, isNotNull, reason: '$id is not in the shipped library');
    return exercise!;
  }

  /// A viewport tall enough to build the whole page — two diagrams, four
  /// content rows and the rail — because a `ListView` builds only what is near
  /// the viewport and "it is not on the page" would otherwise be a claim about
  /// laziness.
  void useTallScreen(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 3000);
    addTearDown(tester.view.reset);
  }

  final routes = <Route<dynamic>>[];
  final observer = _RecordingObserver(routes);
  setUp(routes.clear);

  Widget host(Exercise exercise) => ProviderScope(
        // A fresh scope per pump, for the reason `workout_root_test.dart`
        // gives: re-pumping otherwise reuses the container and the override
        // silently becomes a no-op.
        key: UniqueKey(),
        overrides: [exerciseIndexProvider.overrideWithValue(index)],
        child: MaterialApp(
          theme: buildAppTheme(),
          navigatorObservers: <NavigatorObserver>[observer],
          home: ExerciseDetailScreen(exercise: exercise),
        ),
      );

  /// The painter actually driving the [n]th diagram on the page, rather than
  /// the widget that asked for it: the geometry and the fill both live on the
  /// painter, and a fill is only real once it reaches the canvas.
  BodyDiagramPainter painterAt(WidgetTester tester, int n) =>
      tester.widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(BodyDiagram),
          matching: find.byType(CustomPaint),
        ),
      ).elementAt(n).painter! as BodyDiagramPainter;

  /// The colour [segmentId] was **painted** in — read off the canvas rather
  /// than off the fill callback, because a painter that ignores its fill draws
  /// a perfectly plausible body.
  Color paintedColour(BodyDiagramPainter painter, String segmentId) {
    const size = Size(300, 600);
    final canvas = _RecordingCanvas();
    painter.paint(canvas, size);

    final segments = painter.segmentPathsFor(size);
    final at = segments.indexWhere((s) => s.id == segmentId);
    expect(at, isNot(-1),
        reason: '$segmentId is not drawn on ${painter.assetKey}');
    // One decorative pass precedes the segments, in declaration order.
    return canvas.paints[at + 1].color;
  }

  group('what the page says', () {
    testWidgets('AE7: it names the exercise, its equipment and load type, the '
        'muscles it trains, and carries four content rows', (tester) async {
      useTallScreen(tester);
      final exercise = byId('barbell-bench-press');
      await tester.pumpWidget(host(exercise));
      await tester.pumpAndSettle();

      expect(find.text(exercise.name), findsWidgets,
          reason: 'the header names the exercise');
      expect(find.text(exerciseFactsLabel(exercise)), findsOneWidget,
          reason: 'R16: the equipment and the load type are both stated');
      expect(exerciseFactsLabel(exercise), 'BARBELL · WEIGHTED');

      for (final id in exercise.primary) {
        expect(find.text(kSubMuscleGroups[id]!.label), findsOneWidget,
            reason: 'R16: $id is a primary muscle of this lift');
      }
      for (final id in exercise.secondary) {
        expect(find.text(kSubMuscleGroups[id]!.label), findsOneWidget,
            reason: 'R16: $id is worked as a secondary');
      }

      expect(find.byType(DisclosureRow), findsNWidgets(4));
      for (final field in exerciseContentFields(exercise)) {
        expect(find.byKey(exerciseContentRowKey(field.field)), findsOneWidget,
            reason: 'R17: ${field.field} is one of the four reviewed fields');
        expect(find.text(field.label), findsOneWidget);
      }
    });

    testWidgets('AE7: Common mistakes is open and the other three are closed',
        (tester) async {
      useTallScreen(tester);
      final exercise = byId('barbell-bench-press');
      await tester.pumpWidget(host(exercise));
      await tester.pumpAndSettle();

      expect(find.text(exercise.commonMistakes), findsOneWidget,
          reason: 'R17: the injury-relevant field is the one you cannot miss');
      for (final hidden in <String>[
        exercise.setup,
        exercise.posture,
        exercise.execution,
      ]) {
        expect(find.text(hidden), findsNothing,
            reason: 'R17: the other three start collapsed');
      }
    });

    testWidgets('the four fields render verbatim, unclamped and untruncated',
        (tester) async {
      useTallScreen(tester);

      for (final id in const <String>[
        'barbell-bench-press',
        'assisted-pull-up-machine',
        'plank',
      ]) {
        final exercise = byId(id);
        await tester.pumpWidget(host(exercise));
        await tester.pumpAndSettle();

        for (final field in exerciseContentFields(exercise)) {
          if (field.field == 'commonMistakes') continue; // already open
          await tapContentRow(tester, field.label);
        }

        for (final field in exerciseContentFields(exercise)) {
          final text = find.text(field.text);
          expect(text, findsOneWidget,
              reason: '$id.${field.field} must render as the library wrote it '
                  '-- CLAUDE.md forbids rewriting, summarising or reflowing '
                  'this copy');

          final widget = tester.widget<Text>(text);
          expect(widget.maxLines, isNull,
              reason: 'a maxLines here silently drops the half of a cue that '
                  'carries the injury risk');
          expect(widget.overflow, anyOf(isNull, TextOverflow.visible),
              reason: 'an ellipsis is truncation by another name');
        }
      }
    });

    testWidgets('tapping a collapsed row reveals its text, and tapping again '
        'hides it', (tester) async {
      useTallScreen(tester);
      final exercise = byId('barbell-bench-press');
      await tester.pumpWidget(host(exercise));
      await tester.pumpAndSettle();

      expect(find.text(exercise.setup), findsNothing);

      await tapContentRow(tester, 'SETUP');
      expect(find.text(exercise.setup), findsOneWidget);

      await tapContentRow(tester, 'SETUP');
      expect(find.text(exercise.setup), findsNothing);
    });

    testWidgets('the open row closes too, so nothing is stuck open',
        (tester) async {
      useTallScreen(tester);
      final exercise = byId('barbell-bench-press');
      await tester.pumpWidget(host(exercise));
      await tester.pumpAndSettle();

      await tapContentRow(tester, 'COMMON MISTAKES');
      expect(find.text(exercise.commonMistakes), findsNothing);
    });
  });

  group('what the page must never say', () {
    testWidgets('R15: no stat tile, no session list, no personal-best badge '
        'and no "you haven\'t logged" line, for any of the 260',
        (tester) async {
      useTallScreen(tester);

      // The prototype's detail screen carries three stat tiles, a "Recent"
      // section, a PB badge and a "You haven't logged this yet." placeholder.
      // All four belong to the deferred personal layer; there is no session
      // table, so every one of them would be invented.
      //
      // Checked against the shipped copy first: none of these strings occurs
      // in any exercise's name or in the one content field that renders
      // expanded, so a hit is the page's own text and not the library's.
      const forbidden = <String>[
        'Last',
        'Best',
        'Times',
        'PB',
        'Recent',
        'sessions',
        'logged',
        'haven\'t logged',
        'Lightest',
      ];

      for (final exercise in index.all) {
        await tester.pumpWidget(host(exercise));
        await tester.pumpAndSettle();

        for (final word in forbidden) {
          expect(
            find.textContaining(word, findRichText: true),
            findsNothing,
            reason: '"$word" on ${exercise.id} implies a history this slice '
                'cannot have',
          );
        }
      }
    });

    testWidgets('AE8: an assisted exercise shows no inverted-record banner',
        (tester) async {
      useTallScreen(tester);

      final assisted =
          index.all.where((e) => e.loadType == 'assisted').toList();
      expect(assisted, hasLength(3),
          reason: 'the premise: the library ships three assisted lifts');

      for (final exercise in assisted) {
        await tester.pumpWidget(host(exercise));
        await tester.pumpAndSettle();

        // The inversion is real and belongs to the set-logging screen, which
        // has a record to invert. Here there is none, so the prototype's
        // banner would be a claim about a personal best that does not exist.
        for (final line in const <String>[
          'Less assistance is better',
          'Your record',
          'lightest assist',
          'Lightest assist',
        ]) {
          expect(find.textContaining(line, findRichText: true), findsNothing,
              reason: '${exercise.id} must not claim a record');
        }
      }
    });

    // R18 used to read "nothing on the page adds the exercise to a workout",
    // and it was absolute because no session existed to add to. Sessions exist
    // now, so the rule is route-conditional: browsing the Muscles tab with no
    // workout open still offers nothing, which is what this pins. The three
    // routes that do offer something are covered in
    // `test/exercise_detail_entry_test.dart`.
    testWidgets('R18: browsing with no workout open adds nothing',
        (tester) async {
      useTallScreen(tester);

      for (final id in const <String>[
        'barbell-bench-press',
        'pull-up',
        'plank',
      ]) {
        await tester.pumpWidget(host(byId(id)));
        await tester.pumpAndSettle();

        for (final call in const <String>[
          'Add to workout',
          'Add exercise',
          'Log set',
          'Start',
        ]) {
          expect(find.textContaining(call, findRichText: true), findsNothing,
              reason: 'R18: this page is reference, not a way into a session');
        }
        expect(find.byType(ElevatedButton), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.byType(TextButton), findsNothing);
      }
    });
  });

  group('the diagram', () {
    testWidgets('R16: it does not respond to taps', (tester) async {
      useTallScreen(tester);
      final exercise = byId('barbell-bench-press');
      await tester.pumpWidget(host(exercise));
      await tester.pumpAndSettle();

      for (final diagram in tester.widgetList<BodyDiagram>(
        find.byType(BodyDiagram),
      )) {
        expect(diagram.onSegmentTap, isNull,
            reason: 'R16: the page\'s diagram is read-only');
      }

      routes.clear();
      final painter = painterAt(tester, 0);
      final size = tester.getSize(find.byType(BodyDiagram).first);
      final topLeft = tester.getTopLeft(find.byType(BodyDiagram).first);
      await tester.tapAt(topLeft + _pointHitting(painter, size, 'chest/mid'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(routes, isEmpty,
          reason: 'a tap on the body here opens nothing -- this screen is '
              'already the muscle\'s answer');
    });

    testWidgets('a back-only exercise renders one back diagram, centred, with '
        'its primary muscle filled accent-strong', (tester) async {
      useTallScreen(tester);
      // Lats primary, triceps secondary: both are drawn on the back view
      // alone, so a second, empty front diagram would be noise.
      final exercise = byId('machine-pullover');
      expect(bodyViewsForExercise(exercise), <BodyView>[BodyView.back]);

      await tester.pumpWidget(host(exercise));
      await tester.pumpAndSettle();

      expect(find.byType(BodyDiagram), findsOneWidget);
      final painter = painterAt(tester, 0);
      expect(painter.view, BodyView.back);

      expect(
        paintedColour(painter, 'back/lats').toARGB32(),
        AppPalette.accentStrong.toARGB32(),
        reason: 'the muscle this page exists to show must actually be filled; '
            'a page fixed to the front view leaves it grey and looks fine',
      );
      expect(
        paintedColour(painter, 'triceps/triceps').toARGB32(),
        AppPalette.accentLight.toARGB32(),
        reason: 'a secondary muscle fills accent-light (docs/00 §5)',
      );
      expect(
        paintedColour(painter, 'glutes/glutes').toARGB32(),
        AppPalette.mutedSurface.toARGB32(),
        reason: 'everything else stays the muted surface',
      );

      // Centred: the diagram spans the scrollable's full content width, so the
      // painter's own centring puts the body on the screen's axis.
      final diagram = tester.getRect(find.byType(BodyDiagram));
      final page = tester.getRect(find.byType(ListView));
      expect(diagram.center.dx, moreOrLessEquals(page.center.dx, epsilon: 0.5));
    });

    testWidgets('an exercise whose muscles span both views renders two '
        'diagrams side by side, each filled', (tester) async {
      useTallScreen(tester);
      // Lats are on the back; the biceps it also works are drawn only on the
      // front. Neither view alone can show what this page claims.
      final exercise = byId('pull-up');
      expect(
        bodyViewsForExercise(exercise),
        <BodyView>[BodyView.front, BodyView.back],
      );

      await tester.pumpWidget(host(exercise));
      await tester.pumpAndSettle();

      expect(find.byType(BodyDiagram), findsNWidgets(2));
      final front = painterAt(tester, 0);
      final back = painterAt(tester, 1);
      expect(front.view, BodyView.front);
      expect(back.view, BodyView.back);

      // Side by side, not stacked.
      final boxes = tester.getRect(find.byType(BodyDiagram).at(0));
      final second = tester.getRect(find.byType(BodyDiagram).at(1));
      expect(second.left, greaterThanOrEqualTo(boxes.right),
          reason: 'docs/00 §5: side by side');
      expect(boxes.top, moreOrLessEquals(second.top, epsilon: 0.5));

      expect(
        paintedColour(back, 'back/lats').toARGB32(),
        AppPalette.accentStrong.toARGB32(),
        reason: 'the primary muscle, on the view that draws it',
      );
      expect(
        paintedColour(front, 'biceps/biceps').toARGB32(),
        AppPalette.accentLight.toARGB32(),
        reason: 'the secondary that forced the second diagram',
      );
      expect(
        paintedColour(front, 'chest/mid').toARGB32(),
        AppPalette.mutedSurface.toARGB32(),
      );
    });

    testWidgets('a front-only exercise renders one front diagram',
        (tester) async {
      useTallScreen(tester);
      final exercise = byId('pec-deck-machine');
      await tester.pumpWidget(host(exercise));
      await tester.pumpAndSettle();

      expect(find.byType(BodyDiagram), findsOneWidget);
      expect(painterAt(tester, 0).view, BodyView.front);
    });

    test('every exercise in the library gets a view that draws every muscle '
        'it names', () {
      for (final exercise in index.all) {
        final views = bodyViewsForExercise(exercise);
        expect(views, isNotEmpty, reason: '${exercise.id} rendered no body');
        expect(views.toSet(), hasLength(views.length));

        for (final id in <String>{...exercise.primary, ...exercise.secondary}) {
          final drawnOn = kSubMuscleGroups[id]!
              .segments
              .map((placement) => placement.view)
              .toSet();
          expect(
            views.any((view) => drawnOn.contains(view.taxonomyView)),
            isTrue,
            reason: '${exercise.id} names $id, which is drawn on $drawnOn, but '
                'the page renders $views -- the muscle would be invisible',
          );
        }
      }
    });

    test('a single view is preferred whenever one covers everything', () {
      var single = 0;
      for (final exercise in index.all) {
        if (bodyViewsForExercise(exercise).length == 1) single++;
      }
      expect(single, greaterThan(index.all.length ~/ 2),
          reason: 'two bodies are the exception, not the layout -- a rule that '
              'always returned both would still pass the coverage test above');
    });
  });

  group('the substitutes rail', () {
    /// Where [listed]'s same-equipment half starts, or `listed.length` when
    /// there is no such half.
    int sameEquipmentFrom(List<Exercise> listed, Exercise exercise) {
      final at = listed.indexWhere((e) => e.equipment == exercise.equipment);
      return at == -1 ? listed.length : at;
    }

    testWidgets('AE10: it lists exercises sharing the primary muscle, '
        'different equipment first, and never the exercise itself',
        (tester) async {
      useTallScreen(tester);
      // **The decline dumbbell press, and not the pull-up this was written
      // against.** Every same-equipment candidate for a pull-up falls outside
      // the cap at `kSubstituteRailLimit`, so its rail is all different
      // equipment and the ordering assertions below had nothing to order --
      // they sat behind an `if` that never fired and the test passed while
      // proving nothing. This one's rail carries seven cards on other
      // equipment and then a dumbbell lift, which is the boundary R19 is
      // about.
      final exercise = byId('decline-dumbbell-press');
      await tester.pumpWidget(host(exercise));
      await tester.pumpAndSettle();

      final listed = substitutesFor(index, exercise);
      expect(listed, isNotEmpty);
      expect(listed.map((e) => e.id), isNot(contains(exercise.id)),
          reason: 'an exercise is not its own substitute');

      for (final other in listed) {
        expect(find.byKey(substituteCardKey(other.id)), findsOneWidget);
        expect(
          other.primary.any(exercise.primary.contains),
          isTrue,
          reason: 'R19: ${other.id} must share a primary sub-group',
        );
      }

      final boundary = sameEquipmentFrom(listed, exercise);
      expect(boundary, greaterThan(0),
          reason: 'the fixture must put at least one other-equipment card '
              'first, or the ordering below is not being exercised');
      expect(boundary, lessThan(listed.length),
          reason: 'and at least one same-equipment card after it -- a rail of '
              'one kind cannot tell a correct order from a reversed one');

      for (final other in listed.take(boundary)) {
        expect(other.equipment, isNot(exercise.equipment),
            reason: 'R19: different equipment comes first -- a substitute on '
                'the same bar is not a substitute for an occupied bar');
      }
      for (final other in listed.skip(boundary)) {
        expect(other.equipment, exercise.equipment,
            reason: 'R19: and once the same-equipment half starts, nothing '
                'else may appear after it');
      }

      expect(find.text(substituteRailLabel(exercise)), findsOneWidget);
      expect(substituteRailLabel(exercise), 'OTHER EXERCISES FOR LOWER CHEST',
          reason: 'one primary muscle, so the rail is named after it');
    });

    /// The ordering as a property of the function rather than of one fixture.
    ///
    /// **A pure-function test next to the widget one, not instead of it.** The
    /// widget test proves the page renders what the function returns; this
    /// proves the function is right for all 260 exercises, including the ones
    /// whose rail happens to be one kind of equipment all the way down and
    /// therefore cannot witness an ordering at all. Between them, reversing
    /// the two halves in `substitutesFor` cannot pass.
    test('R19: no rail in the library ever puts same equipment before '
        'different', () {
      var witnessed = 0;

      for (final exercise in index.all) {
        final listed = substitutesFor(index, exercise);
        final boundary = sameEquipmentFrom(listed, exercise);

        for (final other in listed.skip(boundary)) {
          expect(other.equipment, exercise.equipment,
              reason: '${exercise.id}: ${other.id} is on different equipment '
                  'and sits behind a same-equipment card');
        }
        if (boundary > 0 && boundary < listed.length) witnessed++;
      }

      expect(witnessed, greaterThan(0),
          reason: 'a suite where no rail mixes the two kinds would assert the '
              'ordering vacuously, which is how this got missed once already');
    });

    testWidgets('a substitute card opens that exercise\'s page',
        (tester) async {
      useTallScreen(tester);
      final exercise = byId('pull-up');
      await tester.pumpWidget(host(exercise));
      await tester.pumpAndSettle();

      final target = substitutesFor(index, exercise).first;
      await tester.tap(find.byKey(substituteCardKey(target.id)));
      await tester.pumpAndSettle();

      final opened = tester.widgetList<ExerciseDetailScreen>(
        find.byType(ExerciseDetailScreen),
      );
      expect(opened.last.exercise.id, target.id);
      expect(
        ModalRoute.of(tester.element(find.byType(ExerciseDetailScreen).last))!
            .opaque,
        isTrue,
        reason: 'KTD9: only an opaque route covers the floating tab bar',
      );
    });

    testWidgets('a multi-primary exercise matches either muscle, and its rail '
        'is titled neutrally', (tester) async {
      useTallScreen(tester);
      // Lats and upper back both primary: requiring the full set to match
      // would empty the rail for the 31 exercises shaped like this.
      final exercise = byId('barbell-bent-over-row');
      expect(exercise.primary, hasLength(2));

      await tester.pumpWidget(host(exercise));
      await tester.pumpAndSettle();

      final listed = substitutesFor(index, exercise);
      expect(
        listed.any((e) =>
            e.primary.contains('back/lats') &&
            !e.primary.contains('back/upper')),
        isTrue,
        reason: 'R19: matching *any* primary -- this one is a lats exercise',
      );
      expect(
        listed.any((e) =>
            e.primary.contains('back/upper') &&
            !e.primary.contains('back/lats')),
        isTrue,
        reason: 'R19: and this one is an upper-back exercise',
      );

      expect(find.text(substituteRailLabel(exercise)), findsOneWidget);
      expect(substituteRailLabel(exercise), kNeutralSubstituteRailLabel,
          reason: 'naming the rail after the first of two primaries would '
              'mislabel every card matching the second');
      expect(find.text('OTHER EXERCISES FOR LATS'), findsNothing);
    });

    testWidgets('every exercise in the library opens, and the rail never '
        'carries the exercise itself', (tester) async {
      useTallScreen(tester);

      for (final exercise in index.all) {
        await tester.pumpWidget(host(exercise));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: '${exercise.id} must open');
        expect(find.byKey(substituteCardKey(exercise.id)), findsNothing,
            reason: '${exercise.id} is not its own substitute');
      }
    });
  });

  group('reaching the page', () {
    testWidgets('a row on the muscle list opens it, opaquely', (tester) async {
      useTallScreen(tester);
      final target = index.withPrimary('back/lats').first;

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [exerciseIndexProvider.overrideWithValue(index)],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const MuscleExerciseListScreen(subGroupId: 'back/lats'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(exerciseRowKey(target.id)));
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseDetailScreen), findsOneWidget);
      expect(
        tester.widget<ExerciseDetailScreen>(find.byType(ExerciseDetailScreen))
            .exercise
            .id,
        target.id,
      );
      expect(
        ModalRoute.of(tester.element(find.byType(ExerciseDetailScreen)))!
            .opaque,
        isTrue,
      );
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

/// A [Canvas] that records the [Paint] of every fill instead of rasterising —
/// the same device `body_diagram_test.dart` uses, for the same reason: a fill
/// is only real once it reaches the canvas.
class _RecordingCanvas implements Canvas {
  final List<Paint> paints = <Paint>[];

  @override
  void drawPath(Path path, Paint paint) => paints.add(paint);

  @override
  void save() {}

  @override
  void restore() {}

  @override
  void translate(double dx, double dy) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A point, in the widget's local coordinates, that visibly lands on
/// [segmentId].
///
/// Copied in spirit from `body_diagram_test.dart`: scanned rather than taken
/// from the bounding-box centre, and derived from the painted geometry only,
/// never by asking `segmentAt`.
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
