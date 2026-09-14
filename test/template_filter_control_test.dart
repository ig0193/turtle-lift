import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/filter_glyph.dart';
import 'package:turtle_lift/src/ui/template_filter_control.dart';

/// The filter control: what it says, what it opens, and that it can be hit.
///
/// The tap-target test is the one that matters on device. This is the only
/// control between the user and every template, and it is used standing, often
/// one-handed — a chip sized to its own text would be about 34pt tall and
/// comfortably missable.
void main() {
  Widget host({
    required TemplateFilter current,
    required ValueChanged<TemplateFilter> onSelected,
  }) {
    return MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: TemplateFilterControl(
            current: current,
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }

  group('the chip', () {
    testWidgets('names the current filter', (tester) async {
      await tester.pumpWidget(
        host(current: TemplateFilter.multiSplit, onSelected: (_) {}),
      );

      expect(find.text('Multi Split'), findsOneWidget);
      expect(find.byType(FilterGlyphIcon), findsOneWidget);
    });

    testWidgets('changes its label when the filter changes', (tester) async {
      await tester.pumpWidget(
        host(current: TemplateFilter.multiSplit, onSelected: (_) {}),
      );
      expect(find.text('Multi Split'), findsOneWidget);

      await tester.pumpWidget(
        host(current: TemplateFilter.pushPullLegs, onSelected: (_) {}),
      );
      await tester.pump();

      expect(find.text('Push-Pull-Legs'), findsOneWidget);
      expect(find.text('Multi Split'), findsNothing);
    });

    testWidgets('is hittable across a 48pt box, not just the visible chip',
        (tester) async {
      await tester.pumpWidget(
        host(current: TemplateFilter.multiSplit, onSelected: (_) {}),
      );

      final target = tester.getSize(
        find.byKey(TemplateFilterControl.tapTargetKey),
      );
      expect(target.height, greaterThanOrEqualTo(48));
      expect(target.width, greaterThanOrEqualTo(48));

      final chip = tester.getSize(find.byKey(TemplateFilterControl.chipKey));
      expect(
        chip.height,
        lessThan(target.height),
        reason: 'the visible chip is meant to be smaller than its target',
      );
    });

    testWidgets('announces itself with its current value', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(current: TemplateFilter.pushPullLegs, onSelected: (_) {}),
      );

      final node =
          tester.getSemantics(find.byKey(TemplateFilterControl.tapTargetKey));
      // The label merges with the chip's own text, which is what a screen
      // reader should hear -- what matters is that the control names itself
      // and reports which filter is current.
      expect(node.label, contains('Filter templates'));
      expect(node.value, 'Push-Pull-Legs');
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('paints only palette colours', (tester) async {
      await tester.pumpWidget(
        host(current: TemplateFilter.multiSplit, onSelected: (_) {}),
      );

      final chip = tester.widget<Container>(
        find.byKey(TemplateFilterControl.chipKey),
      );
      final decoration = chip.decoration! as BoxDecoration;

      expect(decoration.color, AppPalette.surface);
      expect(decoration.border!.top.color, AppPalette.border);
      expect(kTemplateFilterChipStyle.color, AppPalette.textPrimary);
    });
  });

  group('the menu', () {
    testWidgets('opens on tap and lists exactly the three filters',
        (tester) async {
      await tester.pumpWidget(
        host(current: TemplateFilter.multiSplit, onSelected: (_) {}),
      );

      await tester.tap(find.byKey(TemplateFilterControl.tapTargetKey));
      await tester.pumpAndSettle();

      for (final filter in TemplateFilter.values) {
        expect(find.byKey(templateFilterOptionKey(filter)), findsOneWidget);
      }
      expect(
        find.byKey(templateFilterOptionKey(TemplateFilter.values.first)),
        findsOneWidget,
      );
      expect(TemplateFilter.values, hasLength(3));
    });

    testWidgets('choosing a filter reports it and closes', (tester) async {
      final chosen = <TemplateFilter>[];
      await tester.pumpWidget(
        host(current: TemplateFilter.multiSplit, onSelected: chosen.add),
      );

      await tester.tap(find.byKey(TemplateFilterControl.tapTargetKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(templateFilterOptionKey(TemplateFilter.pushPullLegs)),
      );
      await tester.pumpAndSettle();

      expect(chosen, <TemplateFilter>[TemplateFilter.pushPullLegs]);
      expect(
        find.byKey(templateFilterOptionKey(TemplateFilter.pushPullLegs)),
        findsNothing,
        reason: 'the sheet should be gone',
      );
    });

    testWidgets('choosing the current filter still reports it', (tester) async {
      // Deliberate, and the opposite of swallowing a no-op: on first launch the
      // default is on screen but nothing is stored yet, so picking it is a real
      // choice. Swallowing it here would leave that choice unrecorded and send
      // the user somewhere else next launch.
      final chosen = <TemplateFilter>[];
      await tester.pumpWidget(
        host(current: TemplateFilter.multiSplit, onSelected: chosen.add),
      );

      await tester.tap(find.byKey(TemplateFilterControl.tapTargetKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(templateFilterOptionKey(TemplateFilter.multiSplit)),
      );
      await tester.pumpAndSettle();

      expect(chosen, <TemplateFilter>[TemplateFilter.multiSplit]);
    });

    testWidgets('dismissing without choosing reports nothing', (tester) async {
      final chosen = <TemplateFilter>[];
      await tester.pumpWidget(
        host(current: TemplateFilter.multiSplit, onSelected: chosen.add),
      );

      await tester.tap(find.byKey(TemplateFilterControl.tapTargetKey));
      await tester.pumpAndSettle();
      // Tap the scrim above the sheet.
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();

      expect(chosen, isEmpty);
    });

    testWidgets('sizes itself to the chip, not to the space it is given',
        (tester) async {
      // The bug this pins rendered perfectly: `Center` expands under loose
      // constraints, so the control reported the full screen width as its
      // bounds and the dropdown anchored to the screen edge instead of to the
      // chip. Nothing looked broken; the menu was simply in the wrong place.
      await tester.pumpWidget(
        host(current: TemplateFilter.multiSplit, onSelected: (_) {}),
      );

      final control =
          tester.getRect(find.byKey(TemplateFilterControl.tapTargetKey));
      final chip = tester.getRect(find.byKey(TemplateFilterControl.chipKey));

      expect(
        control.width,
        lessThan(300),
        reason: 'the control must not claim the whole row',
      );
      expect(control.width, closeTo(chip.width, 1));
    });

    testWidgets('drops the menu below the chip, right edges aligned',
        (tester) async {
      await tester.pumpWidget(
        host(current: TemplateFilter.multiSplit, onSelected: (_) {}),
      );
      final chip =
          tester.getRect(find.byKey(TemplateFilterControl.tapTargetKey));

      await tester.tap(find.byKey(TemplateFilterControl.tapTargetKey));
      await tester.pumpAndSettle();

      final firstOption = tester.getRect(
        find.byKey(templateFilterOptionKey(TemplateFilter.values.first)),
      );

      expect(
        firstOption.top,
        greaterThan(chip.bottom),
        reason: 'it is a dropdown -- it hangs below the control',
      );
      // Near the chip's right edge rather than pixel-exact: the menu carries
      // its own screen-edge inset. What matters is that it hangs off the chip
      // and not off the far side of the screen, which is what the anchoring
      // bug actually did.
      expect(
        firstOption.right,
        greaterThan(chip.right - 80),
        reason: 'the menu belongs to the chip, not to the screen edge',
      );
      expect(firstOption.right, lessThanOrEqualTo(chip.right));
    });

    testWidgets('marks the current filter as selected for assistive tech',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(current: TemplateFilter.pushPullLegs, onSelected: (_) {}),
      );

      await tester.tap(find.byKey(TemplateFilterControl.tapTargetKey));
      await tester.pumpAndSettle();

      expect(
        tester
            .getSemantics(
              find.byKey(templateFilterOptionKey(TemplateFilter.pushPullLegs)),
            )
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(
              find.byKey(templateFilterOptionKey(TemplateFilter.multiSplit)),
            )
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
      handle.dispose();
    });
  });
}
