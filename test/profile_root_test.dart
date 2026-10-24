import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/profile_root.dart';
import 'package:turtle_lift/src/ui/profile_screen.dart';

/// The Profile tab root: a Personal | Schedule control over one scroll view.
void main() {
  Widget host() => ProviderScope(
        overrides: [
          customTemplatesProvider.overrideWithValue(const <WorkoutTemplate>[]),
          // The Schedule pane derives its summary from saved sessions.
          historySessionsProvider.overrideWithValue(const <HistorySession>[]),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: AppScreen.root(title: 'Profile', body: const ProfileRoot()),
        ),
      );

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

  testWidgets('each segment is at least 38pt tall (the 44pt control minus its padding)', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    for (final segment in ProfileSegment.values) {
      expect(
        tester.getSize(find.byKey(ProfileRoot.segmentKey(segment))).height,
        greaterThanOrEqualTo(38),
        reason: '${segment.label} must be comfortably tappable one-handed',
      );
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
}
