import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/generated/muscle_taxonomy.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/body_diagram.dart';
import 'package:turtle_lift/src/ui/muscle_search_field.dart';
import 'package:turtle_lift/src/ui/muscle_search_screen.dart';
import 'package:turtle_lift/src/ui/muscles_root.dart';
import 'package:turtle_lift/src/ui/sub_group_row.dart';

/// The Muscles landing, which is two routes to the same 19 destinations.
///
/// What is asserted here is mostly what a screenshot would not show:
///
/// * the map's *fill*, not its presence — a diagram painted in an accent
///   colour is a claim about the user's training history, and this slice has
///   no history to make it from (R2). It renders perfectly either way.
/// * all 19 rows, in the taxonomy's own order — a list missing one is a muscle
///   the app cannot reach, and `shoulders/side-delt` is the one that would go
///   first because it is the one with no artwork to fall back on (R5).
/// * the counts — a row showing the wrong number is indistinguishable from a
///   row showing the right one.
/// * the search field's colours — the app's first text input, and Material's
///   defaults for it are a filled surface and an underline that appear nowhere
///   else in this app.
void main() {
  // The shipped library is read off `rootBundle`.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The real 260 exercises, indexed as `main()` indexes them.
  ///
  /// **Not fixtures.** Every count on this screen is the library's own, so a
  /// hand-written index would let the rows and the shipped data drift apart
  /// and still pass.
  late ExerciseIndex index;

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    index = ExerciseIndex.fromJson(
      await container.read(exerciseLibraryProvider.future),
    );
  });

  /// A viewport tall enough to build all 19 rows below a full-height body map.
  ///
  /// The landing is ~2000pt of content, and a `ListView` builds only what is
  /// near the viewport — on the default 800x600 surface every row below the
  /// map is unbuilt, so "the 19 labels are present" would be a claim about
  /// laziness rather than about the list.
  void useTallScreen(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 2400);
    addTearDown(tester.view.reset);
  }

  /// The root as the shell mounts it: a bare body, with [padding] standing in
  /// for the safe area plus the floating tab bar.
  Widget host({EdgeInsets padding = EdgeInsets.zero}) => ProviderScope(
        overrides: [exerciseIndexProvider.overrideWithValue(index)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(padding: padding),
              child: const MusclesRoot(),
            ),
          ),
        ),
      );

  /// The painter actually driving the map, rather than the widget that asked
  /// for it: the fill is a function, and only the painter resolves it.
  BodyDiagramPainter painterOf(WidgetTester tester) =>
      tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(BodyDiagram),
          matching: find.byType(CustomPaint),
        ),
      ).painter! as BodyDiagramPainter;

  /// The effective decoration Material hands the field — the app's
  /// `inputDecorationTheme` already merged in, which is the thing under test.
  InputDecoration decorationOf(WidgetTester tester) =>
      tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;

  SubGroupRow rowFor(WidgetTester tester, String subGroupId) =>
      tester.widget<SubGroupRow>(find.byKey(subGroupRowKey(subGroupId)));

  /// The box the front/back button for [view] actually paints.
  ///
  /// `theme_palette_test.dart` cannot reach these: it walks the
  /// `ColorScheme`, and both of these colours are widget literals that no
  /// scheme role carries. So the one-meaning rule has to be asserted where the
  /// colour is written.
  BoxDecoration bodyViewBoxOf(WidgetTester tester, BodyView view) =>
      tester.widget<Container>(
        find.descendant(
          of: find.byKey(bodyViewButtonKey(view)),
          matching: find.byType(Container),
        ),
      ).decoration! as BoxDecoration;

  Color bodyViewBorderOf(WidgetTester tester, BodyView view) =>
      (bodyViewBoxOf(tester, view).border! as Border).top.color;

  Color bodyViewLabelColourOf(WidgetTester tester, BodyView view) =>
      tester.widget<Text>(
        find.descendant(
          of: find.byKey(bodyViewButtonKey(view)),
          matching: find.byType(Text),
        ),
      ).style!.color!;

  group('the body map', () {
    testWidgets('every segment is filled with the muted surface, and nothing '
        'carries an accent', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      final diagram = tester.widget<BodyDiagram>(find.byType(BodyDiagram));
      expect(diagram.fill, mutedBodyFill,
          reason: 'R2: the landing hands the diagram the muted fill. A fill '
              'derived from anything else would be a statement about the user, '
              'and this slice has no session data to make one from');

      // The fill is a function, so "it was passed" is not "it resolves muted".
      // Resolving it for all 42 segments is what rules out a fill that returns
      // an accent for some set of ids and muted for the rest.
      final painter = painterOf(tester);
      final size = tester.getSize(find.byType(BodyDiagram));
      final segments = painter.segmentPathsFor(size);
      expect(segments, isNotEmpty, reason: 'the asset must carry segments');

      for (final segment in segments) {
        final colour = painter.fill(segment.subMuscleGroupIds);
        expect(colour.toARGB32(), AppPalette.mutedSurface.toARGB32(),
            reason: '${segment.id} is not the untrained muted surface');
        expect(colour.toARGB32(), isNot(AppPalette.accentStrong.toARGB32()));
        expect(colour.toARGB32(), isNot(AppPalette.accentLight.toARGB32()));
      }
    });

    testWidgets('the front/back control changes the rendered asset and leaves '
        'the 19 rows alone', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      expect(painterOf(tester).assetKey, bodyAssetKey(BodyView.front, BodyGender.male),
          reason: 'the landing opens on the front, where 13 of the 19 are drawn');
      final before = tester
          .widgetList<SubGroupRow>(find.byType(SubGroupRow))
          .map((row) => row.label)
          .toList();

      await tester.tap(find.byKey(bodyViewButtonKey(BodyView.back)));
      await tester.pump();

      expect(painterOf(tester).assetKey, bodyAssetKey(BodyView.back, BodyGender.male),
          reason: 'R3: the control switches which asset the map paints -- and '
              'the asset, not just the enum, because the two are joined by '
              'body_gender.dart and a control that flipped only the label '
              'would render the same body');
      expect(
        tester
            .widgetList<SubGroupRow>(find.byType(SubGroupRow))
            .map((row) => row.label)
            .toList(),
        before,
        reason: 'R3: the list beneath is the whole body on either view. '
            'Filtering it to the visible side would hide six sub-groups '
            'behind a control that looks like it only turns the picture round',
      );
    });

    testWidgets('the selected side is marked in accentStrong, and the other '
        'in the plain border colour', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      // §12 gives `accentStrong` one meaning, "active", and the side being
      // looked at is the active one. It gives `accentLight` a different and
      // narrower one -- "secondary muscle only, never a primary action" --
      // which this control shipped wearing, directly above a body map full of
      // muscles, where it is the one colour that could be read as a statement
      // about the artwork below rather than about the button.
      expect(bodyViewBorderOf(tester, BodyView.front).toARGB32(),
          AppPalette.accentStrong.toARGB32(),
          reason: '§12: the selected side is "active"');
      expect(bodyViewBorderOf(tester, BodyView.front).toARGB32(),
          isNot(AppPalette.accentLight.toARGB32()),
          reason: '§12: accentLight means "secondary muscle" and nothing '
              'else, least of all on the control above the muscles');
      expect(bodyViewBoxOf(tester, BodyView.front).color,
          AppPalette.mutedSurface,
          reason: 'a hairline and a label, not a solid accent panel -- at '
              'this size that reads as a primary action');
      expect(bodyViewLabelColourOf(tester, BodyView.front),
          AppPalette.textPrimary);

      expect(bodyViewBorderOf(tester, BodyView.back).toARGB32(),
          AppPalette.border.toARGB32(),
          reason: 'the unselected side carries no accent at all');
      expect(bodyViewBoxOf(tester, BodyView.back).color, AppPalette.surface);
      expect(bodyViewLabelColourOf(tester, BodyView.back),
          AppPalette.textSecondary);

      // And it is the selection that carries the colour, not the front.
      await tester.tap(find.byKey(bodyViewButtonKey(BodyView.back)));
      await tester.pump();

      expect(bodyViewBorderOf(tester, BodyView.back).toARGB32(),
          AppPalette.accentStrong.toARGB32());
      expect(bodyViewBorderOf(tester, BodyView.front).toARGB32(),
          AppPalette.border.toARGB32());
      expect(bodyViewLabelColourOf(tester, BodyView.back),
          AppPalette.textPrimary);
    });

    testWidgets('a segment tap is accepted and does not throw', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      // Where a segment tap leads is `muscle_exercise_list_test.dart`'s
      // subject. This file's contract is only that the map is live.
      await tester.tapAt(tester.getCenter(find.byType(BodyDiagram)));
      await tester.pump();

      expect(tester.takeException(), isNull);
      // The chosen muscle keeps its accent briefly while the next screen comes
      // in; drain that before the test ends or its timer outlives it.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    });
  });

  group('the sub-group list', () {
    testWidgets('renders all 19 labels, in parent-group order', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      expect(kSubMuscleGroups, hasLength(19),
          reason: 'the taxonomy is what "all 19" means; if this changed, the '
              'landing label and this test are both facts to reconcile');
      expect(find.byType(SubGroupRow), findsNWidgets(19),
          reason: 'R4: one row per sub-muscle group, as one flat list');

      var previousBottom = double.negativeInfinity;
      for (final group in kSubMuscleGroups.values) {
        final row = find.byKey(subGroupRowKey(group.id));
        expect(row, findsOneWidget, reason: '${group.id} has no row');
        expect(find.descendant(of: row, matching: find.text(group.label)),
            findsOneWidget,
            reason: '${group.id} must be named as the taxonomy names it');

        final top = tester.getRect(row).top;
        expect(top, greaterThan(previousBottom),
            reason: '${group.id} is out of order. The list is the taxonomy\'s '
                'own insertion order, which is grouped by parent -- sorting it '
                'by name or by count would scatter a body across the screen');
        previousBottom = tester.getRect(row).bottom - 1;
      }

      expect(find.text(MusclesRoot.listLabel), findsOneWidget,
          reason: 'the label over the list counts the taxonomy rather than '
              'stating a number that can go stale');
    });

    testWidgets('the Side delt row is there and tappable, though no segment '
        'carries it', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      const sideDelt = 'shoulders/side-delt';
      expect(hasOwnArtwork(sideDelt), isFalse,
          reason: 'the premise: side-delt rides on the front-delt polygon and '
              'is drawn nowhere of its own');

      final row = find.byKey(subGroupRowKey(sideDelt));
      expect(row, findsOneWidget,
          reason: 'R5: the list is this muscle\'s only direct route into the '
              'app -- from the map it is behind the front-delt sheet');
      expect(rowFor(tester, sideDelt).subtitle, contains(kNoArtworkNote),
          reason: 'the row says why it cannot be found on the map, so a user '
              'who went looking does not conclude the muscle is missing');

      await tester.tap(row);
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'the row is a live target; where it leads is '
              '`muscle_exercise_list_test.dart`\'s subject');

      expect(tester.getSize(row).height, greaterThanOrEqualTo(SubGroupRow.minHeight),
          reason: 'a row read standing in a gym, one-handed');
    });

    testWidgets('each row counts the exercises that name it as a primary '
        'muscle', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      for (final group in kSubMuscleGroups.values) {
        expect(rowFor(tester, group.id).exerciseCount,
            index.withPrimary(group.id).length,
            reason: '${group.id} is counted off something other than the '
                'index\'s primary bucket');
      }

      // One known sub-group, spelled out, so the loop above cannot pass by
      // comparing the screen against itself.
      final chest = index.withPrimary('chest/mid').length;
      expect(chest, greaterThan(0), reason: 'the shipped library trains chest');
      expect(
        find.descendant(
          of: find.byKey(subGroupRowKey('chest/mid')),
          matching: find.text('$chest exercises'),
        ),
        findsOneWidget,
        reason: 'the count reaches the screen, not just the widget',
      );

      // R10: secondary involvement is excluded. Chest/mid is secondary on a
      // good many pressing movements, so folding those in would be visible
      // here as a larger number.
      expect(
        chest,
        lessThan(index.all.where((e) =>
            e.primary.contains('chest/mid') ||
            e.secondary.contains('chest/mid')).length),
        reason: 'the row must count primary only -- "what to train it with", '
            'not "what happens to touch it"',
      );
    });

    testWidgets('nothing on the landing is derived from training history',
        (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      // KD1: no session table exists, so any of these would be fabricated.
      for (final forbidden in const <String>[
        'sets',
        'Last done',
        'last trained',
        'this week',
        'streak',
      ]) {
        expect(find.textContaining(forbidden, findRichText: true), findsNothing,
            reason: 'the landing must say nothing about the user: "$forbidden" '
                'implies a history this slice cannot have');
      }
    });
  });

  group('the search field', () {
    testWidgets('wears palette colours only -- no Material fill or underline',
        (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      final decoration = decorationOf(tester);

      expect(decoration.filled, isTrue);
      expect(decoration.fillColor?.toARGB32(), AppPalette.surface.toARGB32(),
          reason: 'unset, Material fills from surfaceContainerHighest');
      expect(decoration.hintStyle?.color?.toARGB32(),
          AppPalette.textMuted.toARGB32());

      // The shape, not only the colour: every other box in this app is a 1pt
      // bordered rectangle, and Material's default for a filled field is an
      // underline with no box at all.
      for (final border in <({String role, InputBorder? border, Color colour})>[
        (role: 'border', border: decoration.border, colour: AppPalette.border),
        (
          role: 'enabledBorder',
          border: decoration.enabledBorder,
          colour: AppPalette.border
        ),
        (
          role: 'focusedBorder',
          border: decoration.focusedBorder,
          colour: AppPalette.accentStrong
        ),
        (
          role: 'errorBorder',
          border: decoration.errorBorder,
          colour: AppPalette.danger
        ),
      ]) {
        expect(border.border, isA<OutlineInputBorder>(),
            reason: '${border.role} must be the app\'s box, not an underline');
        expect(border.border!.borderSide.color.toARGB32(),
            border.colour.toARGB32(),
            reason: '${border.role} is off-palette');
      }
    });

    testWidgets('is a button, not an input, and pushes the search screen over '
        'the tab bar', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(MuscleSearchField.fieldKey),
      );
      expect(field.readOnly, isTrue);
      expect(field.canRequestFocus, isFalse,
          reason: 'a caret blinking in a box that cannot be typed into '
              'promises an input and does not deliver one');

      await tester.tap(find.byType(MuscleSearchField));
      await tester.pumpAndSettle();

      expect(find.byType(MuscleSearchScreen), findsOneWidget,
          reason: 'R11/KTD8: the field is the way into search');

      final route = ModalRoute.of(
        tester.element(find.byType(MuscleSearchScreen)),
      )!;
      expect(route.opaque, isTrue,
          reason: 'only an opaque route covers the floating tab bar; a '
              'transparent one would leave "Workout" tappable over a '
              'half-typed query');
    });

    testWidgets('the search screen opens on the same 19 rows', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      await tester.tap(find.byType(MuscleSearchField));
      await tester.pumpAndSettle();

      expect(find.byType(SubGroupRow), findsNWidgets(19),
          reason: 'an empty query is a screenful of somewhere to go rather '
              'than a blank page');
      expect(
        tester.widget<TextField>(find.byKey(MuscleSearchField.fieldKey)).readOnly,
        isFalse,
        reason: 'the field on the search screen is the real one',
      );
    });
  });

  group('the screen contract', () {
    testWidgets('is a bare body, and its scrollable carries the clearance',
        (tester) async {
      const barInset = 63.0;
      useTallScreen(tester);

      late EdgeInsets expected;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [exerciseIndexProvider.overrideWithValue(index)],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(
                  padding: EdgeInsets.fromLTRB(11, 47, 13, barInset),
                ),
                child: Builder(builder: (context) {
                  expected = screenScrollPadding(context);
                  return const MusclesRoot();
                }),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(MusclesRoot),
          matching: find.byType(Scaffold),
        ),
        findsNothing,
        reason: 'the shell owns the Scaffold and the pinned header; a root '
            'that grew its own would nest two and swallow the tab bar inset',
      );

      final list = tester.widget<ListView>(
        find.descendant(
          of: find.byType(MusclesRoot),
          matching: find.byType(ListView),
        ),
      );
      expect(list.padding, expected,
          reason: 'one rule, applied at the scrollable');
      expect((list.padding! as EdgeInsets).bottom, kScreenGutter + barInset,
          reason: 'the last of the 19 rows has to clear the floating bar, and '
              'a ListView that passes any padding of its own stops absorbing '
              'that inset for you');
    });
  });
}
