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
import 'package:turtle_lift/src/ui/personal_details_screen.dart';

/// The two things the app collects about the user, and the log of one of them.
///
/// The load-bearing test in this file is the one that finds **no** edit or
/// delete affordance on a weight row. A bodyweight entry is immutable because
/// the calorie estimate resolves the weight *in effect on* a session's date, so
/// an edit silently re-prices logged history. That rule is invisible in the
/// rendered pixels, which is exactly why it needs a test rather than a comment.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Widget host({
    BodyGender gender = BodyGender.male,
    List<BodyweightEntry> entries = const <BodyweightEntry>[],
  }) =>
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          initialBodyGenderProvider.overrideWithValue(gender),
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

  group('gender', () {
    testWidgets('renders all three options docs/04 specifies', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      for (final option in BodyGender.values) {
        expect(find.byKey(PersonalDetailsScreen.genderKey(option)),
            findsOneWidget);
      }
      expect(find.text('Prefer not to say'), findsOneWidget);
    });

    testWidgets('choosing one stores it', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(PersonalDetailsScreen.genderKey(BodyGender.female)));
      await tester.pumpAndSettle();

      expect(containerOf(tester).read(bodyGenderProvider), BodyGender.female);
      expect(
        await containerOf(tester).read(personalDetailsStoreProvider)
            .readBodyGender(),
        'female',
        reason: 'stored by name, so reordering the enum cannot repaint a '
            "user's diagrams",
      );
    });

    testWidgets('the stored choice is the one shown on arrival',
        (tester) async {
      await tester.pumpWidget(host(gender: BodyGender.preferNotToSay));
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(bodyGenderProvider),
        BodyGender.preferNotToSay,
        reason: '"I declined" is a different answer from "never asked", and '
            'the screen has to render the difference',
      );
    });
  });

  group('recording a weight', () {
    testWidgets('puts it in the log, dated today', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(PersonalDetailsScreen.weightFieldKey), '78.5');
      await tester.tap(find.byKey(PersonalDetailsScreen.recordKey));
      await tester.pumpAndSettle();

      final log = containerOf(tester).read(bodyweightLogProvider);
      expect(log, hasLength(1));
      expect(log.single.weightKg, 78.5);
      expect(log.single.date, todayLocal());
      expect(
        find.byKey(
          PersonalDetailsScreen.weightRowKey(encodeCalendarDate(todayLocal())),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a second weight the same day replaces rather than appends',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      for (final value in <String>['78', '79']) {
        await tester.enterText(
            find.byKey(PersonalDetailsScreen.weightFieldKey), value);
        await tester.tap(find.byKey(PersonalDetailsScreen.recordKey));
        await tester.pumpAndSettle();
      }

      final log = containerOf(tester).read(bodyweightLogProvider);
      expect(
        log,
        hasLength(1),
        reason: 'today is the only day that can be corrected, and correcting '
            'it means replacing it -- not keeping both',
      );
      expect(log.single.weightKg, 79);
    });

    testWidgets('a non-numeric or zero entry is ignored', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      for (final junk in <String>['', 'abc', '0', '-5']) {
        await tester.enterText(
            find.byKey(PersonalDetailsScreen.weightFieldKey), junk);
        await tester.tap(find.byKey(PersonalDetailsScreen.recordKey));
        await tester.pumpAndSettle();
      }

      expect(containerOf(tester).read(bodyweightLogProvider), isEmpty);
    });

    testWidgets('the newest entry is listed first', (tester) async {
      final older = DateTime(2026, 9, 1);
      await tester.pumpWidget(host(
        entries: <BodyweightEntry>[
          BodyweightEntry(date: older, weightKg: 74),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(PersonalDetailsScreen.weightFieldKey), '76');
      await tester.tap(find.byKey(PersonalDetailsScreen.recordKey));
      await tester.pumpAndSettle();

      final newestRow = tester.getRect(find.byKey(
        PersonalDetailsScreen.weightRowKey(encodeCalendarDate(todayLocal())),
      ));
      final olderRow = tester.getRect(find.byKey(
        PersonalDetailsScreen.weightRowKey(encodeCalendarDate(older)),
      ));

      expect(newestRow.top, lessThan(olderRow.top));
    });
  });

  group('the immutability rule', () {
    testWidgets('no weight row offers edit, delete or any tap at all',
        (tester) async {
      await tester.pumpWidget(host(
        entries: <BodyweightEntry>[
          BodyweightEntry(date: DateTime(2026, 9, 1), weightKg: 74),
          BodyweightEntry(date: DateTime(2026, 9, 8), weightKg: 75),
        ],
      ));
      await tester.pumpAndSettle();

      for (final iso in <String>['2026-09-01', '2026-09-08']) {
        final row = find.byKey(PersonalDetailsScreen.weightRowKey(iso));
        expect(row, findsOneWidget);

        expect(
          find.descendant(of: row, matching: find.byType(GestureDetector)),
          findsNothing,
          reason: 'a recorded weight cannot be edited, deleted or backdated '
              '(KD5), so the row offers nothing to hang an action on. A '
              'GestureDetector appearing here is the regression.',
        );
        expect(
          find.descendant(of: row, matching: find.byType(Dismissible)),
          findsNothing,
          reason: 'a swipe-to-delete here would re-price logged history',
        );
        expect(
          find.descendant(of: row, matching: find.byType(IconButton)),
          findsNothing,
        );
      }
    });

    testWidgets('the screen offers no date control', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // Backdating is the third way to move a past figure, and the screen
      // forecloses it by having no date input at all rather than by validating
      // one.
      expect(find.byType(CalendarDatePicker), findsNothing);
      expect(find.textContaining('Date'), findsNothing);
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'the weight is the only thing the user types here',
      );
    });
  });

  group('the empty state', () {
    testWidgets('prompts rather than showing a zero', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text(PersonalDetailsScreen.noWeightLabel), findsOneWidget);
      expect(
        find.text('0 kg'),
        findsNothing,
        reason: 'docs/01 chose a prompt over a wrong number everywhere the '
            'calorie stat is gated',
      );
    });

    testWidgets('says that earlier sessions never get a figure',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // The permanence is the part a user would otherwise discover by
      // accident, so the copy has to carry it.
      expect(find.textContaining('never'), findsWidgets);
    });
  });

  group('the calorie explainer', () {
    testWidgets('carries the three effort tiers and the honesty note',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('1–9 sets'), findsOneWidget);
      expect(find.text('10–20 sets'), findsOneWidget);
      expect(find.text('21+ sets'), findsOneWidget);
      expect(find.textContaining('vary by person'), findsOneWidget);
    });

    testWidgets('states that a recorded weight never moves a logged workout',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('never changes a workout you already logged'),
        findsOneWidget,
        reason: 'this is the promise the whole dated series exists to make, '
            'and the user should be told it where they set the weight',
      );
    });
  });
}
