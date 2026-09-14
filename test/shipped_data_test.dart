import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/generated/body_paths.dart';
import 'package:turtle_lift/src/data/generated/muscle_taxonomy.dart';
import 'package:turtle_lift/src/data/shipped_data.dart';

/// The shipped data is generated, so nothing in `lib/` would notice it
/// drifting. These counts come from `docs/00-build-spec.md` §1 and §3: a
/// failure here means a generator ran and its output changed, which is a fact
/// to reconcile against the spec rather than a test to "fix".
void main() {
  // Loading assets/exercises.json below needs the services binding.
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
