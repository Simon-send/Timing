import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatting/time_formatters.dart';
import '../../../core/widgets/app_shell.dart';
import '../../results/domain/race_result.dart';

class BiathlonResultPanel extends StatelessWidget {
  const BiathlonResultPanel({
    super.key,
    required this.analysis,
    this.result,
    this.classResults = const [],
    this.onSplitSelected,
  });

  final BiathlonAnalysis analysis;
  final RaceResult? result;
  final List<RaceResult> classResults;
  final ValueChanged<String>? onSplitSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final comparisonAnalyses = classResults
        .map((result) => result.biathlon)
        .whereType<BiathlonAnalysis>()
        .toList(growable: false);
    final metrics = <_AnalysisMetricData>[
      if (analysis.skiTimeMs != null)
        _AnalysisMetricData(
          id: 'ski',
          label: 'Skitid',
          value: formatDurationMs(analysis.skiTimeMs),
          rank: _metricRank(
            analysis.skiTimeMs,
            analysis.skiRank,
            comparisonAnalyses.map((item) => item.skiTimeMs),
          ),
        ),
      if (analysis.netSkiTimeMs != null)
        _AnalysisMetricData(
          id: 'net-ski',
          label: 'Netto skitid',
          value: formatDurationMs(analysis.netSkiTimeMs),
          rank: _metricRank(
            analysis.netSkiTimeMs,
            analysis.netSkiRank,
            comparisonAnalyses.map((item) => item.netSkiTimeMs),
          ),
        ),
      if (analysis.shootingTimeMs != null)
        _AnalysisMetricData(
          id: 'shooting',
          label: 'Skytetid',
          value: formatDurationMs(analysis.shootingTimeMs),
          rank: _metricRank(
            analysis.shootingTimeMs,
            analysis.shootingRank,
            comparisonAnalyses.map((item) => item.shootingTimeMs),
          ),
        ),
      if (analysis.penaltyTimeMs != null)
        _AnalysisMetricData(
          id: 'penalty',
          label: 'Straffetid',
          value: formatDurationMs(analysis.penaltyTimeMs),
          rank: _metricRank(
            analysis.penaltyTimeMs,
            analysis.penaltyRank,
            comparisonAnalyses.map((item) => item.penaltyTimeMs),
          ),
        ),
      if (analysis.missesTotal != null)
        _AnalysisMetricData(
          id: 'misses',
          label: 'Bom',
          value: '${analysis.missesTotal}',
          rank: _competitionRank(
            analysis.missesTotal,
            comparisonAnalyses.map((item) => item.missesTotal),
          ),
        ),
    ];

    return ShellPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skiskytinganalyse',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in metrics) _AnalysisMetric(metric: metric),
            ],
          ),
          if (analysis.passes.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (var index = 0; index < analysis.passes.length; index++) ...[
              _ShootingPassRow(
                pass: analysis.passes[index],
                comparisonAnalyses: comparisonAnalyses,
                splitId: _shootingSplitId(result, analysis.passes[index].index),
                onSplitSelected: onSplitSelected,
              ),
              if (index < analysis.passes.length - 1)
                Divider(height: 1, color: palette.border),
            ],
          ],
        ],
      ),
    );
  }
}

class _AnalysisMetricData {
  const _AnalysisMetricData({
    required this.id,
    required this.label,
    required this.value,
    required this.rank,
  });

  final String id;
  final String label;
  final String value;
  final int? rank;
}

class _AnalysisMetric extends StatelessWidget {
  const _AnalysisMetric({required this.metric});

  final _AnalysisMetricData metric;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            metric.value,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(
            _rankLabel(metric.rank),
            key: ValueKey('biathlon-${metric.id}-rank'),
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShootingPassRow extends StatelessWidget {
  const _ShootingPassRow({
    required this.pass,
    required this.comparisonAnalyses,
    required this.splitId,
    required this.onSplitSelected,
  });

  final ShootingPass pass;
  final List<BiathlonAnalysis> comparisonAnalyses;
  final String? splitId;
  final ValueChanged<String>? onSplitSelected;

  @override
  Widget build(BuildContext context) {
    final comparisonPasses = comparisonAnalyses
        .map((analysis) => analysis.passAt(pass.index))
        .whereType<ShootingPass>()
        .toList(growable: false);
    final details = <_PassStatisticData>[
      if (pass.rangeMs != null)
        _PassStatisticData(
          id: 'time',
          label: 'Skytetid',
          value: formatDurationMs(pass.rangeMs),
          rank: _competitionRank(
            pass.rangeMs,
            comparisonPasses.map((item) => item.rangeMs),
          ),
        ),
      if (pass.misses != null)
        _PassStatisticData(
          id: 'misses',
          label: '${pass.misses} bom',
          value: '',
          rank: _competitionRank(
            pass.misses,
            comparisonPasses.map((item) => item.misses),
          ),
        ),
      if (pass.penaltyMs != null)
        _PassStatisticData(
          id: 'penalty',
          label: 'Straff',
          value: formatDurationMs(pass.penaltyMs),
          rank: _competitionRank(
            pass.penaltyMs,
            comparisonPasses.map((item) => item.penaltyMs),
          ),
        ),
    ];
    final canOpenSplit = splitId != null && onSplitSelected != null;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          CircleAvatar(radius: 17, child: Text('${pass.index}')),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skyting ${pass.index} · ${_positionLabel(pass.position)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (details.isNotEmpty)
                  Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      for (final detail in details)
                        Text(
                          '${detail.label}${detail.value.isEmpty ? '' : ' ${detail.value}'} · ${_rankLabel(detail.rank)}',
                          key: ValueKey(
                            'biathlon-shooting-${pass.index}-${detail.id}-rank',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (canOpenSplit) const Icon(Icons.chevron_right),
        ],
      ),
    );
    if (!canOpenSplit) return content;
    return Tooltip(
      message: 'Åpne splitt for skyting ${pass.index}',
      child: InkWell(
        key: ValueKey('biathlon-shooting-${pass.index}-link'),
        onTap: () => onSplitSelected!(splitId!),
        borderRadius: BorderRadius.circular(8),
        child: content,
      ),
    );
  }
}

class _PassStatisticData {
  const _PassStatisticData({
    required this.id,
    required this.label,
    required this.value,
    required this.rank,
  });

  final String id;
  final String label;
  final String value;
  final int? rank;
}

int? _metricRank(
  int? value,
  int? persistedRank,
  Iterable<int?> comparisonValues,
) {
  if (persistedRank != null && persistedRank > 0) return persistedRank;
  return _competitionRank(value, comparisonValues);
}

int? _competitionRank(int? value, Iterable<int?> comparisonValues) {
  if (value == null) return null;
  final values = comparisonValues.whereType<int>().toList(growable: false);
  if (values.isEmpty) return null;
  return 1 + values.where((candidate) => candidate < value).length;
}

String _rankLabel(int? rank) => rank == null ? 'Rank –' : 'Rank $rank';

String? _shootingSplitId(RaceResult? result, int shootingIndex) {
  if (result == null) return null;
  final splits = result.splitValues.values.toList(growable: false)
    ..sort((a, b) {
      if (a.sort != b.sort) return a.sort.compareTo(b.sort);
      return a.id.compareTo(b.id);
    });
  final exactCode = RegExp('^S0*$shootingIndex\$', caseSensitive: false);

  for (final split in splits) {
    if (exactCode.hasMatch(split.label.trim())) return split.id;
  }
  for (final split in splits) {
    if (split.kind.toLowerCase() == 'shooting' &&
        split.roundNumber == shootingIndex) {
      return split.id;
    }
  }
  for (final split in splits) {
    if (split.kind.toLowerCase() == 'shooting' &&
        _shootingIndex(split.label) == shootingIndex) {
      return split.id;
    }
  }
  return null;
}

int? _shootingIndex(String label) {
  final match = RegExp(
    r'^(?:INS|UTS|IS|US|S)0*(\d+)$',
    caseSensitive: false,
  ).firstMatch(label.trim());
  return match == null ? null : int.tryParse(match.group(1)!);
}

String _positionLabel(String position) {
  return switch (position.toLowerCase()) {
    'prone' => 'liggende',
    'standing' => 'stående',
    _ => 'ukjent stilling',
  };
}
