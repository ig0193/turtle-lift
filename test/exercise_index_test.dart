import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/generated/muscle_taxonomy.dart';

/// The index is what every Muscles screen reads instead of the raw JSON, so
/// these tests guard two different things: that the lookups answer correctly,
/// and that the shipped data still says what the lookups assume. A failure in
/// the drift test is a fact about the generated assets to reconcile, not a test
/// to loosen.
void main() {
  // `exerciseLibraryProvider` reaches `rootBundle`, which needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseIndex index;

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    index = ExerciseIndex.fromJson(
      await container.read(exerciseLibraryProvider.future),
    );
  });

  group('lookup by id', () {
    test('the index holds all 260 shipped exercises', () {
      expect(index.all, hasLength(260));
    });

    test('a known id returns its exercise with every field intact', () {
      final exercise = index.byId('barbell-bench-press');
      expect(exercise, isNotNull);
      expect(exercise!.name, 'Barbell bench press');
      expect(exercise.equipment, 'barbell');
      expect(exercise.loadType, 'weighted');
      expect(exercise.primary, <String>['chest/mid']);
      expect(exercise.secondary, contains('triceps/triceps'));
      // Reviewed copy, carried through verbatim and never rewritten.
      expect(exercise.commonMistakes, isNotEmpty);
      expect(exercise.setup, isNotEmpty);
      expect(exercise.posture, isNotEmpty);
      expect(exercise.execution, isNotEmpty);
    });

    test('an unknown id returns nothing rather than throwing', () {
      expect(index.byId('no-such-exercise'), isNull);
      expect(index.byId(''), isNull);
    });
  });

  group('lookup by primary sub-muscle group', () {
    test('every result for chest/mid lists it as a primary muscle', () {
      final results = index.withPrimary('chest/mid');
      expect(results, isNotEmpty);
      for (final exercise in results) {
        expect(
          exercise.primary,
          contains('chest/mid'),
          reason: '${exercise.id} was returned without chest/mid as primary',
        );
      }
    });

    test('an exercise listing chest/mid only as secondary is excluded', () {
      final results = index.withPrimary('chest/mid').map((e) => e.id).toSet();
      final secondaryOnly = index.all.where(
        (e) => e.secondary.contains('chest/mid') &&
            !e.primary.contains('chest/mid'),
      );
      expect(
        secondaryOnly,
        isNotEmpty,
        reason: 'the shipped data must carry at least one to test against',
      );
      for (final exercise in secondaryOnly) {
        expect(results, isNot(contains(exercise.id)));
      }
    });

    test('a sub-group no exercise targets returns an empty list', () {
      expect(index.withPrimary('not/a-muscle'), isEmpty);
    });

    test('every sub-group in the taxonomy is answerable', () {
      for (final id in kSubMuscleGroups.keys) {
        expect(() => index.withPrimary(id), returnsNormally);
      }
    });
  });

  test('every muscle id in the library exists in the taxonomy', () {
    // The analyzer skips `lib/src/data/generated/**`, so this is the only place
    // a typo'd or retired sub-group id in either generated asset is caught.
    for (final exercise in index.all) {
      for (final id in <String>[...exercise.primary, ...exercise.secondary]) {
        expect(
          kSubMuscleGroups,
          contains(id),
          reason: '${exercise.id} names $id, which the taxonomy does not have',
        );
      }
    }
  });

  group('lookup by equipment', () {
    test('the library carries exactly the 8 shipped values', () {
      expect(index.equipmentValues, <String>[
        'bands',
        'barbell',
        'bodyweight',
        'cable',
        'dumbbell',
        'kettlebell',
        'machine',
        'other',
      ]);
    });

    test('grouping by equipment loses no exercise and duplicates none', () {
      var total = 0;
      for (final equipment in index.equipmentValues) {
        final results = index.withEquipment(equipment);
        expect(results, isNotEmpty);
        for (final exercise in results) {
          expect(exercise.equipment, equipment);
        }
        total += results.length;
      }
      expect(total, index.all.length);
    });

    test('an unknown equipment value returns an empty list', () {
      expect(index.withEquipment('sandbag'), isEmpty);
    });
  });

  group('name search', () {
    test('a partial query matches on any part of the name', () {
      final results = index.searchByName('bench press');
      expect(results.map((e) => e.id), contains('barbell-bench-press'));
      for (final exercise in results) {
        expect(exercise.name.toLowerCase(), contains('bench press'));
      }
    });

    test('matching ignores case and surrounding whitespace', () {
      expect(
        index.searchByName('  BARBELL Bench Press ').map((e) => e.id),
        contains('barbell-bench-press'),
      );
    });

    test('an empty query matches nothing rather than everything', () {
      expect(index.searchByName(''), isEmpty);
      expect(index.searchByName('   '), isEmpty);
    });

    test('a query matching no name returns empty rather than throwing', () {
      expect(index.searchByName('zzzznotalift'), isEmpty);
    });
  });

  test('reading exerciseIndexProvider without an override throws', () {
    // A missed boot override would render every screen in the Muscles tab
    // empty, so the provider must fail here rather than ship blank.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(() => container.read(exerciseIndexProvider), throwsA(anything));
  });

  test('an overridden exerciseIndexProvider hands back that index', () {
    final container = ProviderContainer(
      overrides: [exerciseIndexProvider.overrideWithValue(index)],
    );
    addTearDown(container.dispose);
    expect(container.read(exerciseIndexProvider), same(index));
  });

  group('Exercise', () {
    test('decodes a record straight from the shipped shape', () {
      const record = <String, Object?>{
        'id': 'test-lift',
        'name': 'Test lift',
        'equipment': 'cable',
        'loadType': 'assisted',
        'primary': <String>['back/lats'],
        'secondary': <String>['biceps/biceps'],
        'setup': 'Setup copy.',
        'posture': 'Posture copy.',
        'execution': 'Execution copy.',
        'commonMistakes': 'Mistakes copy.',
      };
      final exercise = Exercise.fromJson(record);
      expect(exercise.id, 'test-lift');
      expect(exercise.primary, <String>['back/lats']);
      expect(exercise.secondary, <String>['biceps/biceps']);
      expect(exercise.setup, 'Setup copy.');
      expect(exercise.posture, 'Posture copy.');
      expect(exercise.execution, 'Execution copy.');
      expect(exercise.commonMistakes, 'Mistakes copy.');
    });
  });
}
