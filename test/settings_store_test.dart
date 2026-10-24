import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/settings_store.dart';

/// Proves the provider seam a widget test needs actually works.
///
/// The split filter this file used to round-trip is gone with the exercise-first
/// Workout tab (`docs/adr/0006-workout-tab-is-exercise-first.md`); its column is
/// left in the table, unread.
///
/// Everything here runs against an in-memory database. The real constructor
/// opens a file through `path_provider`, which has no platform channel under
/// `flutter test` — so the override exercised in the last group is not a
/// convenience, it is the only way anything above this layer can be tested.
void main() {
  // Several tests below open their own in-memory database in one isolate,
  // which drift flags on debug builds as a possible mistake. Here it is the
  // point: each test gets a clean database.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late SettingsStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = SettingsStore(database);
  });

  tearDown(() => database.close());

  group('the settings row', () {
    test('a fresh database has no settings row at all', () async {
      expect(await store.rowCount(), 0);
    });
  });

  group('the provider seam', () {
    test('an overridden database yields a working store', () async {
      final overridden = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(overridden.close);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(overridden),
        ],
      );
      addTearDown(container.dispose);

      final seamStore = container.read(settingsStoreProvider);

      expect(await seamStore.rowCount(), 0);
    });

    test('the override really replaces the default database', () async {
      final overridden = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(overridden.close);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(overridden),
        ],
      );
      addTearDown(container.dispose);

      expect(
        identical(container.read(appDatabaseProvider), overridden),
        isTrue,
        reason: 'if this resolved to the real constructor, the test would be '
            'opening a file through a platform channel that does not exist',
      );
    });
  });
}
