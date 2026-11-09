import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/body_diagram.dart';
import 'package:turtle_lift/src/ui/muscles_root.dart';

/// Layout slice of the Muscles audit: B5 (the map ran under the tab bar) and
/// B6 (thin and diagonal muscles were hard to hit).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseIndex index;
  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    index = ExerciseIndex.fromJson(
      await container.read(exerciseLibraryProvider.future),
    );
  });

  group('the map fits above the tab bar (B5)', () {
    // Logical sizes: iPhone SE-class, iPhone 17e, iPhone 17 Pro Max. The
    // bottom inset stands in for the home indicator plus the floating tab bar,
    // which the shell hands every root as MediaQuery padding.
    const screens = <String, Size>{
      'small 375x667': Size(375, 667),
      '17e 390x844': Size(390, 844),
      'Pro Max 440x956': Size(440, 956),
    };
    for (final entry in screens.entries) {
      testWidgets('${entry.key}: figure and hint are above the fold',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = entry.value;
        addTearDown(tester.view.reset);
        const bottomInset = 34.0 + 63.0;
        await tester.pumpWidget(ProviderScope(
          overrides: [exerciseIndexProvider.overrideWithValue(index)],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              appBar: AppBar(toolbarHeight: 56, title: const Text('Muscles')),
              body: const MediaQuery(
                data: MediaQueryData(
                  padding: EdgeInsets.only(bottom: bottomInset),
                ),
                child: MusclesRoot(),
              ),
            ),
          ),
        ));
        await tester.pump();
        final fold = entry.value.height - bottomInset;
        final hint = find.text(MusclesRoot.mapHint);
        expect(hint, findsOneWidget);
        expect(tester.getBottomLeft(hint).dy, lessThanOrEqualTo(fold),
            reason: 'the hint (and so the whole figure) must be visible');
        expect(
          tester.getBottomLeft(find.byType(BodyDiagram)).dy,
          lessThan(tester.getTopLeft(hint).dy),
        );
        expect(tester.getSize(find.byType(BodyDiagram)).height,
            greaterThan(280),
            reason: 'capped, not shrunk to a thumbnail');
      });
    }
  });

  group('tap tolerance (B6)', () {
    const size = Size(390, 700);
    const painter = BodyDiagramPainter(
      view: BodyView.front,
      gender: BodyGender.male,
      fill: mutedBodyFill,
    );

    Offset leftmostVertex(String segmentId) {
      final asset = painter.asset;
      final scale = painter.scaleFor(size);
      final origin = painter.originFor(size);
      final segment = asset.segments.firstWhere((s) => s.id == segmentId);
      var best = const Offset(double.infinity, 0);
      for (final outline in segment.outlines) {
        for (var i = 0; i < outline.length; i += 2) {
          final p = Offset(outline[i], outline[i + 1]) * scale + origin;
          if (p.dx < best.dx) best = p;
        }
      }
      return best;
    }

    test('a tap 8pt outside the forearm opens the forearm', () {
      final point = leftmostVertex('forearms/forearms') - const Offset(8, 0);
      expect(painter.segmentAt(point, size), isNull,
          reason: 'an exact hit-test misses it');
      expect(painter.segmentNear(point, size)?.id, 'forearms/forearms');
    });

    test('a tap 30pt away opens nothing', () {
      final point = leftmostVertex('forearms/forearms') - const Offset(30, 0);
      expect(painter.segmentNear(point, size), isNull);
    });

    test('an exact hit still wins over a nearer edge of another muscle', () {
      final segments = painter.segmentPathsFor(size);
      final mid = segments.firstWhere((s) => s.id == 'chest/mid');
      final bounds = mid.path.getBounds();
      var checked = 0;
      for (var i = 1; i < 20; i++) {
        final point = Offset(bounds.left + bounds.width * i / 20,
                bounds.center.dy) +
            painter.originFor(size);
        final exact = painter.segmentAt(point, size);
        if (exact == null) continue;
        checked++;
        expect(painter.segmentNear(point, size)?.id, exact.id);
      }
      expect(checked, greaterThan(0));
    });

    test('the head, which is no muscle, stays untappable', () {
      final bounds = painter.decorativePathFor(size).getBounds();
      final top = Offset(bounds.center.dx, bounds.top + 10) +
          painter.originFor(size);
      expect(painter.segmentNear(top, size), isNull);
    });
  });
}
