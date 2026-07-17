import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

enum ResultHistoryMetric { topPercent, rank }

class ResultHistoryEntry {
  const ResultHistoryEntry({
    this.eventId = '',
    this.classId = '',
    this.resultId = '',
    this.stageId,
    required this.eventName,
    required this.className,
    required this.date,
    required this.rank,
    required this.participantCount,
    this.totalText = '',
  });

  final String eventId;
  final String classId;
  final String resultId;
  final String? stageId;
  final String eventName;
  final String className;
  final DateTime? date;
  final int rank;
  final int participantCount;
  final String totalText;

  double? get topPercent {
    if (rank <= 0 || participantCount <= 0) return null;
    return (rank / math.max(rank, participantCount)) * 100;
  }

  String get resultSummary {
    final placement = participantCount > 0
        ? 'Plass $rank av $participantCount'
        : 'Plass $rank';
    return totalText.trim().isEmpty ? placement : '$placement · $totalText';
  }
}

class ResultHistoryPanel extends StatefulWidget {
  const ResultHistoryPanel({super.key, required this.entries, this.onEntryTap});

  final List<ResultHistoryEntry> entries;
  final ValueChanged<ResultHistoryEntry>? onEntryTap;

  @override
  State<ResultHistoryPanel> createState() => _ResultHistoryPanelState();
}

class _ResultHistoryPanelState extends State<ResultHistoryPanel> {
  var _metric = ResultHistoryMetric.topPercent;
  int? _hoveredPointIndex;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final points = _pointsFor(widget.entries, _metric);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Resultatutvikling',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 3),
                Text('Resultater over tid – lavere er bedre'),
              ],
            ),
            SegmentedButton<ResultHistoryMetric>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ResultHistoryMetric.topPercent,
                  icon: Icon(Icons.percent, size: 18),
                  label: Text('Topp %'),
                ),
                ButtonSegment(
                  value: ResultHistoryMetric.rank,
                  icon: Icon(Icons.format_list_numbered, size: 18),
                  label: Text('Rank'),
                ),
              ],
              selected: {_metric},
              onSelectionChanged: (selection) {
                setState(() => _metric = selection.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (points.isEmpty)
          Container(
            height: 190,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              _metric == ResultHistoryMetric.topPercent
                  ? 'Mangler deltakerantall for disse løpene'
                  : 'Ingen rangerte resultater ennå',
              style: TextStyle(
                color: palette.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final offsets = _pointOffsets(points, _metric, size);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ResultHistoryPainter(
                          points: points,
                          metric: _metric,
                          palette: palette,
                          textDirection: Directionality.of(context),
                          hoveredPointIndex: _hoveredPointIndex,
                          dateLabel: (date) => date == null
                              ? 'Ukjent dato'
                              : MaterialLocalizations.of(
                                  context,
                                ).formatCompactDate(date),
                        ),
                      ),
                    ),
                    for (var index = 0; index < points.length; index++)
                      Positioned(
                        left: offsets[index].dx - _pointTargetSize / 2,
                        top: offsets[index].dy - _pointTargetSize / 2,
                        width: _pointTargetSize,
                        height: _pointTargetSize,
                        child: Tooltip(
                          waitDuration: const Duration(milliseconds: 150),
                          message: _tooltipMessage(points[index].entry),
                          child: MouseRegion(
                            cursor: widget.onEntryTap == null
                                ? MouseCursor.defer
                                : SystemMouseCursors.click,
                            onEnter: (_) =>
                                setState(() => _hoveredPointIndex = index),
                            onExit: (_) {
                              if (_hoveredPointIndex == index) {
                                setState(() => _hoveredPointIndex = null);
                              }
                            },
                            child: GestureDetector(
                              key: ValueKey('result-history-point-$index'),
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onEntryTap == null
                                  ? null
                                  : () =>
                                        widget.onEntryTap!(points[index].entry),
                            ),
                          ),
                        ),
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

List<_HistoryPoint> _pointsFor(
  List<ResultHistoryEntry> entries,
  ResultHistoryMetric metric,
) {
  return [
    for (final entry in entries)
      if (entry.rank > 0 &&
          (metric == ResultHistoryMetric.rank || entry.topPercent != null))
        _HistoryPoint(
          entry: entry,
          value: metric == ResultHistoryMetric.rank
              ? entry.rank.toDouble()
              : entry.topPercent!,
        ),
  ];
}

class _HistoryPoint {
  const _HistoryPoint({required this.entry, required this.value});

  final ResultHistoryEntry entry;
  final double value;
}

class _ResultHistoryPainter extends CustomPainter {
  const _ResultHistoryPainter({
    required this.points,
    required this.metric,
    required this.palette,
    required this.textDirection,
    required this.dateLabel,
    required this.hoveredPointIndex,
  });

  final List<_HistoryPoint> points;
  final ResultHistoryMetric metric;
  final AppPalette palette;
  final TextDirection textDirection;
  final String Function(DateTime?) dateLabel;
  final int? hoveredPointIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTRB(
      _chartLeft,
      _chartTop,
      size.width - _chartRight,
      size.height - _chartBottom,
    );
    if (chart.width <= 0 || chart.height <= 0) return;

    final axisMax = _axisMax(points, metric);
    final gridPaint = Paint()
      ..color = palette.border.withValues(alpha: 0.75)
      ..strokeWidth = 1;

    for (var index = 0; index <= 4; index++) {
      final ratio = index / 4;
      final y = chart.top + chart.height * ratio;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final value = metric == ResultHistoryMetric.rank
          ? 1 + (axisMax - 1) * ratio
          : axisMax * ratio;
      _drawText(
        canvas,
        metric == ResultHistoryMetric.rank
            ? '#${value.round()}'
            : '${value.round()}%',
        Offset(chart.left - 9, y),
        color: palette.mutedText,
        align: TextAlign.right,
        anchorRight: true,
        anchorCenterY: true,
      );
    }

    final offsets = <Offset>[
      for (var index = 0; index < points.length; index++)
        Offset(
          points.length == 1
              ? chart.center.dx
              : chart.left + chart.width * index / (points.length - 1),
          _yFor(points[index].value, axisMax, metric, chart),
        ),
    ];

    if (offsets.length > 1) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final point in offsets.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = palette.primary
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    final maximumLabels = math.max(2, (chart.width / 86).floor());
    final labelEvery = math.max(
      1,
      ((points.length - 1) / math.max(1, maximumLabels - 1)).ceil(),
    );
    for (var index = 0; index < offsets.length; index++) {
      final offset = offsets[index];
      if (index == hoveredPointIndex) {
        canvas.drawCircle(
          offset,
          10,
          Paint()..color = palette.primary.withValues(alpha: 0.18),
        );
      }
      canvas.drawCircle(offset, 5, Paint()..color = palette.panelAlt);
      canvas.drawCircle(
        offset,
        index == hoveredPointIndex ? 5 : 3.5,
        Paint()..color = palette.primary,
      );

      if (index == 0 ||
          index == offsets.length - 1 ||
          index % labelEvery == 0) {
        _drawText(
          canvas,
          _valueLabel(points[index].value, metric),
          Offset(offset.dx, math.max(chart.top - 18, offset.dy - 18)),
          color: palette.primary,
          align: TextAlign.center,
          anchorCenterX: true,
          anchorCenterY: true,
          fontWeight: FontWeight.w800,
        );
        _drawText(
          canvas,
          dateLabel(points[index].entry.date),
          Offset(offset.dx, chart.bottom + 17),
          color: palette.mutedText,
          align: TextAlign.center,
          anchorCenterX: true,
          anchorCenterY: true,
        );
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
    required TextAlign align,
    bool anchorRight = false,
    bool anchorCenterX = false,
    bool anchorCenterY = false,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: fontWeight),
      ),
      textAlign: align,
      textDirection: textDirection,
      maxLines: 1,
    )..layout(maxWidth: 90);
    final dx = anchorRight
        ? offset.dx - painter.width
        : anchorCenterX
        ? offset.dx - painter.width / 2
        : offset.dx;
    final dy = anchorCenterY ? offset.dy - painter.height / 2 : offset.dy;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _ResultHistoryPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.metric != metric ||
        oldDelegate.palette != palette ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.hoveredPointIndex != hoveredPointIndex;
  }
}

const _chartLeft = 52.0;
const _chartTop = 28.0;
const _chartRight = 46.0;
const _chartBottom = 42.0;
const _pointTargetSize = 34.0;

List<Offset> _pointOffsets(
  List<_HistoryPoint> points,
  ResultHistoryMetric metric,
  Size size,
) {
  final chart = Rect.fromLTRB(
    _chartLeft,
    _chartTop,
    size.width - _chartRight,
    size.height - _chartBottom,
  );
  if (chart.width <= 0 || chart.height <= 0) return const [];
  final axisMax = _axisMax(points, metric);
  return [
    for (var index = 0; index < points.length; index++)
      Offset(
        points.length == 1
            ? chart.center.dx
            : chart.left + chart.width * index / (points.length - 1),
        _yFor(points[index].value, axisMax, metric, chart),
      ),
  ];
}

String _tooltipMessage(ResultHistoryEntry entry) {
  final details = <String>[
    entry.eventName,
    if (entry.className.trim().isNotEmpty) entry.className,
    'Resultat: ${entry.resultSummary}',
  ];
  return details.join('\n');
}

double _axisMax(List<_HistoryPoint> points, ResultHistoryMetric metric) {
  final largest = points.fold<double>(
    1,
    (max, point) => math.max(max, point.value),
  );
  if (metric == ResultHistoryMetric.rank) {
    return math.max(5, (largest / 5).ceil() * 5).toDouble();
  }
  return math.min(100, math.max(10, (largest / 10).ceil() * 10)).toDouble();
}

double _yFor(
  double value,
  double axisMax,
  ResultHistoryMetric metric,
  Rect chart,
) {
  final ratio = metric == ResultHistoryMetric.rank
      ? (value - 1) / math.max(1, axisMax - 1)
      : value / axisMax;
  return chart.top + chart.height * ratio.clamp(0.0, 1.0);
}

String _valueLabel(double value, ResultHistoryMetric metric) {
  return metric == ResultHistoryMetric.rank
      ? '#${value.round()}'
      : 'Topp ${value.ceil()}%';
}
