import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatting/time_formatters.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../results/domain/race_result.dart';

enum HeadToHeadDisplayMode { time, percent }

class AthleteHeadToHeadPanel extends StatelessWidget {
  const AthleteHeadToHeadPanel({
    super.key,
    required this.baseResult,
    required this.results,
    required this.publicSplitIds,
    required this.selectedResultId,
    required this.opponentPlacementLabel,
    required this.title,
    required this.showCloseButton,
    required this.displayMode,
    required this.onDisplayModeChanged,
    required this.onChangeOpponent,
    required this.onClose,
    required this.onSplitSelected,
  });

  final RaceResult baseResult;
  final List<RaceResult> results;
  final Set<String> publicSplitIds;
  final String? selectedResultId;
  final String? opponentPlacementLabel;
  final String title;
  final bool showCloseButton;
  final HeadToHeadDisplayMode displayMode;
  final ValueChanged<HeadToHeadDisplayMode> onDisplayModeChanged;
  final VoidCallback onChangeOpponent;
  final VoidCallback onClose;
  final ValueChanged<String> onSplitSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final opponents =
        results.where((result) => result.id != baseResult.id).toList()
          ..sort(_compareResults);
    final selected = _selectedOpponent(opponents);

    return ShellPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SegmentedButton<HeadToHeadDisplayMode>(
                segments: const [
                  ButtonSegment(
                    value: HeadToHeadDisplayMode.time,
                    label: Text('Tid'),
                  ),
                  ButtonSegment(
                    value: HeadToHeadDisplayMode.percent,
                    label: Text('%'),
                  ),
                ],
                selected: {displayMode},
                onSelectionChanged: (values) {
                  onDisplayModeChanged(values.first);
                },
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Velg annen utover',
                onPressed: onChangeOpponent,
                icon: const Icon(Icons.compare_arrows),
              ),
              if (showCloseButton) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Lukk sammenligning',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (opponents.isEmpty)
            const Expanded(
              child: EmptyState(
                title: 'Ingen andre utovere',
                message:
                    'Denne klassen har ingen andre resultater a sammenligne med.',
              ),
            )
          else if (selected == null)
            Expanded(
              child: EmptyState(
                title: 'Ingen motstander valgt',
                message: 'Velg en utover fra resultatlisten.',
              ),
            )
          else
            Builder(
              builder: (context) {
                final comparisonRows = _rows(selected);
                return Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _OpponentInfoCard(
                          opponent: selected,
                          placementLabel:
                              opponentPlacementLabel ?? selected.placementLabel,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 340,
                          child: _HeadToHeadComparisonChart(
                            rows: comparisonRows,
                            displayMode: displayMode,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final row in comparisonRows) ...[
                          _ComparisonRowTile(
                            row: row,
                            displayMode: displayMode,
                            neutralColor: palette.panelAlt,
                            borderColor: palette.border,
                            onSplitSelected: onSplitSelected,
                          ),
                          if (row != comparisonRows.last)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  RaceResult? _selectedOpponent(List<RaceResult> opponents) {
    if (selectedResultId == null) return null;
    for (final result in opponents) {
      if (result.id == selectedResultId) return result;
    }
    return null;
  }

  List<_ComparisonRow> _rows(RaceResult opponent) {
    final rows = <_ComparisonRow>[
      _ComparisonRow(
        label: 'Totalt',
        splitId: null,
        split: _ComparisonValue.empty(),
        cumulative: _ComparisonValue.fromTimes(
          baseMs: baseResult.totalMs,
          opponentMs: opponent.totalMs,
          baseText: baseResult.totalText,
        ),
      ),
    ];

    final splits =
        baseResult.splitValues.values
            .where((split) => publicSplitIds.contains(split.id))
            .toList()
          ..sort((a, b) {
            if (a.sort != b.sort) return a.sort - b.sort;
            return a.label.compareTo(b.label);
          });

    for (final split in splits) {
      final opponentSplit = opponent.splitValues[split.id];
      rows.add(
        _ComparisonRow(
          label: split.label,
          splitId: split.id,
          split: _ComparisonValue.fromTimes(
            baseMs: split.legMs,
            opponentMs: opponentSplit?.legMs,
            baseText: split.legText,
          ),
          cumulative: _ComparisonValue.fromTimes(
            baseMs: split.cumMs,
            opponentMs: opponentSplit?.cumMs,
            baseText: split.cumText,
          ),
        ),
      );
    }

    return rows;
  }
}

class _OpponentInfoCard extends StatelessWidget {
  const _OpponentInfoCard({
    required this.opponent,
    required this.placementLabel,
  });

  final RaceResult opponent;
  final String placementLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            opponent.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoMetric(label: 'Plass', value: placementLabel),
              _InfoMetric(
                label: 'Startnr',
                value: opponent.bib.isEmpty ? '-' : opponent.bib,
              ),
              _InfoMetric(
                label: 'Skyting',
                value: opponent.shooting.isEmpty ? '-' : opponent.shooting,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoMetric extends StatelessWidget {
  const _InfoMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 130),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.palette.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow {
  const _ComparisonRow({
    required this.label,
    required this.splitId,
    required this.split,
    required this.cumulative,
  });

  final String label;
  final String? splitId;
  final _ComparisonValue split;
  final _ComparisonValue cumulative;
}

class _ComparisonValue {
  const _ComparisonValue({
    required this.baseText,
    required this.diffMs,
    required this.diffPercent,
  });

  factory _ComparisonValue.empty() {
    return const _ComparisonValue(
      baseText: '-',
      diffMs: null,
      diffPercent: null,
    );
  }

  factory _ComparisonValue.fromTimes({
    required int? baseMs,
    required int? opponentMs,
    required String baseText,
  }) {
    if (baseMs == null || opponentMs == null || opponentMs <= 0) {
      return _ComparisonValue(
        baseText: baseText.isEmpty ? '-' : baseText,
        diffMs: null,
        diffPercent: null,
      );
    }
    final diffMs = baseMs - opponentMs;
    return _ComparisonValue(
      baseText: baseText.isEmpty ? formatDurationMs(baseMs) : baseText,
      diffMs: diffMs,
      diffPercent: diffMs / opponentMs * 100,
    );
  }

  final String baseText;
  final int? diffMs;
  final double? diffPercent;
}

class _HeadToHeadComparisonChart extends StatelessWidget {
  const _HeadToHeadComparisonChart({
    required this.rows,
    required this.displayMode,
  });

  final List<_ComparisonRow> rows;
  final HeadToHeadDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    final chartRows = rows
        .where(
          (row) =>
              row.splitId != null &&
              row.split.diffMs != null &&
              row.cumulative.diffMs != null,
        )
        .toList();
    final palette = context.palette;
    if (chartRows.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: palette.panelAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border),
        ),
        child: Center(
          child: Text(
            'Ingen sammenlignbare splitter',
            style: TextStyle(
              color: palette.mutedText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _ChartLegendItem(
                    color: const Color(0xFF39D98A),
                    label: 'Raskere',
                    isLine: false,
                  ),
                  _ChartLegendItem(
                    color: const Color(0xFFFF5C5C),
                    label: 'Tregere',
                    isLine: false,
                  ),
                  _ChartLegendItem(
                    color: palette.secondary,
                    label: 'Differanse over tid',
                    isLine: true,
                  ),
                ],
              ),
            ),
            Expanded(
              child: CustomPaint(
                painter: _HeadToHeadComparisonPainter(
                  rows: chartRows,
                  displayMode: displayMode,
                  palette: palette,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({
    required this.color,
    required this.label,
    required this.isLine,
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
          painter: _ChartLegendPainter(color: color, isLine: isLine),
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

class _ChartLegendPainter extends CustomPainter {
  const _ChartLegendPainter({required this.color, required this.isLine});

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
  bool shouldRepaint(covariant _ChartLegendPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isLine != isLine;
  }
}

class _HeadToHeadComparisonPainter extends CustomPainter {
  const _HeadToHeadComparisonPainter({
    required this.rows,
    required this.displayMode,
    required this.palette,
  });

  final List<_ComparisonRow> rows;
  final HeadToHeadDisplayMode displayMode;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = _ComparisonChartLayout.chartRect(size);
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
      final split = _valueFor(row.split);
      final cumulative = _valueFor(row.cumulative);
      if (split != null) maxAbs = math.max(maxAbs, split.abs());
      if (cumulative != null) maxAbs = math.max(maxAbs, cumulative.abs());
    }
    return maxAbs;
  }

  double? _valueFor(_ComparisonValue value) {
    if (displayMode == HeadToHeadDisplayMode.percent) {
      return value.diffPercent;
    }
    final diffMs = value.diffMs;
    if (diffMs == null) return null;
    return diffMs / 1000;
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
      _paintText(
        textPainter,
        canvas,
        _formatAxisValue(value),
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
      final value = _valueFor(rows[index].split);
      if (value == null) continue;
      final x = chart.left + slotWidth * index + slotWidth / 2;
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
      final value = _valueFor(rows[index].cumulative);
      if (value == null) continue;
      final point = Offset(
        _xForIndex(index, chart, rows.length),
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
      final value = _valueFor(rows[index].cumulative);
      if (value == null) continue;
      final point = Offset(
        _xForIndex(index, chart, rows.length),
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
      _paintText(
        textPainter,
        canvas,
        rows[index].label,
        Offset(_xForIndex(index, chart, rows.length), chart.bottom + 10),
        center: true,
        color: palette.mutedText,
        fontSize: 10,
        maxWidth: 72,
      );
    }
  }

  String _formatAxisValue(double value) {
    if (displayMode == HeadToHeadDisplayMode.percent) {
      if (value == 0) return '0%';
      final sign = value > 0 ? '+' : '';
      return '$sign${value.toStringAsFixed(value.abs() >= 10 ? 0 : 1)}%';
    }
    final ms = (value.abs() * 1000).round();
    if (ms == 0) return '0.0';
    final sign = value > 0 ? '+' : '-';
    return '$sign${formatDurationMs(ms)}';
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
  bool shouldRepaint(covariant _HeadToHeadComparisonPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.displayMode != displayMode ||
        oldDelegate.palette != palette;
  }
}

class _ComparisonChartLayout {
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

double _xForIndex(int index, Rect chart, int count) {
  if (count <= 1) return chart.left + chart.width / 2;
  return chart.left + chart.width * index / (count - 1);
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

class _ComparisonRowTile extends StatelessWidget {
  const _ComparisonRowTile({
    required this.row,
    required this.displayMode,
    required this.neutralColor,
    required this.borderColor,
    required this.onSplitSelected,
  });

  final _ComparisonRow row;
  final HeadToHeadDisplayMode displayMode;
  final Color neutralColor;
  final Color borderColor;
  final ValueChanged<String> onSplitSelected;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    final content = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.palette.panelAlt,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
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
          const SizedBox(width: 10),
          Expanded(
            flex: 9,
            child: _ComparisonValuePill(
              label: 'Split',
              value: row.split,
              displayMode: displayMode,
              neutralColor: neutralColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 9,
            child: _ComparisonValuePill(
              label: 'Tid',
              value: row.cumulative,
              displayMode: displayMode,
              neutralColor: neutralColor,
            ),
          ),
        ],
      ),
    );
    final splitId = row.splitId;
    if (splitId == null) return content;
    return Semantics(
      link: true,
      button: true,
      label: 'Apne ${row.label}',
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: () => onSplitSelected(splitId),
          borderRadius: borderRadius,
          child: content,
        ),
      ),
    );
  }
}

class _ComparisonValuePill extends StatelessWidget {
  const _ComparisonValuePill({
    required this.label,
    required this.value,
    required this.displayMode,
    required this.neutralColor,
  });

  final String label;
  final _ComparisonValue value;
  final HeadToHeadDisplayMode displayMode;
  final Color neutralColor;

  @override
  Widget build(BuildContext context) {
    final diffMs = value.diffMs;
    final diffPercent = value.diffPercent;
    final background = _backgroundColor(diffMs, diffPercent);
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
              color: context.palette.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${value.baseText} ${_diffText()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Color _backgroundColor(int? diffMs, double? diffPercent) {
    if (diffMs == null || diffPercent == null || diffMs == 0) {
      return neutralColor;
    }
    final intensity = (diffPercent.abs() / 20).clamp(0.0, 1.0).toDouble();
    final opacity = 0.14 + intensity * 0.48;
    final color = diffMs < 0
        ? const Color(0xFF39D98A)
        : const Color(0xFFFF5C5C);
    return color.withValues(alpha: opacity);
  }

  String _diffText() {
    final diffMs = value.diffMs;
    final diffPercent = value.diffPercent;
    if (diffMs == null || diffPercent == null) return '-';
    if (displayMode == HeadToHeadDisplayMode.percent) {
      final sign = diffPercent > 0 ? '+' : '';
      return '$sign${diffPercent.toStringAsFixed(1)}%';
    }
    final sign = diffMs > 0
        ? '+'
        : diffMs < 0
        ? '-'
        : '+';
    return '$sign${formatDurationMs(diffMs.abs())}';
  }
}

int _compareResults(RaceResult a, RaceResult b) {
  final aRank = a.finishRank ?? a.rank;
  final bRank = b.finishRank ?? b.rank;
  if (aRank != null && bRank != null && aRank != bRank) {
    return aRank - bRank;
  }
  if (a.totalMs != null && b.totalMs != null && a.totalMs != b.totalMs) {
    return a.totalMs! - b.totalMs!;
  }
  if (aRank != null) return -1;
  if (bRank != null) return 1;
  if (a.totalMs != null) return -1;
  if (b.totalMs != null) return 1;
  return a.name.compareTo(b.name);
}
