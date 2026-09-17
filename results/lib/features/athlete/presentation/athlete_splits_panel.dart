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
  _AverageComparisonGroupMode _averageComparisonGroupMode =
      _AverageComparisonGroupMode.all;

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
                _ClassAverageComparison(
                  result: widget.result,
                  classResults: widget.classResults,
                  splits: splits,
                  displayMode: _averageComparisonDisplayMode,
                  valueMode: _averageComparisonValueMode,
                  groupMode: _averageComparisonGroupMode,
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
                  onGroupModeChanged: (value) {
                    setState(() {
                      _averageComparisonGroupMode = value;
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
                KeyedSubtree(
                  key: const ValueKey('athlete-split-times'),
                  child: _splitDisplayMode == _SplitDisplayMode.graph
                      ? _SplitRankHistogram(
                          splits: splits,
                          onSplitSelected: widget.onSplitSelected,
                        )
                      : Column(
                          children: [
                            for (
                              var index = 0;
                              index < splits.length;
                              index++
                            ) ...[
                              _SplitTile(
                                split: splits[index],
                                onSplitSelected: widget.onSplitSelected,
                              ),
                              if (index < splits.length - 1)
                                const SizedBox(height: 4),
                            ],
                          ],
                        ),
                ),
                if (dispositionGroups.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  KeyedSubtree(
                    key: const ValueKey('athlete-disposition-overview'),
                    child: _DispositionHistogram(
                      groups: dispositionGroups,
                      onSplitSelected: widget.onSplitSelected,
                    ),
                  ),
                ],
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

enum _AverageComparisonGroupMode { all, better, worse }

class _ClassAverageComparison extends StatelessWidget {
  const _ClassAverageComparison({
    required this.result,
    required this.classResults,
    required this.splits,
    required this.displayMode,
    required this.valueMode,
    required this.groupMode,
    required this.onDisplayModeChanged,
    required this.onValueModeChanged,
    required this.onGroupModeChanged,
    required this.onSplitSelected,
  });

  final RaceResult result;
  final List<RaceResult> classResults;
  final List<SplitValue> splits;
  final _AverageComparisonDisplayMode displayMode;
  final _AverageComparisonValueMode valueMode;
  final _AverageComparisonGroupMode groupMode;
  final ValueChanged<_AverageComparisonDisplayMode> onDisplayModeChanged;
  final ValueChanged<_AverageComparisonValueMode> onValueModeChanged;
  final ValueChanged<_AverageComparisonGroupMode> onGroupModeChanged;
  final ValueChanged<String> onSplitSelected;

  @override
  Widget build(BuildContext context) {
    final availableGroupModes = _availableAverageGroupModes(
      result,
      classResults,
    );
    final effectiveGroupMode = availableGroupModes.contains(groupMode)
        ? groupMode
        : _AverageComparisonGroupMode.all;
    final rows = _averageComparisonRows(
      result,
      classResults,
      splits,
      effectiveGroupMode,
    );
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
                  SegmentedButton<_AverageComparisonGroupMode>(
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
                    segments: [
                      const ButtonSegment(
                        value: _AverageComparisonGroupMode.all,
                        label: Text('Gj.snitt'),
                      ),
                      ButtonSegment(
                        value: _AverageComparisonGroupMode.better,
                        label: const Text('Bedre'),
                        enabled: availableGroupModes.contains(
                          _AverageComparisonGroupMode.better,
                        ),
                      ),
                      ButtonSegment(
                        value: _AverageComparisonGroupMode.worse,
                        label: const Text('Dårligere'),
                        enabled: availableGroupModes.contains(
                          _AverageComparisonGroupMode.worse,
                        ),
                      ),
                    ],
                    selected: {effectiveGroupMode},
                    onSelectionChanged: (values) {
                      onGroupModeChanged(values.first);
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
                  Flexible(child: controls),
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

    final axisRange = _AverageAxisRange.fromValues(_chartValues());
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

    _paintGrid(canvas, chart, axisRange, gridPaint, axisPaint, textPainter);
    _paintBars(canvas, chart, axisRange, fasterPaint, slowerPaint);
    _paintLine(canvas, chart, axisRange, linePaint, pointPaint);
    _paintLabels(canvas, chart, textPainter);
  }

  List<double> _chartValues() {
    final values = <double>[];
    for (final row in rows) {
      final split = row.splitDiffValue(valueMode);
      final cumulative = row.cumulativeDiffValue(valueMode);
      if (split != null) values.add(split);
      if (cumulative != null) values.add(cumulative);
    }
    return values;
  }

  void _paintGrid(
    Canvas canvas,
    Rect chart,
    _AverageAxisRange axisRange,
    Paint gridPaint,
    Paint axisPaint,
    TextPainter textPainter,
  ) {
    for (final value in axisRange.ticks) {
      final isZero = value.abs() < 0.000001;
      final y = _yForAverageValue(value, axisRange, chart);
      canvas.drawLine(
        Offset(chart.left, y),
        Offset(chart.right, y),
        isZero ? axisPaint : gridPaint,
      );
      _paintAverageText(
        textPainter,
        canvas,
        _formatAverageAxisValue(value, valueMode),
        Offset(chart.left - 8, y - 7),
        alignRight: true,
        color: isZero ? palette.primary : palette.mutedText,
        fontSize: 10,
      );
    }

    canvas.drawLine(chart.bottomLeft, chart.bottomRight, axisPaint);
    canvas.drawLine(chart.bottomLeft, chart.topLeft, axisPaint);
  }

  void _paintBars(
    Canvas canvas,
    Rect chart,
    _AverageAxisRange axisRange,
    Paint fasterPaint,
    Paint slowerPaint,
  ) {
    final zeroY = _yForAverageValue(0, axisRange, chart);
    final slotWidth = chart.width / rows.length;
    final barWidth = math.max(4.0, math.min(28.0, slotWidth * 0.54));
    for (var index = 0; index < rows.length; index++) {
      final value = rows[index].splitDiffValue(valueMode);
      if (value == null) continue;
      final x = _xForAverageIndex(index, chart, rows.length);
      final y = _yForAverageValue(value, axisRange, chart);
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
    _AverageAxisRange axisRange,
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
        _yForAverageValue(value, axisRange, chart),
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
        _yForAverageValue(value, axisRange, chart),
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
                    final barRects = _splitRankBarRects(chart, splits);
                    return Stack(
                      children: [
                        CustomPaint(
                          painter: _SplitRankHistogramPainter(
                            splits: splits,
                            maxRank: maxRank,
                            palette: palette,
                          ),
                          child: const SizedBox.expand(),
                        ),
                        for (var index = 0; index < splits.length; index++)
                          _SplitHoverTarget(
                            split: splits[index],
                            left: barRects[index].left,
                            top: chart.top,
                            width: barRects[index].width,
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
    required this.palette,
  });

  final List<SplitValue> splits;
  final int maxRank;
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
    final bars = _splitRankBarRects(chart, splits);
    for (var index = 0; index < splits.length; index++) {
      final split = splits[index];
      final rank = _validRank(split.legRank);
      if (rank == null) continue;
      final y = _yForRank(rank, maxRank, chart);
      final visualHeight = math.max(3.0, chart.bottom - y);
      final target = bars[index];
      final rect = Rect.fromLTRB(
        target.left,
        chart.bottom - visualHeight,
        target.right,
        chart.bottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        barPaint,
      );
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
      final x = _splitRankBarCenterX(index, chart, splits);
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
        _splitRankBarCenterX(index, chart, splits),
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
        Offset(_splitRankBarCenterX(index, chart, splits), chart.bottom + 10),
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

enum _DispositionValueMode { absolute, difference }

enum _DispositionMetricMode { time, percent }

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
  _DispositionValueMode _valueMode = _DispositionValueMode.absolute;
  _DispositionMetricMode _metricMode = _DispositionMetricMode.time;
  int _baselineLapNumber = 1;

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    if (groups.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    final availableBaselineLaps = _availableDispositionBaselineLaps(groups);
    final baselineLapNumber = availableBaselineLaps.contains(_baselineLapNumber)
        ? _baselineLapNumber
        : availableBaselineLaps.first;
    final axisRange = _dispositionAxisRange(
      groups,
      _valueMode,
      _metricMode,
      baselineLapNumber,
    );
    final colors = _lapColors(palette);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Disponering',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _dispositionModeSummary(
                    _valueMode,
                    _metricMode,
                    baselineLapNumber,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<_DispositionValueMode>(
                style: _compactSegmentedButtonStyle(),
                segments: const [
                  ButtonSegment(
                    value: _DispositionValueMode.absolute,
                    label: Text('Absolutt'),
                  ),
                  ButtonSegment(
                    value: _DispositionValueMode.difference,
                    label: Text('Differanse'),
                  ),
                ],
                selected: {_valueMode},
                onSelectionChanged: (values) {
                  setState(() {
                    _valueMode = values.first;
                  });
                },
              ),
              SegmentedButton<_DispositionMetricMode>(
                style: _compactSegmentedButtonStyle(),
                segments: const [
                  ButtonSegment(
                    value: _DispositionMetricMode.time,
                    label: Text('Tid'),
                  ),
                  ButtonSegment(
                    value: _DispositionMetricMode.percent,
                    label: Text('%'),
                  ),
                ],
                selected: {_metricMode},
                onSelectionChanged: (values) {
                  setState(() {
                    _metricMode = values.first;
                  });
                },
              ),
              if (_valueMode == _DispositionValueMode.difference ||
                  _metricMode == _DispositionMetricMode.percent)
                SegmentedButton<int>(
                  style: _compactSegmentedButtonStyle(),
                  segments: [
                    for (final lapNumber in availableBaselineLaps)
                      ButtonSegment(
                        value: lapNumber,
                        label: Text('R$lapNumber'),
                      ),
                  ],
                  selected: {baselineLapNumber},
                  onSelectionChanged: (values) {
                    setState(() {
                      _baselineLapNumber = values.first;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _axisLabel(_valueMode, _metricMode, baselineLapNumber),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Flexible(
                child: _DispositionLegend(
                  colors: colors,
                  valueMode: _valueMode,
                  baselineLapNumber: baselineLapNumber,
                  lapNumbers: availableBaselineLaps,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DispositionChart(
            groups: groups,
            axisRange: axisRange,
            valueMode: _valueMode,
            metricMode: _metricMode,
            baselineLapNumber: baselineLapNumber,
            colors: colors,
            onSplitSelected: widget.onSplitSelected,
          ),
        ],
      ),
    );
  }
}

class _DispositionLegend extends StatelessWidget {
  const _DispositionLegend({
    required this.colors,
    required this.valueMode,
    required this.baselineLapNumber,
    required this.lapNumbers,
  });

  final List<Color> colors;
  final _DispositionValueMode valueMode;
  final int baselineLapNumber;
  final List<int> lapNumbers;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (valueMode == _DispositionValueMode.difference) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DispositionLegendItem(
            color: _lapColorForLap(colors, baselineLapNumber),
            label: '0=R$baselineLapNumber',
          ),
          const SizedBox(width: 6),
          _DispositionLegendItem(
            color: _fasterDispositionColor(palette),
            label: 'Mindre',
          ),
          const SizedBox(width: 6),
          _DispositionLegendItem(
            color: _slowerDispositionColor(palette),
            label: 'Mer',
          ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < lapNumbers.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            _DispositionLegendItem(
              color: _lapColorForLap(colors, lapNumbers[index]),
              label: 'R${lapNumbers[index]}',
            ),
          ],
        ],
      ),
    );
  }
}

class _DispositionLegendItem extends StatelessWidget {
  const _DispositionLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: color, width: 1),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DispositionChart extends StatelessWidget {
  const _DispositionChart({
    required this.groups,
    required this.axisRange,
    required this.valueMode,
    required this.metricMode,
    required this.baselineLapNumber,
    required this.colors,
    required this.onSplitSelected,
  });

  final List<_DispositionGroup> groups;
  final _DispositionAxisRange axisRange;
  final _DispositionValueMode valueMode;
  final _DispositionMetricMode metricMode;
  final int baselineLapNumber;
  final List<Color> colors;
  final ValueChanged<String> onSplitSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final height = _dispositionChartHeight(width, groups.length);
        final lapSlotCount = _maxDispositionLapNumber(groups);
        final minimumGroupWidth = math.max(86.0, 30.0 + lapSlotCount * 12.0);
        final contentWidth = math.max(
          width,
          _DispositionChartLayout.left +
              _DispositionChartLayout.right +
              groups.length * minimumGroupWidth,
        );
        final size = Size(contentWidth, height);
        final chart = _DispositionChartLayout.chartRect(size);
        final bars = _dispositionBarTargets(
          chart: chart,
          groups: groups,
          axisRange: axisRange,
          valueMode: valueMode,
          metricMode: metricMode,
          baselineLapNumber: baselineLapNumber,
          colors: colors,
          palette: context.palette,
          onSplitSelected: onSplitSelected,
        );

        return SizedBox(
          height: height,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DispositionHistogramPainter(
                        groups: groups,
                        axisRange: axisRange,
                        valueMode: valueMode,
                        metricMode: metricMode,
                        baselineLapNumber: baselineLapNumber,
                        palette: context.palette,
                      ),
                    ),
                  ),
                  ...bars,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DispositionBar extends StatelessWidget {
  const _DispositionBar({
    required this.group,
    required this.lap,
    required this.valueMode,
    required this.metricMode,
    required this.baselineLapNumber,
    required this.color,
    required this.onSplitSelected,
  });

  final _DispositionGroup group;
  final _DispositionLap lap;
  final _DispositionValueMode valueMode;
  final _DispositionMetricMode metricMode;
  final int baselineLapNumber;
  final Color color;
  final ValueChanged<String> onSplitSelected;

  @override
  Widget build(BuildContext context) {
    final baselineLap = group.baselineLapFor(baselineLapNumber);
    final percent = group.percentFor(lap, baselineLapNumber);
    final diff = group.differenceFor(lap, metricMode, baselineLapNumber);
    return Tooltip(
      message:
          '${lap.tooltipText(valueMode: valueMode, metricMode: metricMode, baselineLap: baselineLap, percent: percent, difference: diff)}'
          '${group.usesFallbackBaseline(baselineLapNumber) ? '\nMangler valgt 0-runde for denne strekningen' : ''}'
          '\nKlikk for a apne splitten',
      child: Semantics(
        key: ValueKey('disposition-bar-${lap.splitId}'),
        link: true,
        button: true,
        label: 'Apne ${lap.splitLabel}',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSplitSelected(lap.splitId),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: color, width: 1),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _DispositionChartLayout {
  static const left = 58.0;
  static const top = 12.0;
  static const right = 10.0;
  static const bottom = 50.0;

  static Rect chartRect(Size size) {
    return Rect.fromLTWH(
      left,
      top,
      math.max(0, size.width - left - right),
      math.max(0, size.height - top - bottom),
    );
  }
}

List<Widget> _dispositionBarTargets({
  required Rect chart,
  required List<_DispositionGroup> groups,
  required _DispositionAxisRange axisRange,
  required _DispositionValueMode valueMode,
  required _DispositionMetricMode metricMode,
  required int baselineLapNumber,
  required List<Color> colors,
  required AppPalette palette,
  required ValueChanged<String> onSplitSelected,
}) {
  if (groups.isEmpty || colors.isEmpty) return const [];
  final widgets = <Widget>[];
  final slotWidth = chart.width / groups.length;
  final lapSlotCount = _maxDispositionLapNumber(groups);

  for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
    final group = groups[groupIndex];
    final slotLeft = chart.left + slotWidth * groupIndex;
    final innerPadding = math.min(18.0, slotWidth * 0.16);
    final innerWidth = math.max(12.0, slotWidth - innerPadding * 2);
    final gap = lapSlotCount <= 1
        ? 0.0
        : innerWidth < lapSlotCount * 14
        ? 2.0
        : 4.0;
    final totalGap = gap * math.max(0, lapSlotCount - 1);
    final barWidth = math.max(
      4.0,
      math.min(24.0, (innerWidth - totalGap) / lapSlotCount),
    );
    final barsWidth = barWidth * lapSlotCount + totalGap;
    final barsLeft = slotLeft + (slotWidth - barsWidth) / 2;

    final laps = group.histogramLaps;
    for (var lapIndex = 0; lapIndex < laps.length; lapIndex++) {
      final lap = laps[lapIndex];
      final slotIndex = lap.lapNumber >= 1 ? lap.lapNumber - 1 : lapIndex;
      if (slotIndex < 0 || slotIndex >= lapSlotCount) continue;
      final value = group.chartValueFor(
        lap,
        valueMode,
        metricMode,
        baselineLapNumber,
      );
      final isBaseline = group.isBaselineLap(lap, baselineLapNumber);
      final zeroY = _yForDispositionValue(0, axisRange, chart);
      final valueY = _yForDispositionValue(value, axisRange, chart);
      final barHeight =
          valueMode == _DispositionValueMode.difference && isBaseline
          ? 4.0
          : math.max(7.0, (valueY - zeroY).abs());
      final top = valueMode == _DispositionValueMode.difference
          ? isBaseline
                ? zeroY - barHeight / 2
                : math.min(valueY, zeroY)
          : valueY;
      widgets.add(
        Positioned(
          left: barsLeft + slotIndex * (barWidth + gap),
          top: top.clamp(chart.top, chart.bottom - barHeight).toDouble(),
          width: barWidth,
          height: barHeight,
          child: _DispositionBar(
            group: group,
            lap: lap,
            valueMode: valueMode,
            metricMode: metricMode,
            baselineLapNumber: baselineLapNumber,
            color: _dispositionBarColor(
              lap: lap,
              group: group,
              valueMode: valueMode,
              metricMode: metricMode,
              baselineLapNumber: baselineLapNumber,
              colors: colors,
              palette: palette,
              slotIndex: slotIndex,
            ),
            onSplitSelected: onSplitSelected,
          ),
        ),
      );
    }
  }

  return widgets;
}

class _DispositionHistogramPainter extends CustomPainter {
  const _DispositionHistogramPainter({
    required this.groups,
    required this.axisRange,
    required this.valueMode,
    required this.metricMode,
    required this.baselineLapNumber,
    required this.palette,
  });

  final List<_DispositionGroup> groups;
  final _DispositionAxisRange axisRange;
  final _DispositionValueMode valueMode;
  final _DispositionMetricMode metricMode;
  final int baselineLapNumber;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = _DispositionChartLayout.chartRect(size);
    final gridPaint = Paint()
      ..color = palette.border.withValues(alpha: 0.42)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = palette.border
      ..strokeWidth = 1.1;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    for (final value in axisRange.ticks) {
      final y = _yForDispositionValue(value, axisRange, chart);
      final isZero = value.abs() < 0.000001;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      textPainter.text = TextSpan(
        text: _formatAxisValue(value, valueMode, metricMode),
        style: TextStyle(
          color: isZero ? palette.primary : palette.mutedText,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      );
      textPainter.layout(maxWidth: chart.left - 6);
      textPainter.paint(
        canvas,
        Offset(chart.left - textPainter.width - 6, math.max(0, y - 11)),
      );
    }

    final zeroY = _yForDispositionValue(0, axisRange, chart);
    canvas.drawLine(
      Offset(chart.left, zeroY),
      Offset(chart.right, zeroY),
      axisPaint,
    );
    canvas.drawLine(chart.bottomLeft, chart.topLeft, axisPaint);
    _paintGroupLabels(canvas, chart, textPainter);
  }

  void _paintGroupLabels(Canvas canvas, Rect chart, TextPainter textPainter) {
    if (groups.isEmpty) return;
    final labelEvery = chart.width < 520
        ? math.max(1, (groups.length / 4).ceil())
        : 1;
    final slotWidth = chart.width / groups.length;
    for (var index = 0; index < groups.length; index++) {
      if (index % labelEvery != 0 && index != groups.length - 1) continue;
      final group = groups[index];
      textPainter.text = TextSpan(
        text: group.label,
        style: TextStyle(
          color: palette.mutedText,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      );
      textPainter.layout(maxWidth: math.max(42, slotWidth - 4));
      final x = chart.left + slotWidth * index + slotWidth / 2;
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, chart.bottom + 8),
      );
      if (group.usesFallbackBaseline(baselineLapNumber)) {
        final actualBaseline = group.baselineLapFor(baselineLapNumber);
        textPainter.text = TextSpan(
          text: '0=R${actualBaseline.lapNumber}',
          style: TextStyle(
            color: palette.mutedText.withValues(alpha: 0.82),
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        );
        textPainter.layout(maxWidth: slotWidth);
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, chart.bottom + 23),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DispositionHistogramPainter oldDelegate) {
    return oldDelegate.groups != groups ||
        oldDelegate.axisRange != axisRange ||
        oldDelegate.valueMode != valueMode ||
        oldDelegate.metricMode != metricMode ||
        oldDelegate.baselineLapNumber != baselineLapNumber ||
        oldDelegate.palette != palette;
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

  _DispositionLap baselineLapFor(int lapNumber) {
    for (final lap in laps) {
      if (lap.lapNumber == lapNumber) return lap;
    }
    return baselineLap;
  }

  bool usesFallbackBaseline(int lapNumber) {
    return baselineLapFor(lapNumber).lapNumber != lapNumber;
  }

  List<_DispositionLap> get histogramLaps {
    return [...laps]..sort((a, b) => a.lapNumber - b.lapNumber);
  }

  double percentFor(_DispositionLap lap, int baselineLapNumber) {
    final baselineMs = baselineLapFor(baselineLapNumber).legMs;
    if (baselineMs <= 0) return 0;
    return lap.legMs * 100 / baselineMs;
  }

  double valueFor(
    _DispositionLap lap,
    _DispositionMetricMode metricMode,
    int baselineLapNumber,
  ) {
    if (metricMode == _DispositionMetricMode.time) return lap.legMs.toDouble();
    return percentFor(lap, baselineLapNumber);
  }

  double differenceFor(
    _DispositionLap lap,
    _DispositionMetricMode metricMode,
    int baselineLapNumber,
  ) {
    final baselineLap = baselineLapFor(baselineLapNumber);
    if (metricMode == _DispositionMetricMode.time) {
      return (lap.legMs - baselineLap.legMs).toDouble();
    }
    final baselineMs = baselineLap.legMs;
    if (baselineMs <= 0) return 0;
    return (lap.legMs - baselineMs) * 100 / baselineMs;
  }

  double barMagnitudeFor(
    _DispositionLap lap,
    _DispositionValueMode valueMode,
    _DispositionMetricMode metricMode,
    int baselineLapNumber,
  ) {
    if (valueMode == _DispositionValueMode.absolute) {
      return valueFor(lap, metricMode, baselineLapNumber);
    }
    return differenceFor(lap, metricMode, baselineLapNumber).abs();
  }

  double chartValueFor(
    _DispositionLap lap,
    _DispositionValueMode valueMode,
    _DispositionMetricMode metricMode,
    int baselineLapNumber,
  ) {
    if (valueMode == _DispositionValueMode.absolute) {
      return valueFor(lap, metricMode, baselineLapNumber);
    }
    return differenceFor(lap, metricMode, baselineLapNumber);
  }

  bool isBaselineLap(_DispositionLap lap, int baselineLapNumber) {
    return lap.splitId == baselineLapFor(baselineLapNumber).splitId;
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

  String tooltipText({
    required _DispositionValueMode valueMode,
    required _DispositionMetricMode metricMode,
    required _DispositionLap baselineLap,
    required double percent,
    required double difference,
  }) {
    final rankText = legRank == null || legRank! <= 0 ? '-' : '$legRank';
    final timeText = formatDurationMs(legMs);
    final percentText = _formatPercent(percent);
    final mainValue = valueMode == _DispositionValueMode.absolute
        ? metricMode == _DispositionMetricMode.time
              ? timeText
              : percentText
        : _formatSignedDispositionValue(difference, metricMode);
    final mainLabel = valueMode == _DispositionValueMode.absolute
        ? 'Absolutt'
        : 'Differanse fra R${baselineLap.lapNumber}';
    return '$from -> $to\nRunde $lapNumber: $mainValue'
        '\n$mainLabel $mainValue\nTid $timeText\n% av R${baselineLap.lapNumber} $percentText'
        '\nReferanse R${baselineLap.lapNumber} ${formatDurationMs(baselineLap.legMs)}'
        '\nPlass $rankText\n$splitLabel';
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

double _dispositionChartHeight(double width, int groupCount) {
  final compactHeight = width < 520 ? 230.0 : 250.0;
  return math.max(compactHeight, math.min(310.0, 220.0 + groupCount * 4.0));
}

int _maxDispositionLapNumber(List<_DispositionGroup> groups) {
  var maximum = 1;
  for (final group in groups) {
    for (final lap in group.laps) {
      maximum = math.max(maximum, lap.lapNumber);
    }
  }
  return maximum;
}

_DispositionAxisRange _dispositionAxisRange(
  List<_DispositionGroup> groups,
  _DispositionValueMode valueMode,
  _DispositionMetricMode metricMode,
  int baselineLapNumber,
) {
  var minValue = 0.0;
  var maxValue =
      valueMode == _DispositionValueMode.absolute &&
          metricMode == _DispositionMetricMode.percent
      ? 100.0
      : 1.0;
  for (final group in groups) {
    for (final lap in group.histogramLaps) {
      final value = group.chartValueFor(
        lap,
        valueMode,
        metricMode,
        baselineLapNumber,
      );
      minValue = math.min(minValue, value);
      maxValue = math.max(maxValue, value);
    }
  }
  return _DispositionAxisRange.fromBounds(
    minValue: minValue,
    maxValue: maxValue,
    valueMode: valueMode,
    metricMode: metricMode,
  );
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

double _averageComparisonChartHeight(int rowCount) {
  return math.max(340.0, 210.0 + rowCount * 18.0);
}

double _splitRankChartHeight({required double width, required int splitCount}) {
  return math.max(180.0, width * 0.37 + splitCount * 3.5);
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
  _AverageComparisonGroupMode groupMode,
) {
  final results = _averageComparisonResults(result, classResults, groupMode);
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

List<RaceResult> _averageComparisonResults(
  RaceResult result,
  List<RaceResult> classResults,
  _AverageComparisonGroupMode groupMode,
) {
  final ownTotalMs = result.totalMs;
  return classResults.where((entry) {
    if (!entry.isFinished) return false;
    if (groupMode == _AverageComparisonGroupMode.all) return true;
    if (entry.id == result.id) return false;
    final totalMs = entry.totalMs;
    if (ownTotalMs == null || ownTotalMs <= 0 || totalMs == null) {
      return false;
    }
    if (groupMode == _AverageComparisonGroupMode.better) {
      return totalMs < ownTotalMs;
    }
    return totalMs > ownTotalMs;
  }).toList();
}

Set<_AverageComparisonGroupMode> _availableAverageGroupModes(
  RaceResult result,
  List<RaceResult> classResults,
) {
  final available = <_AverageComparisonGroupMode>{
    _AverageComparisonGroupMode.all,
  };
  final ownTotalMs = result.totalMs;
  if (ownTotalMs == null || ownTotalMs <= 0) return available;

  for (final entry in classResults) {
    if (!entry.isFinished || entry.id == result.id) continue;
    final totalMs = entry.totalMs;
    if (totalMs == null || totalMs <= 0) continue;
    if (totalMs < ownTotalMs) {
      available.add(_AverageComparisonGroupMode.better);
    } else if (totalMs > ownTotalMs) {
      available.add(_AverageComparisonGroupMode.worse);
    }
  }
  return available;
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

double _yForAverageValue(
  double value,
  _AverageAxisRange axisRange,
  Rect chart,
) {
  if (axisRange.max <= axisRange.min) return chart.center.dy;
  final ratio = ((value - axisRange.min) / (axisRange.max - axisRange.min))
      .clamp(0.0, 1.0);
  return chart.bottom - chart.height * ratio;
}

class _AverageAxisRange {
  const _AverageAxisRange({
    required this.min,
    required this.max,
    required this.ticks,
  });

  final double min;
  final double max;
  final List<double> ticks;

  factory _AverageAxisRange.fromValues(List<double> values) {
    var rawMin = 0.0;
    var rawMax = 0.0;
    for (final value in values) {
      rawMin = math.min(rawMin, value);
      rawMax = math.max(rawMax, value);
    }

    if (rawMin == rawMax) {
      rawMin -= 1;
      rawMax += 1;
    }

    final step = _niceAxisStep((rawMax - rawMin) / 4);
    final min = math.min(0.0, (rawMin / step).floorToDouble() * step);
    final max = math.max(0.0, (rawMax / step).ceilToDouble() * step);
    final ticks = <double>[];
    final tickCount = ((max - min) / step).round();
    for (var i = 0; i <= tickCount; i++) {
      final value = min + step * i;
      ticks.add(value.abs() < step / 1000 ? 0 : value);
    }
    if (!ticks.any((value) => value == 0)) {
      ticks.add(0);
      ticks.sort();
    }

    return _AverageAxisRange(min: min, max: max, ticks: ticks);
  }
}

double _niceAxisStep(double value) {
  if (value <= 0) return 1;
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

List<Rect> _splitRankBarRects(Rect chart, List<SplitValue> splits) {
  if (splits.isEmpty) return const [];
  final preferredGap = chart.width < 520 ? 4.0 : 6.0;
  final gap = splits.length <= 1
      ? 0.0
      : math.min(preferredGap, chart.width / (splits.length * 3));
  final totalGap = gap * math.max(0, splits.length - 1);
  final availableWidth = math.max(0, chart.width - totalGap);
  final totalMs = splits.fold<int>(
    0,
    (sum, split) => sum + math.max(1, split.legMs ?? 0),
  );

  final rects = <Rect>[];
  var left = chart.left;
  for (final split in splits) {
    final legMs = math.max(1, split.legMs ?? 0);
    final width = availableWidth * legMs / math.max(1, totalMs);
    rects.add(Rect.fromLTWH(left, chart.top, width, chart.height));
    left += width + gap;
  }
  return rects;
}

double _splitRankBarCenterX(int index, Rect chart, List<SplitValue> splits) {
  final rects = _splitRankBarRects(chart, splits);
  if (index < 0 || index >= rects.length) return chart.left;
  return rects[index].center.dx;
}

double _yForRank(int rank, int maxRank, Rect chart) {
  if (maxRank <= 1) return chart.top;
  final ratio = ((rank - 1) / (maxRank - 1)).clamp(0.0, 1.0);
  return chart.top + chart.height * ratio;
}

ButtonStyle _compactSegmentedButtonStyle() {
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStateProperty.all(
      const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class _DispositionAxisRange {
  const _DispositionAxisRange({
    required this.min,
    required this.max,
    required this.ticks,
  });

  final double min;
  final double max;
  final List<double> ticks;

  factory _DispositionAxisRange.fromBounds({
    required double minValue,
    required double maxValue,
    required _DispositionValueMode valueMode,
    required _DispositionMetricMode metricMode,
  }) {
    if (valueMode == _DispositionValueMode.absolute) {
      final max = math.max(1.0, maxValue);
      final ticks = <double>{max / 2, max};
      if (metricMode == _DispositionMetricMode.percent && max >= 100) {
        ticks.add(100);
      }
      return _DispositionAxisRange(
        min: 0,
        max: max,
        ticks: ticks.toList()..sort(),
      );
    }

    var min = math.min(0.0, minValue);
    var max = math.max(0.0, maxValue);
    if (min == max) {
      min = -1;
      max = 1;
    }
    final ticks = <double>{min, 0, max};
    return _DispositionAxisRange(
      min: min,
      max: max,
      ticks: ticks.toList()..sort(),
    );
  }
}

double _yForDispositionValue(
  double value,
  _DispositionAxisRange axisRange,
  Rect chart,
) {
  if (axisRange.max <= axisRange.min) return chart.bottom;
  final ratio = ((value - axisRange.min) / (axisRange.max - axisRange.min))
      .clamp(0.0, 1.0);
  return chart.bottom - chart.height * ratio;
}

List<int> _availableDispositionBaselineLaps(List<_DispositionGroup> groups) {
  final lapNumbers = <int>{};
  for (final group in groups) {
    for (final lap in group.histogramLaps) {
      if (lap.lapNumber > 0) lapNumbers.add(lap.lapNumber);
    }
  }
  if (lapNumbers.isEmpty) return const [1];
  final sorted = lapNumbers.toList()..sort();
  return sorted;
}

String _dispositionModeSummary(
  _DispositionValueMode valueMode,
  _DispositionMetricMode metricMode,
  int baselineLapNumber,
) {
  final metricText = metricMode == _DispositionMetricMode.time ? 'tid' : '%';
  if (valueMode == _DispositionValueMode.absolute) {
    return metricMode == _DispositionMetricMode.time
        ? 'Absolutt tid'
        : 'Absolutt % av R$baselineLapNumber';
  }
  return 'Differanse fra R$baselineLapNumber i $metricText';
}

String _axisLabel(
  _DispositionValueMode valueMode,
  _DispositionMetricMode metricMode,
  int baselineLapNumber,
) {
  final unit = metricMode == _DispositionMetricMode.time ? 'tid' : '%';
  if (valueMode == _DispositionValueMode.absolute) {
    return metricMode == _DispositionMetricMode.time
        ? 'Y-akse: absolutt tid'
        : 'Y-akse: % av R$baselineLapNumber';
  }
  return 'Y-akse: differanse i $unit fra R$baselineLapNumber';
}

String _formatAxisValue(
  double value,
  _DispositionValueMode valueMode,
  _DispositionMetricMode metricMode,
) {
  if (valueMode == _DispositionValueMode.difference) {
    if (metricMode == _DispositionMetricMode.time) {
      if (value == 0) return '0';
      final sign = value > 0 ? '+' : '-';
      return '$sign${formatDurationMs(value.abs().round())}';
    }
    if (value == 0) return '0%';
    final sign = value > 0 ? '+' : '-';
    return '$sign${_formatPercent(value.abs())}';
  }
  if (metricMode == _DispositionMetricMode.time) {
    return formatDurationMs(value.round());
  }
  return _formatPercent(value);
}

String _formatSignedDispositionValue(
  double value,
  _DispositionMetricMode metricMode,
) {
  if (value == 0) {
    return metricMode == _DispositionMetricMode.time ? '0:00.0' : '0%';
  }
  final sign = value > 0 ? '+' : '-';
  if (metricMode == _DispositionMetricMode.time) {
    return '$sign${formatDurationMs(value.abs().round())}';
  }
  return '$sign${_formatPercent(value.abs())}';
}

String _formatPercent(double value) {
  if (value.abs() >= 100) return '${value.round()}%';
  if (value.abs() >= 10) return '${value.toStringAsFixed(0)}%';
  return '${value.toStringAsFixed(1)}%';
}

Color _dispositionBarColor({
  required _DispositionLap lap,
  required _DispositionGroup group,
  required _DispositionValueMode valueMode,
  required _DispositionMetricMode metricMode,
  required int baselineLapNumber,
  required List<Color> colors,
  required AppPalette palette,
  required int slotIndex,
}) {
  if (valueMode == _DispositionValueMode.absolute) {
    return colors[slotIndex % colors.length];
  }
  if (group.isBaselineLap(lap, baselineLapNumber)) {
    return _lapColorForLap(colors, lap.lapNumber);
  }
  final diff = group.differenceFor(lap, metricMode, baselineLapNumber);
  if (diff < 0) return _fasterDispositionColor(palette);
  if (diff > 0) return _slowerDispositionColor(palette);
  return palette.mutedText;
}

Color _lapColorForLap(List<Color> colors, int lapNumber) {
  if (colors.isEmpty) return Colors.transparent;
  final index = math.max(0, lapNumber - 1);
  return colors[index % colors.length];
}

Color _fasterDispositionColor(AppPalette palette) {
  return palette.brightness == Brightness.light
      ? const Color(0xFF16864A)
      : const Color(0xFF53D27B);
}

Color _slowerDispositionColor(AppPalette palette) {
  return palette.brightness == Brightness.light
      ? const Color(0xFFD12B2B)
      : const Color(0xFFFF4D4D);
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
