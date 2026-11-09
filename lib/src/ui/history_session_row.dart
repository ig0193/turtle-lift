import 'package:flutter/material.dart';

import '../data/history_preview_data.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'history_session_detail_screen.dart';

/// One logged session, as a row: glyph, title, and the line beneath it.
///
/// **Shared by [HistoryRoot]'s Recent list and `AllSessionsScreen`'s full
/// list.** It first existed only on the tab root, back when the root rendered
/// every session; splitting the root into a calendar plus a short Recent
/// section, with the full chronological list moved to its own pushed screen,
/// gave the row two callers instead of one. `divider_row.dart` and
/// `ghost_button.dart` give the same reasoning for the same move: a row shape
/// belongs to neither of the screens that use it.
class HistorySessionRow extends StatelessWidget {
  const HistorySessionRow({
    required this.session,
    required this.figures,
    super.key,
  });

  final HistorySession session;
  final HistoryRowFigures figures;

  @override
  Widget build(BuildContext context) {
    final title = resolvedTitle(session, figures);
    final exercises =
        '${figures.exerciseCount} exercise${figures.exerciseCount == 1 ? '' : 's'}';
    final sets = '${figures.setCount} set${figures.setCount == 1 ? '' : 's'}';
    final meta = '${historyDateLabel(session.performedOn)} · $exercises · $sets';
    // Opaque, like every push in this app: it is the only route kind that
    // covers the floating tab bar (see `L0Shell`).
    void open() => Navigator.of(context).push(
          MaterialPageRoute<void>(
            // Named for its session, so a delete further up the stack can
            // close it rather than leave a screen for a workout that is gone.
            settings: RouteSettings(
              name: HistorySessionDetailScreen.routeNameFor(session.id),
            ),
            builder: (_) =>
                HistorySessionDetailScreen(sessionId: session.id),
          ),
        );

    return Semantics(
      container: true,
      button: true,
      label: <String>[
        title,
        if (figures.pbCount > 0) '${figures.pbCount} personal best'
            '${figures.pbCount == 1 ? '' : 's'}',
        if (session.isQuickLog) 'quick log',
        meta,
      ].join(', '),
      onTap: open,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppPalette.border)),
          ),
          child: Row(
            children: <Widget>[
              MuscleGlyph(groupIds: figures.trainedGroupIds),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppPalette.textPrimary,
                            ),
                          ),
                        ),
                        // Only when there is one. "0 personal bests" is the
                        // thing the spec explicitly forbids rendering.
                        if (figures.pbCount > 0) _PbPill(count: figures.pbCount),
                        if (session.isQuickLog) const _QuickLogTag(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppPalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today", "Yesterday", or a day and month.
///
/// Relative wording only for the two days a user thinks of relatively; beyond
/// that an absolute date is what someone scanning for a particular session
/// actually wants.
@visibleForTesting
String historyDateLabel(DateTime performedOn, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  // Counted on UTC midnights: a local day across a daylight-saving change is
  // 23 or 25 hours, and `inDays` on local midnights called Sunday "Today" on
  // the Monday after the clocks went forward (QA second pass).
  final days = DateTime.utc(clock.year, clock.month, clock.day)
      .difference(DateTime.utc(
          performedOn.year, performedOn.month, performedOn.day))
      .inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  const abbr = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${performedOn.day} ${abbr[performedOn.month - 1]}';
}

/// A month heading over a run of [HistorySessionRow]s.
class HistoryMonthLabel extends StatelessWidget {
  const HistoryMonthLabel({required this.label, required this.first, super.key});

  final String label;

  /// Whether this is the first heading in the list -- it carries less top air
  /// than one that follows a previous month's rows.
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 4 : 20, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(label, style: kLandingSectionLabelStyle),
      ),
    );
  }
}

/// The personal-best count: the app's one PB mark ([kPbMarkStyle]).
class _PbPill extends StatelessWidget {
  const _PbPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Text('$count PB', style: kPbMarkStyle),
      );
}

/// Marks a single-exercise session, so its shorter line reads as a kind of
/// entry rather than as missing data.
class _QuickLogTag extends StatelessWidget {
  const _QuickLogTag();

  @override
  Widget build(BuildContext context) {
    // Quiet text, not a pill: it states a kind of entry, it is not a control.
    return const Padding(
      padding: EdgeInsets.only(left: 8),
      child: Text(
        'quick log',
        style: TextStyle(
          fontSize: 12,
          color: AppPalette.textMuted,
        ),
      ),
    );
  }
}

/// A thumbnail silhouette, filled where the session's primary muscles were.
///
/// **Hand-painted bands, not `BodyDiagram`.** The real diagram is 42 polygon
/// segments behind a `CustomPainter` with hit-testing; instantiating one per
/// row, in a list that grows without bound, is the cost review flagged on this
/// variant. At 22×34 none of that detail survives anyway — what reads at this
/// size is *where on the body* the fill sits, which a handful of bands carry.
///
/// It is a glyph, not a diagram: no taps, no per-segment colours, no gender
/// variants. When a row needs the real thing it opens session detail, which
/// has room for it.
class MuscleGlyph extends StatelessWidget {
  const MuscleGlyph({required this.groupIds, super.key});

  final List<String> groupIds;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 34,
      child: CustomPaint(
        painter: _MuscleGlyphPainter(groupIds.toSet()),
      ),
    );
  }
}

class _MuscleGlyphPainter extends CustomPainter {
  _MuscleGlyphPainter(this.trained);

  final Set<String> trained;

  /// Where each parent group sits on the silhouette, as a fraction of height:
  /// (top, height, inset from each side). Shoulders and arms sit wide; the
  /// trunk groups sit narrow; legs run the lower half.
  static const Map<String, (double, double, double)> _bands =
      <String, (double, double, double)>{
    'shoulders': (0.12, 0.07, 0.00),
    'chest': (0.20, 0.09, 0.18),
    'back': (0.20, 0.09, 0.18),
    'biceps': (0.28, 0.09, 0.00),
    'triceps': (0.28, 0.09, 0.00),
    'forearms': (0.38, 0.07, 0.00),
    'abs': (0.31, 0.10, 0.28),
    'obliques': (0.31, 0.10, 0.10),
    'quads': (0.50, 0.20, 0.18),
    'hamstrings': (0.50, 0.20, 0.18),
    'glutes': (0.45, 0.06, 0.18),
    'calves': (0.74, 0.16, 0.22),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = AppPalette.mutedSurface;
    final fill = Paint()..color = AppPalette.accentStrong;

    // The silhouette: head, then one rounded slab for everything below it.
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.06),
        size.width * 0.16, body);
    final torso = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.12, size.width, size.height * 0.88),
      Radius.circular(size.width * 0.22),
    );
    canvas.drawRRect(torso, body);

    canvas.save();
    canvas.clipRRect(torso);
    for (final id in trained) {
      final band = _bands[id];
      if (band == null) continue;
      final (top, height, inset) = band;
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * inset,
          size.height * top,
          size.width * (1 - inset * 2),
          size.height * height,
        ),
        fill,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MuscleGlyphPainter old) => old.trained != trained;
}
