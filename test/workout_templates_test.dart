import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/generated/muscle_taxonomy.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';

/// Guards the shipped template set against the exercise library it points into.
///
/// A template is a list of exercise ids, and nothing in the type system says an
/// id exists. So this is what stops a typo — or a regenerated library that
/// dropped an exercise — from turning into a template row that quietly starts a
/// shorter workout than it promised.
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

  group('the shipped set', () {
    test('is eleven templates, all predefined', () {
      expect(kPredefinedTemplates, hasLength(11));
      expect(
        kPredefinedTemplates.every((t) => t.isPredefined),
        isTrue,
        reason: 'nothing in this list is user-authored',
      );
    });

    test('ids are unique', () {
      final ids = kPredefinedTemplates.map((t) => t.id).toSet();
      expect(ids, hasLength(kPredefinedTemplates.length));
    });

    test('is listed in the order the landing renders it', () {
      expect(
        kPredefinedTemplates.map((t) => t.id),
        <String>[
          'push',
          'pull',
          'leg',
          'chest',
          'back',
          'shoulders',
          'arms',
          'chest-triceps',
          'back-biceps',
          'upper-body',
          'full-body',
        ],
      );
    });
  });

  group('every template points at real exercises', () {
    test('each id exists in the library', () {
      for (final template in kPredefinedTemplates) {
        for (final id in template.exerciseIds) {
          expect(
            index.byId(id),
            isNotNull,
            reason: '${template.id} names "$id", which is not in the library',
          );
        }
      }
    });

    test('each template has exercises, with none repeated', () {
      for (final template in kPredefinedTemplates) {
        expect(
          template.exerciseIds,
          isNotEmpty,
          reason: '${template.id} would start an empty workout',
        );
        expect(
          template.exerciseIds.toSet(),
          hasLength(template.exerciseIds.length),
          reason: 'a session holds one row per exercise, so a repeated id '
              'would silently shorten ${template.id}',
        );
      }
    });

    test('every exercise has a load type the session can log', () {
      for (final template in kPredefinedTemplates) {
        for (final id in template.exerciseIds) {
          expect(
            LoadType.fromName(index.byId(id)!.loadType),
            isNotNull,
            reason: '$id in ${template.id} would be skipped on start',
          );
        }
      }
    });
  });

  group('the muscle line a row shows', () {
    test('is derived from the exercises, and says what each day is for', () {
      // Pinned per template so that choosing an exercise whose *primary*
      // muscle is a neighbouring group (a face pull, a hammer curl) cannot
      // change what a template claims to cover without this failing.
      const expected = <String, String>{
        'push': 'Chest, shoulders, triceps',
        'pull': 'Back, biceps',
        'leg': 'Quads, hamstrings, glutes, calves',
        'chest': 'Chest',
        'back': 'Back',
        'shoulders': 'Shoulders',
        'arms': 'Biceps, triceps',
        'chest-triceps': 'Chest, triceps',
        'back-biceps': 'Back, biceps',
        'upper-body': 'Chest, back, shoulders, biceps, triceps',
      };
      for (final entry in expected.entries) {
        expect(
          templateSubtitle(templateById(entry.key), index),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('full body day carries bespoke copy, not a long join', () {
      expect(
        templateSubtitle(templateById('full-body'), index),
        'A mix across all major groups',
      );
    });

    test('a template with no exercises says so rather than rendering blank', () {
      const empty = WorkoutTemplate(
        id: 'mine',
        name: 'Mine',
        exerciseIds: <String>[],
        isPredefined: false,
      );
      expect(templateSubtitle(empty, index), 'No exercises yet');
    });

    test('an id the library no longer has contributes nothing', () {
      const stale = WorkoutTemplate(
        id: 'mine',
        name: 'Mine',
        exerciseIds: <String>['barbell-bench-press', 'not-an-exercise'],
        isPredefined: false,
      );
      expect(templateSubtitle(stale, index), 'Chest');
    });
  });

  group('the subtitle helper', () {
    test('capitalises the first label and lower-cases the rest', () {
      expect(muscleGroupSummary(<String>['chest', 'triceps']), 'Chest, triceps');
      expect(
        muscleGroupSummary(<String>['chest', 'shoulders', 'triceps']),
        'Chest, shoulders, triceps',
      );
    });

    test('orders by the taxonomy, not by the order it was handed', () {
      expect(muscleGroupSummary(<String>['triceps', 'chest']), 'Chest, triceps');
    });

    test('returns an empty string for an empty list', () {
      expect(muscleGroupSummary(const <String>[]), '');
    });

    test('every id it is given is a real parent group', () {
      for (final template in kPredefinedTemplates) {
        for (final id in templateGroupIds(template, index)) {
          expect(kMuscleGroupLabels.containsKey(id), isTrue, reason: id);
        }
      }
    });
  });
}

/// Lookup that fails loudly, so a renamed id shows up as this test's own
/// failure rather than as a confusing `StateError` three lines later.
WorkoutTemplate templateById(String id) => kPredefinedTemplates.firstWhere(
      (t) => t.id == id,
      orElse: () => throw StateError('no shipped template with id "$id"'),
    );
