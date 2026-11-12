import 'package:flutter/material.dart';

import '../data/date_labels.dart';
import '../data/exercise_progress.dart';
import '../data/local_date.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';

/// What exercise history says instead of a chart with too little in it.
///
/// Two points is a line, not a trend; a chart that opens on one or two dots
/// reads as broken (audit principle 10).
const String kTooFewForTrend = 'Log it three times to see a trend.';

/// How far back the chart reaches. Held in memory only; every visit opens on
/// [all].
enum ProgressRange {
  threeMonths('3 months'),
  oneYear('1 year'),
  all('All');

  const ProgressRange(this.label);

  final String label;

  /// The first day inside this range, or null for all of it.
  LocalDate? from(LocalDate today) => switch (this) {
        ProgressRange.threeMonths => _monthsBack(today, 3),
        ProgressRange.oneYear => _monthsBack(today, 12),
        ProgressRange.all => null,
      };

  static LocalDate _monthsBack(LocalDate today, int months) {
    final d = DateTime(today.year, today.month - months, today.day);
    return LocalDate(d.year, d.month, d.day);
  }
}

/// The best set per session, drawn as a quiet line (audit #7, ADR 0013).
///
/// **Drawn with a `CustomPainter`, no chart package**: one line, its dots,
/// two grid lines and four labels do not need a dependency, and every colour
/// comes from the closed palette (`docs/00` §12). The line and dots are
/// greys; a session that set a personal best is the one amber dot, amber's
/// existing meaning. **Better is always up**, so the assisted chart is
/// inverted and its top label is the lightest assist.
///
/// Screen readers hear [ExerciseProgressSeries.summary] instead of the
/// drawing.
class ExerciseProgressChart extends StatelessWidget {
  const ExerciseProgressChart({required this.series, super.key});

  final ExerciseProgressSeries series;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    return Semantics(
      container: true,
      label: series.summary(),
      excludeSemantics: true,
      child: SizedBox(
        height: 168,
        width: double.infinity,
        child: CustomPaint(
          painter: ProgressChartPainter(series: series, textScaler: scale),
        ),
      ),
    );
  }
}

/// Paints [series]. Public so a test can check it uses palette colours only.
class ProgressChartPainter extends CustomPainter {
  ProgressChartPainter({required this.series, required this.textScaler});

  final ExerciseProgressSeries series;
  final TextScaler textScaler;

  static const Color _grid = AppPalette.border;
  static const Color _line = AppPalette.textSecondary;
  static const Color _dot = AppPalette.textMuted;
  static const Color _record = AppPalette.accentStrong;
  static const Color _hole = AppPalette.surface;
  static const Color _label = AppPalette.textMuted;

  /// Every colour this painter draws with (labels share the dots' grey).
  Set<Color> get colorsUsed =>
      <Color>{_grid, _line, _dot, _record, _hole};

  String _valueLabel(double v) => switch (series.unit) {
        'seconds' => formatDuration(v.round()),
        'reps' => '${v.round()} reps',
        'kg assist' => '${formatWeight(v)}kg assist',
        'kg added' => '+${formatWeight(v)}kg',
        _ => '${formatWeight(v)}kg',
      };

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
    final points = series.points;
    if (points.isEmpty) return;

    final values = points.map((p) => p.value).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    // "Better" is the top label: the heaviest weight, or the lightest assist.
    final topValue = series.inverted ? min : max;
    final bottomValue = series.inverted ? max : min;

    final top = _text(_valueLabel(topValue));
    final bottom = _text(_valueLabel(bottomValue));
    final firstDate = _text(shortDateLabel(points.first.date));
    final lastDate = _text(shortDateLabel(points.last.date));

    const pad = 6.0;
    final plot = Rect.fromLTRB(
      pad,
      top.height + 4,
      size.width - pad,
      size.height - firstDate.height - 8,
    );

    final grid = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    canvas
      ..drawLine(plot.topLeft, plot.topRight, grid)
      ..drawLine(plot.bottomLeft, plot.bottomRight, grid);

    top.paint(canvas, Offset(0, 0));
    if (max != min) {
      bottom.paint(canvas, Offset(0, plot.bottom - bottom.height - 2));
    }

    // Time on x, so a long gap reads as a gap rather than a step.
    final firstDay = points.first.date.epochDay;
    final span = (points.last.date.epochDay - firstDay).toDouble();
    Offset at(ProgressPoint p, int i) {
      final x = span == 0
          ? (points.length == 1
              ? plot.center.dx
              : plot.left + plot.width * i / (points.length - 1))
          : plot.left + plot.width * (p.date.epochDay - firstDay) / span;
      final y = plot.bottom - plot.height * series.heightFraction(p.value);
      return Offset(x, y);
    }

    final offsets = <Offset>[
      for (var i = 0; i < points.length; i++) at(points[i], i),
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

    for (var i = 0; i < points.length; i++) {
      final record = points[i].isRecord;
      canvas.drawCircle(
          offsets[i], record ? 4.5 : 3.5, Paint()..color = _hole);
      canvas.drawCircle(
        offsets[i],
        record ? 3.5 : 2.5,
        Paint()..color = record ? _record : _dot,
      );
    }

    firstDate.paint(canvas, Offset(plot.left, size.height - firstDate.height));
    if (points.length > 1) {
      lastDate.paint(
        canvas,
        Offset(plot.right - lastDate.width, size.height - lastDate.height),
      );
    }
  }

  @override
  bool shouldRepaint(ProgressChartPainter old) =>
      old.series != series || old.textScaler != textScaler;
}
