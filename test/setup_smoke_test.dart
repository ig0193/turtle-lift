import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/main.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/generated/body_paths.dart';
import 'package:turtle_lift/src/data/generated/muscle_taxonomy.dart';
import 'package:turtle_lift/src/data/shipped_data.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';

void main() {
  // Loading assets/exercises.json below needs the services binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Counts come from docs/00-build-spec.md §1. If one of these fails, a
  // generator ran and the shipped data drifted -- not a test to "fix".
  test('shipped taxonomy matches the spec', () {
    expect(kMuscleGroupCount, 12, reason: '12 parent groups');
    expect(kSubMuscleGroupCount, 19, reason: '19 sub-muscle groups');
  });

  test('four body assets carry 42 segments between them', () {
    expect(kBodyAssets.keys.toSet(), {
      'frontMale',
      'backMale',
      'frontFemale',
      'backFemale',
    });
    expect(kBodyAssetCount, 4);
    expect(kBodySegmentCount, 42);

    // Every segment id must resolve in the taxonomy: '<group>/<subGroup>'.
    for (final asset in kBodyAssets.values) {
      for (final segment in asset.segments) {
        final parts = segment.id.split('/');
        expect(parts.length, 2, reason: 'malformed segment id ${segment.id}');
        expect(
          kMuscleTaxonomy[parts.first],
          contains(parts.last),
          reason: 'orphan segment ${segment.id}',
        );
      }
    }
  });

  test('the bundled exercise library parses to 260 entries', () async {
    // 260 exercises, docs/00-build-spec.md §3. Content fields are reviewed
    // copy -- this only checks the file is present, valid and complete.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final exercises = await container.read(exerciseLibraryProvider.future);
    expect(exercises, hasLength(260));
  });

  testWidgets('app boots on the page background', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TurtleLiftApp()));
    await tester.pump();

    expect(find.byType(SetupCheckScreen), findsOneWidget);

    // Deliberately not asserting on the placeholder's rendered numbers: the
    // screen is slated for deletion (build order step 4), and a test that
    // reads its text would fail as a side effect of correct work. The counts
    // themselves are covered above, against the data rather than the UI.
    final context = tester.element(find.byType(SetupCheckScreen));
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      AppPalette.pageBackground,
    );
  });
}
