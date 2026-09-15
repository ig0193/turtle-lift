import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/template_filter.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/ui/workout_root.dart';

/// Proves the user's own templates survive a restart, that renaming and
/// deleting touch exactly one template, and that the Workout landing still
/// reads them through the one provider it always has.
///
/// **The restart is the point.** `customTemplatesProvider` used to return
/// `const []`, and every assertion about how the custom group renders passed
/// against that constant — so a store that persists perfectly while the
/// landing keeps reading the constant would look green and ship a template
/// authoring screen whose output vanishes on the next launch. The
/// "survives a restart" group is what joins the two halves: it writes through
/// one container, throws it away, and reads through a second one built the way
/// `main()` builds it.
///
/// Everything runs against an in-memory database. The real constructor opens a
/// file through `path_provider`, which has no platform channel under
/// `flutter test`.
void main() {
  // Several tests below open their own in-memory database in one isolate,
  // which drift flags on debug builds as a possible mistake. Here it is the
  // point: each test gets a clean database.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late CustomTemplateStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = CustomTemplateStore(database);
  });

  tearDown(() => database.close());

  /// A container wired the way `main()` wires the app: one database handle,
  /// and the list already read off it before the first frame.
  Future<ProviderContainer> boot() async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        initialCustomTemplatesProvider.overrideWithValue(
          await readStoredCustomTemplates(store),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('the stored rows', () {
    test('a fresh database has no custom templates', () async {
      expect(await store.readCustomTemplates(), isEmpty);
    });

    test('a written row reads back unchanged', () async {
      await store.insertCustomTemplate(
        id: 'tpl-1',
        name: 'My arm blaster',
        groupIds: 'biceps,triceps',
        sourceTemplateId: 'arms',
      );

      final rows = await store.readCustomTemplates();
      expect(rows, hasLength(1));
      expect(rows.single.id, 'tpl-1');
      expect(rows.single.name, 'My arm blaster');
      expect(rows.single.groupIds, 'biceps,triceps');
      expect(rows.single.sourceTemplateId, 'arms');
    });

    test('a template the user built from scratch has no source', () async {
      await store.insertCustomTemplate(
        id: 'tpl-1',
        name: 'Mine',
        groupIds: 'chest',
      );

      expect(
        (await store.readCustomTemplates()).single.sourceTemplateId,
        isNull,
        reason: 'null is a real answer -- it is how "built from scratch" is '
            'told apart from "duplicated from a template that no longer ships"',
      );
    });

    test('renaming a template leaves its groups and its source alone',
        () async {
      await store.insertCustomTemplate(
        id: 'tpl-1',
        name: 'Push day copy',
        groupIds: 'chest,shoulders,triceps',
        sourceTemplateId: 'push',
      );

      await store.renameCustomTemplate('tpl-1', 'Heavy push');

      final row = (await store.readCustomTemplates()).single;
      expect(row.name, 'Heavy push');
      expect(
        row.groupIds,
        'chest,shoulders,triceps',
        reason: 'a partial companion write must not blank the columns it was '
            'not given -- a full read-modify-write would be the bug here',
      );
      expect(row.sourceTemplateId, 'push');
    });

    test('renaming an id that is not there writes nothing', () async {
      await store.insertCustomTemplate(id: 'tpl-1', name: 'Mine', groupIds: '');

      await store.renameCustomTemplate('tpl-missing', 'Ghost');

      expect(
        (await store.readCustomTemplates()).single.name,
        'Mine',
        reason: 'a rename is scoped by id, so a stale id is a no-op rather '
            'than a rename of whatever row came first',
      );
    });

    test('deleting removes one row and leaves the others', () async {
      await store.insertCustomTemplate(id: 'a', name: 'A', groupIds: 'chest');
      await store.insertCustomTemplate(id: 'b', name: 'B', groupIds: 'back');

      await store.deleteCustomTemplate('a');

      expect((await store.readCustomTemplates()).map((r) => r.id), <String>['b']);
    });

    test('rows come back in name order whatever order they went in', () async {
      await store.insertCustomTemplate(id: 'c', name: 'Zebra', groupIds: 'abs');
      await store.insertCustomTemplate(id: 'a', name: 'Alpha', groupIds: 'abs');
      await store.insertCustomTemplate(id: 'b', name: 'Middle', groupIds: 'abs');

      expect(
        (await store.readCustomTemplates()).map((r) => r.name).toList(),
        <String>['Alpha', 'Middle', 'Zebra'],
        reason: 'there is no insertion-order column to sort on, so the order '
            'the user sees has to come from something stored',
      );
    });
  });

  group('encoding the groups', () {
    test('a group list round-trips', () {
      expect(decodeGroupIds(encodeGroupIds(<String>['chest', 'triceps'])),
          <String>['chest', 'triceps']);
    });

    test('groups are stored in taxonomy order, not the order handed over', () {
      expect(
        encodeGroupIds(<String>['triceps', 'chest']),
        'chest,triceps',
        reason: 'two templates naming the same groups must render the same '
            'subtitle, and the subtitle is derived from this order',
      );
    });

    test('a repeated group is stored once', () {
      expect(encodeGroupIds(<String>['chest', 'chest']), 'chest');
    });

    test('an id the taxonomy does not know is dropped', () {
      expect(
        encodeGroupIds(<String>['chest', 'not-a-muscle']),
        'chest',
        reason: 'taxonomy order is undefined for an id the taxonomy has never '
            'heard of, and a template cannot render a group that does not exist',
      );
    });

    test('an empty group list decodes to an empty list, not to one blank id',
        () {
      expect(
        decodeGroupIds(''),
        isEmpty,
        reason: "''.split(',') yields [''], which would put a phantom group "
            'on every group-less template',
      );
    });
  });

  group('surviving a restart', () {
    test('a saved template is there in the next container', () async {
      final first = await boot();
      final saved = await first
          .read(customTemplateListProvider.notifier)
          .add(name: 'My arm blaster', groupIds: <String>['biceps', 'triceps']);
      first.dispose();

      final second = await boot();
      final templates = second.read(customTemplatesProvider);

      expect(templates, hasLength(1));
      expect(templates.single.id, saved.id);
      expect(templates.single.name, 'My arm blaster');
      expect(templates.single.groupIds, <String>['biceps', 'triceps']);
    });

    test('a restored template is not predefined and carries no filter',
        () async {
      final first = await boot();
      await first
          .read(customTemplateListProvider.notifier)
          .add(name: 'Mine', groupIds: <String>['chest']);
      first.dispose();

      final restored = (await boot()).read(customTemplatesProvider).single;

      expect(restored.isPredefined, isFalse);
      expect(
        restored.filters,
        isEmpty,
        reason: 'custom templates sit outside the split filter entirely -- '
            'with no unfiltered value, classifying one would make it reachable '
            'from exactly one split',
      );
    });

    test('a restored template derives its subtitle from its groups', () async {
      final first = await boot();
      await first.read(customTemplateListProvider.notifier).add(
            name: 'Mine',
            groupIds: <String>['triceps', 'chest'],
          );
      first.dispose();

      expect(
        (await boot()).read(customTemplatesProvider).single.subtitle,
        'Chest, triceps',
        reason: 'the subtitle is derived on read like every other display '
            'value, so nothing about it is stored',
      );
    });

    test('a fresh install restores nothing and shows no custom group',
        () async {
      expect((await boot()).read(customTemplatesProvider), isEmpty);
    });
  });

  group('changing the list', () {
    test('adding shows up immediately, without a re-read', () async {
      final container = await boot();

      await container
          .read(customTemplateListProvider.notifier)
          .add(name: 'Mine', groupIds: <String>['chest']);

      expect(
        container.read(customTemplatesProvider).map((t) => t.name),
        <String>['Mine'],
        reason: 'the landing watches this list, so a write that only reached '
            'the database would leave the screen stale until the next launch',
      );
    });

    test('renaming changes the name and preserves the groups', () async {
      final container = await boot();
      final notifier = container.read(customTemplateListProvider.notifier);
      final saved = await notifier.add(
        name: 'Push day copy',
        groupIds: <String>['chest', 'shoulders', 'triceps'],
      );

      await notifier.rename(saved.id, 'Heavy push');

      final renamed = container.read(customTemplatesProvider).single;
      expect(renamed.id, saved.id, reason: 'the id is stable across a rename');
      expect(renamed.name, 'Heavy push');
      expect(renamed.groupIds, <String>['chest', 'shoulders', 'triceps']);
    });

    test('a rename survives the restart it is meant to', () async {
      final first = await boot();
      final notifier = first.read(customTemplateListProvider.notifier);
      final saved =
          await notifier.add(name: 'Mine', groupIds: <String>['chest']);
      await notifier.rename(saved.id, 'Renamed');
      first.dispose();

      expect((await boot()).read(customTemplatesProvider).single.name,
          'Renamed');
    });

    test('deleting removes it and leaves the other custom templates alone',
        () async {
      final container = await boot();
      final notifier = container.read(customTemplateListProvider.notifier);
      final doomed =
          await notifier.add(name: 'Alpha', groupIds: <String>['chest']);
      await notifier.add(name: 'Beta', groupIds: <String>['back']);

      await notifier.delete(doomed.id);

      expect(
        container.read(customTemplatesProvider).map((t) => t.name),
        <String>['Beta'],
      );
    });

    test('a delete survives the restart it is meant to', () async {
      final first = await boot();
      final notifier = first.read(customTemplateListProvider.notifier);
      final doomed =
          await notifier.add(name: 'Alpha', groupIds: <String>['chest']);
      await notifier.add(name: 'Beta', groupIds: <String>['back']);
      await notifier.delete(doomed.id);
      first.dispose();

      expect(
        (await boot()).read(customTemplatesProvider).map((t) => t.name),
        <String>['Beta'],
      );
    });

    test('deleting an id that is not there changes nothing', () async {
      final container = await boot();
      final notifier = container.read(customTemplateListProvider.notifier);
      await notifier.add(name: 'Mine', groupIds: <String>['chest']);

      await notifier.delete('never-existed');

      expect(container.read(customTemplatesProvider), hasLength(1));
    });

    test('two templates added in one session come back in name order',
        () async {
      final container = await boot();
      final notifier = container.read(customTemplateListProvider.notifier);
      await notifier.add(name: 'Zebra', groupIds: <String>['abs']);
      await notifier.add(name: 'Alpha', groupIds: <String>['abs']);

      expect(
        container.read(customTemplatesProvider).map((t) => t.name),
        <String>['Alpha', 'Zebra'],
        reason: 'the in-memory order after a write has to match the order the '
            'next launch reads back, or the list reshuffles on restart',
      );
    });

    test('each added template gets its own id', () async {
      final container = await boot();
      final notifier = container.read(customTemplateListProvider.notifier);

      final first = await notifier.add(name: 'A', groupIds: <String>['chest']);
      final second = await notifier.add(name: 'B', groupIds: <String>['chest']);

      expect(first.id, isNot(second.id));
      expect(container.read(customTemplatesProvider), hasLength(2));
    });
  });

  group('the Workout landing', () {
    /// The landing hosted the way the shell hosts it, on a real database.
    Widget host() {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          initialTemplateFilterProvider
              .overrideWithValue(TemplateFilter.multiSplit),
        ],
        child: const MaterialApp(home: Scaffold(body: WorkoutRoot())),
      );
    }

    testWidgets('the custom group stays hidden while the table is empty',
        (tester) async {
      await tester.pumpWidget(host());

      expect(
        find.text(WorkoutRoot.customGroupLabel),
        findsNothing,
        reason: 'a heading standing over nothing reads as broken',
      );
    });

    testWidgets('the custom group appears once a template is saved',
        (tester) async {
      await tester.pumpWidget(host());

      final container = ProviderScope.containerOf(
        tester.element(find.byType(WorkoutRoot)),
      );
      await container
          .read(customTemplateListProvider.notifier)
          .add(name: 'My arm blaster', groupIds: <String>['biceps']);
      await tester.pump();

      expect(find.text(WorkoutRoot.customGroupLabel), findsOneWidget);
      expect(find.text('My arm blaster'), findsOneWidget);
      expect(
        find.text('Biceps'),
        findsOneWidget,
        reason: 'the row renders the derived subtitle, not a stored one',
      );
    });

    testWidgets('a saved template is on the first frame of the next launch',
        (tester) async {
      await store.insertCustomTemplate(
        id: 'tpl-1',
        name: 'My arm blaster',
        groupIds: 'biceps',
      );

      // One pump, no settle: this is the frame `main()`'s pre-frame read
      // exists to make honest. A list resolved asynchronously would render the
      // landing without the custom group and then grow it.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            initialCustomTemplatesProvider
                .overrideWithValue(await readStoredCustomTemplates(store)),
          ],
          child: const MaterialApp(home: Scaffold(body: WorkoutRoot())),
        ),
      );

      expect(find.text('My arm blaster'), findsOneWidget);
    });
  });
}
