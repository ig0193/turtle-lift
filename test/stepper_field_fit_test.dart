import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/stepper_field.dart';

/// A weight that does not fit its box must shrink, never clip: "102." on the
/// screen is a wrong number for the bar.
void main() {
  Future<double> sizeFor(WidgetTester tester, double value, double width,
      {double textScale = 1}) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: StepperField(
                value: value,
                step: 2.5,
                decimals: 1,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    ));
    return tester.widget<TextField>(find.byType(TextField)).style!.fontSize!;
  }

  testWidgets('a short value keeps the full size', (tester) async {
    expect(await sizeFor(tester, 60, 200), StepperField.maxValueSize);
  });

  testWidgets('a long value in a narrow field shrinks below the full size',
      (tester) async {
    expect(await sizeFor(tester, 102.5, 130),
        lessThan(StepperField.maxValueSize));
  });

  testWidgets('the value ignores system text scaling, so 1.3x cannot clip it',
      (tester) async {
    await sizeFor(tester, 77.5, 140, textScale: 1.3);
    final field = find.byType(TextField);
    expect(MediaQuery.textScalerOf(tester.element(field)), TextScaler.noScaling);
  });

  group('optional bounds', () {
    Future<List<double?>> stepAndRecord(
      WidgetTester tester, {
      required double value,
      required IconData glyph,
      double? min,
      double? max,
      int taps = 3,
    }) async {
      final seen = <double?>[];
      var current = value;
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: StatefulBuilder(
                builder: (context, setState) => StepperField(
                  value: current,
                  step: 0.5,
                  decimals: 1,
                  min: min,
                  max: max,
                  onChanged: (v) {
                    seen.add(v);
                    setState(() => current = v ?? current);
                  },
                ),
              ),
            ),
          ),
        ),
      ));
      for (var i = 0; i < taps; i++) {
        await tester.tap(find.byIcon(glyph));
        await tester.pump();
      }
      return seen;
    }

    testWidgets('stepping down stops at min', (tester) async {
      final seen = await stepAndRecord(tester,
          value: 1, glyph: Icons.remove_rounded, min: 0.5, max: 4);
      expect(seen, <double?>[0.5],
          reason: 'one step to 0.5, then the button is spent');
      expect(find.text('0.5'), findsOneWidget);
    });

    testWidgets('stepping up stops at max', (tester) async {
      final seen = await stepAndRecord(tester,
          value: 3, glyph: Icons.add_rounded, min: 0.5, max: 4);
      expect(seen, <double?>[3.5, 4]);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('a spent button is announced as disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await stepAndRecord(tester,
          value: 4, glyph: Icons.add_rounded, min: 0.5, max: 4, taps: 0);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Increase')),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Decrease')),
        isSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('without bounds the floor is still 0 and nothing disables',
        (tester) async {
      final handle = tester.ensureSemantics();
      final seen = await stepAndRecord(tester, value: 0.5, glyph: Icons.remove_rounded);
      expect(seen, <double?>[0, 0, 0],
          reason: 'existing callers keep their unsigned floor and behaviour');
      expect(
        tester.getSemantics(find.bySemanticsLabel('Decrease')),
        isSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true),
      );
      handle.dispose();
    });
  });
}
