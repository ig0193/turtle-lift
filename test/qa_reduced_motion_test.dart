import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/ui/finish_celebration.dart';
import 'package:turtle_lift/src/ui/history_calendar_card.dart';
import 'package:turtle_lift/src/ui/motion.dart';
import 'package:turtle_lift/src/ui/reminder_controls.dart';
import 'package:turtle_lift/src/ui/session_overview_body.dart';

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

  // Every other animation in the app honours the same two flags, through the
  // one helper in motion.dart (research item 13).
  group('the rest of the app', () {
    void reduce(WidgetTester tester) {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.binding.platformDispatcher
          .clearAccessibilityFeaturesTestValue);
    }

    testWidgets('the helper reads both platform flags', (tester) async {
      late bool off;
      late Duration d;
      Widget probe() => MaterialApp(home: Builder(builder: (context) {
            off = prefersReducedMotion(context);
            d = motionDuration(context, const Duration(milliseconds: 300));
            return const SizedBox();
          }));
      await tester.pumpWidget(probe());
      expect(off, isFalse);
      expect(d, const Duration(milliseconds: 300));

      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.binding.platformDispatcher
          .clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(probe());
      expect(off, isTrue);
      expect(d, Duration.zero);
    });

    testWidgets('the live strip dot does not pulse', (tester) async {
      reduce(tester);
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: Scaffold(body: LiveStrip())),
      ));
      expect(
        find.descendant(
            of: find.byType(LiveStrip),
            matching: find.byType(TweenAnimationBuilder<double>)),
        findsNothing,
      );
    });

    testWidgets('the live strip dot pulses once by default (the control)',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: Scaffold(body: LiveStrip())),
      ));
      expect(
        find.descendant(
            of: find.byType(LiveStrip),
            matching: find.byType(TweenAnimationBuilder<double>)),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('the reminder switch moves without sliding', (tester) async {
      reduce(tester);
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ReminderSwitch(on: true))));
      final box = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(box.duration, Duration.zero);
    });

    testWidgets('the calendar changes month in one frame', (tester) async {
      reduce(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          historySessionsProvider.overrideWithValue(const <HistorySession>[]),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
              body: SingleChildScrollView(child: HistoryCalendarCard())),
        ),
      ));
      await tester.tap(find.byKey(HistoryCalendarCard.prevButtonKey));
      await tester.pump();
      await tester.pump();

      final now = DateTime.now();
      expect(find.text(monthYearLabel(DateTime(now.year, now.month - 1))),
          findsOneWidget,
          reason: 'a jump, not a 220ms slide');
    });
  });
}
