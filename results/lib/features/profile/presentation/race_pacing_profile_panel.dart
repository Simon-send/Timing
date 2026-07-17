import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../domain/athlete_profile.dart';
import '../domain/race_pacing_profile.dart';

class RacePacingProfilePanel extends StatefulWidget {
  const RacePacingProfilePanel({super.key, required this.races});

  final List<AthleteRace> races;

  @override
  State<RacePacingProfilePanel> createState() => _RacePacingProfilePanelState();
}

class _RacePacingProfilePanelState extends State<RacePacingProfilePanel> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final profile = buildRacePacingProfile(widget.races);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Løpsoppbygging',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          'Gjennomsnittlig plassering gjennom individuelle løp – lavere er bedre',
          style: TextStyle(color: palette.mutedText),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SummaryChip(label: '${profile.raceCount} løp'),
            _SummaryChip(label: '${profile.splitCount} splitter'),
            const _SummaryChip(label: 'Stafett utelatt'),
          ],
        ),
        const SizedBox(height: 12),
        if (profile.samples.isEmpty)
          Container(
            height: 210,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              'Trenger minst ett individuelt løp med totaltid, deltakerantall og to rangerte passeringer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else ...[
          Container(
            key: const Key('race-pacing-chart'),
            height: 320,
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final chart = _PacingChartLayout.chartRect(size);
                final yMax = _axisMax(profile.samples);
                final hovered =
                    _hoveredIndex == null ||
                        _hoveredIndex! >= profile.samples.length
                    ? null
                    : profile.samples[_hoveredIndex!];
                final hoveredOffset = hovered == null
                    ? null
                    : _sampleOffset(hovered, chart, yMax);

                return MouseRegion(
                  onExit: (_) => setState(() => _hoveredIndex = null),
                  onHover: (event) {
                    final next = _nearestSampleIndex(
                      event.localPosition,
                      chart,
                      profile.samples,
                    );
                    if (next != _hoveredIndex) {
                      setState(() => _hoveredIndex = next);
                    }
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _RacePacingPainter(
                            samples: profile.samples,
                            hoveredIndex: _hoveredIndex,
                            palette: palette,
                            textDirection: Directionality.of(context),
                          ),
                        ),
                      ),
                      if (hovered != null && hoveredOffset != null)
                        Positioned(
                          left: _detailLeft(hoveredOffset.dx, size.width),
                          top: _detailTop(hoveredOffset.dy, size.height),
                          child: IgnorePointer(
                            child: _HoverDetail(sample: hovered),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _LegendItem(color: palette.primary, label: 'Gjennomsnitt'),
              _LegendItem(
                color: palette.primary.withValues(alpha: 0.2),
                label: 'Midterste 50 % av løpene',
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tidsaksen er splittenes kumulative tid delt på løpets totaltid. Resultatet er kumulativ plassering delt på antallet rangerte utøvere ved splitten.',
            style: TextStyle(color: palette.mutedText, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _HoverDetail extends StatelessWidget {
  const _HoverDetail({required this.sample});

  final RacePacingSample sample;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: const Key('race-pacing-hover-detail'),
      width: 174,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${(sample.timeFraction * 100).round()} % av totaltid',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Snitt: topp ${_percentLabel(sample.averageRankFraction)}',
            style: TextStyle(
              color: palette.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${sample.raceCount} løp i snittet',
            style: TextStyle(color: palette.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.filled = false,
  });

  final Color color;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: filled ? 10 : 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _RacePacingPainter extends CustomPainter {
  const _RacePacingPainter({
    required this.samples,
    required this.hoveredIndex,
    required this.palette,
    required this.textDirection,
  });

  final List<RacePacingSample> samples;
  final int? hoveredIndex;
  final AppPalette palette;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = _PacingChartLayout.chartRect(size);
    if (chart.width <= 0 || chart.height <= 0 || samples.isEmpty) return;
    final yMax = _axisMax(samples);
    final gridPaint = Paint()
      ..color = palette.border.withValues(alpha: 0.8)
      ..strokeWidth = 1;

    for (var index = 0; index <= 4; index++) {
      final ratio = index / 4;
      final y = chart.top + chart.height * ratio;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _drawText(
        canvas,
        '${(yMax * ratio).round()}%',
        Offset(chart.left - 8, y),
        anchorRight: true,
        anchorCenterY: true,
      );
    }

    for (var index = 0; index <= 4; index++) {
      final ratio = index / 4;
      final x = chart.left + chart.width * ratio;
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), gridPaint);
      _drawText(
        canvas,
        '${(ratio * 100).round()}%',
        Offset(x, chart.bottom + 17),
        anchorCenterX: true,
        anchorCenterY: true,
      );
    }

    final upper = [
      for (final sample in samples)
        _valueOffset(
          sample.timeFraction,
          sample.upperRankFraction,
          chart,
          yMax,
        ),
    ];
    final lower = [
      for (final sample in samples)
        _valueOffset(
          sample.timeFraction,
          sample.lowerRankFraction,
          chart,
          yMax,
        ),
    ];
    if (upper.length > 1) {
      final band = Path()..moveTo(upper.first.dx, upper.first.dy);
      for (final point in upper.skip(1)) {
        band.lineTo(point.dx, point.dy);
      }
      for (final point in lower.reversed) {
        band.lineTo(point.dx, point.dy);
      }
      band.close();
      canvas.drawPath(
        band,
        Paint()..color = palette.primary.withValues(alpha: 0.14),
      );
    }

    final averageOffsets = [
      for (final sample in samples) _sampleOffset(sample, chart, yMax),
    ];
    final line = Path()
      ..moveTo(averageOffsets.first.dx, averageOffsets.first.dy);
    for (final point in averageOffsets.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = palette.primary
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    final activeIndex = hoveredIndex;
    if (activeIndex != null && activeIndex < averageOffsets.length) {
      final active = averageOffsets[activeIndex];
      canvas.drawLine(
        Offset(active.dx, chart.top),
        Offset(active.dx, chart.bottom),
        Paint()
          ..color = palette.primary.withValues(alpha: 0.5)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        active,
        9,
        Paint()..color = palette.primary.withValues(alpha: 0.2),
      );
      canvas.drawCircle(active, 4.5, Paint()..color = palette.primary);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    bool anchorRight = false,
    bool anchorCenterX = false,
    bool anchorCenterY = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: palette.mutedText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();
    final dx = anchorRight
        ? offset.dx - painter.width
        : anchorCenterX
        ? offset.dx - painter.width / 2
        : offset.dx;
    final dy = anchorCenterY ? offset.dy - painter.height / 2 : offset.dy;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _RacePacingPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.palette != palette ||
        oldDelegate.textDirection != textDirection;
  }
}

class _PacingChartLayout {
  static Rect chartRect(Size size) {
    return Rect.fromLTRB(52, 24, size.width - 22, size.height - 42);
  }
}

double _axisMax(List<RacePacingSample> samples) {
  final largest = samples.fold<double>(
    0,
    (value, sample) => math.max(value, sample.upperRankFraction * 100),
  );
  return math.min(100, math.max(10, (largest / 10).ceil() * 10)).toDouble();
}

Offset _sampleOffset(RacePacingSample sample, Rect chart, double yMax) {
  return _valueOffset(
    sample.timeFraction,
    sample.averageRankFraction,
    chart,
    yMax,
  );
}

Offset _valueOffset(
  double timeFraction,
  double rankFraction,
  Rect chart,
  double yMax,
) {
  return Offset(
    chart.left + chart.width * timeFraction,
    chart.top + chart.height * ((rankFraction * 100) / yMax).clamp(0.0, 1.0),
  );
}

int? _nearestSampleIndex(
  Offset position,
  Rect chart,
  List<RacePacingSample> samples,
) {
  if (!chart.inflate(14).contains(position)) return null;
  final fraction = ((position.dx - chart.left) / chart.width).clamp(0.0, 1.0);
  var bestIndex = 0;
  var bestDistance = double.infinity;
  for (var index = 0; index < samples.length; index++) {
    final distance = (samples[index].timeFraction - fraction).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      bestIndex = index;
    }
  }
  return bestIndex;
}

double _detailLeft(double pointX, double width) {
  const cardWidth = 174.0;
  final preferred = pointX + 12;
  if (preferred + cardWidth <= width - 8) return preferred;
  return math.max(8, pointX - cardWidth - 12);
}

double _detailTop(double pointY, double height) {
  const cardHeight = 78.0;
  return (pointY - cardHeight - 12).clamp(8, height - cardHeight - 8);
}

String _percentLabel(double fraction) {
  return '${(fraction * 100).round()} %';
}
