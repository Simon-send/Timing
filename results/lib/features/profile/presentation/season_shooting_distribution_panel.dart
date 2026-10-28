import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/histogram_chart.dart';
import '../../../l10n/app_localizations.dart';
import '../../results/domain/shooting_selection.dart';
import '../domain/athlete_profile.dart';
import '../domain/season_shooting_distribution.dart';
import '../domain/season_shooting_statistics.dart';

/// No fetching or season filtering: the owner supplies the complete selected
/// scope's statistics, labels and result navigation.
class SeasonShootingDistributionPanel extends StatefulWidget {
  const SeasonShootingDistributionPanel({
    super.key,
    required this.statistics,
    required this.metric,
    required this.metricLabel,
    required this.raceLabel,
    this.onRaceSelected,
  });

  final SeasonShootingMetricStatistics statistics;
  final ShootingMetric metric;
  final String metricLabel;
  final String Function(AthleteRace) raceLabel;
  final ValueChanged<AthleteRace>? onRaceSelected;

  @override
  State<SeasonShootingDistributionPanel> createState() =>
      _SeasonShootingDistributionPanelState();
}

class _SeasonShootingDistributionPanelState
    extends State<SeasonShootingDistributionPanel> {
  bool _showTable = false;
  int _timeBinCount = 8;
  int? _selectedBin;

  @override
  void didUpdateWidget(covariant SeasonShootingDistributionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metric != widget.metric ||
        oldWidget.statistics != widget.statistics) {
      _selectedBin = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final number = NumberFormat('0.###', l10n.localeName);
    final percentage = NumberFormat('0.#', l10n.localeName);
    final isTime = widget.metric == ShootingMetric.rangeTime;
    String value(num input) => isTime
        ? l10n.seasonDistributionSeconds(number.format(input / 1000))
        : number.format(input);
    final distribution = SeasonShootingDistribution.fromStatistics(
      widget.statistics,
      widget.metric,
      scale: ShootingDistributionScale.forValues(
        widget.statistics.validObservations.map(
          (observation) => observation.value!,
        ),
        widget.metric,
        timeBinCount: _timeBinCount,
      ),
    );
    String binLabel(SeasonShootingBin bin) => isTime
        ? '${value(bin.start)} ≤ t ${bin.includesEnd ? '≤' : '<'} ${value(bin.end)}'
        : '${widget.metricLabel}: ${bin.start}';
    String share(SeasonShootingBin bin) =>
        '${percentage.format(bin.percentage)} %';
    String binSummary(SeasonShootingBin bin) =>
        '${binLabel(bin)} · ${bin.count} · ${share(bin)}';
    final selected = _selectedBin;
    void select(int index) => setState(() => _selectedBin = index);

    return Column(
      key: const Key('season-shooting-distribution'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.seasonDistributionTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.seasonDistributionSeriesCount(distribution.count),
          key: const Key('season-distribution-count'),
        ),
        if (distribution.count == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.seasonDistributionEmpty,
              key: const Key('season-distribution-empty'),
            ),
          )
        else ...[
          if (distribution.count < 5)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.seasonDistributionLowData,
                key: const Key('season-distribution-low-data'),
                style: TextStyle(
                  color: context.palette.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              Text(
                l10n.seasonDistributionMean(value(distribution.mean!)),
                key: const Key('season-distribution-mean'),
              ),
              Text(
                l10n.seasonDistributionMedian(value(distribution.median!)),
                key: const Key('season-distribution-median'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('season-distribution-table-toggle'),
            onPressed: () => setState(() => _showTable = !_showTable),
            icon: Icon(
              _showTable ? Icons.bar_chart : Icons.table_chart_outlined,
            ),
            label: Text(
              _showTable
                  ? l10n.seasonDistributionShowChart
                  : l10n.seasonDistributionShowTable,
            ),
          ),
          if (_showTable)
            Table(
              key: const Key('season-distribution-table'),
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(
                horizontalInside: BorderSide(color: context.palette.border),
              ),
              children: [
                TableRow(
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        widget.metricLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.seasonDistributionCount,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.seasonDistributionShare,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                for (var i = 0; i < distribution.bins.length; i++)
                  TableRow(
                    children: [
                      TextButton(
                        key: Key('season-distribution-bin-$i'),
                        onPressed: () => select(i),
                        child: Text(binLabel(distribution.bins[i])),
                      ),
                      Text('${distribution.bins[i].count}'),
                      Text(share(distribution.bins[i])),
                    ],
                  ),
              ],
            )
          else ...[
            Text(widget.metricLabel),
            SizedBox(
              height: 360,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, 360);
                  return Stack(
                    key: const Key('season-distribution-chart'),
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: HistogramBarsPainter(
                            buckets: [
                              for (final bin in distribution.bins)
                                HistogramBar(
                                  start: bin.start,
                                  end: bin.end,
                                  count: bin.count,
                                ),
                            ],
                            palette: context.palette,
                            formatValue: (input) =>
                                isTime ? number.format(input / 1000) : '$input',
                            barLabel: (i) =>
                                '${distribution.bins[i].count}\n${share(distribution.bins[i])}',
                            showCountAxisLabels: true,
                            mean: distribution.mean,
                            meanLabel: l10n.seasonDistributionMean(
                              value(distribution.mean!),
                            ),
                            discrete: !isTime,
                            selectedIndex: selected,
                          ),
                        ),
                      ),
                      for (var i = 0; i < distribution.bins.length; i++)
                        Positioned.fromRect(
                          rect: HistogramChartLayout.binRect(
                            size,
                            i,
                            distribution.bins.length,
                          ),
                          child: Semantics(
                            button: true,
                            selected: selected == i,
                            label: binSummary(distribution.bins[i]),
                            child: Tooltip(
                              message: binSummary(distribution.bins[i]),
                              excludeFromSemantics: true,
                              child: TextButton(
                                key: Key('season-distribution-bar-$i'),
                                onPressed: () => select(i),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            Text(l10n.seasonDistributionSelectBin),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < distribution.bins.length; i++)
                  OutlinedButton(
                    key: Key('season-distribution-bin-$i'),
                    onPressed: () => select(i),
                    child: Text(binSummary(distribution.bins[i])),
                  ),
              ],
            ),
          ],
          if (isTime) ...[
            const SizedBox(height: 8),
            Text(l10n.seasonDistributionIntervals(_timeBinCount)),
            Slider(
              key: const Key('season-distribution-intervals'),
              min: 2,
              max: 20,
              divisions: 18,
              value: _timeBinCount.toDouble(),
              label: '$_timeBinCount',
              semanticFormatterCallback: (count) =>
                  l10n.seasonDistributionIntervals(count.round()),
              onChanged: (count) => setState(() {
                _timeBinCount = count.round();
                _selectedBin = null;
              }),
            ),
          ],
          if (selected != null && selected < distribution.bins.length) ...[
            const SizedBox(height: 14),
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.seasonDistributionContributions,
                key: const Key('season-distribution-contributions'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(binSummary(distribution.bins[selected])),
            if (distribution.bins[selected].observations.isEmpty)
              Text(l10n.seasonDistributionNoContributions),
            for (final observation in distribution.bins[selected].observations)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: OutlinedButton(
                  key: ValueKey(
                    'season-distribution-contribution-${observation.race.key}/${observation.race.resultId}/${observation.index}',
                  ),
                  onPressed: widget.onRaceSelected == null
                      ? null
                      : () => widget.onRaceSelected!(observation.race),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      [
                        widget.raceLabel(observation.race),
                        l10n.biathlonShootingNumber(observation.index),
                        switch (observation.position) {
                          'prone' => l10n.biathlonPositionProne,
                          'standing' => l10n.biathlonPositionStanding,
                          _ => l10n.biathlonPositionUnknown,
                        },
                        value(observation.value!),
                      ].join(' · '),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }
}
