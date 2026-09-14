import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/generated/muscle_taxonomy.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';

/// Guards the shipped template set and the subtitle helper.
///
/// Modelled on `test/shipped_data_test.dart`: the counts are pinned against the
/// docs so a hand-edit to the list fails here rather than showing up as a short
/// screen. The filter-membership count is the one that matters most -- it is
/// the only thing standing between `docs/00-build-spec.md` removing the
/// unfiltered "All" value and a filter that renders nothing.
void main() {
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

    test('every parent group id exists in the taxonomy', () {
      for (final template in kPredefinedTemplates) {
        expect(
          template.groupIds,
          isNotEmpty,
          reason: '${template.id} must name at least one muscle group',
        );
        for (final id in template.groupIds) {
          expect(
            kMuscleGroupLabels.containsKey(id),
            isTrue,
            reason: '${template.id} names "$id", which is not a parent group',
          );
        }
      }
    });

    test('stores parent groups only -- never a sub-group id', () {
      for (final template in kPredefinedTemplates) {
        for (final id in template.groupIds) {
          expect(
            id,
            isNot(contains('/')),
            reason: 'sub-groups derive from the taxonomy at render time',
          );
        }
      }
    });

    test('the two additions resolve to a single group each', () {
      expect(templateById('chest').groupIds, <String>['chest']);
      expect(templateById('back').groupIds, <String>['back']);
    });

    test('full body day covers every parent group', () {
      expect(
        templateById('full-body').groupIds.toSet(),
        kMuscleTaxonomy.keys.toSet(),
      );
    });

    test('arms day is biceps and triceps -- "arms" is not a parent id', () {
      expect(templateById('arms').groupIds, <String>['biceps', 'triceps']);
      expect(kMuscleGroupLabels.containsKey('arms'), isFalse);
    });
  });

  group('filter membership', () {
    test('totals twelve across eleven templates', () {
      final memberships = kPredefinedTemplates.fold<int>(
        0,
        (n, t) => n + t.filters.length,
      );
      expect(
        memberships,
        12,
        reason: 'eleven templates, and leg day belongs to two filters',
      );
    });

    test('leg day is the only template in two filters', () {
      final shared =
          kPredefinedTemplates.where((t) => t.filters.length > 1).toList();
      expect(shared.map((t) => t.id), <String>['leg']);
      expect(
        templateById('leg').filters,
        {TemplateFilter.singleMuscle, TemplateFilter.pushPullLegs},
      );
    });

    test('every filter yields at least one template', () {
      for (final filter in TemplateFilter.values) {
        expect(
          templatesFor(filter),
          isNotEmpty,
          reason: 'there is no unfiltered value, so an empty filter is a dead '
              'end the user cannot escape',
        );
      }
    });

    test('each filter yields the curated set, in order', () {
      expect(
        templatesFor(TemplateFilter.singleMuscle).map((t) => t.id),
        <String>['chest', 'back', 'shoulders', 'arms', 'leg'],
      );
      expect(
        templatesFor(TemplateFilter.multiSplit).map((t) => t.id),
        <String>['upper-body', 'full-body', 'chest-triceps', 'back-biceps'],
      );
      expect(
        templatesFor(TemplateFilter.pushPullLegs).map((t) => t.id),
        <String>['push', 'pull', 'leg'],
      );
    });

    test('filter keys are stable and distinct from their labels', () {
      expect(
        TemplateFilter.values.map((f) => f.key),
        <String>['single', 'multi', 'ppl'],
      );
      expect(TemplateFilter.fromKey('ppl'), TemplateFilter.pushPullLegs);
      expect(TemplateFilter.fromKey('nonsense'), isNull);
      expect(TemplateFilter.fromKey(null), isNull);
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

    test('every predefined template renders a non-empty subtitle', () {
      for (final template in kPredefinedTemplates) {
        expect(
          template.subtitle,
          isNotEmpty,
          reason: '${template.id} would render a blank second line',
        );
      }
    });

    test('full body day carries bespoke copy, not a twelve-label join', () {
      final subtitle = templateById('full-body').subtitle;
      expect(subtitle, 'A mix across all major groups');
      expect(subtitle, isNot(contains('Calves')));
      expect(subtitle, isNot(contains('calves')));
    });

    test('every other template joins its own labels', () {
      expect(templateById('push').subtitle, 'Chest, shoulders, triceps');
      expect(templateById('pull').subtitle, 'Back, biceps');
      expect(
        templateById('leg').subtitle,
        'Quads, hamstrings, glutes, calves',
      );
      expect(templateById('chest').subtitle, 'Chest');
    });
  });
}

/// Lookup that fails loudly, so a renamed id shows up as this test's own
/// failure rather than as a confusing `StateError` three lines later.
WorkoutTemplate templateById(String id) => kPredefinedTemplates.firstWhere(
      (t) => t.id == id,
      orElse: () => throw StateError('no shipped template with id "$id"'),
    );
