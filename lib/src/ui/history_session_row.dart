import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart' show activeSessionProvider;
import '../data/date_labels.dart';
import '../data/history_preview_data.dart';
import '../data/local_date.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'destructive_confirmation.dart';
import 'history_session_detail_screen.dart';

/// One logged session, as a row: glyph, title, and the line beneath it.
///
/// **Shared by [HistoryRoot]'s Recent list, the calendar's day panel and
/// `AllSessionsScreen`'s full list**, so a row reads and acts the same
/// wherever it appears.
///
/// **Swipe left to delete** (`docs/00` §11, `docs/04`; audit B8), behind the
/// same confirmation as the editor's Delete. VoiceOver gets Delete as a
/// custom action on the row, since a swipe is not something it can do.
///
/// **The PB mark is quiet here** (ADR 0013): the word "PB" in muted grey, no
/// count. With progressive training most rows earn one, and an amber count on
/// every row stopped carrying news; the amber count stays on the card.
class HistorySessionRow extends ConsumerWidget {
  const HistorySessionRow({
    required this.session,
    required this.figures,
    super.key,
  });

  final HistorySession session;
  final HistoryRowFigures figures;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    Future<bool> confirmDelete() => confirmDestructive(
          context,
          title: 'Delete $title?',
          message: 'This permanently removes the workout from '
              '${cardDateLabel(LocalDate.fromDateTime(session.performedOn))} '
              'and every set in it. Records and your streak will update.',
          confirmLabel: 'Delete',
        );

    Future<void> delete() =>
        ref.read(activeSessionProvider.notifier).deleteSaved(session.id);

    Future<void> deleteFromAction() async {
      if (await confirmDelete()) await delete();
    }

    final row = Semantics(
      container: true,
      button: true,
      label: <String>[
        title,
        if (figures.pbCount > 0) 'personal best',
        if (session.isQuickLog) 'quick log',
        meta,
      ].join(', '),
      onTap: open,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        const CustomSemanticsAction(label: 'Delete'): deleteFromAction,
      },
      excludeSemantics: true,
      child: _PressableRow(
        onTap: open,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          decoration: const BoxDecoration(
            color: AppPalette.pageBackground,
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
                        if (figures.pbCount > 0) const _PbMark(),
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

    return Dismissible(
      key: ValueKey<String>('dismiss-${session.id}'),
      direction: DismissDirection.endToStart,
      // The delete happens here and the row slides back: the derived list
      // drops it on the next frame. Letting Dismissible remove it instead
      // races the async store write, and Flutter asserts on a dismissed row
      // that is still in the tree.
      confirmDismiss: (_) async {
        if (await confirmDelete()) await delete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        // An icon, not the word: the confirmation's own Delete button is the
        // one control with that label on screen.
        child: const ExcludeSemantics(
          child: Icon(
            Icons.delete_outline_rounded,
            size: 22,
            color: AppPalette.danger,
          ),
        ),
      ),
      child: row,
    );
  }
}

/// A row's tap, with the dimming a `GestureDetector` does not give.
class _PressableRow extends StatefulWidget {
  const _PressableRow({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressableRow> createState() => _PressableRowState();
}

class _PressableRowState extends State<_PressableRow> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: AnimatedOpacity(
          opacity: _down ? 0.6 : 1,
          duration: const Duration(milliseconds: 80),
          child: widget.child,
        ),
      );
}

/// "Today", "Yesterday", or a day and month.
///
/// Relative wording only for the two days a user thinks of relatively; beyond
/// that an absolute date is what someone scanning for a particular session
/// actually wants. Also the day on the Workout landing's last-workout line,
/// which must read exactly like the History row it points at.
///
/// The year joins once the date is not this year ("7 Nov 2025", audit B4).
/// Counted on calendar dates ([LocalDate]), never durations: a local day
/// across a daylight-saving change is 23 or 25 hours, and `inDays` on local
/// midnights called Sunday "Today" on the Monday after the clocks went
/// forward (QA second pass).
String historyDateLabel(DateTime performedOn, {DateTime? now}) =>
    relativeDayLabel(
      LocalDate.fromDateTime(performedOn),
      today: LocalDate.fromDateTime(now ?? DateTime.now()),
    );

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

/// A quiet "PB": muted grey, no count (ADR 0013). The amber count lives on
/// the card and the marked set in the log.
class _PbMark extends StatelessWidget {
  const _PbMark();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(left: 8),
        child: Text(
          'PB',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppPalette.textMuted,
          ),
        ),
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
