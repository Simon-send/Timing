import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatting/time_formatters.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../l10n/app_localizations.dart';
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
        .where((result) => result.isFinished)
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
          if (analysis.laps.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Skitid per runde',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            for (final lap in analysis.laps)
              _SkiLapRow(lap: lap, comparisonAnalyses: comparisonAnalyses),
          ],
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

class _SkiLapRow extends StatelessWidget {
  const _SkiLapRow({required this.lap, required this.comparisonAnalyses});

  final BiathlonLap lap;
  final List<BiathlonAnalysis> comparisonAnalyses;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final rank = _competitionRank(
      lap.skiMs,
      comparisonAnalyses.map((analysis) => analysis.lapAt(lap.index)?.skiMs),
    );
    return Container(
      key: ValueKey('biathlon-lap-${lap.index}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 16, child: Text('${lap.index}')),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _lapLabel(lap),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (lap.skiMs != null) ...[
            Text(
              formatDurationMs(lap.skiMs),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            Text(
              _rankLabel(rank),
              key: ValueKey('biathlon-lap-${lap.index}-rank'),
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _lapLabel(BiathlonLap lap) {
  final shooting = lap.beforeShooting;
  if (lap.index == 1 && shooting != null) {
    return 'Start → inn skyting $shooting';
  }
  if (shooting != null) {
    return 'Ut skyting ${lap.index - 1} → inn skyting $shooting';
  }
  return lap.index == 1 ? 'Start → mål' : 'Ut skyting ${lap.index - 1} → mål';
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
    final rangeRank = _metricRank(
      pass.rangeMs,
      pass.rangeRank,
      comparisonPasses.map((item) => item.rangeMs),
    );
    final canOpenSplit = splitId != null && onSplitSelected != null;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: LayoutBuilder(
        builder: (context, _) {
          final l10n = AppLocalizations.of(context);
          final palette = context.palette;
          final secondary = <String>[
            if (pass.position.isNotEmpty) _positionLabel(pass.position, l10n),
            if (pass.misses != null) l10n.biathlonMisses(pass.misses!),
            if (pass.penaltyMs != null)
              l10n.biathlonPenalty(formatDurationMs(pass.penaltyMs)),
          ];
          final main = pass.rangeMs == null
              ? null
              : Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.end,
                  children: [
                    Text(
                      formatDurationMs(pass.rangeMs),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      _numberRankLabel(rangeRank, l10n),
                      key: ValueKey(
                        'biathlon-shooting-${pass.index}-time-rank',
                      ),
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(radius: 17, child: Text('${pass.index}')),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.biathlonShootingIn(pass.index),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (secondary.isNotEmpty)
                      Text(
                        secondary.join(' · '),
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (main != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Align(alignment: Alignment.centerRight, child: main),
                ),
              ],
              if (canOpenSplit) const Icon(Icons.chevron_right),
            ],
          );
        },
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

String _numberRankLabel(int? rank, AppLocalizations l10n) {
  return rank == null
      ? l10n.biathlonRankUnavailable
      : l10n.biathlonRankNumber(rank);
}

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

String _positionLabel(String position, AppLocalizations l10n) {
  return switch (position.toLowerCase()) {
    'prone' => l10n.biathlonPositionProne,
    'standing' => l10n.biathlonPositionStanding,
    _ => l10n.biathlonPositionUnknown,
  };
}
