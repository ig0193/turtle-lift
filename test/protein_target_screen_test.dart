import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/diet_plan.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/ghost_button.dart';
import 'package:turtle_lift/src/ui/personal_details_screen.dart';
import 'package:turtle_lift/src/ui/protein_target_screen.dart';

/// The daily protein target screen (U13; R15, R16, KD3, KTD12, AE5).
///
/// "Today" is the real date here, because a bodyweight recorded on Personal
/// details is stamped with the device's today, and the suggestion reads the
/// weight in effect on [planTodayProvider]'s today.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  final today = LocalDate.today();

  /// A launcher with one button that pushes the target screen, so Back and
  /// Save have somewhere to return to.
  Widget host({int? target, double? kg}) => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          planTodayProvider.overrideWithValue(today),
          initialProteinTargetProvider.overrideWithValue(target),
          initialBodyweightLogProvider.overrideWithValue(<BodyweightEntry>[
            if (kg != null)
              BodyweightEntry(
                  date: today.addDays(-3).toDateTime(), weightKg: kg),
          ]),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => pushProteinTargetScreen(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> open(WidgetTester tester,
      {int? target, double? kg, Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(target: target, kg: kg));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  String fieldText(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(ProteinTargetScreen.fieldKey))
      .controller!
      .text;

  FilledButton save(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(ProteinTargetScreen.saveKey));

  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  group('the screen', () {
    testWidgets('is a pushed screen titled "Daily protein target" with one '
        'filled button', (tester) async {
      await open(tester, kg: 72);

      expect(find.text(ProteinTargetScreen.title), findsOneWidget);
      expect(ProteinTargetScreen.title, 'Daily protein target');
      expect(find.byType(FilledButton), findsOneWidget,
          reason: 'Save is the one primary action');
      expect(find.descendant(
              of: find.byType(FilledButton), matching: find.text('Save')),
          findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
    });

    testWidgets('shows the medical note and the source line', (tester) async {
      await open(tester);

      expect(ProteinTargetScreen.medicalNote,
          'A guide, not medical advice. If you have a health condition, '
          'talk to a doctor before changing your diet.');
      expect(ProteinTargetScreen.sourceLine,
          'Source: Morton et al. 2018, Br J Sports Med; ISSN position stand '
          '2017 (1.4 to 2.0 g per kg).');
      await tester.ensureVisible(find.text(ProteinTargetScreen.sourceLine));
      expect(find.text(ProteinTargetScreen.medicalNote), findsOneWidget);
      expect(find.text(ProteinTargetScreen.sourceLine), findsOneWidget);
    });

    testWidgets('opens on the stored target', (tester) async {
      await open(tester, target: 120);
      expect(fieldText(tester), '120');
    });
  });

  group('the suggestion (KD3, KTD12)', () {
    testWidgets('AE5: 72 kg suggests 115 g with its working', (tester) async {
      await open(tester, kg: 72);

      final row = find.byKey(ProteinTargetScreen.suggestionKey);
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Suggested 115 g')),
          findsOneWidget);
      expect(
        find.descendant(
            of: row,
            matching: find.text('1.6 g per kg at 72 kg, your current '
                'bodyweight. A common starting point.')),
        findsOneWidget,
      );
      expect(find.byKey(ProteinTargetScreen.addBodyweightKey), findsNothing);
    });

    testWidgets('AE5: tapping it fills the field and saves nothing',
        (tester) async {
      await open(tester, kg: 72);

      await tester.tap(find.byKey(ProteinTargetScreen.suggestionKey));
      await tester.pumpAndSettle();
      expect(fieldText(tester), '115');
      expect(containerOf(tester).read(proteinTargetProvider), isNull);

      await back(tester);
      expect(containerOf(tester).read(proteinTargetProvider), isNull);
      expect(await SettingsStore(database).readProteinTarget(), isNull,
          reason: 'leaving without Save stores nothing');
    });

    testWidgets('a half-kilo weight shows its half in the working',
        (tester) async {
      await open(tester, kg: 68.5);

      // 1.6 x 68.5 = 109.6 -> 110.
      expect(find.text('Suggested 110 g'), findsOneWidget);
      expect(find.textContaining('at 68.5 kg'), findsOneWidget);
    });

    testWidgets(
        'with no bodyweight there is no suggestion; the link pushes Personal '
        'details, and recording 80 kg there shows "Suggested 130 g" on return',
        (tester) async {
      // Wide enough for Personal details' gender row in the test font.
      await open(tester, size: const Size(600, 1000));

      expect(find.byKey(ProteinTargetScreen.suggestionKey), findsNothing);
      final link = find.byKey(ProteinTargetScreen.addBodyweightKey);
      expect(link, findsOneWidget);
      expect(find.descendant(
              of: link,
              matching: find.text('Add your bodyweight to get a suggestion')),
          findsOneWidget);

      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byType(PersonalDetailsScreen), findsOneWidget);

      await tester.enterText(
          find.byKey(PersonalDetailsScreen.weightFieldKey), '80');
      await tester.tap(find.byKey(PersonalDetailsScreen.recordKey));
      await tester.pumpAndSettle();

      await back(tester);
      expect(find.byType(ProteinTargetScreen), findsOneWidget,
          reason: 'Back returns to the target screen, not the pane');
      expect(find.text('Suggested 130 g'), findsOneWidget);
      expect(find.byKey(ProteinTargetScreen.addBodyweightKey), findsNothing);
    });
  });

  group('saving (R15)', () {
    testWidgets('Save stores the whole number and returns', (tester) async {
      await open(tester, kg: 72);

      await tester.enterText(find.byKey(ProteinTargetScreen.fieldKey), '125');
      await tester.pump();
      await tester.tap(find.byKey(ProteinTargetScreen.saveKey));
      await tester.pumpAndSettle();

      expect(find.byType(ProteinTargetScreen), findsNothing);
      expect(containerOf(tester).read(proteinTargetProvider), 125);
      expect(await SettingsStore(database).readProteinTarget(), 125);
    });

    testWidgets('accepting the suggestion stores the number', (tester) async {
      await open(tester, kg: 72);

      await tester.tap(find.byKey(ProteinTargetScreen.suggestionKey));
      await tester.pump();
      await tester.tap(find.byKey(ProteinTargetScreen.saveKey));
      await tester.pumpAndSettle();

      expect(await SettingsStore(database).readProteinTarget(), 115);
    });

    for (final bad in <String>['0', '401']) {
      testWidgets('$bad cannot be saved and the reason shows beside the field',
          (tester) async {
        await open(tester, target: 120);

        await tester.enterText(find.byKey(ProteinTargetScreen.fieldKey), bad);
        await tester.pump();

        expect(save(tester).onPressed, isNull);
        final reason = find.byKey(ProteinTargetScreen.reasonKey);
        expect(reason, findsOneWidget);
        expect(find.descendant(
                of: reason, matching: find.text(ProteinTargetScreen.rangeReason)),
            findsOneWidget);
        expect(ProteinTargetScreen.rangeReason, 'Whole grams, 1 to 400');

        await tester.tap(find.byKey(ProteinTargetScreen.saveKey));
        await tester.pumpAndSettle();
        expect(find.byType(ProteinTargetScreen), findsOneWidget);
        expect(containerOf(tester).read(proteinTargetProvider), 120);
      });
    }

    testWidgets('1 and 400 save; a valid number shows no reason',
        (tester) async {
      await open(tester);

      await tester.enterText(find.byKey(ProteinTargetScreen.fieldKey), '400');
      await tester.pump();
      expect(find.byKey(ProteinTargetScreen.reasonKey), findsNothing);
      expect(save(tester).onPressed, isNotNull);

      await tester.enterText(find.byKey(ProteinTargetScreen.fieldKey), '1');
      await tester.pump();
      await tester.tap(find.byKey(ProteinTargetScreen.saveKey));
      await tester.pumpAndSettle();
      expect(containerOf(tester).read(proteinTargetProvider), 1);
    });

    testWidgets('an empty field cannot be saved and gives no reason',
        (tester) async {
      await open(tester);

      expect(fieldText(tester), isEmpty);
      expect(save(tester).onPressed, isNull);
      expect(find.byKey(ProteinTargetScreen.reasonKey), findsNothing);
    });

    testWidgets('the field takes digits only', (tester) async {
      await open(tester);

      await tester.enterText(find.byKey(ProteinTargetScreen.fieldKey), '12.5');
      await tester.pump();
      expect(fieldText(tester), '125');
    });
  });

  group('clearing', () {
    testWidgets('no target: no Clear target', (tester) async {
      await open(tester, kg: 72);
      expect(find.byKey(ProteinTargetScreen.clearKey), findsNothing);
    });

    testWidgets('Clear target is a ghost button that removes it and returns',
        (tester) async {
      await open(tester, target: 120);

      final clear = find.byKey(ProteinTargetScreen.clearKey);
      expect(clear, findsOneWidget);
      expect(
          find.ancestor(of: clear, matching: find.byType(GhostButton)),
          findsOneWidget);
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(find.byType(ProteinTargetScreen), findsNothing);
      expect(containerOf(tester).read(proteinTargetProvider), isNull);
      expect(await SettingsStore(database).readProteinTarget(), isNull);
    });
  });

  testWidgets('copy ban: no verdict words and no em or en dash',
      (tester) async {
    for (final kg in <double?>[null, 72]) {
      await open(tester, target: 120, kg: kg);
      final copy = <String>[
        ...tester
            .widgetList<Text>(find.descendant(
                of: find.byType(ProteinTargetScreen),
                matching: find.byType(Text)))
            .map((t) => t.data ?? t.textSpan!.toPlainText()),
        ProteinTargetScreen.title,
        ProteinTargetScreen.medicalNote,
        ProteinTargetScreen.sourceLine,
        ProteinTargetScreen.rangeReason,
      ];
      for (final text in copy) {
        expectNoBannedCopy(text);
      }
      await back(tester);
    }
  });

  // QA (Maestro): the iOS number pad has no return key; a tap off the field
  // must put it away, or it sits over the screen's lower half.
  testWidgets('a tap outside the field puts the number pad away',
      (tester) async {
    await open(tester, target: 120);
    await tester.showKeyboard(find.byKey(ProteinTargetScreen.fieldKey));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tapAt(const Offset(195, 830));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
  });
}

/// R17's verdict words, and the dashes the taste pass bans.
void expectNoBannedCopy(String text) {
  final lower = text.toLowerCase();
  for (final banned in <String>[
    'behind',
    'missed',
    'failed',
    'over',
    'great job',
    '–',
    '—',
  ]) {
    expect(lower.contains(banned), isFalse, reason: '"$text" has "$banned"');
  }
}
