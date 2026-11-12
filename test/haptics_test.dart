import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/haptics.dart';
import 'package:turtle_lift/src/ui/set_row.dart';
import 'package:turtle_lift/src/ui/stepper_field.dart';

import 'support/haptic_log.dart';

/// The haptic vocabulary (research item 1): one meaning per pattern, defined
/// once in `AppHaptics`, and nothing on scroll or navigation.
///
/// Mark exercise done and Finish are proven where those buttons live
/// (`set_logging_test.dart`, `session_overview_parts_test.dart`).
void main() {
  group('the vocabulary is fixed', () {
    testWidgets('a step is a selection click, a set a medium impact, an '
        'ending a success notification', (tester) async {
      final log = recordHaptics(tester);

      await AppHaptics.step();
      await AppHaptics.setDone();
      await AppHaptics.success();

      expect(log, <String>[kHapticStep, kHapticSetDone, kHapticSuccess]);
    });
  });

  group('the stepper', () {
    testWidgets('each + and - tap clicks once', (tester) async {
      final log = recordHaptics(tester);
      double? value = 60;
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => StepperField(
              value: value,
              step: 2.5,
              decimals: 1,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ));

      await tester.tap(find.bySemanticsLabel('Increase'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Decrease'));
      await tester.pump();

      expect(log, <String>[kHapticStep, kHapticStep]);
      expect(value, 60);
    });

    testWidgets('typing a value is silent', (tester) async {
      final log = recordHaptics(tester);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: StepperField(value: null, step: 1, onChanged: (_) {}),
        ),
      ));

      await tester.enterText(find.byType(TextField), '8');
      await tester.pump();

      expect(log, isEmpty);
    });
  });

  group('the set tick', () {
    Future<List<String>> tickRow(WidgetTester tester, SetEntry entry) async {
      final log = recordHaptics(tester);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SetRow(
            index: 0,
            loadType: LoadType.weighted,
            entry: entry,
            isPrefill: false,
            onChanged: (_) {},
            onToggleComplete: () {},
            onDelete: () {},
          ),
        ),
      ));
      await tester.tap(find.byKey(SetRow.checkKey(0)));
      await tester.pump();
      return log;
    }

    testWidgets('completing a set is one impact', (tester) async {
      final log = await tickRow(
        tester,
        const SetEntry(
            id: 's', position: 0, completed: false, weightKg: 60, reps: 8),
      );
      expect(log, <String>[kHapticSetDone]);
    });

    testWidgets('unticking a set is silent', (tester) async {
      final log = await tickRow(
        tester,
        const SetEntry(
            id: 's', position: 0, completed: true, weightKg: 60, reps: 8),
      );
      expect(log, isEmpty);
    });

    testWidgets('a tick refused for an empty row is silent', (tester) async {
      final log = await tickRow(
        tester,
        const SetEntry(id: 's', position: 0, completed: false, weightKg: 60),
      );
      expect(log, isEmpty, reason: 'nothing was completed');
    });
  });
}
