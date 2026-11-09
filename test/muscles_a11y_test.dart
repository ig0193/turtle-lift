import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/generated/body_paths.dart';
import 'package:turtle_lift/src/data/generated/muscle_taxonomy.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/body_diagram.dart';
import 'package:turtle_lift/src/ui/muscle_search_field.dart';
import 'package:turtle_lift/src/ui/muscle_search_screen.dart';

/// Accessibility slice of the Muscles audit: B2 (the body map is invisible to
/// VoiceOver) and B8 (the search field loses its name once typed into).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseIndex index;
  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    index = ExerciseIndex.fromJson(
      await container.read(exerciseLibraryProvider.future),
    );
  });

  Widget host(Widget child) => ProviderScope(
        overrides: [
          initialBodyGenderProvider.overrideWithValue(BodyGender.male),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 300, height: 600, child: child),
            ),
          ),
        ),
      );

  group('body map semantics (B2)', () {
    for (final view in BodyView.values) {
      testWidgets('the ${view.name} view announces itself', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(host(BodyDiagram(
          view: view,
          fill: mutedBodyFill,
          onSegmentTap: (_) {},
        )));
        expect(
          find.semantics.byLabel(bodyMapSemanticsLabel(view)).evaluate(),
          isNotEmpty,
        );
        handle.dispose();
      });

      testWidgets('every tappable ${view.name} segment is a labelled button '
          'that opens its muscle', (tester) async {
        final handle = tester.ensureSemantics();
        final opened = <Set<String>>[];
        await tester.pumpWidget(host(BodyDiagram(
          view: view,
          fill: mutedBodyFill,
          onSegmentTap: opened.add,
        )));
        final asset = kBodyAssets[bodyAssetKey(view, BodyGender.male)]!;
        final ids = <String>{
          for (final segment in asset.segments)
            if (subMuscleGroupsForSegment(view, segment.id).isNotEmpty)
              segment.id,
        };
        expect(ids, isNotEmpty);
        for (final id in ids) {
          final groups = subMuscleGroupsForSegment(view, id);
          final label = bodySegmentSemanticsLabel(groups);
          final found = find.semantics.byLabel(label);
          expect(found.evaluate(), isNotEmpty, reason: label);
          // Touch exploration taps the node's centre; that point must open
          // this muscle, not a neighbour (the union of both shoulders used to
          // centre on the chest).
          final centre = tester.getCenter(find.byWidgetPredicate((w) =>
              w is Semantics && w.properties.label == label));
          await tester.tapAt(centre);
          await tester.pump(const Duration(milliseconds: 600));
          expect(opened.last, groups, reason: '$label by touch at centre');
          tester.semantics.tap(found);
          await tester.pump(const Duration(milliseconds: 600));
          expect(opened.last, groups, reason: label);
        }
        handle.dispose();
      });
    }

    testWidgets('a read-only diagram still says what it is, with no buttons',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const BodyDiagram(
        view: BodyView.front,
        fill: mutedBodyFill,
      )));
      expect(
        find.semantics.byLabel(bodyMapSemanticsLabel(BodyView.front))
            .evaluate(),
        isNotEmpty,
      );
      expect(
        find.semantics
            .byLabel(bodySegmentSemanticsLabel(<String>{'biceps/biceps'}))
            .evaluate(),
        isEmpty,
      );
      handle.dispose();
    });

    test('the shared front-delt segment names both muscles', () {
      final label = bodySegmentSemanticsLabel(<String>{
        'shoulders/front-delt',
        'shoulders/side-delt',
      });
      expect(label, contains(kSubMuscleGroups['shoulders/front-delt']!.label));
      expect(label, contains(kSubMuscleGroups['shoulders/side-delt']!.label));
    });
  });

  group('search field name (B8)', () {
    testWidgets('keeps its spoken name while typing', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ProviderScope(
        overrides: [exerciseIndexProvider.overrideWithValue(index)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const MuscleSearchScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(MuscleSearchField.fieldKey), 'bench');
      await tester.pump();
      final node = tester.getSemantics(find.byKey(MuscleSearchField.fieldKey));
      expect(node.label, startsWith(kMuscleSearchSpokenName));
      expect(node.value, 'bench');
      handle.dispose();
    });
  });
}
