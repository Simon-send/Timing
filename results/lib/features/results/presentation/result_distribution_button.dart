import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';

import '../../../app/app_theme.dart';

class ResultDistributionData {
  const ResultDistributionData({
    required this.title,
    required this.values,
    required this.formatValue,
    this.regression,
    this.regressionTargets = const [],
    this.splitAnalysis,
    this.currentAthleteValue,
    this.currentAthleteLabel = 'Din tid',
  });

  final String title;
  final List<int> values;
  final String Function(int value) formatValue;
  final ResultRegressionData? regression;
  final List<ResultRegressionTarget> regressionTargets;
  final ResultSplitAnalysisData? splitAnalysis;
  final int? currentAthleteValue;
  final String currentAthleteLabel;

  bool get hasDistribution => values.length >= 2;
  bool get hasRegression => regression?.hasEnoughData ?? false;
  bool get hasSplitAnalysis => splitAnalysis?.hasEnoughData ?? false;
  bool get hasEnoughData =>
      hasDistribution || hasRegression || hasSplitAnalysis;
}

class ResultSplitAnalysisData {
  const ResultSplitAnalysisData({required this.points});

  final List<ResultSplitAnalysisPoint> points;

  bool get hasEnoughData => points.length >= 2;
}

class ResultSplitAnalysisPoint {
  const ResultSplitAnalysisPoint({
    required this.splitId,
    required this.label,
    required this.sort,
    required this.timeCorrelation,
    required this.rankCorrelation,
    required this.sampleSize,
  });

  final String splitId;
  final String label;
  final int sort;
  final double timeCorrelation;
  final double rankCorrelation;
  final int sampleSize;
}

class ResultRegressionData {
  const ResultRegressionData({
    required this.title,
    required this.subjectLabel,
    required this.xLabel,
    required this.yLabel,
    required this.points,
    required this.formatX,
    required this.formatY,
  });

  final String title;
  final String subjectLabel;
  final String xLabel;
  final String yLabel;
  final List<ResultRegressionPoint> points;
  final String Function(int value) formatX;
  final String Function(int value) formatY;

  bool get hasEnoughData => points.length >= 2;
}

class ResultRegressionTarget {
  const ResultRegressionTarget({
    required this.key,
    required this.label,
    required this.regression,
  });

  final String key;
  final String label;
  final ResultRegressionData regression;
}

class ResultRegressionPoint {
  const ResultRegressionPoint({
    required this.x,
    required this.y,
    required this.label,
    this.color,
    this.isCurrentAthlete = false,
  });

  final int x;
  final int y;
  final String label;
  final Color? color;
  final bool isCurrentAthlete;
}

class ResultDistributionButton extends StatelessWidget {
  const ResultDistributionButton({
    super.key,
    required this.data,
    this.loadData,
    this.loadingLabel = 'Laster grafdata',
    this.errorTitle = 'Kunne ikke lese grafdata',
    this.onSplitSelected,
    this.onChooseFromResultsList,
  });

  final ResultDistributionData? data;
  final Future<ResultDistributionData?> Function()? loadData;
  final String loadingLabel;
  final String errorTitle;
  final ValueChanged<String>? onSplitSelected;
  final VoidCallback? onChooseFromResultsList;

  @override
  Widget build(BuildContext context) {
    final enabled = loadData != null || (data?.hasEnoughData ?? false);
    return SizedBox(
      width: 42,
      height: 42,
      child: IconButton.outlined(
        tooltip: 'Fordeling, regresjon og splittanalyse',
        onPressed: enabled
            ? () {
                showResultAnalysisDialog(
                  context,
                  data: data,
                  loadData: loadData,
                  loadingLabel: loadingLabel,
                  errorTitle: errorTitle,
                  onSplitSelected: onSplitSelected,
                  onChooseFromResultsList: onChooseFromResultsList,
                );
              }
            : null,
        icon: const Icon(Icons.analytics_outlined),
      ),
    );
  }
}

Future<void> showResultAnalysisDialog(
  BuildContext context, {
  ResultDistributionData? data,
  Future<ResultDistributionData?> Function()? loadData,
  required String loadingLabel,
  required String errorTitle,
  ValueChanged<String>? onSplitSelected,
  VoidCallback? onChooseFromResultsList,
  bool openRegression = false,
  String? initialRegressionTargetKey,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => loadData == null
        ? _DistributionDialog(
            data: data!,
            onSplitSelected: onSplitSelected,
            onChooseFromResultsList: onChooseFromResultsList,
            openRegression: openRegression,
            initialRegressionTargetKey: initialRegressionTargetKey,
          )
        : _DistributionLoadDialog(
            loadData: loadData,
            loadingLabel: loadingLabel,
            errorTitle: errorTitle,
            onSplitSelected: onSplitSelected,
            onChooseFromResultsList: onChooseFromResultsList,
            openRegression: openRegression,
            initialRegressionTargetKey: initialRegressionTargetKey,
          ),
  );
}

class _DistributionLoadDialog extends StatefulWidget {
  const _DistributionLoadDialog({
    required this.loadData,
    required this.loadingLabel,
    required this.errorTitle,
    required this.onSplitSelected,
    required this.onChooseFromResultsList,
    required this.openRegression,
    required this.initialRegressionTargetKey,
  });

  final Future<ResultDistributionData?> Function() loadData;
  final String loadingLabel;
  final String errorTitle;
  final ValueChanged<String>? onSplitSelected;
  final VoidCallback? onChooseFromResultsList;
  final bool openRegression;
  final String? initialRegressionTargetKey;

  @override
  State<_DistributionLoadDialog> createState() =>
      _DistributionLoadDialogState();
}

class _DistributionLoadDialogState extends State<_DistributionLoadDialog> {
  late final Future<ResultDistributionData?> _data = widget.loadData();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResultDistributionData?>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return AlertDialog(
            title: const Text('Resultatanalyse'),
            content: SizedBox(
              width: 320,
              height: 110,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(widget.loadingLabel),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return AlertDialog(
            title: Text(widget.errorTitle),
            content: Text('${snapshot.error}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Lukk'),
              ),
            ],
          );
        }

        final data = snapshot.data;
        if (data == null || !data.hasEnoughData) {
          return AlertDialog(
            title: const Text('Resultatanalyse'),
            content: const Text('For lite data til graf'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Lukk'),
              ),
            ],
          );
        }

        return _DistributionDialog(
          data: data,
          onSplitSelected: widget.onSplitSelected,
          onChooseFromResultsList: widget.onChooseFromResultsList,
          openRegression: widget.openRegression,
          initialRegressionTargetKey: widget.initialRegressionTargetKey,
        );
      },
    );
  }
}

class _DistributionDialog extends StatefulWidget {
  const _DistributionDialog({
    required this.data,
    this.onSplitSelected,
    this.onChooseFromResultsList,
    this.openRegression = false,
    this.initialRegressionTargetKey,
  });

  final ResultDistributionData data;
  final ValueChanged<String>? onSplitSelected;
  final VoidCallback? onChooseFromResultsList;
  final bool openRegression;
  final String? initialRegressionTargetKey;

  @override
  State<_DistributionDialog> createState() => _DistributionDialogState();
}

class _DistributionDialogState extends State<_DistributionDialog> {
  var bucketCount = 10;
  double firstPercentile = 10;
  double secondPercentile = 50;
  bool showPercentileSystem = false;
  bool showPlacements = false;
  _DistributionView view = _DistributionView.histogram;
  String? regressionTargetKey;
  _DraggedMarker? draggedMarker;

  @override
  void initState() {
    super.initState();
    if (widget.openRegression) view = _DistributionView.regression;
    regressionTargetKey = widget.initialRegressionTargetKey;
  }

  Future<void> _chooseRegressionTarget() async {
    final targets = widget.data.regressionTargets;
    final l10n = AppLocalizations.of(context);
    var selected = regressionTargetKey ?? targets.first.key;
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, updateSelection) => AlertDialog(
          title: Text(l10n.regressionChooseTarget),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final target in targets)
                    ListTile(
                      key: ValueKey('regression-target-${target.key}'),
                      title: Text(target.label),
                      selected: selected == target.key,
                      trailing: selected == target.key
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => updateSelection(() => selected = target.key),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.regressionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: Text(l10n.regressionApply),
            ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      setState(() => regressionTargetKey = chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canShowDistribution = widget.data.hasDistribution;
    final canShowRegression = widget.data.hasRegression;
    final regressionTargets = widget.data.regressionTargets;
    final selectedRegressionTarget = regressionTargets
        .where((target) => target.key == regressionTargetKey)
        .firstOrNull;
    final regression =
        selectedRegressionTarget?.regression ?? widget.data.regression;
    final canShowSplitAnalysis = widget.data.hasSplitAnalysis;
    final availableViews = <_DistributionView>[
      if (canShowDistribution) _DistributionView.histogram,
      if (canShowRegression) _DistributionView.regression,
      if (canShowSplitAnalysis) _DistributionView.splits,
    ];
    final activeView = availableViews.contains(view)
        ? view
        : availableViews.first;
    final title = Text(
      switch (activeView) {
        _DistributionView.regression => regression?.title ?? widget.data.title,
        _DistributionView.splits => 'Analyse gjennom løpet',
        _DistributionView.histogram => widget.data.title,
      },
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final viewSelector = SegmentedButton<_DistributionView>(
      segments: [
        ButtonSegment<_DistributionView>(
          value: _DistributionView.histogram,
          enabled: canShowDistribution,
          icon: const Icon(Icons.bar_chart),
          label: const Text('Fordeling'),
        ),
        ButtonSegment<_DistributionView>(
          value: _DistributionView.regression,
          enabled: canShowRegression,
          icon: const Icon(Icons.show_chart),
          label: const Text('Regresjon'),
        ),
        ButtonSegment<_DistributionView>(
          value: _DistributionView.splits,
          enabled: canShowSplitAnalysis,
          icon: const Icon(Icons.multiline_chart),
          label: const Text('Splitter'),
        ),
      ],
      selected: {activeView},
      onSelectionChanged: (selection) {
        setState(() => view = selection.first);
      },
    );
    final compactHeader = MediaQuery.sizeOf(context).width < 760;

    return AlertDialog(
      title: compactHeader
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 10), viewSelector],
            )
          : Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                viewSelector,
              ],
            ),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: switch (activeView) {
            _DistributionView.regression => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (regressionTargets.length > 1 ||
                    widget.onChooseFromResultsList != null) ...[
                  OutlinedButton.icon(
                    key: const Key('regression-target-button'),
                    onPressed: widget.onChooseFromResultsList == null
                        ? _chooseRegressionTarget
                        : () {
                            Navigator.of(context).pop();
                            widget.onChooseFromResultsList!();
                          },
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(
                      AppLocalizations.of(context).regressionCompareWith(
                        selectedRegressionTarget?.label ??
                            (regressionTargets.isNotEmpty
                                ? regressionTargets.first.label
                                : regression!.xLabel),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _RegressionView(data: regression!),
              ],
            ),
            _DistributionView.splits => _SplitAnalysisView(
              data: widget.data.splitAnalysis!,
              onSplitSelected: widget.onSplitSelected,
            ),
            _DistributionView.histogram => _buildHistogramView(context),
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Lukk'),
        ),
      ],
    );
  }

  Widget _buildHistogramView(BuildContext context) {
    final palette = context.palette;
    final values = [...widget.data.values]..sort();
    if (values.length < 2) {
      return SizedBox(
        height: 340,
        child: Center(
          child: Text(
            'For lite data til fordeling',
            style: TextStyle(
              color: palette.mutedText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final maxBucketCount = math.max(2, math.min(40, values.length));
    final safeBucketCount = bucketCount.clamp(2, maxBucketCount).toInt();
    if (safeBucketCount != bucketCount) bucketCount = safeBucketCount;

    final buckets = _buildBuckets(values, safeBucketCount);
    final averageValue = _averageValue(values);
    final firstSelection = _PercentileSelection.fromValues(
      values,
      firstPercentile,
    );
    final secondSelection = _PercentileSelection.fromValues(
      values,
      secondPercentile,
    );
    final intervalWidth = _intervalWidth(values, safeBucketCount);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 400,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, 400);
              final chartRect = _HistogramLayout.chartRect(size);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  if (!showPercentileSystem) return;
                  setState(() {
                    draggedMarker = _nearestMarker(
                      details.localPosition.dx,
                      chartRect,
                      values,
                      firstSelection,
                      secondSelection,
                    );
                  });
                },
                onPanUpdate: (details) {
                  if (!showPercentileSystem) return;
                  final active = draggedMarker;
                  if (active == null) return;
                  final nextPercentile = _percentileFromDrag(
                    details.localPosition.dx,
                    chartRect,
                  );
                  setState(() {
                    switch (active) {
                      case _DraggedMarker.first:
                        firstPercentile = math.min(
                          nextPercentile,
                          secondPercentile,
                        );
                      case _DraggedMarker.second:
                        secondPercentile = math.max(
                          nextPercentile,
                          firstPercentile,
                        );
                    }
                  });
                },
                onPanEnd: (_) => setState(() => draggedMarker = null),
                onPanCancel: () => setState(() => draggedMarker = null),
                child: CustomPaint(
                  painter: _HistogramPainter(
                    buckets: buckets,
                    averageValue: averageValue,
                    currentAthleteValue: widget.data.currentAthleteValue,
                    currentAthleteLabel: widget.data.currentAthleteLabel,
                    palette: palette,
                    formatValue: widget.data.formatValue,
                    firstSelection: firstSelection,
                    secondSelection: secondSelection,
                    showPercentileSystem: showPercentileSystem,
                    showPlacements: showPlacements,
                    totalCount: values.length,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Tooltip(
              message: showPlacements ? 'Vis prosent' : 'Vis plassering',
              child: IconButton.outlined(
                onPressed: showPercentileSystem
                    ? () {
                        setState(() => showPlacements = !showPlacements);
                      }
                    : null,
                icon: Icon(
                  showPlacements ? Icons.percent : Icons.format_list_numbered,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: showPercentileSystem
                  ? 'Skjul sammenligning'
                  : 'Vis sammenligning',
              child: IconButton.outlined(
                onPressed: () {
                  setState(() => showPercentileSystem = !showPercentileSystem);
                },
                icon: Icon(
                  showPercentileSystem
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 190,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Intervallbredde',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.data.formatValue(intervalWidth),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Slider(
                min: 2,
                max: maxBucketCount.toDouble(),
                divisions: math.max(1, maxBucketCount - 2),
                value: safeBucketCount.toDouble(),
                label: '$safeBucketCount',
                onChanged: (value) {
                  setState(() => bucketCount = value.round());
                },
              ),
            ),
            SizedBox(
              width: 42,
              child: Text(
                '$safeBucketCount',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _DistributionView { histogram, regression, splits }

enum _DraggedMarker { first, second }

class _SplitAnalysisView extends StatefulWidget {
  const _SplitAnalysisView({required this.data, this.onSplitSelected});

  final ResultSplitAnalysisData data;
  final ValueChanged<String>? onSplitSelected;

  @override
  State<_SplitAnalysisView> createState() => _SplitAnalysisViewState();
}

class _SplitAnalysisViewState extends State<_SplitAnalysisView> {
  int? hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Hver splitt vurderes for seg. Linjene viser hvor godt splittiden og '
          'splitplasseringen samsvarer med sluttresultatet.',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            _ChartLegend(color: palette.primary, label: 'Splittid ↔ sluttid'),
            _ChartLegend(
              color: palette.secondary,
              label: 'Splitplassering ↔ sluttplassering',
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 400,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, 400);
              final chart = _splitChartRect(size);
              final points = widget.data.points;
              final activeIndex = hoveredIndex;
              final activePoint = activeIndex == null
                  ? null
                  : points[activeIndex];
              final activeOffset = activeIndex == null
                  ? null
                  : Offset(
                      _splitPointX(activeIndex, points.length, chart),
                      _splitPointY(activePoint!.timeCorrelation, chart),
                    );

              int nearestIndex(Offset position) {
                if (points.length == 1) return 0;
                final ratio = ((position.dx - chart.left) / chart.width).clamp(
                  0.0,
                  1.0,
                );
                return (ratio * (points.length - 1)).round();
              }

              void openSplit(int index) {
                final callback = widget.onSplitSelected;
                if (callback == null) return;
                Navigator.of(context).pop();
                callback(points[index].splitId);
              }

              return MouseRegion(
                cursor: widget.onSplitSelected == null
                    ? MouseCursor.defer
                    : SystemMouseCursors.click,
                onHover: (event) {
                  final next = nearestIndex(event.localPosition);
                  if (next != hoveredIndex) {
                    setState(() => hoveredIndex = next);
                  }
                },
                onExit: (_) => setState(() => hoveredIndex = null),
                child: GestureDetector(
                  key: const Key('split-analysis-chart'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      openSplit(nearestIndex(details.localPosition)),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.panelAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: palette.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CustomPaint(
                              painter: _SplitAnalysisPainter(
                                points: points,
                                palette: palette,
                                hoveredIndex: activeIndex,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (activePoint != null && activeOffset != null)
                        Positioned(
                          left: (activeOffset.dx - 92).clamp(
                            4.0,
                            math.max(4.0, size.width - 188),
                          ),
                          top: (activeOffset.dy - 94).clamp(4.0, 286.0),
                          child: IgnorePointer(
                            child: _SplitPointTooltip(point: activePoint),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.onSplitSelected == null
              ? 'Hold over et punkt for detaljer.'
              : 'Hold over for detaljer. Klikk på et punkt for å åpne splitten.',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _SplitPointTooltip extends StatelessWidget {
  const _SplitPointTooltip({required this.point});

  final ResultSplitAnalysisPoint point;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 184,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            point.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text('Splittid mot sluttid ${_percent(point.timeCorrelation)}'),
          Text(
            'Splitplassering mot sluttplassering '
            '${_percent(point.rankCorrelation)}',
          ),
          Text('${point.sampleSize} resultater'),
        ],
      ),
    );
  }
}

class _SplitAnalysisPainter extends CustomPainter {
  const _SplitAnalysisPainter({
    required this.points,
    required this.palette,
    required this.hoveredIndex,
  });

  final List<ResultSplitAnalysisPoint> points;
  final AppPalette palette;
  final int? hoveredIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = _splitChartRect(size);
    final gridPaint = Paint()
      ..color = palette.border
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: palette.mutedText, fontSize: 10);

    for (var step = 0; step <= 4; step++) {
      final value = step * 25;
      final y = _splitPointY(value / 100, chart);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _paintChartText(canvas, '$value%', Offset(5, y - 6), labelStyle);
    }

    void drawSeries(
      Color color,
      double Function(ResultSplitAnalysisPoint) read,
    ) {
      final path = Path();
      for (var index = 0; index < points.length; index++) {
        final offset = Offset(
          _splitPointX(index, points.length, chart),
          _splitPointY(read(points[index]), chart),
        );
        if (index == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
      for (var index = 0; index < points.length; index++) {
        final offset = Offset(
          _splitPointX(index, points.length, chart),
          _splitPointY(read(points[index]), chart),
        );
        canvas.drawCircle(
          offset,
          hoveredIndex == index ? 5 : 3.5,
          Paint()..color = color,
        );
      }
    }

    drawSeries(palette.primary, (point) => point.timeCorrelation);
    drawSeries(palette.secondary, (point) => point.rankCorrelation);

    final labelStep = math.max(1, (points.length / 7).ceil());
    for (var index = 0; index < points.length; index++) {
      if (index % labelStep != 0 && index != points.length - 1) continue;
      final label = points[index].label;
      final shortLabel = label.length > 11
          ? '${label.substring(0, 10)}…'
          : label;
      final painter = TextPainter(
        text: TextSpan(text: shortLabel, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 86);
      final x = _splitPointX(index, points.length, chart);
      painter.paint(
        canvas,
        Offset(
          (x - painter.width / 2).clamp(0.0, size.width - painter.width),
          chart.bottom + 9,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplitAnalysisPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.palette != palette ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}

Rect _splitChartRect(Size size) => Rect.fromLTWH(
  42,
  18,
  math.max(1, size.width - 58),
  math.max(1, size.height - 70),
);

double _splitPointX(int index, int length, Rect chart) {
  if (length <= 1) return chart.center.dx;
  return chart.left + chart.width * index / (length - 1);
}

double _splitPointY(double value, Rect chart) {
  final normalized = value.clamp(0.0, 1.0);
  return chart.bottom - chart.height * normalized;
}

String _percent(double value) => '${(value * 100).round()}%';

void _paintChartText(
  Canvas canvas,
  String text,
  Offset offset,
  TextStyle style,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, offset);
}

class _RegressionView extends StatelessWidget {
  const _RegressionView({required this.data});

  final ResultRegressionData data;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final analysis = _linearRegression(data.points);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 400,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: _RegressionPainter(
                  data: data,
                  analysis: analysis,
                  palette: palette,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _RegressionSummary(data: data, analysis: analysis),
      ],
    );
  }
}

class _RegressionSummary extends StatelessWidget {
  const _RegressionSummary({required this.data, required this.analysis});

  final ResultRegressionData data;
  final _RegressionAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final analysis = this.analysis;
    if (analysis == null) {
      return _RegressionSummaryBox(
        child: Text(
          'Kan ikke beregne regresjon fordi punktene mangler variasjon.',
          style: TextStyle(
            color: palette.mutedText,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final correlationPercent = (analysis.correlation.abs() * 100).round();
    final explainedPercent = (analysis.rSquared * 100).round();
    return _RegressionSummaryBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _RegressionMetric(
                  label: 'Korrelasjon',
                  value: '$correlationPercent%',
                  tooltip:
                      'Viser hvor tett punktene følger en rett linje. Høy prosent betyr sterkere sammenheng.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RegressionMetric(
                  label: 'Forklart variasjon',
                  value: '$explainedPercent%',
                  tooltip:
                      'Viser hvor mye av variasjonen i ${data.yLabel.toLowerCase()} som kan forklares av ${data.xLabel.toLowerCase()}.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RegressionMetric(
                  label: 'Punkter',
                  value: '${data.points.length}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegressionSummaryBox extends StatelessWidget {
  const _RegressionSummaryBox({required this.child});

  final Widget child;

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
      child: child,
    );
  }
}

class _RegressionMetric extends StatelessWidget {
  const _RegressionMetric({
    required this.label,
    required this.value,
    this.tooltip,
  });

  final String label;
  final String value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final labelTextStyle = TextStyle(
      color: palette.mutedText,
      fontSize: 11,
      fontWeight: FontWeight.w800,
    );
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: labelTextStyle,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        tooltip == null
            ? labelText
            : Tooltip(
                message: tooltip!,
                waitDuration: const Duration(milliseconds: 250),
                child: MouseRegion(
                  cursor: SystemMouseCursors.help,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(child: labelText),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.help_outline,
                        size: 14,
                        color: palette.mutedText,
                      ),
                    ],
                  ),
                ),
              ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _RegressionPainter extends CustomPainter {
  const _RegressionPainter({
    required this.data,
    required this.analysis,
    required this.palette,
  });

  final ResultRegressionData data;
  final _RegressionAnalysis? analysis;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = _RegressionLayout.chartRect(size);
    if (chart.width <= 0 || chart.height <= 0 || data.points.isEmpty) return;

    final xRange = _axisRange(data.points.map((point) => point.x));
    final yRange = _axisRange(data.points.map((point) => point.y));
    final axisPaint = Paint()
      ..color = palette.border
      ..strokeWidth = 1.3;
    final gridPaint = Paint()
      ..color = palette.border.withValues(alpha: 0.42)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = palette.secondary
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );

    _paintGrid(
      canvas,
      chart,
      xRange,
      yRange,
      gridPaint,
      axisPaint,
      textPainter,
    );
    _paintRegressionLine(canvas, chart, xRange, yRange, linePaint);
    _paintPoints(canvas, chart, xRange, yRange);
    _paintAxisLabels(canvas, size, chart, textPainter);
  }

  void _paintGrid(
    Canvas canvas,
    Rect chart,
    _AxisRange xRange,
    _AxisRange yRange,
    Paint gridPaint,
    Paint axisPaint,
    TextPainter textPainter,
  ) {
    for (var i = 0; i <= 4; i++) {
      final xValue = xRange.valueAt(i / 4);
      final x = _xForValue(xValue, xRange, chart);
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), gridPaint);
      _paintText(
        textPainter,
        canvas,
        data.formatX(xValue.round()),
        Offset(x, chart.bottom + 8),
        center: true,
        color: palette.mutedText,
        fontSize: 10,
        maxWidth: 82,
      );

      final yValue = yRange.valueAt(i / 4);
      final y = _yForValue(yValue, yRange, chart);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _paintText(
        textPainter,
        canvas,
        data.formatY(yValue.round()),
        Offset(chart.left - 8, y - 7),
        alignRight: true,
        color: palette.mutedText,
        fontSize: 10,
        maxWidth: 74,
      );
    }

    canvas.drawLine(chart.bottomLeft, chart.bottomRight, axisPaint);
    canvas.drawLine(chart.bottomLeft, chart.topLeft, axisPaint);
  }

  void _paintRegressionLine(
    Canvas canvas,
    Rect chart,
    _AxisRange xRange,
    _AxisRange yRange,
    Paint paint,
  ) {
    final analysis = this.analysis;
    if (analysis == null) return;
    final left = Offset(
      chart.left,
      _yForValue(analysis.predict(xRange.min), yRange, chart),
    );
    final right = Offset(
      chart.right,
      _yForValue(analysis.predict(xRange.max), yRange, chart),
    );
    canvas.save();
    canvas.clipRect(chart.inflate(1));
    canvas.drawLine(left, right, paint);
    canvas.restore();
  }

  void _paintPoints(
    Canvas canvas,
    Rect chart,
    _AxisRange xRange,
    _AxisRange yRange,
  ) {
    final usePointColors = data.points.any((point) => point.color != null);
    final radius = data.points.length > 80 ? 2.8 : 3.8;
    final orderedPoints = [
      ...data.points.where((point) => !point.isCurrentAthlete),
      ...data.points.where((point) => point.isCurrentAthlete),
    ];
    for (final point in orderedPoints) {
      final color = point.isCurrentAthlete
          ? palette.danger
          : usePointColors
          ? point.color ?? palette.primary
          : palette.primary;
      final pointRadius = point.isCurrentAthlete ? radius + 1.8 : radius;
      final center = Offset(
        _xForValue(point.x, xRange, chart),
        _yForValue(point.y, yRange, chart),
      );
      canvas.drawCircle(
        center,
        pointRadius,
        Paint()..color = color.withValues(alpha: 0.84),
      );
      canvas.drawCircle(
        center,
        pointRadius,
        Paint()
          ..color = palette.panelAlt
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
    }
  }

  void _paintAxisLabels(
    Canvas canvas,
    Size size,
    Rect chart,
    TextPainter textPainter,
  ) {
    _paintText(
      textPainter,
      canvas,
      data.xLabel,
      Offset(chart.center.dx, size.height - 24),
      center: true,
      color: palette.mutedText,
      bold: true,
      fontSize: 12,
      maxWidth: 180,
    );
    _paintText(
      textPainter,
      canvas,
      'Y: ${data.yLabel}',
      Offset(chart.left, 16),
      color: palette.mutedText,
      bold: true,
      fontSize: 12,
      maxWidth: 180,
    );
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
  bool shouldRepaint(covariant _RegressionPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.analysis != analysis ||
        oldDelegate.palette != palette;
  }
}

class _RegressionLayout {
  static const left = 76.0;
  static const top = 42.0;
  static const right = 22.0;
  static const bottom = 66.0;

  static Rect chartRect(Size size) {
    return Rect.fromLTWH(
      left,
      top,
      math.max(0, size.width - left - right),
      math.max(0, size.height - top - bottom),
    );
  }
}

class _AxisRange {
  const _AxisRange({required this.min, required this.max});

  final double min;
  final double max;

  double get span => math.max(1, max - min);

  double valueAt(double ratio) => min + span * ratio;
}

class _RegressionAnalysis {
  const _RegressionAnalysis({
    required this.slope,
    required this.intercept,
    required this.correlation,
  });

  final double slope;
  final double intercept;
  final double correlation;

  double get rSquared => correlation * correlation;

  double predict(double x) => slope * x + intercept;
}

_RegressionAnalysis? _linearRegression(List<ResultRegressionPoint> points) {
  if (points.length < 2) return null;
  var sumX = 0.0;
  var sumY = 0.0;
  var sumXX = 0.0;
  var sumYY = 0.0;
  var sumXY = 0.0;

  for (final point in points) {
    final x = point.x.toDouble();
    final y = point.y.toDouble();
    sumX += x;
    sumY += y;
    sumXX += x * x;
    sumYY += y * y;
    sumXY += x * y;
  }

  final n = points.length.toDouble();
  final xVariance = n * sumXX - sumX * sumX;
  final yVariance = n * sumYY - sumY * sumY;
  if (xVariance <= 0 || yVariance <= 0) return null;

  final covariance = n * sumXY - sumX * sumY;
  final slope = covariance / xVariance;
  final intercept = (sumY - slope * sumX) / n;
  final correlation = covariance / math.sqrt(xVariance * yVariance);
  if (correlation.isNaN || correlation.isInfinite) return null;
  return _RegressionAnalysis(
    slope: slope,
    intercept: intercept,
    correlation: correlation.clamp(-1.0, 1.0).toDouble(),
  );
}

_AxisRange _axisRange(Iterable<int> values) {
  final sorted = values.toList()..sort();
  final minValue = sorted.first;
  final maxValue = sorted.last;
  final span = maxValue - minValue;
  final pad = span == 0
      ? math.max(1, (maxValue.abs() * 0.05).round())
      : math.max(1, (span * 0.08).round());
  return _AxisRange(
    min: math.max(0, minValue - pad).toDouble(),
    max: (maxValue + pad).toDouble(),
  );
}

double _xForValue(num value, _AxisRange range, Rect chart) {
  final ratio = ((value - range.min) / range.span).clamp(0.0, 1.0);
  return chart.left + chart.width * ratio;
}

double _yForValue(num value, _AxisRange range, Rect chart) {
  final ratio = ((value - range.min) / range.span).clamp(0.0, 1.0);
  return chart.bottom - chart.height * ratio;
}

class _HistogramBucket {
  const _HistogramBucket({
    required this.start,
    required this.end,
    required this.count,
  });

  final int start;
  final int end;
  final int count;
}

class _PercentileSelection {
  const _PercentileSelection({required this.percentile, required this.value});

  factory _PercentileSelection.fromValues(
    List<int> sortedValues,
    double percentile,
  ) {
    final clamped = percentile.clamp(1, 100).toDouble();
    final index = math.max(
      0,
      math.min(
        sortedValues.length - 1,
        ((sortedValues.length * clamped) / 100).ceil() - 1,
      ),
    );
    return _PercentileSelection(
      percentile: clamped,
      value: sortedValues[index],
    );
  }

  final double percentile;
  final int value;

  String get title => 'Topp ${percentile.round()}%';

  String placementTitle(int totalCount) {
    final placement = math.max(1, (totalCount * percentile / 100).ceil());
    return 'Plass $placement';
  }
}

class _HistogramLayout {
  static const left = 52.0;
  static const top = 104.0;
  static const right = 16.0;
  static const bottom = 72.0;

  static Rect chartRect(Size size) {
    return Rect.fromLTWH(
      left,
      top,
      math.max(0, size.width - left - right),
      math.max(0, size.height - top - bottom),
    );
  }
}

List<_HistogramBucket> _buildBuckets(List<int> values, int bucketCount) {
  if (values.isEmpty) return const [];
  final minValue = values.first;
  final maxValue = values.last;
  if (minValue == maxValue) {
    return [
      _HistogramBucket(start: minValue, end: maxValue, count: values.length),
    ];
  }

  final width = (maxValue - minValue) / bucketCount;
  final counts = List.filled(bucketCount, 0);
  for (final value in values) {
    final rawIndex = ((value - minValue) / width).floor();
    final index = rawIndex.clamp(0, bucketCount - 1).toInt();
    counts[index]++;
  }

  return [
    for (var index = 0; index < bucketCount; index++)
      _HistogramBucket(
        start: minValue + (width * index).round(),
        end: index == bucketCount - 1
            ? maxValue
            : minValue + (width * (index + 1)).round(),
        count: counts[index],
      ),
  ];
}

int _intervalWidth(List<int> values, int bucketCount) {
  if (values.length < 2) return 0;
  final minValue = values.first;
  final maxValue = values.last;
  if (minValue == maxValue) return 0;
  return math.max(1, ((maxValue - minValue) / bucketCount).round());
}

double _averageValue(List<int> values) {
  if (values.isEmpty) return 0;
  return values.reduce((sum, value) => sum + value) / values.length;
}

_DraggedMarker _nearestMarker(
  double dx,
  Rect chartRect,
  List<int> values,
  _PercentileSelection firstSelection,
  _PercentileSelection secondSelection,
) {
  final firstX = _valueToX(firstSelection.value, values, chartRect);
  final secondX = _valueToX(secondSelection.value, values, chartRect);
  return (dx - firstX).abs() <= (dx - secondX).abs()
      ? _DraggedMarker.first
      : _DraggedMarker.second;
}

double _percentileFromDrag(double dx, Rect chartRect) {
  if (chartRect.width <= 0) return 1;
  final ratio = ((dx - chartRect.left) / chartRect.width).clamp(0.0, 1.0);
  return math.max(1, ratio * 100);
}

double _valueToX(num value, List<int> values, Rect chartRect) {
  final minValue = values.first;
  final maxValue = values.last;
  if (minValue == maxValue) return chartRect.left + chartRect.width / 2;
  final ratio = (value - minValue) / (maxValue - minValue);
  return chartRect.left + chartRect.width * ratio;
}

class _HistogramPainter extends CustomPainter {
  const _HistogramPainter({
    required this.buckets,
    required this.averageValue,
    required this.currentAthleteValue,
    required this.currentAthleteLabel,
    required this.palette,
    required this.formatValue,
    required this.firstSelection,
    required this.secondSelection,
    required this.showPercentileSystem,
    required this.showPlacements,
    required this.totalCount,
  });

  final List<_HistogramBucket> buckets;
  final double averageValue;
  final int? currentAthleteValue;
  final String currentAthleteLabel;
  final AppPalette palette;
  final String Function(int value) formatValue;
  final _PercentileSelection firstSelection;
  final _PercentileSelection secondSelection;
  final bool showPercentileSystem;
  final bool showPlacements;
  final int totalCount;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = _HistogramLayout.chartRect(size);
    if (chart.width <= 0 || chart.height <= 0 || buckets.isEmpty) return;

    final axisPaint = Paint()
      ..color = palette.border
      ..strokeWidth = 1.4;
    final barPaint = Paint()..color = palette.primary;
    final peakPaint = Paint()..color = palette.primary;
    final averageColor = _averageLineColor(palette);
    final averagePaint = Paint()
      ..color = averageColor
      ..strokeWidth = 2.4;
    final currentAthletePaint = Paint()
      ..color = palette.danger
      ..strokeWidth = 3.0;
    final linePaint = Paint()
      ..color = palette.primary
      ..strokeWidth = 2.2;
    final arrowPaint = Paint()
      ..color = palette.primary
      ..strokeWidth = 2.0;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );

    canvas.drawLine(chart.bottomLeft, chart.bottomRight, axisPaint);
    canvas.drawLine(chart.bottomLeft, chart.topLeft, axisPaint);

    final maxCount = buckets.map((bucket) => bucket.count).reduce(math.max);
    final peakBucket = buckets.reduce(
      (best, current) => current.count > best.count ? current : best,
    );
    final peakIndex = buckets.indexOf(peakBucket);
    final barGap = buckets.length > 18 ? 3.0 : 6.0;
    final barWidth = math.max(2.0, (chart.width / buckets.length) - barGap);

    for (var i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      final height = maxCount == 0
          ? 0.0
          : chart.height * bucket.count / maxCount;
      final x = chart.left + i * (chart.width / buckets.length) + barGap / 2;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chart.bottom - height, barWidth, height),
        const Radius.circular(4),
      );
      canvas.drawRRect(barRect, i == peakIndex ? peakPaint : barPaint);
      if (i == peakIndex) {
        canvas.drawRRect(
          barRect,
          Paint()
            ..color = palette.panel
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }

      _paintText(
        textPainter,
        canvas,
        '${bucket.count}',
        Offset(x + barWidth / 2, chart.bottom - height - 18),
        palette,
        center: true,
        fontSize: 11,
        bold: true,
      );

      if (buckets.length <= 14 || i == 0 || i == buckets.length - 1) {
        final label = i == buckets.length - 1
            ? formatValue(bucket.end)
            : formatValue(bucket.start);
        _paintText(
          textPainter,
          canvas,
          label,
          Offset(x + barWidth / 2, chart.bottom + 8),
          palette,
          center: true,
          fontSize: 10,
        );
      }
    }

    final peakCenterX =
        chart.left +
        peakIndex * (chart.width / buckets.length) +
        barGap / 2 +
        barWidth / 2;
    _paintBadge(
      textPainter,
      canvas,
      '',
      '${formatValue(peakBucket.start)}-${formatValue(peakBucket.end)}',
      peakCenterX,
      chart.bottom + 30,
      palette,
      fill: palette.primary.withValues(alpha: 0.2),
      stroke: palette.primary,
      titleFontSize: 12,
      valueFontSize: 13,
    );

    final chartValues = [
      for (final bucket in buckets) bucket.start,
      buckets.last.end,
    ];
    final averageX = _valueToX(averageValue, chartValues, chart);
    final averageValueText = formatValue(averageValue.round());
    final averageSize = _badgeSize(
      'Snitt',
      averageValueText,
      titleFontSize: 12,
      valueFontSize: 13,
    );
    var averageBadgeCenter = _badgeCenterWithin(
      size.width,
      averageX,
      averageSize.width,
    );
    final currentValue = currentAthleteValue;
    final currentX = currentValue == null
        ? null
        : _valueToX(currentValue, chartValues, chart);
    final currentValueText = currentValue == null
        ? null
        : formatValue(currentValue);
    final currentSize = currentValueText == null
        ? null
        : _badgeSize(
            currentAthleteLabel,
            currentValueText,
            titleFontSize: 12,
            valueFontSize: 13,
          );
    var currentBadgeCenter = currentX == null || currentSize == null
        ? null
        : _badgeCenterWithin(size.width, currentX, currentSize.width);
    if (currentX != null && currentSize != null) {
      if (averageX <= currentX) {
        final centers = _badgeCenters(
          firstX: averageX,
          secondX: currentX,
          firstWidth: averageSize.width,
          secondWidth: currentSize.width,
          minX: 0,
          maxX: size.width,
        );
        averageBadgeCenter = centers.first;
        currentBadgeCenter = centers.second;
      } else {
        final centers = _badgeCenters(
          firstX: currentX,
          secondX: averageX,
          firstWidth: currentSize.width,
          secondWidth: averageSize.width,
          minX: 0,
          maxX: size.width,
        );
        currentBadgeCenter = centers.first;
        averageBadgeCenter = centers.second;
      }
    }
    _drawDottedLine(
      canvas,
      Offset(averageX, chart.top),
      Offset(averageX, chart.bottom),
      averagePaint,
    );
    if (currentX != null &&
        currentValueText != null &&
        currentBadgeCenter != null) {
      canvas.drawLine(
        Offset(currentX, chart.top),
        Offset(currentX, chart.bottom),
        currentAthletePaint,
      );
      _paintBadge(
        textPainter,
        canvas,
        currentAthleteLabel,
        currentValueText,
        currentBadgeCenter,
        showPercentileSystem ? 54 : 10,
        palette,
        fill: palette.danger.withValues(alpha: 0.16),
        stroke: palette.danger,
        titleFontSize: 12,
        valueFontSize: 13,
      );
    }
    _paintBadge(
      textPainter,
      canvas,
      'Snitt',
      averageValueText,
      averageBadgeCenter,
      showPercentileSystem ? 54 : 10,
      palette,
      fill: averageColor.withValues(alpha: 0.16),
      stroke: averageColor,
      titleFontSize: 12,
      valueFontSize: 13,
    );

    final firstX = _valueToX(firstSelection.value, chartValues, chart);
    final secondX = _valueToX(secondSelection.value, chartValues, chart);
    if (showPercentileSystem) {
      final firstTitle = showPlacements
          ? firstSelection.placementTitle(totalCount)
          : firstSelection.title;
      final secondTitle = showPlacements
          ? secondSelection.placementTitle(totalCount)
          : secondSelection.title;
      final firstValue = formatValue(firstSelection.value);
      final secondValue = formatValue(secondSelection.value);
      final firstSize = _badgeSize(
        firstTitle,
        firstValue,
        titleFontSize: 12,
        valueFontSize: 13,
      );
      final secondSize = _badgeSize(
        secondTitle,
        secondValue,
        titleFontSize: 12,
        valueFontSize: 13,
      );
      final badgeCenters = _badgeCenters(
        firstX: firstX,
        secondX: secondX,
        firstWidth: firstSize.width,
        secondWidth: secondSize.width,
        minX: 0,
        maxX: size.width,
      );

      _drawDottedLine(
        canvas,
        Offset(firstX, chart.top),
        Offset(firstX, chart.bottom),
        linePaint,
      );
      _drawDottedLine(
        canvas,
        Offset(secondX, chart.top),
        Offset(secondX, chart.bottom),
        linePaint,
      );

      _paintBadge(
        textPainter,
        canvas,
        firstTitle,
        firstValue,
        badgeCenters.first,
        10,
        palette,
        fill: palette.panelAlt,
        stroke: palette.primary,
        titleFontSize: 12,
        valueFontSize: 13,
      );
      _paintBadge(
        textPainter,
        canvas,
        secondTitle,
        secondValue,
        badgeCenters.second,
        10,
        palette,
        fill: palette.panelAlt,
        stroke: palette.primary,
        titleFontSize: 12,
        valueFontSize: 13,
      );

      final arrowY = chart.top + 20;
      final leftX = math.min(firstX, secondX);
      final rightX = math.max(firstX, secondX);
      if ((rightX - leftX).abs() > 8) {
        canvas.drawLine(
          Offset(leftX, arrowY),
          Offset(rightX, arrowY),
          arrowPaint,
        );
        _drawArrowHead(canvas, Offset(leftX, arrowY), 1, arrowPaint);
        _drawArrowHead(canvas, Offset(rightX, arrowY), -1, arrowPaint);
      }
      _paintBadge(
        textPainter,
        canvas,
        '',
        formatValue((secondSelection.value - firstSelection.value).abs()),
        (leftX + rightX) / 2,
        arrowY - 18,
        palette,
        fill: palette.panel,
        stroke: palette.primary,
        titleFontSize: 12,
        valueFontSize: 13,
      );
    }

    _paintText(
      textPainter,
      canvas,
      '$maxCount',
      Offset(chart.left - 8, chart.top - 2),
      palette,
      alignRight: true,
      fontSize: 10,
    );
    _paintText(
      textPainter,
      canvas,
      '0',
      Offset(chart.left - 8, chart.bottom - 12),
      palette,
      alignRight: true,
      fontSize: 10,
    );
  }

  void _paintBadge(
    TextPainter textPainter,
    Canvas canvas,
    String title,
    String value,
    double centerX,
    double y,
    AppPalette palette, {
    required Color fill,
    required Color stroke,
    double titleFontSize = 12,
    double valueFontSize = 13,
  }) {
    final hasTitle = title.trim().isNotEmpty;
    textPainter.text = TextSpan(
      text: title,
      style: TextStyle(
        color: palette.mutedText,
        fontSize: titleFontSize,
        fontWeight: FontWeight.w800,
      ),
    );
    textPainter.layout(maxWidth: 220);
    final titleWidth = hasTitle ? textPainter.width : 0.0;
    final titleHeight = hasTitle ? textPainter.height : 0.0;

    final valuePainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: palette.mutedText,
          fontSize: valueFontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
    )..layout(maxWidth: 220);

    final width = math.max(titleWidth, valuePainter.width) + 16;
    final height = titleHeight + valuePainter.height + (hasTitle ? 10 : 6);
    final left = centerX - width / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, y, width, height),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = fill);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke,
    );
    if (hasTitle) {
      textPainter.paint(canvas, Offset(left + (width - titleWidth) / 2, y + 3));
    }
    valuePainter.paint(
      canvas,
      Offset(
        left + (width - valuePainter.width) / 2,
        y + (hasTitle ? titleHeight + 4 : 3),
      ),
    );
  }

  void _drawDottedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 4.0;
    const gap = 4.0;
    for (double y = start.dy; y < end.dy; y += dash + gap) {
      canvas.drawLine(
        Offset(start.dx, y),
        Offset(end.dx, math.min(y + dash, end.dy)),
        paint,
      );
    }
  }

  void _drawArrowHead(Canvas canvas, Offset point, int direction, Paint paint) {
    const size = 6.0;
    canvas.drawLine(
      Offset(point.dx + direction * size, point.dy - size / 2),
      point,
      paint,
    );
    canvas.drawLine(
      Offset(point.dx + direction * size, point.dy + size / 2),
      point,
      paint,
    );
  }

  void _paintText(
    TextPainter textPainter,
    Canvas canvas,
    String text,
    Offset offset,
    AppPalette palette, {
    bool center = false,
    bool alignRight = false,
    double fontSize = 13,
    bool bold = false,
  }) {
    textPainter.text = TextSpan(
      text: text.isEmpty ? '-' : text,
      style: TextStyle(
        color: palette.mutedText,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
      ),
    );
    textPainter.layout(maxWidth: 76);
    var dx = offset.dx;
    if (center) dx -= textPainter.width / 2;
    if (alignRight) dx -= textPainter.width;
    textPainter.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _HistogramPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.averageValue != averageValue ||
        oldDelegate.currentAthleteValue != currentAthleteValue ||
        oldDelegate.currentAthleteLabel != currentAthleteLabel ||
        oldDelegate.palette != palette ||
        oldDelegate.firstSelection != firstSelection ||
        oldDelegate.secondSelection != secondSelection ||
        oldDelegate.showPercentileSystem != showPercentileSystem ||
        oldDelegate.showPlacements != showPlacements ||
        oldDelegate.totalCount != totalCount;
  }
}

Color _averageLineColor(AppPalette palette) {
  return palette.brightness == Brightness.dark
      ? const Color(0xFF8ED8FF)
      : const Color(0xFF006DAD);
}

double _badgeCenterWithin(double width, double centerX, double badgeWidth) {
  if (width <= badgeWidth) return width / 2;
  final halfWidth = badgeWidth / 2;
  return centerX.clamp(halfWidth, width - halfWidth).toDouble();
}

({double first, double second}) _badgeCenters({
  required double firstX,
  required double secondX,
  required double firstWidth,
  required double secondWidth,
  required double minX,
  required double maxX,
}) {
  const gap = 8.0;
  var first = firstX;
  var second = secondX;
  final requiredDistance = firstWidth / 2 + secondWidth / 2 + gap;
  final actualDistance = second - first;
  if (actualDistance < requiredDistance) {
    final shift = (requiredDistance - actualDistance) / 2;
    first -= shift;
    second += shift;
  }
  first = first.clamp(minX + firstWidth / 2, maxX - firstWidth / 2).toDouble();
  second = second
      .clamp(minX + secondWidth / 2, maxX - secondWidth / 2)
      .toDouble();
  return (first: first, second: second);
}

Size _badgeSize(
  String title,
  String value, {
  required double titleFontSize,
  required double valueFontSize,
}) {
  final titlePainter = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '...',
    text: TextSpan(
      text: title,
      style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.w800),
    ),
  )..layout(maxWidth: 220);
  final valuePainter = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '...',
    text: TextSpan(
      text: value,
      style: TextStyle(fontSize: valueFontSize, fontWeight: FontWeight.w900),
    ),
  )..layout(maxWidth: 220);
  final hasTitle = title.trim().isNotEmpty;
  return Size(
    math.max(hasTitle ? titlePainter.width : 0, valuePainter.width) + 16,
    (hasTitle ? titlePainter.height : 0) +
        valuePainter.height +
        (hasTitle ? 10 : 6),
  );
}
