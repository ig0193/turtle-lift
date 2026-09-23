import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/body_gender.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/ui/body_diagram.dart';
import 'package:turtle_lift/src/ui/template_body_thumbnail.dart';
import 'package:turtle_lift/src/ui/template_row.dart';

/// The Workout landing's template card: the body it draws, the chips it fits,
/// and the day it remembers.
///
/// **The thumbnail is the part that fails silently**, which is why most of this
/// file is about it. A coverage fill that matches nothing still renders a
/// perfectly plausible grey body — that is exactly how it shipped the first
/// time, because `kMuscleTaxonomy` lists a parent's children as `'upper'` while
/// every diagram is keyed by `'chest/upper'`. So the colours are read off the
/// canvas, not off the fill callback.
void main() {
  WorkoutTemplate byId(String id) =>
      kPredefinedTemplates.firstWhere((t) => t.id == id);

  WorkoutSession ran(String templateId, LocalDate on) => WorkoutSession(
        id: 'session-$templateId-${on.encode()}',
        title: null,
        performedOn: on,
        loggedAt: on.toDateTime(),
        templateId: templateId,
        templateName: null,
        groupIds: const <String>[],
        isOpen: false,
        exercises: <SessionExercise>[
          SessionExercise(
            id: 'se-1',
            exerciseId: 'bench',
            position: 0,
            loadType: LoadType.weighted,
            markedDone: false,
            sets: <SetEntry>[
              SetEntry(
                id: 'set-1',
                position: 0,
                completed: true,
                weightKg: 60,
                reps: 8,
              ),
            ],
          ),
        ],
      );

  Widget host(
    WorkoutTemplate template, {
    List<WorkoutSession> saved = const <WorkoutSession>[],
    double width = 400,
    VoidCallback? onTap,
  }) =>
      ProviderScope(
        overrides: [
          initialSavedSessionsProvider.overrideWithValue(saved),
          initialBodyGenderProvider.overrideWithValue(BodyGender.male),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: TemplateRow(
                  template: template,
                  onTap: onTap ?? () {},
                ),
              ),
            ),
          ),
        ),
      );

  /// The painter driving the [view] body of the card's thumbnail.
  BodyDiagramPainter painterFor(WidgetTester tester, BodyView view) =>
      tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(TemplateBodyThumbnail),
              matching: find.byType(CustomPaint),
            ),
          )
          .elementAt(view.index)
          .painter! as BodyDiagramPainter;

  /// The colour [segmentId] was actually painted in, packed as ARGB.
  ///
  /// **Packed, not as a `Color`.** `Paint` round-trips its colour through
  /// 32-bit channels, so the doubles that come back out differ from the
  /// constant's in the last places and compare unequal while printing
  /// identically — a failure whose message reads "expected X, got X".
  ///
  /// The thumbnail passes `separatorWidth: null`, so the canvas receives one
  /// decorative path and then the segments in declaration order — no separator
  /// pass after them.
  int paintedColour(BodyDiagramPainter painter, String segmentId) {
    const size = Size(28, 46);
    final canvas = _RecordingCanvas();
    painter.paint(canvas, size);

    final segments = painter.segmentPathsFor(size);
    final at = segments.indexWhere((s) => s.id == segmentId);
    expect(at, isNot(-1),
        reason: '$segmentId is not drawn on ${painter.assetKey}');
    expect(
      canvas.paints.length,
      segments.length + 1,
      reason: 'one decorative pass and one pass per segment -- a separator '
          'pass at this size would smother the body',
    );
    return canvas.paints[at + 1].color.toARGB32();
  }

  group('the thumbnail', () {
    testWidgets('lights the template\'s own muscles and leaves the rest muted',
        (tester) async {
      await tester.pumpWidget(host(byId('chest-triceps')));

      final front = painterFor(tester, BodyView.front);
      for (final lit in <String>['chest/upper', 'chest/mid', 'chest/lower']) {
        expect(
          paintedColour(front, lit),
          AppPalette.textSecondary.toARGB32(),
          reason: '$lit is in the template',
        );
      }
      expect(
        paintedColour(front, 'quads/quads'),
        AppPalette.mutedSurface.toARGB32(),
        reason: 'Chest and triceps day does not cover legs',
      );

      final back = painterFor(tester, BodyView.back);
      expect(
        paintedColour(back, 'triceps/triceps'),
        AppPalette.textSecondary.toARGB32(),
        reason: 'the back view is the only one that can show triceps -- a '
            'front-only thumbnail would render this template as chest alone',
      );
    });

    testWidgets('never paints a template in the accent colour', (tester) async {
      // `docs/01` §Usage rules gives #D85A30 one meaning -- "this is active /
      // this has been worked" -- wherever it appears. A template is a menu of
      // muscles the user has not touched, so lighting it accent would claim a
      // workout that never happened.
      for (final template in kPredefinedTemplates) {
        await tester.pumpWidget(host(template));
        await tester.pump();

        for (final view in BodyView.values) {
          final painter = painterFor(tester, view);
          const size = Size(28, 46);
          final canvas = _RecordingCanvas();
          painter.paint(canvas, size);
          for (final paint in canvas.paints) {
            expect(
              paint.color.toARGB32(),
              isNot(anyOf(
                AppPalette.accentStrong.toARGB32(),
                AppPalette.accentLight.toARGB32(),
              )),
              reason: '${template.name} lit a muscle as if it were trained',
            );
          }
        }
      }
    });

    testWidgets('a whole-body template lights far more than a single-group one',
        (tester) async {
      Future<int> litCount(WorkoutTemplate template) async {
        await tester.pumpWidget(host(template));
        await tester.pump();
        var lit = 0;
        for (final view in BodyView.values) {
          final painter = painterFor(tester, view);
          const size = Size(28, 46);
          final canvas = _RecordingCanvas();
          painter.paint(canvas, size);
          lit += canvas.paints
              .where((p) =>
                  p.color.toARGB32() == AppPalette.textSecondary.toARGB32())
              .length;
        }
        return lit;
      }

      final full = await litCount(byId('full-body'));
      final chest = await litCount(byId('chest'));
      expect(
        full,
        greaterThan(chest),
        reason: 'the whole point of the thumbnail is that these two are '
            'distinguishable before a word is read',
      );
    });
  });

  group('the muscle chips', () {
    testWidgets('names every group when they all fit', (tester) async {
      await tester.pumpWidget(host(byId('back-biceps')));

      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Biceps'), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('counts what it could not fit, rather than clipping it',
        (tester) async {
      // Upper body day covers five groups and no phone is wide enough for five
      // chips beside a thumbnail.
      await tester.pumpWidget(host(byId('upper-body'), width: 400));

      expect(find.text('Chest'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'^\+\d+$')),
        findsOneWidget,
        reason: 'the groups that did not fit are counted, not dropped',
      );
    });

    testWidgets('keeps at least one chip however narrow the card', (tester) async {
      await tester.pumpWidget(host(byId('upper-body'), width: 220));

      expect(
        find.text('Chest'),
        findsOneWidget,
        reason: 'a card showing only "+5" would have dropped every word on it',
      );
    });

    testWidgets('defers to the bespoke line for the one template that has one',
        (tester) async {
      // Full body day spans all twelve groups; twelve chips would be the card.
      await tester.pumpWidget(host(byId('full-body')));

      expect(find.text('A mix across all major groups'), findsOneWidget);
      expect(find.text('Chest'), findsNothing);
    });
  });

  group('the recency line', () {
    testWidgets('says so when the template has never been run', (tester) async {
      await tester.pumpWidget(host(byId('chest-triceps')));
      expect(find.text('Not done yet'), findsOneWidget);
    });

    testWidgets('reads back the day it was last performed', (tester) async {
      final today = LocalDate.today();
      await tester.pumpWidget(host(
        byId('chest-triceps'),
        saved: <WorkoutSession>[
          ran('chest-triceps', today.addDays(-3)),
          ran('chest-triceps', today.addDays(-20)),
        ],
      ));

      expect(find.text('Last done 3 days ago'), findsOneWidget);
    });

    testWidgets('ignores another template\'s history', (tester) async {
      await tester.pumpWidget(host(
        byId('chest-triceps'),
        saved: <WorkoutSession>[ran('back-biceps', LocalDate.today())],
      ));

      expect(find.text('Not done yet'), findsOneWidget);
    });

    testWidgets('never says anything about what to do next', (tester) async {
      // The line is recall, not recommendation (`docs/02` §Recency). If it ever
      // grows a "due", an "overdue" or a "time for", it has become the
      // suggestion engine the app does not have.
      final today = LocalDate.today();
      await tester.pumpWidget(host(
        byId('chest-triceps'),
        saved: <WorkoutSession>[ran('chest-triceps', today.addDays(-45))],
      ));

      for (final forbidden in <String>['due', 'overdue', 'time for', 'today?']) {
        expect(
          find.textContaining(forbidden, findRichText: true),
          findsNothing,
          reason: '"$forbidden" would make this a schedule',
        );
      }
    });
  });

  testWidgets('the whole card starts the workout', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(byId('chest-triceps'), onTap: () => taps++),
    );

    // Not the chevron, not the title -- the thumbnail, which is the corner a
    // decorative widget would most plausibly have swallowed.
    await tester.tap(find.byType(TemplateBodyThumbnail));
    expect(taps, 1);
  });
}

class _RecordingCanvas implements Canvas {
  final List<Paint> paints = <Paint>[];

  @override
  void drawPath(Path path, Paint paint) => paints.add(paint);

  @override
  void save() {}

  @override
  void restore() {}

  @override
  void translate(double dx, double dy) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
