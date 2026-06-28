import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatting/time_formatters.dart';
import '../domain/race_result.dart';
import '../domain/split_def.dart';
import 'results_table.dart';

const _maxVisibleSeries = 28;
const _splitGraphRadius = 12.0;
const _splitBarGap = 3.0;
const _splitBarRadius = 4.0;

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
      maxRank: _maxRank(visibleSeries),
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
  const _SplitGraphChart({required this.data, required this.disabledResultId});

  final _SplitGraphData data;
  final String? disabledResultId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(_splitGraphRadius),
        border: Border.all(color: palette.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_splitGraphRadius),
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
        borderRadius: BorderRadius.circular(_splitGraphRadius),
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
                  'Tid',
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
                  '${series.focusLegRank}',
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
                _formatTime(series.focusLegMs),
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
        borderRadius: BorderRadius.circular(_splitGraphRadius),
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

    final yMax = _niceRankMax(data.maxRank);
    final axisPaint = Paint()
      ..color = palette.border
      ..strokeWidth = 1.2;
    final gridPaint = Paint()
      ..color = palette.border.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );

    _paintGrid(canvas, chart, yMax, gridPaint, axisPaint, textPainter);
    _paintFocusBand(canvas, chart);
    _paintHistogram(canvas, chart, yMax);
    _paintLabels(canvas, chart, textPainter);
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
      final value = 1 + ((yMax - 1) * i / 4).round();
      final y = _yForRank(value, yMax, chart);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _paintText(
        textPainter,
        canvas,
        '$value',
        Offset(chart.left - 8, y - 7),
        alignRight: true,
        color: palette.mutedText,
        fontSize: 10,
      );
    }

    canvas.drawLine(chart.bottomLeft, chart.bottomRight, axisPaint);
    canvas.drawLine(chart.bottomLeft, chart.topLeft, axisPaint);
  }

  void _paintFocusBand(Canvas canvas, Rect chart) {
    final split = data.splits[data.selectedSplitIndex];
    _paintText(
      TextPainter(textDirection: TextDirection.ltr, maxLines: 1),
      canvas,
      split.label,
      Offset(chart.left, chart.top - 18),
      color: palette.secondary,
      fontSize: 11,
      bold: true,
      maxWidth: chart.width,
    );
  }

  void _paintHistogram(Canvas canvas, Rect chart, int yMax) {
    final useRowColors = data.series.any((item) => item.row.color != null);
    final bars = _barRects(chart);
    final cumulativePath = Path();
    final cumulativePoints = <Offset>[];
    var pathStarted = false;

    for (var index = 0; index < data.series.length; index++) {
      final series = data.series[index];
      final disabled = _isDisabled(series.row, disabledResultId);
      final color = _seriesColor(
        palette,
        series,
        index,
        useRowColors: useRowColors,
        disabled: disabled,
      );
      final rect = bars[index];
      final top = _yForRank(series.focusLegRank, yMax, chart);
      final barRect = Rect.fromLTRB(rect.left, top, rect.right, chart.bottom);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          barRect,
          const Radius.circular(_splitBarRadius),
        ),
        Paint()..color = color.withValues(alpha: disabled ? 0.28 : 0.72),
      );

      final point = Offset(
        rect.center.dx,
        _yForRank(series.focusCumRank, yMax, chart),
      );
      if (!pathStarted) {
        cumulativePath.moveTo(point.dx, point.dy);
        pathStarted = true;
      } else {
        cumulativePath.lineTo(point.dx, point.dy);
      }
      cumulativePoints.add(point);
    }

    final linePaint = Paint()
      ..color = palette.secondary
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (pathStarted) canvas.drawPath(cumulativePath, linePaint);

    final pointFill = Paint()..color = palette.secondary;
    final pointStroke = Paint()
      ..color = palette.panelAlt
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final point in cumulativePoints) {
      canvas.drawCircle(point, 3.8, pointFill);
      canvas.drawCircle(point, 3.8, pointStroke);
    }
  }

  void _paintLabels(Canvas canvas, Rect chart, TextPainter textPainter) {
    final wantedLabels = chart.width < 480 ? 4 : 7;
    final labelEvery = math.max(1, (data.series.length / wantedLabels).ceil());
    final bars = _barRects(chart);
    for (var index = 0; index < data.series.length; index++) {
      if (index != 0 &&
          index != data.series.length - 1 &&
          index % labelEvery != 0) {
        continue;
      }
      _paintText(
        textPainter,
        canvas,
        '${index + 1}',
        Offset(bars[index].center.dx, chart.bottom + 10),
        center: true,
        color: palette.mutedText,
        fontSize: 10,
        maxWidth: 42,
      );
    }
  }

  List<Rect> _barRects(Rect chart) {
    final count = data.series.length;
    if (count == 0) return const [];
    final totalGap = _splitBarGap * math.max(0, count - 1);
    final availableWidth = math.max(0, chart.width - totalGap);
    final totalMs = data.series.fold<int>(
      0,
      (sum, series) => sum + math.max(1, series.focusLegMs),
    );
    final rects = <Rect>[];
    var left = chart.left;
    for (var index = 0; index < count; index++) {
      final series = data.series[index];
      final width = availableWidth * math.max(1, series.focusLegMs) / totalMs;
      rects.add(Rect.fromLTWH(left, chart.top, width, chart.height));
      left += width + _splitBarGap;
    }
    return rects;
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
    required this.maxRank,
  });

  final List<SplitOption> splits;
  final List<_SplitSeries> series;
  final int selectedSplitIndex;
  final int maxRank;

  _SplitGraphData copyWith({List<_SplitSeries>? series, int? maxRank}) {
    return _SplitGraphData(
      splits: splits,
      series: series ?? this.series,
      selectedSplitIndex: selectedSplitIndex,
      maxRank: maxRank ?? this.maxRank,
    );
  }
}

class _SplitSeries {
  const _SplitSeries({
    required this.row,
    required this.focusLegRank,
    required this.focusCumRank,
    required this.focusLegMs,
    required this.focusCumMs,
  });

  final ResultTableRow row;
  final int focusLegRank;
  final int focusCumRank;
  final int focusLegMs;
  final int focusCumMs;
}

_SplitGraphData? _buildSplitGraph({
  required List<ResultTableRow> rows,
  required List<SplitOption> splitOptions,
  required String? selectedSplitId,
  required SplitRangeSelection? splitRange,
}) {
  if (rows.isEmpty || splitOptions.isEmpty) return null;

  final splits = [
    for (final split in splitOptions)
      if (rows.any(
        (row) =>
            effectiveSplitLegMs(row.result, split.id) != null &&
            row.result.splitValues[split.id]?.cumMs != null,
      ))
        split,
  ];
  if (splits.isEmpty) return null;

  final focusedSplitId = splitRange?.toSplitId ?? selectedSplitId;
  var selectedSplitIndex = splits.indexWhere(
    (split) => split.id == focusedSplitId,
  );
  if (selectedSplitIndex < 0) selectedSplitIndex = splits.length - 1;

  final selectedGraphSplitId = splits[selectedSplitIndex].id;
  final legRanks = _ranksByTime(
    rows,
    (row) => effectiveSplitLegMs(row.result, selectedGraphSplitId),
  );
  final cumulativeRanks = _ranksByTime(
    rows,
    (row) => row.result.splitValues[selectedGraphSplitId]?.cumMs,
  );
  final series = <_SplitSeries>[];
  for (final row in rows) {
    final split = row.result.splitValues[selectedGraphSplitId];
    final legMs = effectiveSplitLegMs(row.result, selectedGraphSplitId);
    final cumMs = split?.cumMs;
    // Calculate ranks from the loaded rows. Stored ranks are absent on older
    // imports and are class-local when multiple classes are compared.
    final legRank = legRanks[row] ?? split?.legRank ?? split?.cumRank;
    final cumRank = cumulativeRanks[row] ?? split?.cumRank;
    if (split == null ||
        legMs == null ||
        legMs <= 0 ||
        cumMs == null ||
        cumMs <= 0 ||
        legRank == null ||
        legRank <= 0 ||
        cumRank == null ||
        cumRank <= 0) {
      continue;
    }
    series.add(
      _SplitSeries(
        row: row,
        focusLegRank: legRank,
        focusCumRank: cumRank,
        focusLegMs: legMs,
        focusCumMs: cumMs,
      ),
    );
  }

  series.sort((a, b) {
    if (a.focusLegMs != b.focusLegMs) return a.focusLegMs - b.focusLegMs;
    if (a.focusCumMs != b.focusCumMs) return a.focusCumMs - b.focusCumMs;
    return a.row.result.name.compareTo(b.row.result.name);
  });

  return _SplitGraphData(
    splits: splits,
    series: series,
    selectedSplitIndex: selectedSplitIndex,
    maxRank: _maxRank(series),
  );
}

Map<ResultTableRow, int> _ranksByTime(
  List<ResultTableRow> rows,
  int? Function(ResultTableRow row) timeFor,
) {
  final timedRows = <({ResultTableRow row, int time})>[];
  for (final row in rows) {
    final time = timeFor(row);
    if (time != null && time > 0) timedRows.add((row: row, time: time));
  }
  timedRows.sort((a, b) {
    final timeCompare = a.time.compareTo(b.time);
    if (timeCompare != 0) return timeCompare;
    return a.row.result.name.compareTo(b.row.result.name);
  });

  final ranks = <ResultTableRow, int>{};
  int? previousTime;
  var previousRank = 0;
  for (var index = 0; index < timedRows.length; index++) {
    final entry = timedRows[index];
    final rank = previousTime == entry.time ? previousRank : index + 1;
    ranks[entry.row] = rank;
    previousTime = entry.time;
    previousRank = rank;
  }
  return ranks;
}

int _maxRank(List<_SplitSeries> series) {
  var maxRank = 1;
  for (final item in series) {
    maxRank = math.max(maxRank, item.focusLegRank);
    maxRank = math.max(maxRank, item.focusCumRank);
  }
  return maxRank;
}

int _niceRankMax(int value) {
  if (value <= 5) return 5;
  if (value <= 10) return 10;
  if (value <= 20) return 20;
  final step = value <= 50 ? 10 : 25;
  return ((value + step - 1) ~/ step) * step;
}

double _yForRank(int rank, int maxRank, Rect chart) {
  if (maxRank <= 1) return chart.top;
  final ratio = ((rank - 1) / (maxRank - 1)).clamp(0.0, 1.0);
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

String _formatTime(int timeMs) {
  final formatted = formatDurationMs(timeMs);
  return formatted.isEmpty ? '-' : formatted;
}
