import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/today.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/theme/app_typography.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/history_calendar_card.dart';
import 'package:turtle_lift/src/ui/history_root.dart';
import 'package:turtle_lift/src/ui/profile_screen.dart';
import 'package:turtle_lift/src/ui/you_root.dart';

/// The You tab root: a Profile | Activity | Analysis control over three panes
/// (`docs/adr/0016-you-tab-and-diet-tab.md`).
void main() {
  DateTime day(int daysAgo) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - daysAgo);
  }

  Widget host({
    Key? key,
    double textScale = 1,
    List<HistorySession> sessions = const <HistorySession>[],
  }) =>
      ProviderScope(
        key: key,
        overrides: [
          customTemplatesProvider.overrideWithValue(const <WorkoutTemplate>[]),
          historySessionsProvider.overrideWithValue(sessions),
          foodIndexProvider.overrideWithValue(FoodIndex.fromJson(const [])),
          planTodayProvider.overrideWithValue(LocalDate(2026, 11, 4)),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: AppScreen.root(title: 'You', body: const YouRoot()),
        ),
      );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(YouRoot)));

  ScrollPosition profileScroll(WidgetTester tester) => tester
      .state<ScrollableState>(find.descendant(
        of: find.byKey(YouRoot.profileScrollKey),
        matching: find.byType(Scrollable),
      ))
      .position;

  Future<void> select(WidgetTester tester, YouSegment segment) async {
    await tester.tap(find.byKey(YouRoot.segmentKey(segment)));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on Activity, not Profile: what you did is what you come '
      'here to read', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(containerOf(tester).read(youSegmentProvider), YouSegment.activity);
    expect(find.byType(HistoryRoot), findsOneWidget);
    expect(find.text('No workouts yet'), findsOneWidget,
        reason: 'the old History empty state, now the Activity pane');
    expect(find.byKey(profileRowKey('templates')), findsNothing,
        reason: 'the Profile rows are mounted but not on stage');
  });

  testWidgets('Profile shows the four rows', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await select(tester, YouSegment.profile);

    expect(containerOf(tester).read(youSegmentProvider), YouSegment.profile);
    expect(find.text(ProfilePersonalPane.yoursGroupLabel), findsOneWidget);
    expect(find.byKey(profileRowKey('templates')), findsOneWidget);
    expect(find.byKey(profileRowKey('delete-all')), findsOneWidget);
  });

  testWidgets('Profile swaps the pane in, and Activity brings it back',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await select(tester, YouSegment.profile);
    expect(find.byKey(profileRowKey('templates')), findsOneWidget);
    expect(find.text('No workouts yet'), findsNothing,
        reason: 'the Activity pane is not shown on the Profile segment');

    await select(tester, YouSegment.activity);
    expect(find.byType(HistoryRoot), findsOneWidget);
    expect(find.text('No workouts yet'), findsOneWidget);
    expect(find.byKey(profileRowKey('templates')), findsNothing);
  });

  testWidgets('Activity still shows the stats line and the calendar once a '
      'workout is saved', (tester) async {
    // Tall enough that the lazy list builds the Recent row under the calendar.
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(sessions: <HistorySession>[
      HistorySession(
        id: 'a',
        performedOn: day(1),
        title: 'Push day',
        isQuickLog: false,
        exercises: const <HistoryExercise>[],
      ),
    ]));
    await tester.pumpAndSettle();

    // No tap: Activity is the segment You opens on.
    expect(containerOf(tester).read(youSegmentProvider), YouSegment.activity);
    expect(find.byKey(HistoryRoot.statsKey), findsOneWidget);
    expect(find.byType(HistoryCalendarCard), findsOneWidget);
    expect(find.byKey(HistoryRoot.recentRowKey('a')), findsOneWidget);
  });

  testWidgets('Analysis is an empty pane for now', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await select(tester, YouSegment.analysis);

    expect(find.byKey(YouRoot.analysisKey), findsOneWidget);
    expect(find.text(YouRoot.analysisCopy), findsOneWidget);
    expect(find.byKey(profileRowKey('templates')), findsNothing);
    expect(find.byType(HistoryRoot), findsNothing,
        reason: 'the Activity pane is mounted but not on stage');
  });

  testWidgets('Diet is not a segment of You any more (ADR 0016)',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Diet'), findsNothing);
    expect(find.text('Schedule'), findsNothing);
    expect(find.byType(DietPane), findsNothing);
  });

  testWidgets('reads Profile | Activity | Analysis, in that order',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      YouSegment.values.map((s) => s.label),
      <String>['Profile', 'Activity', 'Analysis'],
    );
    final xs = <double>[
      for (final s in YouSegment.values)
        tester.getCenter(find.byKey(YouRoot.segmentKey(s))).dx,
    ];
    expect(xs[0] < xs[1], isTrue);
    expect(xs[1] < xs[2], isTrue);
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

    for (final segment in YouSegment.values) {
      final target = find.byKey(YouRoot.segmentKey(segment));
      expect(
        tester.getSize(target).height,
        greaterThanOrEqualTo(48),
        reason: '${segment.label} must be a 48pt target (R9)',
      );
      final label =
          find.descendant(of: target, matching: find.text(segment.label));
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
      tester.getSemantics(find.bySemanticsLabel('Activity')),
      isSemantics(label: 'Activity', isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Profile')),
      isSemantics(label: 'Profile', isButton: true, isSelected: false),
    );
    handle.dispose();
  });

  testWidgets('tapping a segment records the selection in the provider',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await select(tester, YouSegment.profile);
    expect(containerOf(tester).read(youSegmentProvider), YouSegment.profile);

    await select(tester, YouSegment.activity);
    expect(containerOf(tester).read(youSegmentProvider), YouSegment.activity);
  });

  testWidgets('setting the provider from outside the widget switches the pane',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final handle = tester.ensureSemantics();

    containerOf(tester)
        .read(youSegmentProvider.notifier)
        .select(YouSegment.analysis);
    await tester.pumpAndSettle();

    expect(find.text(YouRoot.analysisCopy), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Analysis')),
      isSemantics(label: 'Analysis', isButton: true, isSelected: true),
    );
    handle.dispose();
  });

  testWidgets('the control is outside every pane, so it stays put while a pane '
      'scrolls', (tester) async {
    tester.view.physicalSize = const Size(390, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await select(tester, YouSegment.profile);
    final segment = find.byKey(YouRoot.segmentKey(YouSegment.profile));
    expect(
      find.ancestor(of: segment, matching: find.byType(Scrollable)),
      findsNothing,
    );
    final before = tester.getTopLeft(segment);
    await tester.drag(find.byKey(YouRoot.profileScrollKey), const Offset(0, -150));
    await tester.pumpAndSettle();

    expect(profileScroll(tester).pixels, greaterThan(0));
    expect(tester.getTopLeft(segment), before);
  });

  testWidgets('a pane keeps its scroll position while another is showing '
      '(all three stay mounted)', (tester) async {
    // Short enough that the Profile pane scrolls.
    tester.view.physicalSize = const Size(390, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await select(tester, YouSegment.profile);
    await tester.drag(find.byKey(YouRoot.profileScrollKey), const Offset(0, -150));
    await tester.pumpAndSettle();
    final scrolled = profileScroll(tester).pixels;
    expect(scrolled, greaterThan(0));

    await select(tester, YouSegment.activity);
    expect(find.byKey(profileRowKey('templates')), findsNothing);
    expect(find.byKey(YouRoot.profileScrollKey, skipOffstage: false),
        findsOneWidget,
        reason: 'the Profile pane is off stage, not unmounted');

    await select(tester, YouSegment.profile);

    expect(profileScroll(tester).pixels, scrolled,
        reason: 'no more jump to the top: each pane owns its own scroll view '
            '(this replaces the old shared-scroll reset, KTD3)');
  });

  testWidgets('a fresh ProviderScope (the reboot) starts on Activity (AE8)',
      (tester) async {
    await tester.pumpWidget(host(key: UniqueKey()));
    await tester.pumpAndSettle();
    await select(tester, YouSegment.analysis);
    expect(find.text(YouRoot.analysisCopy), findsOneWidget);

    await tester.pumpWidget(host(key: UniqueKey()));
    await tester.pumpAndSettle();

    expect(containerOf(tester).read(youSegmentProvider), YouSegment.activity);
    expect(find.text(YouRoot.analysisCopy), findsNothing);
    expect(find.text('No workouts yet'), findsOneWidget);
  });
}
