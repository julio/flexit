import 'package:flutter/material.dart';
import '../data/storage.dart';
import '../theme.dart';

class WeightChartScreen extends StatelessWidget {
  final Map<String, int> weights; // YYYY-MM-DD -> grams
  final String unit; // 'kg' or 'lb'

  const WeightChartScreen({
    super.key,
    required this.weights,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    // Sort entries by date ascending so the chart's x-axis flows left→right.
    final entries = weights.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final points = entries
        .map((e) => _Point(
              date: DateTime.parse(e.key),
              value: unit == 'kg' ? gramsToKg(e.value) : gramsToLb(e.value),
            ))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight evolution'),
      ),
      body: points.isEmpty
          ? Center(
              child: Text(
                'No weight entries yet.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            )
          : Column(
              children: [
                _StatsRow(points: points, unit: unit),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: _WeightLineChart(points: points, unit: unit),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Point {
  final DateTime date;
  final double value;
  const _Point({required this.date, required this.value});
}

class _StatsRow extends StatelessWidget {
  final List<_Point> points;
  final String unit;
  const _StatsRow({required this.points, required this.unit});

  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.value).toList();
    final latest = values.last;
    final first = values.first;
    final delta = latest - first;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    Widget cell(String label, String value, {Color? valueColor}) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppColors.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style:
                  TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final deltaColor = delta == 0
        ? AppColors.textSecondary
        : (delta < 0 ? AppColors.success : AppColors.missed);
    final sign = delta > 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            cell('Latest', '${latest.toStringAsFixed(1)} $unit'),
            cell('Change',
                '$sign${delta.toStringAsFixed(1)} $unit',
                valueColor: deltaColor),
            cell('Min', '${min.toStringAsFixed(1)} $unit'),
            cell('Max', '${max.toStringAsFixed(1)} $unit'),
          ],
        ),
      ),
    );
  }
}

class _WeightLineChart extends StatelessWidget {
  final List<_Point> points;
  final String unit;
  const _WeightLineChart({required this.points, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(8, 14, 14, 8),
      child: LayoutBuilder(
        builder: (_, c) => CustomPaint(
          size: Size(c.maxWidth, c.maxHeight),
          painter: _LineChartPainter(
            points: points,
            unit: unit,
            lineColor: AppColors.accent,
            fillColor: AppColors.accent.withValues(alpha: 0.15),
            axisColor: AppColors.cardBorder,
            labelColor: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_Point> points;
  final String unit;
  final Color lineColor;
  final Color fillColor;
  final Color axisColor;
  final Color labelColor;

  _LineChartPainter({
    required this.points,
    required this.unit,
    required this.lineColor,
    required this.fillColor,
    required this.axisColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const leftPad = 44.0;
    const rightPad = 8.0;
    const topPad = 8.0;
    const bottomPad = 28.0;

    final plotW = size.width - leftPad - rightPad;
    final plotH = size.height - topPad - bottomPad;
    if (plotW <= 0 || plotH <= 0) return;

    // Y range with a little headroom on both sides.
    final values = points.map((p) => p.value).toList();
    var minY = values.reduce((a, b) => a < b ? a : b);
    var maxY = values.reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    } else {
      final pad = (maxY - minY) * 0.1;
      minY -= pad;
      maxY += pad;
    }

    // X is by index — uneven gaps in dates are smoothed away. The date axis
    // still shows endpoints so the timeline is legible.
    Offset pointFor(int i) {
      final x = leftPad +
          (points.length == 1 ? plotW / 2 : (i / (points.length - 1)) * plotW);
      final y = topPad + plotH * (1 - (points[i].value - minY) / (maxY - minY));
      return Offset(x, y);
    }

    // Y gridlines (4 horizontal lines including endpoints).
    final gridPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    const yTicks = 4;
    for (var i = 0; i <= yTicks; i++) {
      final t = i / yTicks;
      final y = topPad + plotH * t;
      canvas.drawLine(
          Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
      final v = minY + (maxY - minY) * (1 - t);
      tp.text = TextSpan(
        text: v.toStringAsFixed(1),
        style: TextStyle(color: labelColor, fontSize: 10),
      );
      tp.layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    // Build the path.
    final linePath = Path();
    final fillPath = Path();
    for (var i = 0; i < points.length; i++) {
      final p = pointFor(i);
      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
        fillPath.moveTo(p.dx, topPad + plotH);
        fillPath.lineTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
        fillPath.lineTo(p.dx, p.dy);
      }
    }
    fillPath.lineTo(pointFor(points.length - 1).dx, topPad + plotH);
    fillPath.close();

    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots for each data point.
    final dotPaint = Paint()..color = lineColor;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(pointFor(i), 3, dotPaint);
    }

    // X axis labels — first and last dates.
    String fmt(DateTime d) =>
        '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    tp.text = TextSpan(
      text: fmt(points.first.date),
      style: TextStyle(color: labelColor, fontSize: 10),
    );
    tp.layout();
    tp.paint(canvas, Offset(leftPad - 4, size.height - bottomPad + 6));

    tp.text = TextSpan(
      text: fmt(points.last.date),
      style: TextStyle(color: labelColor, fontSize: 10),
    );
    tp.layout();
    tp.paint(
        canvas,
        Offset(size.width - rightPad - tp.width,
            size.height - bottomPad + 6));

    // Unit label in top-left.
    tp.text = TextSpan(
      text: unit,
      style: TextStyle(
        color: labelColor,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
    tp.layout();
    tp.paint(canvas, const Offset(0, 0));
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.points != points || old.unit != unit;
}
