import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../data/local_date.dart';
import '../data/workout_templates.dart';
import '../theme/app_palette.dart';
import 'template_body_thumbnail.dart';

/// [kLandingSectionLabelStyle] was written here and then read by both tabs, so
/// it now lives in `app_typography.dart`, which neither tab owns. Re-exported
/// rather than moved outright: this file's own callers ask it for the label
/// their rows sit under, and that is a fair thing to ask a row file for.
export '../theme/app_typography.dart' show kLandingSectionLabelStyle;

/// One template on the Workout landing: the body it works, its name, its
/// muscles, and when it was last done.
///
/// **This is a card you start a workout from, not a row you drill into.** The
/// first version was a name, a comma-joined muscle line and a chevron, sized
/// like a settings row — six of them stacked, all identical, the most
/// consequential tap on the screen wearing the least consequential affordance.
/// Tapping one starts a session and auto-saves or discards whatever was open
/// (`WorkoutLandingBody._openTemplate`), which is not what a disclosure chevron
/// promises. So the chevron became a bounded circular control, and the row
/// became a card with something in it.
///
/// **Three cues, each answering a different question.** The thumbnail answers
/// *what does this work* before a word is read; the chips answer *which
/// muscles, precisely*; the recency line answers *when did I last do this*.
/// Nothing here answers *should I do this today* — see [_RecencyLine].
///
/// **Sized for a thumb, not for a cursor.** The landing is opened standing, in
/// a gym, often one-handed and between sets.
class TemplateRow extends ConsumerWidget {
  const TemplateRow({
    required this.template,
    required this.onTap,
    super.key,
  });

  /// The template this row starts. Taken whole rather than as name plus
  /// subtitle, because the card now needs its id (for recency) and its group
  /// ids (for the thumbnail and the chips) as well — and four positional
  /// strings at a call site is how a row ends up rendering one template's name
  /// over another's muscles.
  final WorkoutTemplate template;

  final VoidCallback onTap;

  /// The row's name, kept as a getter because callers and tests ask rows what
  /// they are showing.
  String get title => template.name;

  /// The minimum row height, matching the app's other tap target
  /// (`ProfileAvatarButton.tapTarget`). The card is far taller than this in
  /// practice; the floor is what `template_library_screen.dart` shares.
  static const double minHeight = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedSessionsProvider);
    final last = lastPerformed(template.id, saved);

    return Semantics(
      button: true,
      label: '${template.name}. ${template.subtitle}. '
          '${_recencyLabel(last)}. Starts this workout',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: minHeight),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              TemplateBodyThumbnail(groupIds: template.groupIds),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      template.name,
                      style: kTemplateCardTitleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _MuscleStrip(template: template),
                    const SizedBox(height: 7),
                    _RecencyLine(lastPerformed: last),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const _StartAffordance(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The template's muscles, as chips that fit on one line.
///
/// **Chips rather than the comma-joined line they replace.** "Chest, back,
/// shoulders, biceps, triceps" has to be read left to right and assembled;
/// five bounded shapes are counted at a glance. The line was also the row's
/// only supporting text while saying nothing that changes between users or
/// over time, which made it the least useful thing on the busiest row.
///
/// **One line, always, measured rather than guessed.** A `Wrap` would spill to
/// a second line for the wider templates and leave the list with two row
/// heights; a fixed "first three" would clip "Hamstrings, shoulders" and leave
/// a gap after "Abs, calves". So the labels are measured and as many as fit are
/// kept, with the remainder counted in a trailing chip.
class _MuscleStrip extends StatelessWidget {
  const _MuscleStrip({required this.template});

  final WorkoutTemplate template;

  /// The gap between two chips.
  static const double _gap = 5;

  @override
  Widget build(BuildContext context) {
    // Full body day spans all twelve groups and carries a bespoke line instead
    // — twelve chips would be the whole card. `WorkoutTemplate.subtitleOverride`
    // already made that call for the muscle line; the chips inherit it rather
    // than making it twice.
    final override = template.subtitleOverride;
    if (override != null) {
      return Text(
        override,
        style: kTemplateCardMuscleStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final labels = _labelsFor(template.groupIds);
    if (labels.isEmpty) return const SizedBox(height: _chipHeight);

    // The user's text-size setting widens every chip, so it has to be part of
    // the measurement -- without it the strip fits three chips on paper and
    // clips the third on any device that is not at the default scale.
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final shown = _fit(labels, constraints.maxWidth, scaler);
        final hidden = labels.length - shown;
        return SizedBox(
          height: _chipHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // **Flexible only when there is a single chip, never when there
              // are several.** A `Flexible` divides the *free* space equally
              // between the flex children, so three kept chips each got a
              // third of the room and "Shoulders" came out clipped to
              // "Shoulder" beside a "Chest" with space to spare — even though
              // [_fit] had correctly measured that all three fit. Where [_fit]
              // says they fit, they are laid out at their natural width.
              //
              // The one chip [_fit] keeps on a card too narrow to hold it
              // beside the counter is the exception: "+5" alone would have
              // dropped every word on the row, so that chip gives way and
              // clips while the count stays whole and readable.
              for (var i = 0; i < shown; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: _gap),
                if (shown == 1)
                  Flexible(child: _MuscleChip(label: labels[i]))
                else
                  _MuscleChip(label: labels[i]),
              ],
              if (hidden > 0) ...<Widget>[
                if (shown > 0) const SizedBox(width: _gap),
                _MuscleChip(label: '+$hidden'),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Parent group labels in taxonomy order, so two templates naming the same
  /// groups always render the same strip — the rule `muscleGroupSummary`
  /// already follows for the line this replaces.
  static List<String> _labelsFor(List<String> groupIds) {
    final wanted = groupIds.toSet();
    return <String>[
      for (final id in kMuscleTaxonomy.keys)
        if (wanted.contains(id)) kMuscleGroupLabels[id]!,
    ];
  }

  /// How many of [labels] fit in [maxWidth], leaving room for the overflow chip
  /// whenever it will be needed.
  ///
  /// Always at least one: a card that showed a bare "+5" would have dropped the
  /// only words on it, and one clipped chip reads better than no chips.
  static int _fit(List<String> labels, double maxWidth, TextScaler scaler) {
    if (!maxWidth.isFinite) return labels.length;

    final widths = <double>[
      for (final label in labels) _chipWidth(label, scaler),
    ];
    final total = widths.fold<double>(0, (sum, w) => sum + w) +
        _gap * (labels.length - 1);
    if (total <= maxWidth) return labels.length;

    var used = 0.0;
    var count = 0;
    for (var i = 0; i < labels.length; i++) {
      final overflowChip =
          _gap + _chipWidth('+${labels.length - i - 1}', scaler);
      final next = used + (i == 0 ? 0 : _gap) + widths[i];
      // The last kept chip has to leave room for the count of what it displaced.
      if (i > 0 && next + overflowChip > maxWidth) break;
      used = next;
      count = i + 1;
    }
    return count == 0 ? 1 : count;
  }

  static double _chipWidth(String label, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: kTemplateCardChipStyle),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    // A hair of slack: the painter measures the glyphs, the chip lays out the
    // same text inside a padded box, and a sub-pixel disagreement between the
    // two is the difference between "Shoulders" and "Shoulder".
    return width + _chipPaddingX * 2 + 0.5;
  }
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        height: _chipHeight,
        padding: const EdgeInsets.symmetric(horizontal: _chipPaddingX),
        // **No `alignment:` here.** A `Container` given one wraps itself in an
        // `Align` that expands to its incoming constraints, so under the
        // `Flexible` above each chip grew to fill the row and the strip came
        // out as full-width bars rather than pills. `Center` with a
        // `widthFactor` sizes to the text and still centres it vertically.
        decoration: BoxDecoration(
          // The page colour, not a surface: inset into the card rather than
          // raised off it, which is the only way to read as a chip when the
          // card is already the lightest thing on the screen.
          color: AppPalette.pageBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: kTemplateCardChipStyle,
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
          ),
        ),
      );
}

/// When this template was last performed.
///
/// **Recall, not recommendation, and the distinction is the whole reason this
/// line is allowed to exist.** `docs/02` forbids the Workout tab from stating
/// or implying a schedule; it does not forbid the tab from remembering. This
/// line says what the user did. It never says what to do: it does not rank the
/// list, does not reorder it, does not mark anything overdue, and reads the
/// same whether the gap is one day or one year. A user who wants to train chest
/// still chooses Chest day themselves.
///
/// **"Not done yet" rather than a blank.** Every row keeps the line so the list
/// has one row height, and a template the user has never run is a fact worth
/// telling them — on a fresh install it also shows what the line will become.
class _RecencyLine extends StatelessWidget {
  const _RecencyLine({required this.lastPerformed});

  final LocalDate? lastPerformed;

  @override
  Widget build(BuildContext context) => Text(
        _recencyLabel(lastPerformed),
        style: kTemplateCardRecencyStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
}

/// "Last done 3 days ago", or "Not done yet".
///
/// Relative wording throughout, unlike the History tab's list, which falls back
/// to an absolute date after yesterday. The question here is "how long has it
/// been", not "which session was that" — nobody scans this screen for a
/// particular date.
String _recencyLabel(LocalDate? date) {
  if (date == null) return 'Not done yet';
  final days = LocalDate.today().daysAfter(date);
  if (days <= 0) return 'Last done today';
  if (days == 1) return 'Last done yesterday';
  if (days < 7) return 'Last done $days days ago';
  if (days < 14) return 'Last done 1 week ago';
  if (days < 31) return 'Last done ${days ~/ 7} weeks ago';
  if (days < 62) return 'Last done 1 month ago';
  return 'Last done ${days ~/ 30} months ago';
}

/// The control at the card's trailing edge.
///
/// **A bounded circle, not a bare chevron.** A chevron floating at the edge of
/// a row is the platform's disclosure idiom — it promises a sub-screen you can
/// come back from. This tap starts a workout. A ringed control reads as a
/// button instead, which is what it is.
///
/// **Not accent.** The accent appears exactly once on this screen, on the
/// primary action at the top; seven accent discs down the list would flatten
/// that back to nothing. See `TemplateBodyThumbnail` for the same argument
/// about what `#D85A30` is allowed to mean.
class _StartAffordance extends StatelessWidget {
  const _StartAffordance();

  static const double _size = 30;

  @override
  Widget build(BuildContext context) => Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: AppPalette.pageBackground,
          shape: BoxShape.circle,
          border: Border.all(color: AppPalette.border),
        ),
        child: const Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: AppPalette.textSecondary,
        ),
      );
}

const double _chipHeight = 19;
const double _chipPaddingX = 7;

/// The card's name.
///
/// **Two points larger than [kTemplateRowTitleStyle], which it deliberately
/// does not replace.** That token is now the app's generic row title and is
/// read by the template library, personal details and the library's section
/// rows; this one belongs to the landing card, which is a different size of
/// thing and the only place the user is choosing between options at arm's
/// length.
const TextStyle kTemplateCardTitleStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.2,
  color: AppPalette.textPrimary,
);

/// A muscle chip's label.
const TextStyle kTemplateCardChipStyle = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w500,
  letterSpacing: 0.1,
  color: AppPalette.textSecondary,
  height: 1.0,
);

/// The bespoke muscle line, for the one template the chips do not suit.
const TextStyle kTemplateCardMuscleStyle = TextStyle(
  fontSize: 11.5,
  color: AppPalette.textSecondary,
);

/// "Last done 3 days ago". The quietest thing on the card — it is context for a
/// choice, never the choice itself.
const TextStyle kTemplateCardRecencyStyle = TextStyle(
  fontSize: 11,
  color: AppPalette.textMuted,
);

/// The row's name.
///
/// Kept at its original size: `template_library_screen.dart` and
/// `personal_details_screen.dart` both read it, and neither is a landing card.
const TextStyle kTemplateRowTitleStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.1,
  color: AppPalette.textPrimary,
);

/// The muted supporting line under a row title.
const TextStyle kTemplateRowSubtitleStyle = TextStyle(
  fontSize: 11.5,
  color: AppPalette.textMuted,
);

/// The count line under the filter control.
const TextStyle kLandingCountStyle = TextStyle(
  fontSize: 12,
  color: AppPalette.textSecondary,
);
