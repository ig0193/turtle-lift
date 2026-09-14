import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/template_filter.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';

/// Proves the split filter defaults correctly, survives a restart, and is
/// resolved before anything builds.
///
/// That last point is the whole shape of this unit. Reading the stored key
/// asynchronously inside the provider would leave the landing rendering Multi
/// Split's rows on the first frames of every cold start and swapping them a
/// frame later — which is not what "opens on your last filter" claims.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late SettingsStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = SettingsStore(database);
  });

  tearDown(() => database.close());

  /// A container wired the way `main()` wires the real app: the stored key is
  /// already resolved, so the provider is synchronous from its first read.
  Future<ProviderContainer> boot() async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        initialTemplateFilterProvider
            .overrideWithValue(await readStoredTemplateFilter(store)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('resolving the stored key', () {
    test('nothing stored resolves to Multi Split', () async {
      expect(await readStoredTemplateFilter(store), TemplateFilter.multiSplit);
      expect(kDefaultTemplateFilter, TemplateFilter.multiSplit);
    });

    test('a stored key resolves to its filter', () async {
      await store.writeWorkoutTemplateFilter('ppl');
      expect(
        await readStoredTemplateFilter(store),
        TemplateFilter.pushPullLegs,
      );
    });

    test('an unrecognised stored key falls back rather than throwing',
        () async {
      // A downgrade or a hand-edited database. The app's first screen is the
      // last place that should crash.
      await store.writeWorkoutTemplateFilter('nonsense');
      expect(await readStoredTemplateFilter(store), TemplateFilter.multiSplit);
    });
  });

  group('the provider', () {
    test('is already resolved on first read -- never a loading state',
        () async {
      final container = await boot();

      // Not a Future, not an AsyncValue. If this ever becomes either, the
      // landing grows a first frame with no rows in it.
      final TemplateFilter filter = container.read(templateFilterProvider);
      expect(filter, TemplateFilter.multiSplit);
    });

    test('opens on the stored filter', () async {
      await store.writeWorkoutTemplateFilter('single');
      final container = await boot();

      expect(
        container.read(templateFilterProvider),
        TemplateFilter.singleMuscle,
      );
    });

    test('selecting a filter updates state and persists the key', () async {
      final container = await boot();

      await container
          .read(templateFilterProvider.notifier)
          .select(TemplateFilter.pushPullLegs);

      expect(
        container.read(templateFilterProvider),
        TemplateFilter.pushPullLegs,
      );
      expect(await store.readWorkoutTemplateFilter(), 'ppl');
    });

    test('persists the stable key, never the display label', () async {
      final container = await boot();

      await container
          .read(templateFilterProvider.notifier)
          .select(TemplateFilter.singleMuscle);

      final stored = await store.readWorkoutTemplateFilter();
      expect(stored, 'single');
      expect(
        stored,
        isNot(TemplateFilter.singleMuscle.label),
        reason: 'storing the label would strand the value on a copy change',
      );
    });

    test('re-selecting the current filter still records the choice', () async {
      final container = await boot();
      expect(await store.readWorkoutTemplateFilter(), isNull);

      await container
          .read(templateFilterProvider.notifier)
          .select(TemplateFilter.multiSplit);

      expect(
        await store.readWorkoutTemplateFilter(),
        'multi',
        reason: 'the default was never stored, so choosing it is a real write',
      );
    });

    test('a fresh boot against the same store opens on the last choice',
        () async {
      final first = await boot();
      await first
          .read(templateFilterProvider.notifier)
          .select(TemplateFilter.pushPullLegs);
      first.dispose();

      // The actual claim: relaunch the app, land on what you last chose.
      final second = await boot();
      expect(
        second.read(templateFilterProvider),
        TemplateFilter.pushPullLegs,
      );
    });
  });
}
