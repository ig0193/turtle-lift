import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/personal_details_screen.dart';
import 'package:turtle_lift/src/ui/set_row.dart';
import 'package:turtle_lift/src/ui/stepper_field.dart';

/// QA (second pass, input edge cases): what a user can type or paste into the
/// app's number fields.
///
/// - **Comma decimals.** On a device whose region writes "77,5", the iOS
///   decimal pad offers a comma and no full stop. The fields kept only digits
///   and '.', so "77,5" was stored as 775 kg.
/// - **A second decimal point** ("7.7.5") left the text on screen while the
///   value underneath was null.
/// - **More decimals than the field takes** ("77.25" in a one-decimal weight)
///   was stored as typed and shown rounded.
/// - **A pasted run of digits** overflowed: 400 digits parse to Infinity and
///   the reps field's `round()` threw.
void main() {
  Future<List<double?>> pumpField(
    WidgetTester tester, {
    int decimals = 1,
  }) async {
    final values = <double?>[];
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => StepperField(
            value: values.isEmpty ? null : values.last,
            step: 2.5,
            decimals: decimals,
            onChanged: (v) => setState(() => values.add(v)),
          ),
        ),
      ),
    ));
    return values;
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  group('the stepper field', () {
    testWidgets('a comma is a decimal point, not dropped', (tester) async {
      final values = await pumpField(tester);
      await tester.enterText(find.byType(TextField), '77,5');
      await tester.pump();

      expect(values.last, 77.5);
      expect(fieldText(tester), '77.5');
    });

    testWidgets('a second decimal point is refused', (tester) async {
      final values = await pumpField(tester);
      await tester.enterText(find.byType(TextField), '7.7');
      await tester.pump();
      await tester.enterText(find.byType(TextField), '7.7.5');
      await tester.pump();

      expect(fieldText(tester), '7.7');
      expect(values.last, 7.7);
    });

    testWidgets('more decimals than the field takes are refused',
        (tester) async {
      final values = await pumpField(tester);
      await tester.enterText(find.byType(TextField), '77.2');
      await tester.pump();
      await tester.enterText(find.byType(TextField), '77.25');
      await tester.pump();

      expect(fieldText(tester), '77.2');
      expect(values, isNot(contains(77.25)));
    });

    testWidgets('a whole-number field refuses a decimal point',
        (tester) async {
      final values = await pumpField(tester, decimals: 0);
      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();
      await tester.enterText(find.byType(TextField), '12.5');
      await tester.pump();

      expect(fieldText(tester), '12');
      expect(values.last, 12);
    });

    testWidgets('large real values still go in', (tester) async {
      final values = await pumpField(tester);
      await tester.enterText(find.byType(TextField), '9999.5');
      await tester.pump();
      expect(values.last, 9999.5);
    });

    testWidgets('a pasted run of digits is refused, not stored as infinity',
        (tester) async {
      final values = await pumpField(tester, decimals: 0);
      await tester.enterText(find.byType(TextField), '1' * 400);
      await tester.pump();

      expect(values.every((v) => v == null || v.isFinite), isTrue);
      expect(fieldText(tester).length, lessThanOrEqualTo(5));
    });
  });

  group('the set row', () {
    testWidgets('pasting a huge number into reps does not throw',
        (tester) async {
      var current = const SetEntry(id: 's', position: 0, completed: false);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SetRow(
              index: 0,
              loadType: LoadType.bodyweight,
              entry: current,
              isPrefill: false,
              onChanged: (next) => setState(() => current = next),
              onToggleComplete: () {},
              onDelete: () {},
            ),
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField).first, '9' * 400);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(current.reps == null || current.reps! <= 99999, isTrue);
    });
  });

  group('the bodyweight field', () {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    testWidgets('records "77,5" as 77.5 kg', (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          initialBodyGenderProvider.overrideWithValue(BodyGender.male),
          initialBodyweightLogProvider
              .overrideWithValue(const <BodyweightEntry>[]),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const PersonalDetailsScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(PersonalDetailsScreen.weightFieldKey), '77,5');
      await tester.tap(find.byKey(PersonalDetailsScreen.recordKey));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
          tester.element(find.byType(PersonalDetailsScreen)));
      final log = container.read(bodyweightLogProvider);
      expect(log, hasLength(1));
      expect(log.single.weightKg, 77.5);
    });
  });
}
