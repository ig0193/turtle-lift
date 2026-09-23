import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/body_gender.dart';
import '../theme/app_palette.dart';
import 'body_diagram.dart';
import 'history_session_detail_screen.dart' show subMuscleGroupIdsFor;

/// The pair of bodies on a template row, with the template's muscles lit.
///
/// **It answers the question the muscle-group line could not.** A row reading
/// "Chest, back, shoulders, biceps, triceps" has to be read word by word and
/// then assembled into a mental picture of a body; this *is* the picture. At a
/// glance the user sees whether a template is an upper day, a leg day or a
/// whole body, which is the one thing they are choosing between.
///
/// **Front and back, always both.** A single front view would render Back day
/// and Leg day as almost nothing — the two templates whose whole point is the
/// posterior chain. The pair costs about 64pt of row width and is the only
/// arrangement that can tell every template apart.
///
/// **Never in the accent colour.** `docs/01` §Usage rules gives
/// [AppPalette.accentStrong] one meaning — "this is active / this has been
/// worked" — with the same meaning wherever it appears, and a template is
/// neither. It is a menu of muscles the user has not touched yet. So coverage
/// is drawn in [AppPalette.textSecondary]: unmistakably "these ones", and
/// unmistakably not a claim about the user's history. The accent's one
/// appearance on this screen stays the primary action.
///
/// **Decorative and inert.** It draws with [BodyDiagramPainter] directly rather
/// than hosting a [BodyDiagram], because that widget carries press state and a
/// muscle-name label for a tap this row must not answer: the row's tap starts a
/// workout, and a thumbnail that swallowed it to name a muscle would be a
/// 64pt dead zone on the most consequential target on the screen.
class TemplateBodyThumbnail extends ConsumerWidget {
  const TemplateBodyThumbnail({required this.groupIds, super.key});

  /// Parent muscle group ids, exactly as a template stores them.
  final List<String> groupIds;

  /// How tall each of the two bodies stands.
  ///
  /// Sized against the row, not the other way round: two lines of text and a
  /// muscle-group line come to roughly this, so the thumbnail sets the row's
  /// height without being the reason for it.
  static const double height = 52;

  /// How wide each body's box is. The four viewBoxes are about 0.53 as wide as
  /// they are tall, so this is [height] at that ratio, rounded up — the painter
  /// centres whatever is left over.
  static const double viewWidth = 28;

  /// The gap between front and back.
  static const double viewGap = 4;

  /// The whole widget's width. Fixed, so every row's text starts at the same x
  /// however many muscles a template covers.
  static const double totalWidth = viewWidth * 2 + viewGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gender = ref.watch(bodyGenderProvider);
    final fill = TemplateCoverageFill.forGroups(groupIds);

    return Container(
      width: totalWidth,
      height: height,
      // **Inset, on the page colour, like the muscle chips beside it.** The
      // painter draws its head and neck in [AppPalette.surface] and every
      // untrained muscle in [AppPalette.mutedSurface] — on a card that is
      // itself `surface`, that is a headless body on an invisible ground. The
      // darker well is what gives all three fills something to read against,
      // and it frames the body as a thing on the card rather than a smudge in
      // its corner.
      decoration: BoxDecoration(
        color: AppPalette.pageBackground,
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final view in BodyView.values) ...<Widget>[
            if (view != BodyView.values.first) const SizedBox(width: viewGap),
            SizedBox(
              width: viewWidth,
              height: height,
              child: CustomPaint(
                painter: BodyDiagramPainter(
                  view: view,
                  gender: gender,
                  fill: fill.colorFor,
                  // At 30pt wide a 2.5pt separator is wider than most of the
                  // muscles it would divide. See BodyDiagramPainter.
                  separatorWidth: null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Which sub-muscle groups a template covers, as a [BodySegmentFill].
///
/// **A class with a real `==`, not a closure**, for the reason `MuscleFill`
/// is one: [BodyDiagramPainter.shouldRepaint] compares its fill, and a fresh
/// closure every build compares unequal every build — seven rows repainting 42
/// polygons each on every frame of a scroll. Two coverages that light the same
/// muscles are the same coverage, and Dart's tear-off equality carries that
/// through to `colorFor`.
@immutable
class TemplateCoverageFill {
  TemplateCoverageFill(Set<String> covered)
      : covered = Set<String>.unmodifiable(covered);

  /// Expands parent group ids into the sub-groups the diagram is keyed by.
  ///
  /// A template stores parent groups only (`docs/00` §2), and the taxonomy is
  /// the only thing that knows what is under one — so a sub-group added to a
  /// parent later lights up in every existing template's thumbnail with no
  /// migration, which is the same promise the row's muscle line already makes.
  ///
  /// **Through [subMuscleGroupIdsFor], never by reading the taxonomy here.**
  /// `kMuscleTaxonomy` lists a parent's children by bare name — `'chest'` maps
  /// to `['upper', 'mid', 'lower']` — while every diagram is keyed by the
  /// qualified `'chest/upper'`. Composing the two halves is the step that
  /// silently misses if it is forgotten: the fill matches nothing, no muscle
  /// lights, and the thumbnail still renders a perfectly plausible grey body.
  /// It was forgotten here exactly once, which is why this now calls the
  /// helper that already existed for it.
  factory TemplateCoverageFill.forGroups(List<String> groupIds) =>
      TemplateCoverageFill(subMuscleGroupIdsFor(groupIds));

  final Set<String> covered;

  /// [AppPalette.textSecondary] for a muscle this template covers,
  /// [AppPalette.mutedSurface] for one it does not — the same untrained fill
  /// the Muscles tab uses, so an uncovered muscle looks the same everywhere.
  Color colorFor(Set<String> subMuscleGroupIds) =>
      subMuscleGroupIds.any(covered.contains)
          ? AppPalette.textSecondary
          : AppPalette.mutedSurface;

  @override
  bool operator ==(Object other) =>
      other is TemplateCoverageFill && setEquals(other.covered, covered);

  @override
  int get hashCode => Object.hashAllUnordered(covered);
}
