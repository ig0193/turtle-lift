import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/body_diagram.dart';

/// Proves the two personal details round-trip, that the bodyweight series
/// cannot be rewritten, and that a stored gender actually reaches the body map.
///
/// That last point is why this file pumps a widget at all. `bodyGenderProvider`
/// used to return a constant, and every diagram in the app watches it — so a
/// store that persists the value perfectly while the provider keeps answering
/// "male" would pass every unit test here and ship a Profile field that does
/// nothing. The widget group is the one assertion that joins the two halves.
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
  late PersonalDetailsStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = PersonalDetailsStore(database);
  });

  tearDown(() => database.close());

  group('the bodyweight series', () {
    test('a fresh database has no entries', () async {
      expect(await store.readBodyweightEntries(), isEmpty);
    });

    test('an appended entry reads back unchanged', () async {
      await store.appendBodyweightEntry('2026-09-14', 72.5);

      final entries = await store.readBodyweightEntries();
      expect(entries, hasLength(1));
      expect(entries.single.date, '2026-09-14');
      expect(entries.single.weightKg, 72.5);
    });

    test('entries come back oldest first, whatever order they went in',
        () async {
      await store.appendBodyweightEntry('2026-09-14', 72.5);
      await store.appendBodyweightEntry('2026-01-02', 75.0);
      await store.appendBodyweightEntry('2026-03-30', 74.0);

      expect(
        (await store.readBodyweightEntries()).map((e) => e.date).toList(),
        <String>['2026-01-02', '2026-03-30', '2026-09-14'],
        reason: 'resolving the weight in effect on a date walks the series '
            'forward, so the order is part of the contract rather than a '
            'presentation choice',
      );
    });

    test('a second entry on a date already recorded replaces that day',
        () async {
      await store.appendBodyweightEntry('2026-09-14', 72.5);
      await store.appendBodyweightEntry('2026-09-14', 73.0);

      final entries = await store.readBodyweightEntries();
      expect(entries, hasLength(1),
          reason: 'the date is the primary key -- two rows for one day would '
              'leave no way to say which one the user meant');
      expect(entries.single.weightKg, 73.0,
          reason: 'correcting a typo on the day it was typed is the only '
              'correction KD5 allows, and this is it');
    });

    test('a weight recorded late in the evening keeps its own day', () {
      // The failure this guards is invisible on a machine set to UTC and on
      // every run before 23:00: a date that round-trips through a timestamp
      // lands on tomorrow for anyone east of Greenwich.
      final lateEvening = DateTime(2026, 9, 14, 23, 30);

      expect(encodeCalendarDate(lateEvening), '2026-09-14');
      expect(
        BodyweightEntry(date: lateEvening, weightKg: 72.5).date,
        DateTime(2026, 9, 14),
        reason: 'an entry is a calendar date, so the time of day must not '
            'survive construction',
      );
    });

    test('a stored date decodes to the same local calendar day', () {
      final decoded = decodeCalendarDate('2026-09-14');

      expect(decoded, DateTime(2026, 9, 14));
      expect(decoded.isUtc, isFalse,
          reason: 'a calendar date is local -- a UTC midnight would be the '
              'previous day for anyone west of Greenwich');
      expect(encodeCalendarDate(decoded), '2026-09-14');
    });
  });

  group('the bodyweight series is append-only', () {
    /// The store's own source, with doc comments and commented-out code
    /// stripped — the same trick `test/android_manifest_test.dart` uses, so
    /// that prose about deletion cannot pass for the absence of it and
    /// commented-out code cannot pass for its removal.
    late String source;

    setUpAll(() {
      final raw =
          File('lib/src/data/personal_details_store.dart').readAsStringSync();
      source = raw
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
    });

    test('the store issues no delete or update against any table', () {
      // KD5 is enforced by there being no method to call, so the assertion has
      // to be structural: a behavioural test can only prove that the API it
      // knows about behaves, and the failure here is an API that grew.
      expect(source, isNot(contains(RegExp(r'\.delete\('))),
          reason: 'a recorded bodyweight is immutable (KD5) -- deleting one '
              're-prices every session logged after it, silently');
      expect(source, isNot(contains(RegExp(r'\.update\('))),
          reason: 'a correction is a new entry that supersedes the old one '
              'going forward, never a rewrite of it (KD5)');
      expect(source, isNot(contains(RegExp(r'\bdeleteAll\b|\bdeleteWhere\b'))));
    });

    test('the store names no method that edits or removes an entry', () {
      expect(
        source,
        isNot(contains(RegExp(
            r'\b(update|edit|delete|remove|clear)[A-Za-z]*Bodyweight',
            caseSensitive: false))),
        reason: 'the absence of the method is the enforcement -- if one is '
            'added, this is the test that has to be argued with first',
      );
    });

    test('the log notifier offers no way to date an entry', () {
      // `record(weightKg)` stamps the date itself. A `record(date, weight)`
      // would make backdating a one-argument mistake, which R9 forbids.
      final log = File('lib/src/data/personal_details_store.dart')
          .readAsStringSync();
      expect(log, contains('Future<void> record(double weightKg)'),
          reason: 'recording takes a weight and nothing else; the day is the '
              'day it was recorded');
    });
  });

  group('the gender field', () {
    test('a fresh database has no stored gender', () async {
      expect(await store.readBodyGender(), isNull,
          reason: 'null is how "never answered" is told apart from a user who '
              'chose Male, and the Profile screen renders that difference');
    });

    test('a written name reads back unchanged', () async {
      await store.writeBodyGender('female');
      expect(await store.readBodyGender(), 'female');
    });

    test('an unrecognised name is stored and returned verbatim', () async {
      // The store deals in opaque values on purpose -- deciding what a name
      // means belongs to body_gender.dart, which owns the vocabulary.
      await store.writeBodyGender('nonsense');
      expect(await store.readBodyGender(), 'nonsense');
    });

    test('writing twice leaves exactly one settings row', () async {
      await store.writeBodyGender('male');
      await store.writeBodyGender('female');

      expect(await SettingsStore(database).rowCount(), 1);
      expect(await store.readBodyGender(), 'female');
    });

    test('gender and the split filter share a row without clobbering it',
        () async {
      // Both writes upsert the one settings row. An UpdateCompanion carries
      // only the columns it was given, which is the whole reason this passes;
      // build either write as a read-modify-write of the full row and whichever
      // ran second silently resets the other.
      final settings = SettingsStore(database);

      await settings.writeWorkoutTemplateFilter('ppl');
      await store.writeBodyGender('female');

      expect(await settings.readWorkoutTemplateFilter(), 'ppl',
          reason: 'storing a gender must not reset the split filter');
      expect(await store.readBodyGender(), 'female');

      await settings.writeWorkoutTemplateFilter('single');

      expect(await store.readBodyGender(), 'female',
          reason: 'storing a filter must not reset the gender');
      expect(await settings.rowCount(), 1);
    });
  });

  group('resolving the stored gender', () {
    test('nothing stored resolves to male', () async {
      expect(await readStoredBodyGender(store), BodyGender.male);
      expect(kDefaultBodyGender, BodyGender.male,
          reason: "docs/04: skippable, defaulting to the male asset set");
    });

    test('a stored name resolves to its gender', () async {
      await store.writeBodyGender('female');
      expect(await readStoredBodyGender(store), BodyGender.female);
    });

    test('prefer-not-to-say survives the round trip as itself', () async {
      await store.writeBodyGender(BodyGender.preferNotToSay.name);

      expect(await readStoredBodyGender(store), BodyGender.preferNotToSay,
          reason: 'it renders the male artwork, but it is not the same answer '
              'as Male and must not be stored as one');
    });

    test('an unrecognised stored name falls back rather than throwing',
        () async {
      // A downgrade, or a hand-edited database. The first frame draws a body
      // map, so throwing here would be a crash on the app's opening screen.
      await store.writeBodyGender('nonbinary_artwork_that_never_shipped');
      expect(await readStoredBodyGender(store), BodyGender.male);
    });

    test('names are matched, never indexes', () {
      expect(BodyGender.fromName('preferNotToSay'), BodyGender.preferNotToSay);
      expect(BodyGender.fromName('2'), isNull,
          reason: 'reordering the enum must not repaint a stored choice');
      expect(BodyGender.fromName(null), isNull);
      for (final gender in BodyGender.values) {
        expect(BodyGender.fromName(gender.name), gender);
      }
    });
  });

  group('the provider seam', () {
    /// A container wired the way `main()` wires the real app: the database is
    /// the overridden one and the stored gender is already resolved, so the
    /// provider is synchronous from its first read.
    Future<ProviderContainer> boot(AppDatabase db) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          initialBodyGenderProvider.overrideWithValue(
            await readStoredBodyGender(PersonalDetailsStore(db)),
          ),
          initialBodyweightLogProvider.overrideWithValue(
            await readStoredBodyweightLog(PersonalDetailsStore(db)),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('an overridden database is the one the store writes to', () async {
      final overridden = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(overridden.close);

      final container = await boot(overridden);
      final seamStore = container.read(personalDetailsStoreProvider);
      await seamStore.writeBodyGender('female');
      await seamStore.appendBodyweightEntry('2026-09-14', 72.5);

      expect(
        await PersonalDetailsStore(overridden).readBodyGender(),
        'female',
        reason: 'if this resolved to the real constructor the test would be '
            'opening a file through a platform channel that does not exist',
      );
      expect(
        await PersonalDetailsStore(overridden).readBodyweightEntries(),
        hasLength(1),
      );
      expect(await store.readBodyGender(), isNull,
          reason: "the setUp database must not have seen the seam's writes");
    });

    test('a stored gender is what the provider starts on', () async {
      await store.writeBodyGender('female');

      final container = await boot(database);
      expect(container.read(bodyGenderProvider), BodyGender.female);
    });

    test('gender left unset reads as male', () async {
      final container = await boot(database);
      expect(container.read(bodyGenderProvider), BodyGender.male,
          reason: "an unset field keeps today's default rather than asking");
    });

    test('selecting a gender stores it and moves the provider', () async {
      final container = await boot(database);

      await container
          .read(bodyGenderProvider.notifier)
          .select(BodyGender.female);

      expect(container.read(bodyGenderProvider), BodyGender.female);
      expect(await store.readBodyGender(), 'female',
          reason: 'the choice has to survive the next cold start');
    });

    test('choosing the default on a fresh install is still recorded', () async {
      final container = await boot(database);

      await container.read(bodyGenderProvider.notifier).select(BodyGender.male);

      expect(await store.readBodyGender(), 'male',
          reason: 'Male was already showing but nothing was stored, so '
              'choosing it is a real answer -- swallowing the write would '
              'leave "I chose" indistinguishable from "I never answered"');
    });

    test('a stored series is what the log starts on', () async {
      await store.appendBodyweightEntry('2026-01-02', 75.0);
      await store.appendBodyweightEntry('2026-09-14', 72.5);

      final container = await boot(database);

      expect(
        container.read(bodyweightLogProvider),
        <BodyweightEntry>[
          BodyweightEntry(date: DateTime(2026, 1, 2), weightKg: 75.0),
          BodyweightEntry(date: DateTime(2026, 9, 14), weightKg: 72.5),
        ],
      );
    });

    test('recording a weight stores it dated today and moves the log',
        () async {
      final container = await boot(database);

      await container.read(bodyweightLogProvider.notifier).record(72.5);

      final today = todayLocal();
      expect(
        container.read(bodyweightLogProvider),
        <BodyweightEntry>[BodyweightEntry(date: today, weightKg: 72.5)],
      );
      expect(
        (await store.readBodyweightEntries()).single.date,
        encodeCalendarDate(today),
        reason: 'an entry takes effect from the day it is recorded (KD5), so '
            'the date is stamped rather than accepted',
      );
    });

    test('recording twice in a day replaces the day rather than appending',
        () async {
      final container = await boot(database);
      final log = container.read(bodyweightLogProvider.notifier);

      await log.record(72.5);
      await log.record(73.0);

      expect(
        container.read(bodyweightLogProvider),
        <BodyweightEntry>[BodyweightEntry(date: todayLocal(), weightKg: 73.0)],
        reason: 'the in-memory list and the table must agree about how many '
            'entries a day holds -- one',
      );
      expect(await store.readBodyweightEntries(), hasLength(1));
    });

    test('recording keeps the series oldest first', () async {
      await store.appendBodyweightEntry('2020-01-01', 80.0);
      final container = await boot(database);

      await container.read(bodyweightLogProvider.notifier).record(72.5);

      final dates = container
          .read(bodyweightLogProvider)
          .map((entry) => entry.date)
          .toList();
      expect(dates, <DateTime>[DateTime(2020, 1, 1), todayLocal()],
          reason: 'today is by construction the latest date, so the appended '
              'entry belongs at the end');
    });
  });

  group('the gender reaches the body map', () {
    /// A real `BodyDiagram` under the same wiring `main()` installs — the
    /// stored value resolved before the tree builds, rather than the provider
    /// being stubbed with the answer the test wants.
    Future<Widget> host(AppDatabase db) async => ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            initialBodyGenderProvider.overrideWithValue(
              await readStoredBodyGender(PersonalDetailsStore(db)),
            ),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 600,
                  child: BodyDiagram(
                    view: BodyView.front,
                    fill: mutedBodyFill,
                  ),
                ),
              ),
            ),
          ),
        );

    BodyDiagramPainter painterOf(WidgetTester tester) =>
        tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(BodyDiagram),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter! as BodyDiagramPainter;

    testWidgets('a stored female gender selects the female artwork',
        (tester) async {
      await store.writeBodyGender(BodyGender.female.name);

      await tester.pumpWidget(await host(database));

      expect(painterOf(tester).assetKey, 'frontFemale',
          reason: 'this is the assertion the Profile field exists for: a '
              'stored gender that never reaches the painter is a setting that '
              'does nothing, and no store test can see that');
    });

    testWidgets('nothing stored leaves the male artwork', (tester) async {
      await tester.pumpWidget(await host(database));

      expect(painterOf(tester).assetKey, 'frontMale');
    });

    testWidgets('changing the gender repaints without touching the caller',
        (tester) async {
      await tester.pumpWidget(await host(database));
      expect(painterOf(tester).assetKey, 'frontMale');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BodyDiagram)),
      );
      await container
          .read(bodyGenderProvider.notifier)
          .select(BodyGender.female);
      await tester.pump();

      expect(painterOf(tester).assetKey, 'frontFemale',
          reason: "docs/04: changing gender in Profile switches the diagram "
              'set app-wide, and no diagram takes it as a parameter');
    });
  });
}
