import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/finish_celebration.dart';

/// QA (second pass, reduced motion): the finish celebration read only
/// `MediaQuery.disableAnimations`, which is Android's flag. iOS reports
/// Reduce Motion as `reduceMotion` and leaves `disableAnimations` false (see
/// `GlassTabBar.prefersReducedMotion`), so on an iPhone with Reduce Motion on
/// the ring still radiated and the check still scaled in.
void main() {
  Future<int> ringsWhilePlaying(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Stack(children: <Widget>[FinishCelebration(onDone: () {})]),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    final scales = tester
        .widgetList<Transform>(find.descendant(
            of: find.byType(FinishCelebration), matching: find.byType(Transform)))
        .length;
    await tester.pumpAndSettle();
    return scales;
  }

  testWidgets('iOS Reduce Motion: no ring, the check just appears',
      (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

    expect(await ringsWhilePlaying(tester), 1,
        reason: 'only the check, at full size');
  });

  testWidgets('motion is on by default (the control)', (tester) async {
    expect(await ringsWhilePlaying(tester), 2,
        reason: 'the ring and the check');
  });
}
