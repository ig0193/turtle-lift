import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/diet_plan.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/bodyweight_trend_chart.dart';
import 'package:turtle_lift/src/ui/personal_details_screen.dart';
import 'package:turtle_lift/src/ui/protein_target_screen.dart';

/// ADR 0014 §2 and §3: the weight log shows its shape, and a weigh-in that
/// moves the protein suggestion says so at that moment, without ever changing
/// the stored target by itself (ADR 0007).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  BodyweightEntry e(int y, int m, int d, double kg) =>
      BodyweightEntry(date: DateTime(y, m, d), weightKg: kg);

  group('bodyweightTrendSummary', () {
    test('names the first and last weight, the count and the start date', () {
      expect(
        bodyweightTrendSummary(
          <BodyweightEntry>[e(2026, 10, 27, 72), e(2026, 11, 3, 73), e(2026, 11, 10, 74.5)],
          today: const LocalDate(2026, 11, 10),
        ),
        'From 72 to 74.5 kg over 3 weigh-ins since 27 Oct.',
      );
    });

    test('says steady when the weight did not move', () {
      expect(
        bodyweightTrendSummary(
          <BodyweightEntry>[e(2025, 12, 1, 80), e(2026, 1, 5, 80)],
          today: const LocalDate(2026, 11, 10),
        ),
        'Steady at 80 kg over 2 weigh-ins since 1 Dec 2025.',
      );
    });
  });

  test('the trend painter draws in palette greys only, never amber', () {
    final painter = BodyweightTrendPainter(
      entries: <BodyweightEntry>[e(2026, 10, 27, 72), e(2026, 11, 10, 74)],
      textScaler: TextScaler.noScaling,
    );
    expect(painter.colorsUsed, isNot(contains(AppPalette.accentStrong)));
    final greys = <Color>{
      AppPalette.border,
      AppPalette.surface,
      AppPalette.textPrimary,
      AppPalette.textSecondary,
      AppPalette.textMuted,
    };
    expect(greys.containsAll(painter.colorsUsed), isTrue);
  });

  late AppDatabase database;
  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Widget host({List<BodyweightEntry> entries = const [], int? target}) =>
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          initialBodyGenderProvider.overrideWithValue(BodyGender.male),
          initialBodyweightLogProvider.overrideWithValue(entries),
          initialProteinTargetProvider.overrideWithValue(target),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const PersonalDetailsScreen(),
        ),
      );

  testWidgets('no chart with one weigh-in; a chart with two, spoken as one '
      'sentence', (tester) async {
    await tester.pumpWidget(host(entries: [e(2026, 10, 27, 72)]));
    await tester.pumpAndSettle();
    expect(find.byType(BodyweightTrendChart), findsNothing);

    await tester.pumpWidget(
        host(entries: [e(2026, 10, 27, 72), e(2026, 11, 3, 73)]));
    await tester.pumpAndSettle();
    expect(find.byType(BodyweightTrendChart), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^From 72 to 73 kg over 2 weigh-ins')),
      findsOneWidget,
    );
  });

  Future<void> record(WidgetTester tester, String kg) async {
    await tester.enterText(
        find.byKey(PersonalDetailsScreen.weightFieldKey), kg);
    await tester.tap(find.byKey(PersonalDetailsScreen.recordKey));
    await tester.pumpAndSettle();
  }

  testWidgets('a weigh-in that moves the suggestion offers Update target, '
      'which opens the target screen filled with it', (tester) async {
    await tester.pumpWidget(host(target: 100));
    await tester.pumpAndSettle();
    await record(tester, '80');

    expect(find.textContaining('Protein suggestion is now 130 g'),
        findsOneWidget);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(PersonalDetailsScreen)));
    expect(container.read(proteinTargetProvider), 100,
        reason: 'the stored target never changes by itself (ADR 0007)');

    await tester.ensureVisible(
        find.byKey(PersonalDetailsScreen.updateTargetKey));
    await tester.tap(find.byKey(PersonalDetailsScreen.updateTargetKey));
    await tester.pumpAndSettle();
    expect(find.byType(ProteinTargetScreen), findsOneWidget);
    final field = tester.widget<TextField>(
        find.byKey(ProteinTargetScreen.fieldKey));
    expect(field.controller!.text, '130');
  });

  testWidgets('no follow-up without a target, or when it already matches',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await record(tester, '80');
    expect(find.byKey(PersonalDetailsScreen.updateTargetKey), findsNothing);

    await tester.pumpWidget(host(target: 130));
    await tester.pumpAndSettle();
    await record(tester, '80');
    expect(find.byKey(PersonalDetailsScreen.updateTargetKey), findsNothing);
  });

  testWidgets('the target screen names the weigh-in its suggestion uses',
      (tester) async {
    final today = LocalDate.today();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        planTodayProvider.overrideWithValue(today),
        initialBodyweightLogProvider.overrideWithValue(<BodyweightEntry>[
          BodyweightEntry(date: DateTime(today.year, 1, 5), weightKg: 75),
        ]),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const ProteinTargetScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(
      find.text('1.6 g per kg at 75 kg, your weigh-in on 5 Jan. '
          'A common starting point.'),
      findsOneWidget,
    );
  });
}
