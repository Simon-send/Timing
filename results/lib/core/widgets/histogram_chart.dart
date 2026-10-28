import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

class HistogramBar {
  const HistogramBar({
    required this.start,
    required this.end,
    required this.count,
    this.value,
  });

  final int start;
  final int end;
  final int count;
  final double? value;
  double get heightValue => value ?? count.toDouble();
}

/// Shared geometry for drawing, hit targets and the result percentile markers.
class HistogramChartLayout {
  static Rect chartRect(Size size) => Rect.fromLTWH(
    52,
    104,
    math.max(0, size.width - 68),
    math.max(0, size.height - 176),
  );

  static Rect binRect(Size size, int index, int count) {
    final chart = chartRect(size);
    return Rect.fromLTWH(
      chart.left + index * chart.width / count,
      chart.top,
      chart.width / count,
      chart.height,
    );
  }
}

/// The actual bar/axis painter used by result and season histograms. Result
/// annotations (percentiles, athlete, peak and mean) remain with their owner.
class HistogramBarsPainter extends CustomPainter {
  const HistogramBarsPainter({
    required this.buckets,
    required this.palette,
    required this.formatValue,
    this.barLabel,
    this.maximumCount,
    this.maximumValue,
    this.axisLabel,
    this.showCountAxisLabels = false,
    this.mean,
    this.meanLabel,
    this.discrete = false,
    this.selectedIndex,
  });

  final List<HistogramBar> buckets;
  final AppPalette palette;
  final String Function(int) formatValue;
  final String Function(int index)? barLabel;
  final int? maximumCount;
  final double? maximumValue;
  final String Function(num)? axisLabel;
  final bool showCountAxisLabels;
  final double? mean;
  final String? meanLabel;
  final bool discrete;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = HistogramChartLayout.chartRect(size);
    if (chart.width <= 0 || chart.height <= 0 || buckets.isEmpty) return;
    final axisPaint = Paint()
      ..color = palette.border
      ..strokeWidth = 1.4;
    final barPaint = Paint()..color = palette.primary;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: barLabel == null ? 1 : 2,
      ellipsis: '...',
    );
    canvas.drawLine(chart.bottomLeft, chart.bottomRight, axisPaint);
    canvas.drawLine(chart.bottomLeft, chart.topLeft, axisPaint);
    final maxCount = math.max(
      maximumValue ?? maximumCount?.toDouble() ?? 0,
      buckets.map((bucket) => bucket.heightValue).reduce(math.max),
    );
    final peakBucket = buckets.reduce(
      (best, current) => current.count > best.count ? current : best,
    );
    final peakIndex = buckets.indexOf(peakBucket);
    final barGap = buckets.length > 18 ? 3.0 : 6.0;
    final barWidth = math.max(2.0, chart.width / buckets.length - barGap);
    for (var i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      final height = maxCount == 0
          ? 0.0
          : chart.height * bucket.heightValue / maxCount;
      final x = chart.left + i * chart.width / buckets.length + barGap / 2;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chart.bottom - height, barWidth, height),
        const Radius.circular(4),
      );
      canvas.drawRRect(barRect, barPaint);
      if (i == peakIndex) {
        canvas.drawRRect(
          barRect,
          Paint()
            ..color = palette.panel
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
      if (i == selectedIndex) {
        canvas.drawRRect(
          barRect,
          Paint()
            ..color = palette.secondary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4,
        );
      }
      _paintText(
        textPainter,
        canvas,
        barLabel?.call(i) ?? '${bucket.count}',
        Offset(
          x + barWidth / 2,
          chart.bottom - height - (barLabel == null ? 18 : 32),
        ),
        center: true,
        fontSize: 11,
        bold: true,
        maxWidth: barLabel == null ? 76 : chart.width / buckets.length,
      );
      if (buckets.length <= 14 || i == 0 || i == buckets.length - 1) {
        _paintText(
          textPainter,
          canvas,
          i == buckets.length - 1
              ? formatValue(bucket.end)
              : formatValue(bucket.start),
          Offset(x + barWidth / 2, chart.bottom + 8),
          center: true,
          fontSize: 10,
        );
      }
    }
    if (showCountAxisLabels) {
      _paintText(
        textPainter,
        canvas,
        axisLabel?.call(maxCount) ?? maxCount.toInt().toString(),
        Offset(chart.left - 8, chart.top - 2),
        alignRight: true,
        fontSize: 10,
      );
      _paintText(
        textPainter,
        canvas,
        '0',
        Offset(chart.left - 8, chart.bottom - 12),
        alignRight: true,
        fontSize: 10,
      );
    }
    if (mean != null && meanLabel != null) {
      final low = buckets.first.start;
      final high = buckets.last.end;
      final span = high - low + (discrete ? 1 : 0);
      final ratio = span == 0
          ? 0.5
          : (mean! - low + (discrete ? 0.5 : 0)) / span;
      final x = chart.left + chart.width * ratio.clamp(0, 1);
      final color = histogramAverageLineColor(palette);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.4;
      for (var y = chart.top; y < chart.bottom; y += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(y + 4, chart.bottom)),
          paint,
        );
      }
      textPainter.maxLines = 1;
      textPainter.text = TextSpan(
        text: meanLabel,
        style: TextStyle(
          color: palette.mutedText,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      );
      textPainter.layout(maxWidth: math.max(0, size.width - 24));
      final width = textPainter.width + 16;
      final left = (x - width / 2)
          .clamp(0, math.max(0, size.width - width))
          .toDouble();
      final badge = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 10, width, textPainter.height + 12),
        const Radius.circular(6),
      );
      canvas.drawRRect(badge, Paint()..color = color.withValues(alpha: 0.16));
      canvas.drawRRect(
        badge,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke,
      );
      textPainter.paint(canvas, Offset(left + 8, 16));
    }
  }

  void _paintText(
    TextPainter painter,
    Canvas canvas,
    String text,
    Offset offset, {
    bool center = false,
    bool alignRight = false,
    double fontSize = 13,
    bool bold = false,
    double maxWidth = 76,
  }) {
    painter.text = TextSpan(
      text: text.isEmpty ? '-' : text,
      style: TextStyle(
        color: palette.mutedText,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
      ),
    );
    painter.textAlign = center ? TextAlign.center : TextAlign.left;
    painter.layout(maxWidth: maxWidth);
    var dx = offset.dx;
    if (center) dx -= painter.width / 2;
    if (alignRight) dx -= painter.width;
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant HistogramBarsPainter oldDelegate) =>
      oldDelegate.buckets != buckets ||
      oldDelegate.palette != palette ||
      oldDelegate.formatValue != formatValue ||
      oldDelegate.barLabel != barLabel ||
      oldDelegate.maximumCount != maximumCount ||
      oldDelegate.maximumValue != maximumValue ||
      oldDelegate.axisLabel != axisLabel ||
      oldDelegate.showCountAxisLabels != showCountAxisLabels ||
      oldDelegate.mean != mean ||
      oldDelegate.meanLabel != meanLabel ||
      oldDelegate.discrete != discrete ||
      oldDelegate.selectedIndex != selectedIndex;
}

Color histogramAverageLineColor(AppPalette palette) =>
    palette.brightness == Brightness.dark
    ? const Color(0xFF8ED8FF)
    : const Color(0xFF006DAD);
