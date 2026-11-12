import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/app_info.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/exercise.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/profile_root.dart';
import 'package:turtle_lift/src/ui/profile_screen.dart';

/// ADR 0014 §4 and §7 (profile audit B4, B12): the segment control stays put
/// while a pane scrolls, the Personal details row shows what it holds, and
/// Personal ends with an About block (version, privacy, licences).
void main() {
  Widget host({
    List<BodyweightEntry> weights = const <BodyweightEntry>[],
    BodyGender gender = BodyGender.male,
  }) =>
      ProviderScope(
        overrides: [
          customTemplatesProvider.overrideWithValue(const <WorkoutTemplate>[]),
          exerciseIndexProvider
              .overrideWithValue(ExerciseIndex(const <Exercise>[])),
          initialBodyweightLogProvider.overrideWithValue(weights),
          initialBodyGenderProvider.overrideWithValue(gender),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: AppScreen.root(title: 'Profile', body: const ProfileRoot()),
        ),
      );

  testWidgets('B4: the segment control is outside the scroll view and stays '
      'put when the pane scrolls', (tester) async {
    tester.view.physicalSize = const Size(390, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final segment = find.byKey(ProfileRoot.segmentKey(ProfileSegment.diet));
    expect(
      find.ancestor(of: segment, matching: find.byType(Scrollable)),
      findsNothing,
    );
    final before = tester.getTopLeft(segment);
    await tester.drag(find.byType(ProfilePersonalPane), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(segment), before);
  });

  group('B12: the Personal details row shows its values', () {
    test('subtitle wording', () {
      expect(personalDetailsSubtitle(74.5, BodyGender.female),
          '74.5 kg · female diagram');
      expect(personalDetailsSubtitle(null, BodyGender.male),
          'No weight yet · male diagram');
      expect(personalDetailsSubtitle(80, BodyGender.preferNotToSay),
          '80 kg · default diagram');
    });

    testWidgets('the row reads the latest weigh-in and the diagram',
        (tester) async {
      await tester.pumpWidget(host(
        weights: <BodyweightEntry>[
          BodyweightEntry(date: DateTime(2026, 1, 1), weightKg: 70),
          BodyweightEntry(date: DateTime(2026, 2, 1), weightKg: 74.5),
        ],
        gender: BodyGender.female,
      ));
      await tester.pumpAndSettle();
      expect(find.text('74.5 kg · female diagram'), findsOneWidget);
    });
  });

  group('About', () {
    test('kAppVersion matches pubspec.yaml', () {
      final line = File('pubspec.yaml')
          .readAsLinesSync()
          .firstWhere((l) => l.startsWith('version:'));
      expect(line.trim(), 'version: $kAppVersion+$kAppBuild');
    });

    testWidgets('shows the version, the privacy promise and a licences row '
        'that opens the licence page', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final licences = find.byKey(profileRowKey('licences'));
      await tester.scrollUntilVisible(licences, 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(ProfilePersonalPane.aboutGroupLabel), findsOneWidget);
      expect(find.text(appVersionLabel()), findsOneWidget);
      expect(find.text(ProfilePersonalPane.privacyNote), findsOneWidget);
      await tester.tap(licences);
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
    });
  });
}
