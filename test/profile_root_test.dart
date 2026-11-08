import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/theme/app_typography.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/profile_root.dart';
import 'package:turtle_lift/src/ui/profile_screen.dart';

/// The Profile tab root: a Personal | Schedule | Diet control over one scroll
/// view.
void main() {
  Widget host({
    Key? key,
    FoodIndex? foods,
    double textScale = 1,
  }) =>
      ProviderScope(
        key: key,
        overrides: [
          customTemplatesProvider.overrideWithValue(const <WorkoutTemplate>[]),
          // The Schedule pane derives its summary from saved sessions.
          historySessionsProvider.overrideWithValue(const <HistorySession>[]),
          foodIndexProvider
              .overrideWithValue(foods ?? FoodIndex.fromJson(const [])),
          planTodayProvider.overrideWithValue(LocalDate(2026, 11, 4)),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: AppScreen.root(title: 'Profile', body: const ProfileRoot()),
        ),
      );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ProfileRoot)));

  ScrollPosition profileScroll(WidgetTester tester) => tester
      .state<ScrollableState>(find
          .descendant(
            of: find.byType(ProfileRoot),
            matching: find.byType(Scrollable),
          )
          .first)
      .position;

  testWidgets('opens on Personal, showing the four rows', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text(ProfilePersonalPane.yoursGroupLabel), findsOneWidget);
    expect(find.byKey(profileRowKey('templates')), findsOneWidget);
    expect(find.byKey(profileRowKey('delete-all')), findsOneWidget);
  });

  testWidgets('Schedule swaps the pane, and Personal brings it back',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.schedule)));
    await tester.pumpAndSettle();
    expect(find.byKey(profileRowKey('templates')), findsNothing,
        reason: 'the Personal rows are not shown on the Schedule segment');

    await tester.tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.personal)));
    await tester.pumpAndSettle();
    expect(find.byKey(profileRowKey('templates')), findsOneWidget);
  });

  testWidgets('reads Personal | Schedule | Diet, in that order',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      ProfileSegment.values.map((s) => s.label),
      <String>['Personal', 'Schedule', 'Diet'],
    );
    final xs = <double>[
      for (final s in ProfileSegment.values)
        tester.getCenter(find.byKey(ProfileRoot.segmentKey(s))).dx,
    ];
    expect(xs[0] < xs[1] && xs[1] < xs[2], isTrue);
  });

  testWidgets(
      'at 375pt wide and 1.3x text every segment is one line, unclipped, '
      'with a 48pt tap target', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(textScale: 1.3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (final segment in ProfileSegment.values) {
      final target = find.byKey(ProfileRoot.segmentKey(segment));
      expect(
        tester.getSize(target).height,
        greaterThanOrEqualTo(48),
        reason: '${segment.label} must be a 48pt target (R9)',
      );
      final label = find.descendant(of: target, matching: find.text(segment.label));
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(paragraph.didExceedMaxLines, isFalse,
          reason: '${segment.label} must not wrap or clip');
      // The rendered rect, after any fit-down. The test font draws every
      // glyph a full em wide, about twice a real font, so this is a harsher
      // check than the phone; even so the label never drops under 12pt.
      final drawn = tester.getRect(label);
      expect(
        drawn.width,
        lessThanOrEqualTo(tester.getSize(target).width),
        reason: '${segment.label} must fit inside its own segment',
      );
      final scale = drawn.width / tester.getSize(label).width;
      expect(AppTypeScale.footnote * 1.3 * scale, greaterThanOrEqualTo(12),
          reason: 'no text under 12pt');
    }
  });

  testWidgets('announces the selected segment', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Personal')),
      isSemantics(label: 'Personal', isButton: true, isSelected: true),
    );
    handle.dispose();
  });

  testWidgets('tapping Diet shows the Diet pane', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.diet)));
    await tester.pumpAndSettle();

    expect(find.byType(DietPane), findsOneWidget);
    expect(find.byKey(profileRowKey('templates')), findsNothing);
    expect(containerOf(tester).read(profileSegmentProvider), ProfileSegment.diet);
  });

  testWidgets('setting the provider from outside the widget switches the pane',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    containerOf(tester)
        .read(profileSegmentProvider.notifier)
        .select(ProfileSegment.diet);
    await tester.pumpAndSettle();

    expect(find.byType(DietPane), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Diet')),
      isSemantics(label: 'Diet', isButton: true, isSelected: true),
    );
  });

  testWidgets('switching segment after scrolling lands at the top (KTD3)',
      (tester) async {
    // Short enough that the Diet empty state scrolls.
    tester.view.physicalSize = const Size(390, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.diet)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(DietPane), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(profileScroll(tester).pixels, greaterThan(0));

    containerOf(tester)
        .read(profileSegmentProvider.notifier)
        .select(ProfileSegment.personal);
    await tester.pumpAndSettle();

    expect(find.byKey(profileRowKey('templates')), findsOneWidget);
    expect(profileScroll(tester).pixels, 0);
  });

  testWidgets('a fresh ProviderScope (the reboot) starts on Personal (AE8)',
      (tester) async {
    await tester.pumpWidget(host(key: UniqueKey()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.diet)));
    await tester.pumpAndSettle();
    expect(find.byType(DietPane), findsOneWidget);

    await tester.pumpWidget(host(key: UniqueKey()));
    await tester.pumpAndSettle();

    expect(find.byType(DietPane), findsNothing);
    expect(find.byKey(profileRowKey('templates')), findsOneWidget);
  });

  testWidgets('with no food list, Diet says so and Personal still renders',
      (tester) async {
    await tester.pumpWidget(host(foods: FoodIndex.unavailable()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.diet)));
    await tester.pumpAndSettle();
    expect(find.text(DietPane.unavailableCopy), findsOneWidget);

    await tester.tap(find.byKey(ProfileRoot.segmentKey(ProfileSegment.personal)));
    await tester.pumpAndSettle();
    expect(find.byKey(profileRowKey('templates')), findsOneWidget);
  });
}
