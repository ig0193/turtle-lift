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

  testWidgets('a short value keeps the full 15pt', (tester) async {
    expect(await sizeFor(tester, 60, 200), 15);
  });

  testWidgets('a long value in a narrow field shrinks below 15pt',
      (tester) async {
    expect(await sizeFor(tester, 102.5, 130), lessThan(15));
  });

  testWidgets('the value ignores system text scaling, so 1.3x cannot clip it',
      (tester) async {
    await sizeFor(tester, 77.5, 140, textScale: 1.3);
    final field = find.byType(TextField);
    expect(MediaQuery.textScalerOf(tester.element(field)), TextScaler.noScaling);
  });
}
