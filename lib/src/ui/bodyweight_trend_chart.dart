import 'package:flutter/material.dart';

import '../data/date_labels.dart';
import '../data/local_date.dart';
import '../data/personal_details_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';

/// One sentence for the weight log's shape, which is also what a screen
/// reader hears for the chart (ADR 0014 §2): "From 72 to 74.5 kg over 3
/// weigh-ins since 27 Oct." [entries] are oldest first, at least two.
///
/// A sentence about **authored** data (the weigh-ins the user typed), not a
/// figure computed from sessions, so it may live on Profile (ADR 0004).
String bodyweightTrendSummary(
  List<BodyweightEntry> entries, {
  LocalDate? today,
}) {
  final first = entries.first;
  final last = entries.last;
  final since = shortDateLabel(LocalDate.fromDateTime(first.date), today: today);
  final count = entries.length;
  if (first.weightKg == last.weightKg) {
    return 'Steady at ${formatWeight(last.weightKg)} kg over $count weigh-ins '
        'since $since.';
  }
  return 'From ${formatWeight(first.weightKg)} to ${formatWeight(last.weightKg)}'
      ' kg over $count weigh-ins since $since.';
}

/// The weigh-ins as a line on Personal details, shown from two entries.
///
/// **Greys only.** Amber means worked, active or a record; a heavier or
/// lighter bodyweight is none of those, and the app passes no verdict on it.
class BodyweightTrendChart extends StatelessWidget {
  const BodyweightTrendChart({required this.entries, super.key});

  /// Oldest first, at least two.
  final List<BodyweightEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: bodyweightTrendSummary(entries),
      excludeSemantics: true,
      child: SizedBox(
        height: 120,
        width: double.infinity,
        child: CustomPaint(
          painter: BodyweightTrendPainter(
            entries: entries,
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
      ),
    );
  }
}

/// Paints [entries]. Public so a test can check its colours.
class BodyweightTrendPainter extends CustomPainter {
  BodyweightTrendPainter({required this.entries, required this.textScaler});

  final List<BodyweightEntry> entries;
  final TextScaler textScaler;

  static const Color _grid = AppPalette.border;
  static const Color _line = AppPalette.textSecondary;
  static const Color _dot = AppPalette.textPrimary;
  static const Color _hole = AppPalette.surface;
  static const Color _label = AppPalette.textMuted;

  /// Every colour this painter draws with.
  Set<Color> get colorsUsed => <Color>{_grid, _line, _dot, _hole, _label};

  TextPainter _text(String s) => TextPainter(
        text: TextSpan(
          text: s,
          style: const TextStyle(fontSize: 12, color: _label),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) return;
    final values = entries.map((e) => e.weightKg).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    final top = _text('${formatWeight(max)} kg');
    final bottom = _text('${formatWeight(min)} kg');
    final firstDate =
        _text(shortDateLabel(LocalDate.fromDateTime(entries.first.date)));
    final lastDate =
        _text(shortDateLabel(LocalDate.fromDateTime(entries.last.date)));

    const pad = 6.0;
    // The weight labels get a gutter of their own on the left, so the first
    // dot never sits on top of the lowest label.
    final gutter =
        (top.width > bottom.width ? top.width : bottom.width) + 10;
    final plot = Rect.fromLTRB(
      gutter,
      top.height / 2 + 2,
      size.width - pad,
      size.height - firstDate.height - 8,
    );
    final grid = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    canvas
      ..drawLine(plot.topLeft, plot.topRight, grid)
      ..drawLine(plot.bottomLeft, plot.bottomRight, grid);
    top.paint(canvas, Offset(0, plot.top - top.height / 2));
    if (max != min) {
      bottom.paint(canvas, Offset(0, plot.bottom - bottom.height / 2));
    }

    // Time on x, so a month without a weigh-in reads as a gap.
    final firstDay = LocalDate.fromDateTime(entries.first.date).epochDay;
    final span =
        (LocalDate.fromDateTime(entries.last.date).epochDay - firstDay)
            .toDouble();
    final offsets = <Offset>[
      for (var i = 0; i < entries.length; i++)
        Offset(
          span == 0
              ? plot.left + plot.width * i / (entries.length - 1)
              : plot.left +
                  plot.width *
                      (LocalDate.fromDateTime(entries[i].date).epochDay -
                          firstDay) /
                      span,
          max == min
              ? plot.center.dy
              : plot.bottom -
                  plot.height * (entries[i].weightKg - min) / (max - min),
        ),
    ];
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final o in offsets.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
    for (final o in offsets) {
      canvas
        ..drawCircle(o, 3.5, Paint()..color = _hole)
        ..drawCircle(o, 2.5, Paint()..color = _dot);
    }
    firstDate.paint(canvas, Offset(plot.left, size.height - firstDate.height));
    lastDate.paint(
      canvas,
      Offset(plot.right - lastDate.width, size.height - lastDate.height),
    );
  }

  @override
  bool shouldRepaint(BodyweightTrendPainter old) =>
      old.entries != entries || old.textScaler != textScaler;
}
