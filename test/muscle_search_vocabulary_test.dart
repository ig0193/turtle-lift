import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/generated/muscle_taxonomy.dart';
import 'package:turtle_lift/src/data/muscle_synonyms.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/muscle_search_field.dart';
import 'package:turtle_lift/src/ui/muscle_search_screen.dart';

/// Search slice of the Muscles audit (B1): parent groups, synonyms, words in
/// any order, typo tolerance and relevance order.
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

  List<String> muscleIds(String query) => muscleSearchResults(index, query)
      .where((r) => r.kind == SearchResultKind.muscle)
      .map((r) => r.id)
      .toList();

  List<String> exerciseNames(String query) => muscleSearchResults(index, query)
      .where((r) => r.kind == SearchResultKind.exercise)
      .map((r) => r.label)
      .toList();

  group('the synonym table', () {
    test('every target is a real sub-group id', () {
      for (final entry in kMuscleSynonyms.entries) {
        expect(entry.value, isNotEmpty, reason: entry.key);
        for (final id in entry.value) {
          expect(kSubMuscleGroups.containsKey(id), isTrue,
              reason: '"${entry.key}" points at unknown id $id');
        }
      }
    });

    test('every key is already folded, so lookup can be exact', () {
      for (final key in kMuscleSynonyms.keys) {
        expect(searchFold(key), key);
      }
    });

    test('every parent group label leads to all of its sub-groups', () {
      for (final entry in kMuscleTaxonomy.entries) {
        final label = searchFold(kMuscleGroupLabels[entry.key]!);
        final ids = [for (final sub in entry.value) '${entry.key}/$sub'];
        expect(muscleIds(label), containsAll(ids), reason: label);
      }
    });
  });

  group('parent groups and synonyms (table-driven)', () {
    const cases = <String, List<String>>{
      'shoulders': [
        'shoulders/front-delt',
        'shoulders/side-delt',
        'shoulders/rear-delt',
      ],
      'shoulder': [
        'shoulders/front-delt',
        'shoulders/side-delt',
        'shoulders/rear-delt',
      ],
      'delts': [
        'shoulders/front-delt',
        'shoulders/side-delt',
        'shoulders/rear-delt',
      ],
      'pecs': ['chest/upper', 'chest/mid', 'chest/lower'],
      'chest': ['chest/upper', 'chest/mid', 'chest/lower'],
      'back': ['back/upper', 'back/lats', 'back/lower'],
      'legs': [
        'quads/quads',
        'hamstrings/hamstrings',
        'glutes/glutes',
        'calves/calves',
      ],
      'arms': ['biceps/biceps', 'triceps/triceps', 'forearms/forearms'],
      'core': ['abs/upper', 'abs/lower', 'obliques/obliques'],
      'abs': ['abs/upper', 'abs/lower'],
      'calf': ['calves/calves'],
      'calves': ['calves/calves'],
      'hip': ['glutes/glutes'],
      'glute': ['glutes/glutes'],
      'traps': ['back/upper'],
      'lats': ['back/lats'],
      'quad': ['quads/quads'],
      'hams': ['hamstrings/hamstrings'],
      'bis': ['biceps/biceps'],
      'tris': ['triceps/triceps'],
      'front delts': ['shoulders/front-delt'],
      'rear delts': ['shoulders/rear-delt'],
      'lateral delt': ['shoulders/side-delt'],
      'Shoulders ': [
        'shoulders/front-delt',
        'shoulders/side-delt',
        'shoulders/rear-delt',
      ],
    };
    for (final entry in cases.entries) {
      test('"${entry.key}" finds ${entry.value.length} muscle(s)', () {
        expect(muscleIds(entry.key), entry.value);
      });
    }

    test('"hip" still finds hip thrusts as exercises', () {
      expect(exerciseNames('hip'), contains('Barbell hip thrust'));
    });

    test('a synonym does not leak into unrelated muscles', () {
      expect(muscleIds('lats'), isNot(contains('back/lower')));
      expect(muscleIds('arms'), isNot(contains('shoulders/front-delt')));
    });
  });

  group('words in any order', () {
    test('"press bench" finds the bench presses', () {
      expect(exerciseNames('press bench'), contains('Barbell bench press'));
    });

    test('"curl dumbbell" finds Dumbbell curl', () {
      expect(exerciseNames('curl dumbbell'), contains('Dumbbell curl'));
    });

    test('every word must appear', () {
      expect(exerciseNames('bench curl'), isEmpty);
    });
  });

  group('relevance order', () {
    test('an exact name comes first', () {
      final results = muscleSearchResults(index, 'push-up');
      expect(results.first.label, 'Push-up');
    });

    test('a name starting with the query beats one merely containing it', () {
      final names = exerciseNames('bench press');
      // "Barbell bench press" contains it; no name starts with it, so the
      // whole-phrase hits come before anything matched word by word.
      final phraseHits = names.takeWhile((n) => n.toLowerCase().contains('bench press'));
      expect(phraseHits.length, greaterThanOrEqualTo(7));
    });

    test('prefix matches lead within exercises', () {
      final names = exerciseNames('curl');
      final firstContainsOnly =
          names.indexWhere((n) => !n.toLowerCase().startsWith('curl'));
      final lastPrefix =
          names.lastIndexWhere((n) => n.toLowerCase().startsWith('curl'));
      if (lastPrefix != -1) expect(lastPrefix, lessThan(firstContainsOnly));
    });
  });

  group('typo tolerance', () {
    test('"bech press" suggests "bench press" and returns its results', () {
      final outcome = muscleSearch(index, 'bech press');
      expect(outcome.didYouMean, 'bench press');
      expect(
        outcome.results.map((r) => r.label),
        contains('Barbell bench press'),
      );
    });

    test('"sholders" suggests shoulders', () {
      final outcome = muscleSearch(index, 'sholders');
      expect(outcome.didYouMean, 'shoulders');
      expect(
        outcome.results.where((r) => r.kind == SearchResultKind.muscle),
        hasLength(3),
      );
    });

    test('"dumbell" suggests dumbbell', () {
      expect(muscleSearch(index, 'dumbell').didYouMean, 'dumbbell');
    });

    test('a correct query has no suggestion', () {
      expect(muscleSearch(index, 'bench press').didYouMean, isNull);
    });

    test('short words are not corrected', () {
      expect(muscleSearch(index, 'xyz').didYouMean, isNull);
      expect(muscleSearch(index, 'xyz').results, isEmpty);
    });

    test('gibberish stays a no-match', () {
      final outcome = muscleSearch(index, 'qqqqqqq');
      expect(outcome.didYouMean, isNull);
      expect(outcome.results, isEmpty);
    });
  });

  group('custom exercises', () {
    test('a custom exercise is found by its words in any order', () {
      final custom = Exercise(
        id: 'custom-1',
        name: 'Cable hip kickback',
        equipment: 'cable',
        loadType: 'weighted',
        primary: const ['glutes/glutes'],
        secondary: const [],
        setup: '',
        posture: '',
        execution: '',
        commonMistakes: '',
        isCustom: true,
      );
      final withCustom = ExerciseIndex([...index.all, custom]);
      final names = muscleSearchResults(withCustom, 'kickback cable')
          .map((r) => r.label);
      expect(names, contains('Cable hip kickback'));
    });
  });

  group('the screen', () {
    testWidgets('a typo shows "Did you mean" above the corrected results',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [exerciseIndexProvider.overrideWithValue(index)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const MuscleSearchScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(MuscleSearchField.fieldKey), 'bech press');
      await tester.pump();
      expect(find.text(didYouMeanNote('bench press')), findsOneWidget);
      expect(find.text('Barbell bench press'), findsOneWidget);
    });

    testWidgets('"shoulders" lists the three delts, not the fallback',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [exerciseIndexProvider.overrideWithValue(index)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const MuscleSearchScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(MuscleSearchField.fieldKey), 'shoulders');
      await tester.pump();
      expect(find.text(noSearchMatchNote('shoulders')), findsNothing);
      expect(find.text('Front delt'), findsOneWidget);
      expect(find.text('Side delt'), findsOneWidget);
      expect(find.text('Rear delt'), findsOneWidget);
    });
  });
}
