import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/date_labels.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/personal_details_screen.dart';

/// Profile audit B1-B3 (`docs/research/profile-tab-audit.md`, ADR 0014):
/// a bodyweight is refused outside a plausible range with a reason, the log
/// prints dates in the app's one format, and recording says what happened.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('parseBodyweight', () {
    test('accepts 20 to 250 kg, with a comma or a point', () {
      expect(parseBodyweight('72.5'), 72.5);
      expect(parseBodyweight('72,5'), 72.5);
      expect(parseBodyweight(' 20 '), 20);
      expect(parseBodyweight('250'), 250);
    });

    test('refuses anything outside the range or not a number', () {
      for (final junk in <String>['', 'abc', '0', '0.5', '19.9', '250.1', '-5']) {
        expect(parseBodyweight(junk), isNull, reason: junk);
      }
    });

    test('the top of the range keeps the 1.6 g/kg suggestion inside the '
        'protein target cap', () {
      expect((kMaxBodyweightKg * 1.6).round(), lessThanOrEqualTo(400));
    });
  });

  late AppDatabase database;
  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Widget host({List<BodyweightEntry> entries = const <BodyweightEntry>[]}) =>
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          initialBodyGenderProvider.overrideWithValue(BodyGender.male),
          initialBodyweightLogProvider.overrideWithValue(entries),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const PersonalDetailsScreen(),
        ),
      );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(PersonalDetailsScreen)),
      );

  test('choosing a body diagram never clears the protein target (both live '
      'on the one settings row)', () async {
    await SettingsStore(database).writeProteinTarget(120);
    await PersonalDetailsStore(database).writeBodyGender('female');
    expect(await SettingsStore(database).readProteinTarget(), 120);
  });

  testWidgets('B1: 0.5 kg shows the reason and records nothing',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(PersonalDetailsScreen.weightFieldKey), '0.5');
    await tester.pump();
    expect(find.text(PersonalDetailsScreen.rangeReason), findsOneWidget);

    await tester.tap(find.byKey(PersonalDetailsScreen.recordKey));
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(bodyweightLogProvider), isEmpty);
  });

  testWidgets('B1: no reason while the field is empty or valid',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text(PersonalDetailsScreen.rangeReason), findsNothing);

    await tester.enterText(
        find.byKey(PersonalDetailsScreen.weightFieldKey), '74.5');
    await tester.pump();
    expect(find.text(PersonalDetailsScreen.rangeReason), findsNothing);
  });

  testWidgets('B3: recording says what was recorded, as a live region',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(PersonalDetailsScreen.weightFieldKey), '74.5');
    await tester.tap(find.byKey(PersonalDetailsScreen.recordKey));
    await tester.pumpAndSettle();

    final status = find.text('Recorded 74.5 kg for today.');
    expect(status, findsOneWidget);
    final live = find.ancestor(
      of: status,
      matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.liveRegion ?? false)),
    );
    expect(live, findsOneWidget);
  });

  testWidgets('B3: the screen says today can be replaced and earlier cannot',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text(PersonalDetailsScreen.correctionNote), findsOneWidget);
    expect(PersonalDetailsScreen.correctionNote, contains('midnight'));
  });

  testWidgets('B2: log rows use the day-month date format, not ISO',
      (tester) async {
    final today = LocalDate.today();
    final earlier = DateTime(today.year - 1, 10, 27);
    await tester.pumpWidget(host(entries: <BodyweightEntry>[
      BodyweightEntry(date: earlier, weightKg: 72),
    ]));
    await tester.pumpAndSettle();

    final label = shortDateLabel(LocalDate.fromDateTime(earlier));
    expect(label, '27 Oct ${today.year - 1}');
    expect(find.text('from $label'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d{4}-\d{2}-\d{2}')), findsNothing);
  });
}
