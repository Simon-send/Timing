import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatting/time_formatters.dart';
import '../domain/split_def.dart';
import 'results_table.dart';

const _maxVisibleSeries = 28;

class ResultsSplitGraph extends StatelessWidget {
  const ResultsSplitGraph({
    super.key,
    required this.rows,
    required this.splitOptions,
    required this.selectedSplitId,
    required this.splitRange,
    this.disabledResultId,
    required this.onAthleteTap,
  });

  final List<ResultTableRow> rows;
  final List<SplitOption> splitOptions;
  final String? selectedSplitId;
  final SplitRangeSelection? splitRange;
  final String? disabledResultId;
  final ValueChanged<ResultTableRow> onAthleteTap;

  @override
  Widget build(BuildContext context) {
    final graph = _buildSplitGraph(
      rows: rows,
      splitOptions: splitOptions,
      selectedSplitId: selectedSplitId,
      splitRange: splitRange,
    );
    if (graph == null || graph.series.isEmpty) {
      return const _SplitGraphEmpty();
    }

    final visibleSeries = graph.series.take(_maxVisibleSeries).toList();
    final visibleGraph = graph.copyWith(
      series: visibleSeries,
      maxGapMs: _maxGapMs(visibleSeries),
    );
    final hiddenCount = graph.series.length - visibleSeries.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final chart = _SplitGraphChart(
          data: visibleGraph,
          disabledResultId: disabledResultId,
        );
        final legend = _SplitGraphLegend(
          series: visibleSeries,
          hiddenCount: hiddenCount,
          disabledResultId: disabledResultId,
          onAthleteTap: onAthleteTap,
        );

        if (compact) {
          return Column(
            children: [
              Expanded(child: chart),
              const SizedBox(height: 10),
              SizedBox(height: 172, child: legend),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: chart),
            const SizedBox(width: 12),
            SizedBox(width: 280, child: legend),
          ],
        );
      },
    );
  }
}

class _SplitGraphChart extends StatelessWidget {
  const _SplitGraphChart({
    required this.data,
    required this.disabledResultId,
  });

  final _SplitGraphData data;
  final String? disabledResultId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: _SplitGraphPainter(
            data: data,
            palette: palette,
            disabledResultId: disabledResultId,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SplitGraphLegend extends StatelessWidget {
  const _SplitGraphLegend({
    required this.series,
    required this.hiddenCount,
    required this.disabledResultId,
    required this.onAthleteTap,
  });

  final List<_SplitSeries> series;
  final int hiddenCount;
  final String? disabledResultId;
  final ValueChanged<ResultTableRow> onAthleteTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final useRowColors = series.any((item) => item.row.color != null);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Utover',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  'Gap',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              itemCount: series.length,
              separatorBuilder: (context, index) => const SizedBox(height: 5),
              itemBuilder: (context, index) {
                final item = series[index];
                return _SplitGraphLegendTile(
                  index: index,
                  series: item,
                  color: _seriesColor(
                    palette,
                    item,
                    index,
                    useRowColors: useRowColors,
                    disabled: _isDisabled(item.row, disabledResultId),
                  ),
                  disabled: _isDisabled(item.row, disabledResultId),
                  onTap: () => onAthleteTap(item.row),
                );
              },
            ),
          ),
          if (hiddenCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(
                '+$hiddenCount flere',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SplitGraphLegendTile extends StatelessWidget {
  const _SplitGraphLegendTile({
    required this.index,
    required this.series,
    required this.color,
    required this.disabled,
    required this.onTap,
  });

  final int index;
  final _SplitSeries series;
  final Color color;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final row = series.row;
    return Material(
      color: disabled ? palette.border.withValues(alpha: 0.22) : palette.panel,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      row.result.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: disabled ? palette.mutedText : null,
                      ),
                    ),
                    if (row.color != null)
                      Text(
                        row.className,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatGap(series.focusGapMs),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: disabled ? palette.mutedText : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplitGraphEmpty extends StatelessWidget {
  const _SplitGraphEmpty();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Center(
        child: Text(
          'Ingen splitgrafdata',
          style: TextStyle(
            color: palette.mutedText,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SplitGraphPainter extends CustomPainter {
  const _SplitGraphPainter({
    required this.data,
    required this.palette,
    required this.disabledResultId,
  });

  final _SplitGraphData data;
  final AppPalette palette;
  final String? disabledResultId;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = _SplitGraphLayout.chartRect(size);
    if (chart.width <= 0 || chart.height <= 0 || data.series.isEmpty) return;

    final yMax = _niceAxisMax(data.maxGapMs);
    final axisPaint = Paint()
      ..color = palette.border
      ..strokeWidth = 1.2;
    final gridPaint = Paint()
      ..color = palette.border.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final selectedPaint = Paint()
      ..color = palette.secondary
      ..strokeWidth = 1.8;
    final rangePaint = Paint()
      ..color = palette.primary.withValues(alpha: 0.09);
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );

    _paintRangeBand(canvas, chart, rangePaint);
    _paintGrid(canvas, chart, yMax, gridPaint, axisPaint, textPainter);
    _paintSplitLines(canvas, chart, gridPaint, selectedPaint, textPainter);
    _paintSeries(canvas, chart, yMax);
  }

  void _paintRangeBand(Canvas canvas, Rect chart, Paint paint) {
    final start = data.rangeStartIndex;
    final end = data.rangeEndIndex;
    if (start == null || end == null || end < start) return;
    final left = _xForSplit(start, chart, data.splits.length);
    final right = _xForSplit(end, chart, data.splits.length);
    canvas.drawRect(
      Rect.fromLTRB(left, chart.top, right, chart.bottom),
      paint,
    );
  }

  void _paintGrid(
    Canvas canvas,
    Rect chart,
    int yMax,
    Paint gridPaint,
    Paint axisPaint,
    TextPainter textPainter,
  ) {
    for (var i = 0; i <= 4; i++) {
      final value = (yMax * i / 4).round();
      final y = _yForGap(value, yMax, chart);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _paintText(
        textPainter,
        canvas,
        _formatGap(value),
        Offset(chart.left - 8, y - 7),
        alignRight: true,
        color: palette.mutedText,
        fontSize: 10,
      );
    }

    canvas.drawLine(chart.bottomLeft, chart.bottomRight, axisPaint);
    canvas.drawLine(chart.bottomLeft, chart.topLeft, axisPaint);
  }

  void _paintSplitLines(
    Canvas canvas,
    Rect chart,
    Paint gridPaint,
    Paint selectedPaint,
    TextPainter textPainter,
  ) {
    final splits = data.splits;
    final wantedLabels = chart.width < 480 ? 5 : 8;
    final labelEvery = math.max(1, (splits.length / wantedLabels).ceil());

    for (var index = 0; index < splits.length; index++) {
      final x = _xForSplit(index, chart, splits.length);
      final selected = index == data.selectedSplitIndex;
      canvas.drawLine(
        Offset(x, chart.top),
        Offset(x, chart.bottom),
        selected ? selectedPaint : gridPaint,
      );

      final showLabel =
          selected ||
          index == 0 ||
          index == splits.length - 1 ||
          index % labelEvery == 0;
      if (!showLabel) continue;
      _paintText(
        textPainter,
        canvas,
        splits[index].label,
        Offset(x, chart.bottom + 10),
        center: true,
        color: selected ? palette.secondary : palette.mutedText,
        fontSize: selected ? 11 : 10,
        bold: selected,
        maxWidth: 72,
      );
    }
  }

  void _paintSeries(Canvas canvas, Rect chart, int yMax) {
    final useRowColors = data.series.any((item) => item.row.color != null);
    for (var index = data.series.length - 1; index >= 0; index--) {
      final series = data.series[index];
      final disabled = _isDisabled(series.row, disabledResultId);
      final color = _seriesColor(
        palette,
        series,
        index,
        useRowColors: useRowColors,
        disabled: disabled,
      );
      final linePaint = Paint()
        ..color = color.withValues(alpha: disabled ? 0.38 : 0.84)
        ..strokeWidth = index < 8 ? 2.5 : 1.55
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final pointPaint = Paint()..color = color;
      final path = Path();
      var started = false;

      for (final point in series.points) {
        final x = _xForSplit(point.splitIndex, chart, data.splits.length);
        final y = _yForGap(point.gapMs, yMax, chart);
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }

      if (started) canvas.drawPath(path, linePaint);

      final activePoint = series.pointAt(data.selectedSplitIndex);
      if (activePoint == null) continue;
      final x = _xForSplit(activePoint.splitIndex, chart, data.splits.length);
      final y = _yForGap(activePoint.gapMs, yMax, chart);
      canvas.drawCircle(Offset(x, y), index < 8 ? 4.0 : 3.0, pointPaint);
      canvas.drawCircle(
        Offset(x, y),
        index < 8 ? 4.0 : 3.0,
        Paint()
          ..color = palette.panelAlt
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _paintText(
    TextPainter painter,
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
    bool center = false,
    bool alignRight = false,
    bool bold = false,
    double fontSize = 11,
    double maxWidth = 84,
  }) {
    painter.text = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
      ),
    );
    painter.layout(maxWidth: maxWidth);
    var dx = offset.dx;
    if (center) dx -= painter.width / 2;
    if (alignRight) dx -= painter.width;
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _SplitGraphPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.palette != palette ||
        oldDelegate.disabledResultId != disabledResultId;
  }
}

class _SplitGraphLayout {
  static const left = 58.0;
  static const top = 24.0;
  static const right = 18.0;
  static const bottom = 58.0;

  static Rect chartRect(Size size) {
    return Rect.fromLTWH(
      left,
      top,
      math.max(0, size.width - left - right),
      math.max(0, size.height - top - bottom),
    );
  }
}

class _SplitGraphData {
  const _SplitGraphData({
    required this.splits,
    required this.series,
    required this.selectedSplitIndex,
    required this.maxGapMs,
    required this.rangeStartIndex,
    required this.rangeEndIndex,
  });

  final List<SplitOption> splits;
  final List<_SplitSeries> series;
  final int selectedSplitIndex;
  final int maxGapMs;
  final int? rangeStartIndex;
  final int? rangeEndIndex;

  _SplitGraphData copyWith({
    List<_SplitSeries>? series,
    int? maxGapMs,
  }) {
    return _SplitGraphData(
      splits: splits,
      series: series ?? this.series,
      selectedSplitIndex: selectedSplitIndex,
      maxGapMs: maxGapMs ?? this.maxGapMs,
      rangeStartIndex: rangeStartIndex,
      rangeEndIndex: rangeEndIndex,
    );
  }
}

class _SplitSeries {
  const _SplitSeries({
    required this.row,
    required this.points,
    required this.focusGapMs,
    required this.focusCumMs,
  });

  final ResultTableRow row;
  final List<_SplitGraphPoint> points;
  final int focusGapMs;
  final int focusCumMs;

  _SplitGraphPoint? pointAt(int splitIndex) {
    for (final point in points) {
      if (point.splitIndex == splitIndex) return point;
    }
    return null;
  }
}

class _SplitGraphPoint {
  const _SplitGraphPoint({
    required this.splitIndex,
    required this.gapMs,
    required this.cumMs,
  });

  final int splitIndex;
  final int gapMs;
  final int cumMs;
}

_SplitGraphData? _buildSplitGraph({
  required List<ResultTableRow> rows,
  required List<SplitOption> splitOptions,
  required String? selectedSplitId,
  required SplitRangeSelection? splitRange,
}) {
  if (rows.isEmpty || splitOptions.length < 2) return null;

  final bestBySplitId = <String, int>{};
  for (final split in splitOptions) {
    int? best;
    for (final row in rows) {
      final value = row.result.splitValues[split.id]?.cumMs;
      if (value == null || value <= 0) continue;
      if (best == null || value < best) best = value;
    }
    if (best != null) bestBySplitId[split.id] = best;
  }

  final splits = [
    for (final split in splitOptions)
      if (bestBySplitId.containsKey(split.id)) split,
  ];
  if (splits.length < 2) return null;

  final focusedSplitId = splitRange?.toSplitId ?? selectedSplitId;
  var selectedSplitIndex = splits.indexWhere(
    (split) => split.id == focusedSplitId,
  );
  if (selectedSplitIndex < 0) selectedSplitIndex = splits.length - 1;

  final rangeIndexes = _rangeIndexes(splitRange, splits);
  final series = <_SplitSeries>[];
  for (final row in rows) {
    final points = <_SplitGraphPoint>[];
    for (var index = 0; index < splits.length; index++) {
      final split = splits[index];
      final cumMs = row.result.splitValues[split.id]?.cumMs;
      final bestMs = bestBySplitId[split.id];
      if (cumMs == null || cumMs <= 0 || bestMs == null) continue;
      points.add(
        _SplitGraphPoint(
          splitIndex: index,
          gapMs: math.max(0, cumMs - bestMs),
          cumMs: cumMs,
        ),
      );
    }
    if (points.length < 2) continue;

    final focusPoint = _nearestPoint(points, selectedSplitIndex);
    series.add(
      _SplitSeries(
        row: row,
        points: points,
        focusGapMs: focusPoint.gapMs,
        focusCumMs: focusPoint.cumMs,
      ),
    );
  }

  series.sort((a, b) {
    if (a.focusGapMs != b.focusGapMs) return a.focusGapMs - b.focusGapMs;
    if (a.focusCumMs != b.focusCumMs) return a.focusCumMs - b.focusCumMs;
    return a.row.result.name.compareTo(b.row.result.name);
  });

  return _SplitGraphData(
    splits: splits,
    series: series,
    selectedSplitIndex: selectedSplitIndex,
    maxGapMs: _maxGapMs(series),
    rangeStartIndex: rangeIndexes?.start,
    rangeEndIndex: rangeIndexes?.end,
  );
}

({int start, int end})? _rangeIndexes(
  SplitRangeSelection? splitRange,
  List<SplitOption> splits,
) {
  if (splitRange == null) return null;
  final end = splits.indexWhere((split) => split.id == splitRange.toSplitId);
  if (end < 0) return null;
  final fromSplitId = splitRange.fromSplitId;
  if (fromSplitId == null) return (start: 0, end: end);
  final from = splits.indexWhere((split) => split.id == fromSplitId);
  if (from < 0 || from >= end) return (start: 0, end: end);
  return (start: from, end: end);
}

_SplitGraphPoint _nearestPoint(List<_SplitGraphPoint> points, int splitIndex) {
  for (final point in points) {
    if (point.splitIndex == splitIndex) return point;
  }
  return points.reduce((best, point) {
    final bestDistance = (best.splitIndex - splitIndex).abs();
    final pointDistance = (point.splitIndex - splitIndex).abs();
    return pointDistance < bestDistance ? point : best;
  });
}

int _maxGapMs(List<_SplitSeries> series) {
  var maxGap = 1;
  for (final item in series) {
    for (final point in item.points) {
      maxGap = math.max(maxGap, point.gapMs);
    }
  }
  return maxGap;
}

int _niceAxisMax(int value) {
  if (value <= 1000) return 1000;
  final magnitude = math.pow(10, value.toString().length - 1).toInt();
  for (final step in [1, 2, 5, 10]) {
    final candidate = step * magnitude;
    if (candidate >= value) return candidate;
  }
  return value;
}

double _xForSplit(int index, Rect chart, int splitCount) {
  if (splitCount <= 1) return chart.left + chart.width / 2;
  return chart.left + chart.width * index / (splitCount - 1);
}

double _yForGap(int gapMs, int maxGapMs, Rect chart) {
  if (maxGapMs <= 0) return chart.bottom;
  final ratio = (gapMs / maxGapMs).clamp(0.0, 1.0);
  return chart.top + chart.height * ratio;
}

Color _seriesColor(
  AppPalette palette,
  _SplitSeries series,
  int index, {
  required bool useRowColors,
  required bool disabled,
}) {
  if (disabled) return palette.mutedText;
  if (useRowColors && series.row.color != null) return series.row.color!;
  final colors = [
    palette.primary,
    palette.secondary,
    const Color(0xFF8ED8FF),
    const Color(0xFFFF8E72),
    const Color(0xFFBBA6FF),
    const Color(0xFF7EE081),
    const Color(0xFFFFCF5A),
    const Color(0xFF5FA8FF),
  ];
  return colors[index % colors.length];
}

bool _isDisabled(ResultTableRow row, String? disabledResultId) {
  return disabledResultId != null && row.result.id == disabledResultId;
}

String _formatGap(int gapMs) {
  if (gapMs <= 0) return '+0.0';
  return '+${formatDurationMs(gapMs)}';
}
