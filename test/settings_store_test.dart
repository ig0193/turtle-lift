import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
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

  group('the protein target', () {
    test('is null on a fresh database', () async {
      expect(await store.readProteinTarget(), isNull);
    });

    test('round-trips a value and keeps one settings row', () async {
      await store.writeProteinTarget(120);
      await store.writeProteinTarget(140);
      expect(await store.readProteinTarget(), 140);
      expect(await store.rowCount(), 1);
    });

    test('the bounds 1 and 400 are accepted', () async {
      await store.writeProteinTarget(1);
      expect(await store.readProteinTarget(), 1);
      await store.writeProteinTarget(400);
      expect(await store.readProteinTarget(), 400);
    });

    for (final grams in <int>[0, 401, -5]) {
      test('$grams throws and leaves the stored value alone', () async {
        await store.writeProteinTarget(100);
        await expectLater(store.writeProteinTarget(grams), throwsArgumentError);
        expect(await store.readProteinTarget(), 100);
      });
    }

    test('null clears it', () async {
      await store.writeProteinTarget(120);
      await store.writeProteinTarget(null);
      expect(await store.readProteinTarget(), isNull);
    });

    test('writing it leaves the body gender on the same row alone', () async {
      final details = PersonalDetailsStore(database);
      await details.writeBodyGender('female');
      await store.writeProteinTarget(120);
      await store.writeProteinTarget(null);
      expect(await details.readBodyGender(), 'female');
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
