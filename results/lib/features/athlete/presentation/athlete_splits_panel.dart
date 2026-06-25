import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatting/time_formatters.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../results/domain/race_result.dart';
import '../../results/domain/split_def.dart';

class AthleteSplitsPanel extends StatefulWidget {
  const AthleteSplitsPanel({
    super.key,
    required this.result,
    required this.classResults,
    required this.publicSplitIds,
    required this.splitDefs,
    required this.onSplitSelected,
  });

  final RaceResult result;
  final List<RaceResult> classResults;
  final Set<String> publicSplitIds;
  final List<SplitDef> splitDefs;
  final ValueChanged<String> onSplitSelected;

  @override
  State<AthleteSplitsPanel> createState() => _AthleteSplitsPanelState();
}

class _AthleteSplitsPanelState extends State<AthleteSplitsPanel> {
  _SplitDisplayMode _splitDisplayMode = _SplitDisplayMode.table;
  _AverageComparisonDisplayMode _averageComparisonDisplayMode =
      _AverageComparisonDisplayMode.graph;
  _AverageComparisonValueMode _averageComparisonValueMode =
      _AverageComparisonValueMode.time;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final splits =
        widget.result.splitValues.values
            .where((split) => widget.publicSplitIds.contains(split.id))
            .toList()
          ..sort((a, b) {
            if (a.sort != b.sort) return a.sort - b.sort;
            return a.label.compareTo(b.label);
          });
    final splitDefById = {
      for (final splitDef in widget.splitDefs)
        if (splitDef.isPublic) splitDef.id: splitDef,
    };
    final dispositionGroups = _dispositionGroups(splits, splitDefById);

    return ShellPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.splitBreakdown,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (splits.isEmpty)
            EmptyState(
              title: l10n.noResultsTitle,
              message: l10n.noResultsMessage,
            )
          else
            Column(
              children: [
                _DispositionHistogram(
                  groups: dispositionGroups,
                  onSplitSelected: widget.onSplitSelected,
                ),
                if (dispositionGroups.isNotEmpty) const SizedBox(height: 8),
                _ClassAverageComparison(
                  result: widget.result,
                  classResults: widget.classResults,
                  splits: splits,
                  displayMode: _averageComparisonDisplayMode,
                  valueMode: _averageComparisonValueMode,
                  onDisplayModeChanged: (value) {
                    setState(() {
                      _averageComparisonDisplayMode = value;
                    });
                  },
                  onValueModeChanged: (value) {
                    setState(() {
                      _averageComparisonValueMode = value;
                    });
                  },
                  onSplitSelected: widget.onSplitSelected,
                ),
                const SizedBox(height: 8),
                _SplitDisplayHeader(
                  displayMode: _splitDisplayMode,
                  onDisplayModeChanged: (value) {
                    setState(() {
                      _splitDisplayMode = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                if (_splitDisplayMode == _SplitDisplayMode.graph)
                  _SplitRankHistogram(
                    splits: splits,
                    onSplitSelected: widget.onSplitSelected,
                  )
                else
                  Column(
                    children: [
                      for (var index = 0; index < splits.length; index++) ...[
                        _SplitTile(
                          split: splits[index],
                          onSplitSelected: widget.onSplitSelected,
                        ),
                        if (index < splits.length - 1)
                          const SizedBox(height: 4),
                      ],
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

enum _SplitDisplayMode { table, graph }

enum _AverageComparisonDisplayMode { table, graph }

enum _AverageComparisonValueMode { time, percent }

class _ClassAverageComparison extends StatelessWidget {
  const _ClassAverageComparison({
    required this.result,
    required this.classResults,
    required this.splits,
    required this.displayMode,
    required this.valueMode,
    required this.onDisplayModeChanged,
    required this.onValueModeChanged,
    required this.onSplitSelected,
  });

  final RaceResult result;
  final List<RaceResult> classResults;
  final List<SplitValue> splits;
  final _AverageComparisonDisplayMode displayMode;
  final _AverageComparisonValueMode valueMode;
  final ValueChanged<_AverageComparisonDisplayMode> onDisplayModeChanged;
  final ValueChanged<_AverageComparisonValueMode> onValueModeChanged;
  final ValueChanged<String> onSplitSelected;

  @override
  Widget build(BuildContext context) {
    final rows = _averageComparisonRows(result, classResults, splits);
    final palette = context.palette;
    if (rows.length <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final controls = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SegmentedButton<_AverageComparisonValueMode>(
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: _AverageComparisonValueMode.time,
                        label: Text('Tid'),
                      ),
                      ButtonSegment(
                        value: _AverageComparisonValueMode.percent,
                        label: Text('%'),
                      ),
                    ],
                    selected: {valueMode},
                    onSelectionChanged: (values) {
                      onValueModeChanged(values.first);
                    },
                  ),
                  SegmentedButton<_AverageComparisonDisplayMode>(
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: _AverageComparisonDisplayMode.table,
                        icon: Icon(Icons.table_rows),
                        label: Text('Tabell'),
                      ),
                      ButtonSegment(
                        value: _AverageComparisonDisplayMode.graph,
                        icon: Icon(Icons.bar_chart),
                        label: Text('Graf'),
                      ),
                    ],
                    selected: {displayMode},
                    onSelectionChanged: (values) {
                      onDisplayModeChanged(values.first);
                    },
                  ),
                ],
              );
              final title = const Text(
                'Mot klassegjennomsnitt',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              );
              if (constraints.maxWidth < 430) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 8), controls],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  controls,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          if (displayMode == _AverageComparisonDisplayMode.graph)
            SizedBox(
              height: _averageComparisonChartHeight(rows.length),
              child: _ClassAverageComparisonChart(
                rows: rows,
                valueMode: valueMode,
                onSplitSelected: onSplitSelected,
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  _ClassAverageComparisonTile(
                    row: rows[index],
                    valueMode: valueMode,
                    onSplitSelected: onSplitSelected,
                  ),
                  if (index < rows.length - 1) const SizedBox(height: 6),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ClassAverageComparisonChart extends StatelessWidget {
  const _ClassAverageComparisonChart({
    required this.rows,
    required this.valueMode,
    required this.onSplitSelected,
  });

  final List<_AverageComparisonRow> rows;
  final _AverageComparisonValueMode valueMode;
  final ValueChanged<String> onSplitSelected;

  @override
  Widget build(BuildContext context) {
    final chartRows = rows
        .where(
          (row) =>
              row.splitId != null &&
              row.splitDiffMs != null &&
              row.cumulativeDiffMs != null,
        )
        .toList();
    final palette = context.palette;
    if (chartRows.isEmpty) {
      return Center(
        child: Text(
          'For lite data til graf',
          style: TextStyle(
            color: palette.mutedText,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _AverageLegendItem(
              color: const Color(0xFF39D98A),
              label: 'Raskere',
            ),
            _AverageLegendItem(
              color: const Color(0xFFFF5C5C),
              label: 'Tregere',
            ),
            _AverageLegendItem(
              color: palette.secondary,
              label: 'Differanse over tid',
              isLine: true,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final chart = _AverageComparisonLayout.chartRect(chartSize);
              return Stack(
                children: [
                  CustomPaint(
                    painter: _ClassAverageComparisonPainter(
                      rows: chartRows,
                      valueMode: valueMode,
                      palette: palette,
                    ),
                    child: const SizedBox.expand(),
                  ),
                  for (var index = 0; index < chartRows.length; index++)
                    _AverageComparisonHoverTarget(
                      row: chartRows[index],
                      valueMode: valueMode,
                      left: _averageTargetLeft(index, chart, chartRows.length),
                      top: chart.top,
                      width: _averageTargetWidth(chart, chartRows.length),
                      height: chart.height,
                      onTap: () => onSplitSelected(chartRows[index].splitId!),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AverageComparisonHoverTarget extends StatelessWidget {
  const _AverageComparisonHoverTarget({
    required this.row,
    required this.valueMode,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final _AverageComparisonRow row;
  final _AverageComparisonValueMode valueMode;
  final double left;
  final double top;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Tooltip(
        message:
            '${row.label}\nLeg dif ${row.splitDiffText(valueMode)}\nCum dif ${row.cumulativeDiffText(valueMode)}\nKlikk for a apne splitten',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

class _ClassAverageComparisonPainter extends CustomPainter {
  const _ClassAverageComparisonPainter({
    required this.rows,
    required this.valueMode,
    required this.palette,
  });

  final List<_AverageComparisonRow> rows;
  final _AverageComparisonValueMode valueMode;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = _AverageComparisonLayout.chartRect(size);
    if (chart.width <= 0 || chart.height <= 0 || rows.isEmpty) return;

    final maxAbs = _niceSignedAxisMax(_maxAbsValue());
    final axisPaint = Paint()
      ..color = palette.border
      ..strokeWidth = 1.2;
    final gridPaint = Paint()
      ..color = palette.border.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final fasterPaint = Paint()..color = const Color(0xFF39D98A);
    final slowerPaint = Paint()..color = const Color(0xFFFF5C5C);
    final linePaint = Paint()
      ..color = palette.secondary
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()..color = palette.secondary;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );

    _paintGrid(canvas, chart, maxAbs, gridPaint, axisPaint, textPainter);
    _paintBars(canvas, chart, maxAbs, fasterPaint, slowerPaint);
    _paintLine(canvas, chart, maxAbs, linePaint, pointPaint);
    _paintLabels(canvas, chart, textPainter);
  }

  double _maxAbsValue() {
    var maxAbs = 1.0;
    for (final row in rows) {
      final split = row.splitDiffValue(valueMode);
      final cumulative = row.cumulativeDiffValue(valueMode);
      if (split != null) maxAbs = math.max(maxAbs, split.abs());
      if (cumulative != null) maxAbs = math.max(maxAbs, cumulative.abs());
    }
    return maxAbs;
  }

  void _paintGrid(
    Canvas canvas,
    Rect chart,
    double maxAbs,
    Paint gridPaint,
    Paint axisPaint,
    TextPainter textPainter,
  ) {
    for (final ratio in const [-1.0, -0.5, 0.0, 0.5, 1.0]) {
      final value = maxAbs * ratio;
      final y = _yForSignedValue(value, maxAbs, chart);
      canvas.drawLine(
        Offset(chart.left, y),
        Offset(chart.right, y),
        ratio == 0 ? axisPaint : gridPaint,
      );
      _paintAverageText(
        textPainter,
        canvas,
        _formatAverageAxisValue(value, valueMode),
        Offset(chart.left - 8, y - 7),
        alignRight: true,
        color: ratio == 0 ? palette.primary : palette.mutedText,
        fontSize: 10,
      );
    }

    canvas.drawLine(chart.bottomLeft, chart.bottomRight, axisPaint);
    canvas.drawLine(chart.bottomLeft, chart.topLeft, axisPaint);
  }

  void _paintBars(
    Canvas canvas,
    Rect chart,
    double maxAbs,
    Paint fasterPaint,
    Paint slowerPaint,
  ) {
    final zeroY = _yForSignedValue(0, maxAbs, chart);
    final slotWidth = chart.width / rows.length;
    final barWidth = math.max(4.0, math.min(28.0, slotWidth * 0.54));
    for (var index = 0; index < rows.length; index++) {
      final value = rows[index].splitDiffValue(valueMode);
      if (value == null) continue;
      final x = _xForAverageIndex(index, chart, rows.length);
      final y = _yForSignedValue(value, maxAbs, chart);
      final rect = Rect.fromLTRB(
        x - barWidth / 2,
        math.min(y, zeroY),
        x + barWidth / 2,
        math.max(y, zeroY),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        value <= 0 ? fasterPaint : slowerPaint,
      );
    }
  }

  void _paintLine(
    Canvas canvas,
    Rect chart,
    double maxAbs,
    Paint linePaint,
    Paint pointPaint,
  ) {
    final path = Path();
    var started = false;
    for (var index = 0; index < rows.length; index++) {
      final value = rows[index].cumulativeDiffValue(valueMode);
      if (value == null) continue;
      final point = Offset(
        _xForAverageIndex(index, chart, rows.length),
        _yForSignedValue(value, maxAbs, chart),
      );
      if (started) {
        path.lineTo(point.dx, point.dy);
      } else {
        path.moveTo(point.dx, point.dy);
        started = true;
      }
    }
    if (!started) return;
    canvas.drawPath(path, linePaint);
    for (var index = 0; index < rows.length; index++) {
      final value = rows[index].cumulativeDiffValue(valueMode);
      if (value == null) continue;
      final point = Offset(
        _xForAverageIndex(index, chart, rows.length),
        _yForSignedValue(value, maxAbs, chart),
      );
      canvas.drawCircle(point, 3.4, pointPaint);
      canvas.drawCircle(
        point,
        3.4,
        Paint()
          ..color = palette.panelAlt
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _paintLabels(Canvas canvas, Rect chart, TextPainter textPainter) {
    final wantedLabels = chart.width < 420 ? 4 : 7;
    final labelEvery = math.max(1, (rows.length / wantedLabels).ceil());
    for (var index = 0; index < rows.length; index++) {
      final showLabel =
          index == 0 || index == rows.length - 1 || index % labelEvery == 0;
      if (!showLabel) continue;
      _paintAverageText(
        textPainter,
        canvas,
        rows[index].label,
        Offset(_xForAverageIndex(index, chart, rows.length), chart.bottom + 10),
        center: true,
        color: palette.mutedText,
        fontSize: 10,
        maxWidth: 72,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ClassAverageComparisonPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.valueMode != valueMode ||
        oldDelegate.palette != palette;
  }
}

class _ClassAverageComparisonTile extends StatelessWidget {
  const _ClassAverageComparisonTile({
    required this.row,
    required this.valueMode,
    required this.onSplitSelected,
  });

  final _AverageComparisonRow row;
  final _AverageComparisonValueMode valueMode;
  final ValueChanged<String> onSplitSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final borderRadius = BorderRadius.circular(8);
    final content = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: borderRadius,
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 12,
            child: Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 9,
            child: _AverageComparisonPill(
              label: 'Split',
              ownText: row.splitOwnText(valueMode),
              averageText: row.splitAverageText(valueMode),
              diffText: row.splitDiffText(valueMode),
              diffMs: row.splitDiffMs,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 9,
            child: _AverageComparisonPill(
              label: 'Tid',
              ownText: row.cumulativeOwnText(valueMode),
              averageText: row.cumulativeAverageText(valueMode),
              diffText: row.cumulativeDiffText(valueMode),
              diffMs: row.cumulativeDiffMs,
            ),
          ),
        ],
      ),
    );
    final splitId = row.splitId;
    if (splitId == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: () => onSplitSelected(splitId),
        borderRadius: borderRadius,
        child: content,
      ),
    );
  }
}

class _AverageComparisonPill extends StatelessWidget {
  const _AverageComparisonPill({
    required this.label,
    required this.ownText,
    required this.averageText,
    required this.diffText,
    required this.diffMs,
  });

  final String label;
  final String ownText;
  final String averageText;
  final String diffText;
  final int? diffMs;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final background = _averageDiffBackground(diffMs, palette.panelAlt);
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$ownText $diffText',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(
            'Snitt $averageText',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AverageLegendItem extends StatelessWidget {
  const _AverageLegendItem({
    required this.color,
    required this.label,
    this.isLine = false,
  });

  final Color color;
  final String label;
  final bool isLine;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(24, 12),
          painter: _AverageLegendPainter(color: color, isLine: isLine),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: context.palette.mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _AverageLegendPainter extends CustomPainter {
  const _AverageLegendPainter({required this.color, required this.isLine});

  final Color color;
  final bool isLine;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    if (isLine) {
      final y = size.height / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      canvas.drawCircle(Offset(size.width / 2, y), 3, paint);
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 2, size.width - 8, size.height - 4),
        const Radius.circular(3),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AverageLegendPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isLine != isLine;
  }
}

class _AverageComparisonRow {
  const _AverageComparisonRow({
    required this.label,
    required this.splitId,
    required this.splitMs,
    required this.averageSplitMs,
    required this.cumulativeMs,
    required this.averageCumulativeMs,
  });

  final String label;
  final String? splitId;
  final int? splitMs;
  final int? averageSplitMs;
  final int? cumulativeMs;
  final int? averageCumulativeMs;

  int? get splitDiffMs => _diffMs(splitMs, averageSplitMs);

  int? get cumulativeDiffMs => _diffMs(cumulativeMs, averageCumulativeMs);

  double? splitDiffValue(_AverageComparisonValueMode mode) {
    if (mode == _AverageComparisonValueMode.time) {
      final diffMs = splitDiffMs;
      return diffMs == null ? null : diffMs / 1000;
    }
    return _diffPercent(splitMs, averageSplitMs);
  }

  double? cumulativeDiffValue(_AverageComparisonValueMode mode) {
    if (mode == _AverageComparisonValueMode.time) {
      final diffMs = cumulativeDiffMs;
      return diffMs == null ? null : diffMs / 1000;
    }
    return _diffPercent(cumulativeMs, averageCumulativeMs);
  }

  String splitOwnText(_AverageComparisonValueMode mode) {
    return _formatAverageOwnValue(splitMs, averageSplitMs, mode);
  }

  String splitAverageText(_AverageComparisonValueMode mode) {
    return _formatAverageBaselineValue(averageSplitMs, mode);
  }

  String splitDiffText(_AverageComparisonValueMode mode) {
    return _formatAverageDiffValue(splitMs, averageSplitMs, mode);
  }

  String cumulativeOwnText(_AverageComparisonValueMode mode) {
    return _formatAverageOwnValue(cumulativeMs, averageCumulativeMs, mode);
  }

  String cumulativeAverageText(_AverageComparisonValueMode mode) {
    return _formatAverageBaselineValue(averageCumulativeMs, mode);
  }

  String cumulativeDiffText(_AverageComparisonValueMode mode) {
    return _formatAverageDiffValue(cumulativeMs, averageCumulativeMs, mode);
  }
}

class _AverageComparisonLayout {
  static const left = 64.0;
  static const top = 18.0;
  static const right = 16.0;
  static const bottom = 46.0;

  static Rect chartRect(Size size) {
    return Rect.fromLTWH(
      left,
      top,
      math.max(0, size.width - left - right),
      math.max(0, size.height - top - bottom),
    );
  }
}

class _SplitDisplayHeader extends StatelessWidget {
  const _SplitDisplayHeader({
    required this.displayMode,
    required this.onDisplayModeChanged,
  });

  final _SplitDisplayMode displayMode;
  final ValueChanged<_SplitDisplayMode> onDisplayModeChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Splittider',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
        SegmentedButton<_SplitDisplayMode>(
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          segments: const [
            ButtonSegment(
              value: _SplitDisplayMode.table,
              icon: Icon(Icons.table_rows),
              label: Text('Tabell'),
            ),
            ButtonSegment(
              value: _SplitDisplayMode.graph,
              icon: Icon(Icons.bar_chart),
              label: Text('Graf'),
            ),
          ],
          selected: {displayMode},
          onSelectionChanged: (values) {
            onDisplayModeChanged(values.first);
          },
        ),
      ],
    );
  }
}

class _SplitRankHistogram extends StatelessWidget {
  const _SplitRankHistogram({
    required this.splits,
    required this.onSplitSelected,
  });

  final List<SplitValue> splits;
  final ValueChanged<String> onSplitSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxRank = _maxRank(splits);
    final maxLegMs = _maxLegMs(splits);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = _splitRankChartHeight(
          width: constraints.maxWidth,
          splitCount: splits.length,
        );
        return Container(
          height: height,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            color: palette.panelAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const SizedBox(
                    width: 130,
                    child: Text(
                      'Split histogram',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _RankLegendItem(color: palette.primary, label: 'Leg rank'),
                  _RankLegendItem(color: palette.secondary, label: 'Cum rank'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, chartConstraints) {
                    final chartSize = Size(
                      chartConstraints.maxWidth,
                      chartConstraints.maxHeight,
                    );
                    final chart = _SplitRankLayout.chartRect(chartSize);
                    return Stack(
                      children: [
                        CustomPaint(
                          painter: _SplitRankHistogramPainter(
                            splits: splits,
                            maxRank: maxRank,
                            maxLegMs: maxLegMs,
                            palette: palette,
                          ),
                          child: const SizedBox.expand(),
                        ),
                        for (var index = 0; index < splits.length; index++)
                          _SplitHoverTarget(
                            split: splits[index],
                            left: _splitTargetLeft(index, chart, splits.length),
                            top: chart.top,
                            width: _splitTargetWidth(chart, splits.length),
                            height: chart.height,
                            onTap: () => onSplitSelected(splits[index].id),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SplitRankHistogramPainter extends CustomPainter {
  const _SplitRankHistogramPainter({
    required this.splits,
    required this.maxRank,
    required this.maxLegMs,
    required this.palette,
  });

  final List<SplitValue> splits;
  final int maxRank;
  final int maxLegMs;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = _SplitRankLayout.chartRect(size);
    if (chart.width <= 0 || chart.height <= 0 || splits.isEmpty) return;

    final axisPaint = Paint()
      ..color = palette.border
      ..strokeWidth = 1.2;
    final gridPaint = Paint()
      ..color = palette.border.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final barPaint = Paint()..color = palette.primary.withValues(alpha: 0.74);
    final linePaint = Paint()
      ..color = palette.secondary
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()..color = palette.secondary;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );

    _paintGrid(canvas, chart, axisPaint, gridPaint, textPainter);
    _paintBars(canvas, chart, barPaint, textPainter);
    _paintCumLine(canvas, chart, linePaint, pointPaint);
    _paintSplitLabels(canvas, chart, textPainter);
  }

  void _paintGrid(
    Canvas canvas,
    Rect chart,
    Paint axisPaint,
    Paint gridPaint,
    TextPainter textPainter,
  ) {
    for (var i = 0; i <= 4; i++) {
      final rank = math.max(1, (1 + (maxRank - 1) * i / 4).round());
      final y = _yForRank(rank, maxRank, chart);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _paintText(
        textPainter,
        canvas,
        '#$rank',
        Offset(chart.left - 8, y - 7),
        alignRight: true,
        color: palette.mutedText,
        fontSize: 10,
      );
    }
    canvas.drawLine(chart.bottomLeft, chart.bottomRight, axisPaint);
    canvas.drawLine(chart.bottomLeft, chart.topLeft, axisPaint);
  }

  void _paintBars(
    Canvas canvas,
    Rect chart,
    Paint barPaint,
    TextPainter textPainter,
  ) {
    final slotWidth = chart.width / splits.length;
    for (var index = 0; index < splits.length; index++) {
      final split = splits[index];
      final rank = _validRank(split.legRank);
      if (rank == null) continue;
      final legMs = split.legMs;
      final widthRatio = legMs == null || legMs <= 0
          ? 0.12
          : (legMs / math.max(1, maxLegMs)).clamp(0.12, 1.0).toDouble();
      final barWidth = math.max(2.0, slotWidth * widthRatio);
      final left = chart.left + slotWidth * index;
      final y = _yForRank(rank, maxRank, chart);
      final rect = Rect.fromLTRB(left, y, left + barWidth, chart.bottom);
      canvas.drawRect(rect, barPaint);
    }
  }

  void _paintCumLine(
    Canvas canvas,
    Rect chart,
    Paint linePaint,
    Paint pointPaint,
  ) {
    final path = Path();
    var started = false;
    for (var index = 0; index < splits.length; index++) {
      final rank = _validRank(splits[index].cumRank);
      if (rank == null) continue;
      final x = _xForSplitIndex(index, chart, splits.length);
      final y = _yForRank(rank, maxRank, chart);
      if (started) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
        started = true;
      }
    }
    if (!started) return;
    canvas.drawPath(path, linePaint);
    for (var index = 0; index < splits.length; index++) {
      final rank = _validRank(splits[index].cumRank);
      if (rank == null) continue;
      final point = Offset(
        _xForSplitIndex(index, chart, splits.length),
        _yForRank(rank, maxRank, chart),
      );
      canvas.drawCircle(point, 3.4, pointPaint);
      canvas.drawCircle(
        point,
        3.4,
        Paint()
          ..color = palette.panelAlt
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _paintSplitLabels(Canvas canvas, Rect chart, TextPainter textPainter) {
    final wantedLabels = chart.width < 420 ? 4 : 7;
    final labelEvery = math.max(1, (splits.length / wantedLabels).ceil());
    for (var index = 0; index < splits.length; index++) {
      final showLabel =
          index == 0 || index == splits.length - 1 || index % labelEvery == 0;
      if (!showLabel) continue;
      _paintText(
        textPainter,
        canvas,
        splits[index].label,
        Offset(_xForSplitIndex(index, chart, splits.length), chart.bottom + 10),
        center: true,
        color: palette.mutedText,
        fontSize: 10,
        maxWidth: 78,
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
    double fontSize = 11,
    double maxWidth = 84,
  }) {
    painter.text = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
      ),
    );
    painter.layout(maxWidth: maxWidth);
    var dx = offset.dx;
    if (center) dx -= painter.width / 2;
    if (alignRight) dx -= painter.width;
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _SplitRankHistogramPainter oldDelegate) {
    return oldDelegate.splits != splits ||
        oldDelegate.maxRank != maxRank ||
        oldDelegate.maxLegMs != maxLegMs ||
        oldDelegate.palette != palette;
  }
}

class _SplitHoverTarget extends StatelessWidget {
  const _SplitHoverTarget({
    required this.split,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final SplitValue split;
  final double left;
  final double top;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Tooltip(
        message:
            '${split.label}\nLeg rank ${_rankText(split.legRank)}\nCum rank ${_rankText(split.cumRank)}\nKlikk for a apne legget',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

class _RankLegendItem extends StatelessWidget {
  const _RankLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: context.palette.mutedText,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SplitTile extends StatelessWidget {
  const _SplitTile({required this.split, required this.onSplitSelected});

  final SplitValue split;
  final ValueChanged<String> onSplitSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final borderRadius = BorderRadius.circular(8);
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: borderRadius,
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              split.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.primary,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
                decorationColor: palette.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _SplitMetric(
            value: split.legText.isEmpty ? '-' : split.legText,
            rank: split.legRank,
            alignEnd: true,
          ),
          const SizedBox(width: 10),
          _SplitMetric(
            value: split.cumText.isEmpty ? '-' : split.cumText,
            rank: split.cumRank,
            alignEnd: true,
          ),
        ],
      ),
    );
    return Tooltip(
      message: 'Apne ${split.label}',
      child: Semantics(
        link: true,
        button: true,
        label: 'Apne ${split.label}',
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            onTap: () => onSplitSelected(split.id),
            borderRadius: borderRadius,
            child: content,
          ),
        ),
      ),
    );
  }
}

class _SplitMetric extends StatelessWidget {
  const _SplitMetric({
    required this.value,
    required this.rank,
    this.alignEnd = false,
  });

  final String value;
  final int? rank;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 74,
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            rank == null || rank! <= 0 ? 'Rank -' : 'Rank $rank',
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
    );
  }
}

enum _DispositionDisplayMode { time, percentOfFirstRound }

class _DispositionHistogram extends StatefulWidget {
  const _DispositionHistogram({
    required this.groups,
    required this.onSplitSelected,
  });

  final List<_DispositionGroup> groups;
  final ValueChanged<String> onSplitSelected;

  @override
  State<_DispositionHistogram> createState() => _DispositionHistogramState();
}

class _DispositionHistogramState extends State<_DispositionHistogram> {
  _DispositionDisplayMode _displayMode = _DispositionDisplayMode.time;

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    if (groups.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    final maxValue = _maxDispositionValue(groups, _displayMode);
    final wantedHeight =
        58.0 +
        groups.fold<double>(
          0,
          (height, group) => height + _dispositionRowHeight(group) + 8,
        );
    final height = math.max(112.0, wantedHeight);

    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Disponering',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              SegmentedButton<_DispositionDisplayMode>(
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: _DispositionDisplayMode.time,
                    label: Text('Tid'),
                  ),
                  ButtonSegment(
                    value: _DispositionDisplayMode.percentOfFirstRound,
                    label: Text('% 1.r'),
                  ),
                ],
                selected: {_displayMode},
                onSelectionChanged: (values) {
                  setState(() {
                    _displayMode = values.first;
                  });
                },
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _axisLabel(_displayMode),
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              for (var index = 0; index < groups.length; index++) ...[
                _DispositionRow(
                  group: groups[index],
                  maxValue: maxValue,
                  displayMode: _displayMode,
                  colors: _lapColors(palette),
                  onSplitSelected: widget.onSplitSelected,
                ),
                if (index < groups.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
          const SizedBox(height: 4),
          _DispositionAxis(maxValue: maxValue, displayMode: _displayMode),
        ],
      ),
    );
  }
}

class _DispositionRow extends StatelessWidget {
  const _DispositionRow({
    required this.group,
    required this.maxValue,
    required this.displayMode,
    required this.colors,
    required this.onSplitSelected,
  });

  final _DispositionGroup group;
  final double maxValue;
  final _DispositionDisplayMode displayMode;
  final List<Color> colors;
  final ValueChanged<String> onSplitSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final rowHeight = _dispositionRowHeight(group);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 118,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                group.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (displayMode == _DispositionDisplayMode.percentOfFirstRound &&
                  group.usesFallbackBaseline)
                Text(
                  'Bruker runde ${group.baselineLap.lapNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: rowHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: palette.border, width: 1),
                  bottom: BorderSide(color: palette.border, width: 1),
                ),
              ),
              child: Stack(
                children: [
                  for (var index = 0; index < group.laps.length; index++)
                    _DispositionBar(
                      group: group,
                      lap: group.laps[index],
                      maxValue: maxValue,
                      displayMode: displayMode,
                      color:
                          colors[math.max(0, group.laps[index].lapNumber - 1) %
                              colors.length],
                      top: _barTop(index, group.laps.length, rowHeight),
                      height: _barHeight(group.laps.length),
                      onSplitSelected: onSplitSelected,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DispositionBar extends StatelessWidget {
  const _DispositionBar({
    required this.group,
    required this.lap,
    required this.maxValue,
    required this.displayMode,
    required this.color,
    required this.top,
    required this.height,
    required this.onSplitSelected,
  });

  final _DispositionGroup group;
  final _DispositionLap lap;
  final double maxValue;
  final _DispositionDisplayMode displayMode;
  final Color color;
  final double top;
  final double height;
  final ValueChanged<String> onSplitSelected;

  @override
  Widget build(BuildContext context) {
    final value = group.valueFor(lap, displayMode);
    final widthFactor = math
        .max(0.015, value / math.max(maxValue, 1))
        .clamp(0.0, 1.0)
        .toDouble();
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      child: Tooltip(
        message:
            '${lap.tooltipText(displayMode, value)}'
            '${group.usesFallbackBaseline && displayMode == _DispositionDisplayMode.percentOfFirstRound ? '\nMangler runde 1 for denne strekningen' : ''}'
            '\nKlikk for a apne splitten',
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Semantics(
            link: true,
            button: true,
            label: 'Apne ${lap.splitLabel}',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSplitSelected(lap.splitId),
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color, width: 1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DispositionAxis extends StatelessWidget {
  const _DispositionAxis({required this.maxValue, required this.displayMode});

  final double maxValue;
  final _DispositionDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final middleValue = maxValue / 2;
    final style = TextStyle(
      color: palette.mutedText,
      fontSize: 9,
      fontWeight: FontWeight.w800,
    );
    return Row(
      children: [
        const SizedBox(width: 126),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatAxisValue(0, displayMode), style: style),
              Text(_formatAxisValue(middleValue, displayMode), style: style),
              Text(_formatAxisValue(maxValue, displayMode), style: style),
            ],
          ),
        ),
      ],
    );
  }
}

class _DispositionGroup {
  const _DispositionGroup({
    required this.from,
    required this.to,
    required this.laps,
  });

  final String from;
  final String to;
  final List<_DispositionLap> laps;

  String get label => '$from -> $to';

  _DispositionLap get baselineLap {
    return firstRoundLap ?? laps.first;
  }

  _DispositionLap? get firstRoundLap {
    for (final lap in laps) {
      if (lap.lapNumber == 1) return lap;
    }
    return null;
  }

  bool get usesFallbackBaseline => firstRoundLap == null;

  int get maxLegMs {
    return laps.fold<int>(1, (maxValue, lap) => math.max(maxValue, lap.legMs));
  }

  double valueFor(_DispositionLap lap, _DispositionDisplayMode displayMode) {
    if (displayMode == _DispositionDisplayMode.time) {
      return lap.legMs.toDouble();
    }
    final baselineMs = baselineLap.legMs;
    if (baselineMs <= 0) return 0;
    return lap.legMs * 100 / baselineMs;
  }
}

class _DispositionLap {
  const _DispositionLap({
    required this.from,
    required this.to,
    required this.splitId,
    required this.splitLabel,
    required this.legMs,
    required this.lapNumber,
    required this.legRank,
  });

  final String from;
  final String to;
  final String splitId;
  final String splitLabel;
  final int legMs;
  final int lapNumber;
  final int? legRank;

  String tooltipText(_DispositionDisplayMode displayMode, double value) {
    final rankText = legRank == null || legRank! <= 0 ? '-' : '$legRank';
    final valueText = displayMode == _DispositionDisplayMode.time
        ? 'Tid ${formatDurationMs(legMs)}'
        : 'Prosent ${_formatPercent(value)}';
    final timeText = displayMode == _DispositionDisplayMode.time
        ? ''
        : '\nTid ${formatDurationMs(legMs)}';
    return '$from -> $to\nRunde $lapNumber\n$valueText'
        '$timeText\nPlass $rankText\n$splitLabel';
  }
}

List<_DispositionGroup> _dispositionGroups(
  List<SplitValue> splits,
  Map<String, SplitDef> splitDefById,
) {
  final grouped = <String, List<_PendingDispositionLap>>{};
  final stationVisitCounts = <String, int>{};
  var from = 'Start';

  for (final split in splits) {
    final to = _stationLabel(split, splitDefById[split.id]);
    final toKey = _normalizeStation(to);
    final lapNumber = (stationVisitCounts[toKey] ?? 0) + 1;
    stationVisitCounts[toKey] = lapNumber;
    final legMs = split.legMs;
    if (legMs != null && legMs > 0) {
      final key = '${_normalizeStation(from)}>${_normalizeStation(to)}';
      grouped
          .putIfAbsent(key, () => [])
          .add(
            _PendingDispositionLap(
              from: from,
              to: to,
              splitId: split.id,
              splitLabel: split.label,
              legMs: legMs,
              lapNumber: lapNumber,
              legRank: split.legRank,
            ),
          );
    }
    from = to;
  }

  final groups = <_DispositionGroup>[];
  for (final laps in grouped.values) {
    if (laps.length <= 1) continue;
    groups.add(
      _DispositionGroup(
        from: laps.first.from,
        to: laps.first.to,
        laps: [
          for (var index = 0; index < laps.length; index++)
            _DispositionLap(
              from: laps[index].from,
              to: laps[index].to,
              splitId: laps[index].splitId,
              splitLabel: laps[index].splitLabel,
              legMs: laps[index].legMs,
              lapNumber: laps[index].lapNumber,
              legRank: laps[index].legRank,
            ),
        ],
      ),
    );
  }

  return groups;
}

class _PendingDispositionLap {
  const _PendingDispositionLap({
    required this.from,
    required this.to,
    required this.splitId,
    required this.splitLabel,
    required this.legMs,
    required this.lapNumber,
    required this.legRank,
  });

  final String from;
  final String to;
  final String splitId;
  final String splitLabel;
  final int legMs;
  final int lapNumber;
  final int? legRank;
}

String _stationLabel(SplitValue split, SplitDef? splitDef) {
  final stationName = splitDef?.stationName.trim();
  if (stationName != null && stationName.isNotEmpty) return stationName;
  return split.label.trim().isEmpty ? split.id : split.label.trim();
}

String _normalizeStation(String value) {
  return value.trim().toLowerCase();
}

double _dispositionRowHeight(_DispositionGroup group) {
  return math.max(24.0, math.min(54.0, 8.0 + group.laps.length * 9.0));
}

double _barHeight(int lapCount) {
  if (lapCount <= 3) return 6;
  if (lapCount <= 5) return 5;
  return 4;
}

double _barTop(int index, int lapCount, double rowHeight) {
  final barHeight = _barHeight(lapCount);
  final totalHeight = lapCount * barHeight + math.max(0, lapCount - 1) * 3;
  final top = (rowHeight - totalHeight) / 2 + index * (barHeight + 3);
  return math.max(1, top);
}

double _maxDispositionValue(
  List<_DispositionGroup> groups,
  _DispositionDisplayMode displayMode,
) {
  var maxValue = displayMode == _DispositionDisplayMode.time ? 1.0 : 100.0;
  for (final group in groups) {
    for (final lap in group.laps) {
      maxValue = math.max(maxValue, group.valueFor(lap, displayMode));
    }
  }
  return maxValue;
}

int _maxRank(List<SplitValue> splits) {
  var maxRank = 1;
  for (final split in splits) {
    final legRank = split.legRank;
    final cumRank = split.cumRank;
    if (legRank != null && legRank > maxRank) maxRank = legRank;
    if (cumRank != null && cumRank > maxRank) maxRank = cumRank;
  }
  return maxRank;
}

int _maxLegMs(List<SplitValue> splits) {
  var maxLegMs = 1;
  for (final split in splits) {
    final legMs = split.legMs;
    if (legMs != null && legMs > maxLegMs) maxLegMs = legMs;
  }
  return maxLegMs;
}

double _averageComparisonChartHeight(int rowCount) {
  return math.max(340.0, 210.0 + rowCount * 18.0);
}

double _splitRankChartHeight({required double width, required int splitCount}) {
  return math.max(360.0, width * 0.74 + splitCount * 7.0);
}

String _rankText(int? rank) {
  if (rank == null || rank <= 0) return '-';
  return '#$rank';
}

int? _validRank(int? rank) {
  if (rank == null || rank <= 0) return null;
  return rank;
}

List<_AverageComparisonRow> _averageComparisonRows(
  RaceResult result,
  List<RaceResult> classResults,
  List<SplitValue> splits,
) {
  final results = classResults.where((entry) => entry.isFinished).toList();
  return [
    _AverageComparisonRow(
      label: 'Totalt',
      splitId: null,
      splitMs: null,
      averageSplitMs: null,
      cumulativeMs: result.totalMs,
      averageCumulativeMs: _averageMs(
        results.map((entry) => entry.totalMs).whereType<int>(),
      ),
    ),
    for (final split in splits)
      _AverageComparisonRow(
        label: split.label,
        splitId: split.id,
        splitMs: split.legMs,
        averageSplitMs: _averageMs(
          results
              .map((entry) => entry.splitValues[split.id]?.legMs)
              .whereType<int>(),
        ),
        cumulativeMs: split.cumMs,
        averageCumulativeMs: _averageMs(
          results
              .map((entry) => entry.splitValues[split.id]?.cumMs)
              .whereType<int>(),
        ),
      ),
  ];
}

int? _averageMs(Iterable<int> values) {
  var count = 0;
  var sum = 0;
  for (final value in values) {
    if (value <= 0) continue;
    count++;
    sum += value;
  }
  if (count == 0) return null;
  return (sum / count).round();
}

int? _diffMs(int? ownMs, int? averageMs) {
  if (ownMs == null || averageMs == null || averageMs <= 0) return null;
  return ownMs - averageMs;
}

double? _diffPercent(int? ownMs, int? averageMs) {
  if (ownMs == null || ownMs <= 0 || averageMs == null || averageMs <= 0) {
    return null;
  }
  return (ownMs - averageMs) / averageMs * 100;
}

Color _averageDiffBackground(int? diffMs, Color neutralColor) {
  if (diffMs == null || diffMs == 0) return neutralColor;
  final intensity = (diffMs.abs() / 30000).clamp(0.0, 1.0).toDouble();
  final opacity = 0.14 + intensity * 0.48;
  final color = diffMs < 0 ? const Color(0xFF39D98A) : const Color(0xFFFF5C5C);
  return color.withValues(alpha: opacity);
}

String _formatNullableMs(int? value) {
  if (value == null || value <= 0) return '-';
  return formatDurationMs(value);
}

String _formatDiffMs(int? diffMs) {
  if (diffMs == null) return '-';
  final sign = diffMs > 0
      ? '+'
      : diffMs < 0
      ? '-'
      : '+';
  return '$sign${formatDurationMs(diffMs.abs())}';
}

String _formatAverageOwnValue(
  int? ownMs,
  int? averageMs,
  _AverageComparisonValueMode mode,
) {
  if (mode == _AverageComparisonValueMode.time) return _formatNullableMs(ownMs);
  if (ownMs == null || ownMs <= 0 || averageMs == null || averageMs <= 0) {
    return '-';
  }
  return _formatPercentValue(ownMs / averageMs * 100);
}

String _formatAverageBaselineValue(
  int? averageMs,
  _AverageComparisonValueMode mode,
) {
  if (mode == _AverageComparisonValueMode.time) {
    return _formatNullableMs(averageMs);
  }
  return averageMs == null || averageMs <= 0 ? '-' : '100%';
}

String _formatAverageDiffValue(
  int? ownMs,
  int? averageMs,
  _AverageComparisonValueMode mode,
) {
  if (mode == _AverageComparisonValueMode.time) {
    return _formatDiffMs(_diffMs(ownMs, averageMs));
  }
  final diffPercent = _diffPercent(ownMs, averageMs);
  if (diffPercent == null) return '-';
  final sign = diffPercent > 0
      ? '+'
      : diffPercent < 0
      ? '-'
      : '+';
  return '$sign${_formatPercentValue(diffPercent.abs())}';
}

String _formatAverageAxisValue(double value, _AverageComparisonValueMode mode) {
  if (mode == _AverageComparisonValueMode.time) {
    return _formatSignedSeconds(value);
  }
  if (value == 0) return '0%';
  final sign = value > 0 ? '+' : '-';
  return '$sign${_formatPercentValue(value.abs())}';
}

String _formatPercentValue(double value) {
  if (value.abs() >= 10) return '${value.toStringAsFixed(0)}%';
  return '${value.toStringAsFixed(1)}%';
}

String _formatSignedSeconds(double value) {
  final ms = (value.abs() * 1000).round();
  if (ms == 0) return '0.0';
  final sign = value > 0 ? '+' : '-';
  return '$sign${formatDurationMs(ms)}';
}

void _paintAverageText(
  TextPainter painter,
  Canvas canvas,
  String text,
  Offset offset, {
  required Color color,
  bool center = false,
  bool alignRight = false,
  double fontSize = 11,
  double maxWidth = 84,
}) {
  painter.text = TextSpan(
    text: text,
    style: TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
    ),
  );
  painter.layout(maxWidth: maxWidth);
  var dx = offset.dx;
  if (center) dx -= painter.width / 2;
  if (alignRight) dx -= painter.width;
  painter.paint(canvas, Offset(dx, offset.dy));
}

double _xForAverageIndex(int index, Rect chart, int count) {
  if (count <= 1) return chart.left + chart.width / 2;
  final slotWidth = chart.width / count;
  return chart.left + slotWidth * index + slotWidth / 2;
}

double _averageTargetWidth(Rect chart, int count) {
  if (count <= 1) return chart.width;
  return chart.width / count;
}

double _averageTargetLeft(int index, Rect chart, int count) {
  return chart.left + _averageTargetWidth(chart, count) * index;
}

double _yForSignedValue(double value, double maxAbs, Rect chart) {
  if (maxAbs <= 0) return chart.center.dy;
  final ratio = ((value / maxAbs).clamp(-1.0, 1.0) + 1) / 2;
  return chart.bottom - chart.height * ratio;
}

double _niceSignedAxisMax(double value) {
  if (value <= 1) return 1;
  final magnitude = math
      .pow(10, (math.log(value) / math.ln10).floor())
      .toDouble();
  for (final step in const [1.0, 2.0, 5.0, 10.0]) {
    final candidate = step * magnitude;
    if (candidate >= value) return candidate;
  }
  return value;
}

class _SplitRankLayout {
  static const left = 44.0;
  static const top = 18.0;
  static const right = 12.0;
  static const bottom = 54.0;

  static Rect chartRect(Size size) {
    return Rect.fromLTWH(
      left,
      top,
      math.max(0, size.width - left - right),
      math.max(0, size.height - top - bottom),
    );
  }
}

double _xForSplitIndex(int index, Rect chart, int count) {
  if (count <= 1) return chart.left + chart.width / 2;
  final slotWidth = chart.width / count;
  return chart.left + slotWidth * index + slotWidth / 2;
}

double _splitTargetWidth(Rect chart, int count) {
  if (count <= 1) return chart.width;
  return chart.width / count;
}

double _splitTargetLeft(int index, Rect chart, int count) {
  final width = _splitTargetWidth(chart, count);
  return chart.left + width * index;
}

double _yForRank(int rank, int maxRank, Rect chart) {
  if (maxRank <= 1) return chart.top;
  final ratio = ((rank - 1) / (maxRank - 1)).clamp(0.0, 1.0);
  return chart.top + chart.height * ratio;
}

String _axisLabel(_DispositionDisplayMode displayMode) {
  return displayMode == _DispositionDisplayMode.time
      ? 'X-akse: legMs'
      : 'X-akse: % av forste runde';
}

String _formatAxisValue(double value, _DispositionDisplayMode displayMode) {
  if (displayMode == _DispositionDisplayMode.time) {
    return formatDurationMs(value.round());
  }
  return _formatPercent(value);
}

String _formatPercent(double value) {
  if (value >= 100) return '${value.round()}%';
  return '${value.toStringAsFixed(1)}%';
}

List<Color> _lapColors(AppPalette palette) {
  return [
    palette.primary,
    palette.secondary,
    const Color(0xFFE0782F),
    const Color(0xFF2D7FE6),
    const Color(0xFF8A5BE8),
    const Color(0xFF26925F),
    const Color(0xFFD84B60),
    const Color(0xFF008A99),
  ];
}
