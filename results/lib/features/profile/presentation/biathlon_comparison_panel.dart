import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatting/time_formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../events/domain/result_event.dart';
import '../domain/athlete_profile.dart';
import '../domain/biathlon_aggregate_profile.dart';
import '../domain/biathlon_comparison.dart';

class BiathlonComparisonPanel extends StatefulWidget {
  const BiathlonComparisonPanel({
    super.key,
    required this.races,
    required this.events,
  });

  final List<AthleteRace> races;
  final List<ResultEvent> events;

  @override
  State<BiathlonComparisonPanel> createState() =>
      _BiathlonComparisonPanelState();
}

class _BiathlonComparisonPanelState extends State<BiathlonComparisonPanel> {
  BiathlonReferenceGroup _group = BiathlonReferenceGroup.topHalf;
  BiathlonMetric _metric = BiathlonMetric.finishTime;
  String? _selectedDetailKey;
  String? _selectedRaceId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);
    final eventsById = {for (final event in widget.events) event.id: event};
    final races =
        widget.races
            .where((race) => race.isCompletedIndividualBiathlonRace)
            .toList()
          ..sort((a, b) {
            final aDate = eventsById[a.eventId]?.date;
            final bDate = eventsById[b.eventId]?.date;
            if (aDate != null && bDate != null) {
              final dateOrder = aDate.compareTo(bDate);
              if (dateOrder != 0) return dateOrder;
            }
            return _raceId(a).compareTo(_raceId(b));
          });

    if (races.isEmpty) return const SizedBox.shrink();

    final selected = races.where((race) => _raceId(race) == _selectedRaceId);
    final selectedRace = selected.isNotEmpty ? selected.first : races.last;
    final selectedReference = selectedRace.referenceFor(_group);
    final detailChoices = <String, _DetailedChoice>{
      for (final race in races)
        if (race.referenceFor(_group) case final profile?)
          for (final choice in _choicesFor(profile, l10n)) choice.id: choice,
    };
    final activeDetail = detailChoices[_selectedDetailKey];
    final selectedDetails = selectedReference == null
        ? const <_DetailedChoice>[]
        : _choicesFor(selectedReference, l10n);
    final activeLabel = activeDetail?.label ?? _metricLabel(_metric, l10n);
    final activeUnit =
        activeDetail?.unit ??
        (_metric.isPercentage ? _MeasureUnit.percent : _MeasureUnit.time);
    final comparisons = [
      for (final race in races)
        if (_comparisonFor(race, _group, _metric, activeDetail)
            case final comparison?)
          (race: race, comparison: comparison),
    ];
    final scale = comparisons.fold<double>(
      0,
      (maxValue, item) => math.max(maxValue, item.comparison.advantage.abs()),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.biathlonStatistics,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.biathlonComparisonDescription(_groupLabel(_group, l10n)),
          style: TextStyle(color: palette.mutedText),
        ),
        const SizedBox(height: 14),
        Container(
          key: const Key('biathlon-average-hit-percent'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.panelAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.biathlonAverageHitPercent,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.biathlonAverageHitExplanation,
                style: TextStyle(color: palette.mutedText, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  for (final metric in const [
                    BiathlonMetric.proneHitPercent,
                    BiathlonMetric.standingHitPercent,
                    BiathlonMetric.totalHitPercent,
                  ])
                    Builder(
                      builder: (context) {
                        final average = averageBiathlonHitPercent(
                          races.map((race) => race.biathlonMetrics!),
                          metric,
                        );
                        final label = switch (metric) {
                          BiathlonMetric.proneHitPercent =>
                            l10n.biathlonHitProne,
                          BiathlonMetric.standingHitPercent =>
                            l10n.biathlonHitStanding,
                          _ => l10n.biathlonHitTotal,
                        };
                        return Column(
                          key: Key('biathlon-average-${metric.name}'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label),
                            Text(
                              average == null
                                  ? '—'
                                  : '${average.mean.toStringAsFixed(1)} %',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              l10n.biathlonAverageRaceCount(
                                average?.count ?? 0,
                              ),
                              style: TextStyle(
                                color: palette.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final group in BiathlonReferenceGroup.values)
              ChoiceChip(
                key: Key('biathlon-reference-${group.name}'),
                label: Text(_groupLabel(group, l10n)),
                selected: _group == group,
                onSelected: (_) => setState(() => _group = group),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final metric in BiathlonMetric.values)
              ChoiceChip(
                key: Key('biathlon-metric-${metric.name}'),
                label: Text(_metricLabel(metric, l10n)),
                selected: activeDetail == null && _metric == metric,
                onSelected: (_) => setState(() {
                  _metric = metric;
                  _selectedDetailKey = null;
                }),
              ),
          ],
        ),
        if (detailChoices.isNotEmpty) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: DropdownButton<String>(
              key: const Key('biathlon-detail-selector'),
              value: activeDetail?.id,
              isExpanded: true,
              hint: Text(l10n.biathlonDetailSelector),
              items: [
                for (final choice in detailChoices.values)
                  DropdownMenuItem(
                    value: choice.id,
                    child: Text(choice.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _selectedDetailKey = value),
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (comparisons.isEmpty)
          Container(
            key: const Key('biathlon-comparison-unavailable'),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              l10n.biathlonComparisonUnavailable(
                activeLabel,
                _groupLabel(_group, l10n),
              ),
              style: TextStyle(color: palette.mutedText),
            ),
          )
        else ...[
          Text(
            activeUnit == _MeasureUnit.percent
                ? l10n.biathlonPercentDifferenceCaption
                : l10n.biathlonDifferenceCaption(_groupLabel(_group, l10n)),
            style: TextStyle(color: palette.mutedText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            key: const Key('biathlon-comparison-chart'),
            height: 228,
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    for (final item in comparisons)
                      _ComparisonBar(
                        key: Key('biathlon-bar-${_raceId(item.race)}'),
                        comparison: item.comparison,
                        metricLabel: activeLabel,
                        scale: scale,
                        label: _shortRaceLabel(item.race, eventsById),
                        selected: _raceId(item.race) == _raceId(selectedRace),
                        onTap: () => setState(
                          () => _selectedRaceId = _raceId(item.race),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          eventsById[selectedRace.eventId]?.name ??
              l10n.biathlonRaceLabel(selectedRace.eventId),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        Text(
          [
            selectedRace.className,
            if (eventsById[selectedRace.eventId]?.dateLabel.isNotEmpty == true)
              eventsById[selectedRace.eventId]!.dateLabel,
            if (selectedReference case final reference?)
              l10n.biathlonCohortSummary(
                _groupLabel(_group, l10n),
                reference.cohortCount,
                reference.finishersCount,
              ),
          ].where((part) => part.isNotEmpty).join(' · '),
          style: TextStyle(color: palette.mutedText, fontSize: 12),
        ),
        const SizedBox(height: 10),
        for (final metric in BiathlonMetric.values)
          _MetricDetail(
            keySuffix: metric.name,
            label: _metricLabel(metric, l10n),
            unit: metric.isPercentage
                ? _MeasureUnit.percent
                : _MeasureUnit.time,
            referenceLabel: _groupLabel(_group, l10n),
            own: selectedRace.biathlonMetrics?.valueFor(metric),
            benchmark: selectedReference?.valueForMetric(metric),
          ),
        if (selectedDetails.isNotEmpty)
          ExpansionTile(
            key: const Key('biathlon-extra-details'),
            tilePadding: EdgeInsets.zero,
            title: Text(l10n.biathlonExtraDetails),
            children: [
              for (final choice in selectedDetails)
                _MetricDetail(
                  keySuffix: choice.id,
                  label: choice.label,
                  unit: choice.unit,
                  referenceLabel: _groupLabel(_group, l10n),
                  own: choice.ownValue(
                    selectedRace.biathlonMetrics,
                    selectedReference!,
                  ),
                  benchmark: choice.benchmarkValue(selectedReference),
                ),
            ],
          ),
      ],
    );
  }
}

String _raceId(AthleteRace race) => '${race.key}/${race.resultId}';

String _shortRaceLabel(AthleteRace race, Map<String, ResultEvent> eventsById) {
  final event = eventsById[race.eventId];
  if (event?.date != null) {
    return '${event!.date!.day}.${event.date!.month}';
  }
  final name = event?.name ?? race.eventId;
  return name.length > 11 ? '${name.substring(0, 10)}…' : name;
}

enum _MeasureUnit { time, percent, misses, rank, number }

class _PanelComparison {
  const _PanelComparison(this.own, this.benchmark, this.unit);

  final double own;
  final BiathlonBenchmarkValue benchmark;
  final _MeasureUnit unit;

  double get difference => own - benchmark.mean;
  double get advantage =>
      unit == _MeasureUnit.percent ? difference : -difference;
}

_PanelComparison? _comparisonFor(
  AthleteRace race,
  BiathlonReferenceGroup group,
  BiathlonMetric metric,
  _DetailedChoice? detail,
) {
  final reference = race.referenceFor(group);
  if (reference == null) return null;
  final own = detail == null
      ? race.biathlonMetrics?.valueFor(metric)
      : detail.ownValue(race.biathlonMetrics, reference);
  final benchmark = detail == null
      ? reference.valueForMetric(metric)
      : detail.benchmarkValue(reference);
  if (own == null || benchmark == null || !own.isFinite) return null;
  return _PanelComparison(
    own,
    benchmark,
    detail?.unit ??
        (metric.isPercentage ? _MeasureUnit.percent : _MeasureUnit.time),
  );
}

class _DetailedChoice {
  const _DetailedChoice({
    required this.id,
    required this.label,
    required this.field,
    required this.section,
    required this.unit,
    this.pointId,
  });

  final String id;
  final String label;
  final String field;
  final String section;
  final String? pointId;
  final _MeasureUnit unit;

  BiathlonAggregatePoint? _point(BiathlonAggregateProfile profile) =>
      switch (section) {
        'timing' => profile.timingPoints[pointId],
        'shooting' => profile.shootingPasses[pointId],
        'lap' => profile.laps[pointId],
        _ => null,
      };

  BiathlonBenchmarkValue? benchmarkValue(BiathlonAggregateProfile profile) =>
      section == 'metrics'
      ? profile.metrics[field]
      : _point(profile)?.valueFor(field);

  double? ownValue(BiathlonRaceMetrics? own, BiathlonAggregateProfile profile) {
    if (own == null) return null;
    if (section == 'metrics') return own.valueForMetricField(field);
    final point = _point(profile);
    if (point == null) return null;
    return switch (section) {
      'timing' => own.valueForTimingPoint(point.id, field),
      'shooting' =>
        point.index == null
            ? null
            : own.valueForShootingPass(point.index!, point.position, field),
      'lap' =>
        point.index == null
            ? null
            : own.valueForLap(
                point.index!,
                field,
                beforeShooting: point.beforeShooting,
                startCode: point.startCode,
                endCode: point.endCode,
              ),
      _ => null,
    };
  }
}

List<_DetailedChoice> _choicesFor(
  BiathlonAggregateProfile profile,
  AppLocalizations l10n,
) {
  final core = {for (final metric in BiathlonMetric.values) metric.fieldName};
  final choices = <_DetailedChoice>[];
  final extraMetrics =
      profile.metrics.keys.where((field) => !core.contains(field)).toList()
        ..sort();
  for (final field in extraMetrics) {
    choices.add(
      _DetailedChoice(
        id: 'metrics/$field',
        label: _fieldLabel(field, l10n),
        field: field,
        section: 'metrics',
        unit: _unitForField(field),
      ),
    );
  }

  final timing = profile.timingPoints.values.toList()
    ..sort((a, b) {
      final order = (a.sort ?? 10000).compareTo(b.sort ?? 10000);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
  for (final point in timing) {
    for (final field in const ['cumMs', 'legMs', 'cumRank', 'legRank']) {
      if (!point.values.containsKey(field)) continue;
      choices.add(
        _DetailedChoice(
          id: 'timing/${point.id}/$field',
          label:
              '${point.label ?? point.code ?? point.id} · ${_fieldLabel(field, l10n)}',
          field: field,
          section: 'timing',
          pointId: point.id,
          unit: _unitForField(field),
        ),
      );
    }
  }

  final shooting = profile.shootingPasses.values.toList()
    ..sort((a, b) => (a.index ?? 10000).compareTo(b.index ?? 10000));
  for (final point in shooting) {
    if (point.index == null) continue;
    for (final field in const [
      'misses',
      'rangeMs',
      'penaltyMs',
      'rangeRank',
      'rangeExitMs',
      'approachCumMs',
      'inCumMs',
      'shootingCumMs',
      'outCumMs',
      'rangeExitCumMs',
      'cumulativeMisses',
    ]) {
      if (!point.values.containsKey(field)) continue;
      choices.add(
        _DetailedChoice(
          id: 'shooting/${point.id}/$field',
          label:
              '${l10n.biathlonShootingNumber(point.index!)} · ${_fieldLabel(field, l10n)}',
          field: field,
          section: 'shooting',
          pointId: point.id,
          unit: _unitForField(field),
        ),
      );
    }
  }

  final laps = profile.laps.values.toList()
    ..sort((a, b) => (a.index ?? 10000).compareTo(b.index ?? 10000));
  for (final point in laps) {
    if (point.index == null) continue;
    for (final field in const ['skiMs', 'startCumMs', 'endCumMs']) {
      if (!point.values.containsKey(field)) continue;
      choices.add(
        _DetailedChoice(
          id: 'lap/${point.id}/$field',
          label:
              '${l10n.biathlonSkiLap(point.index!)} · ${_fieldLabel(field, l10n)}',
          field: field,
          section: 'lap',
          pointId: point.id,
          unit: _unitForField(field),
        ),
      );
    }
  }
  return choices;
}

_MeasureUnit _unitForField(String field) {
  if (field.endsWith('Ms')) return _MeasureUnit.time;
  if (field.endsWith('Percent')) return _MeasureUnit.percent;
  if (field.endsWith('Rank')) return _MeasureUnit.rank;
  if (field == 'misses' ||
      field == 'missesTotal' ||
      field == 'proneMisses' ||
      field == 'standingMisses' ||
      field == 'cumulativeMisses') {
    return _MeasureUnit.misses;
  }
  return _MeasureUnit.number;
}

String _metricLabel(BiathlonMetric metric, AppLocalizations l10n) =>
    switch (metric) {
      BiathlonMetric.finishTime => l10n.biathlonFinishTime,
      BiathlonMetric.skiTime => l10n.biathlonSkiTime,
      BiathlonMetric.shootingTime => l10n.biathlonShootingTime,
      BiathlonMetric.proneHitPercent => l10n.biathlonHitProneLabel,
      BiathlonMetric.standingHitPercent => l10n.biathlonHitStandingLabel,
      BiathlonMetric.totalHitPercent => l10n.biathlonHitTotalLabel,
    };

String _groupLabel(BiathlonReferenceGroup group, AppLocalizations l10n) =>
    switch (group) {
      BiathlonReferenceGroup.all => l10n.biathlonAllFinishers,
      BiathlonReferenceGroup.topHalf => l10n.biathlonTopHalf,
    };

String _fieldLabel(String field, AppLocalizations l10n) => switch (field) {
  'netSkiTimeMs' => l10n.biathlonNetSkiTime,
  'penaltyTimeMs' => l10n.biathlonPenaltyTime,
  'rangeTimeMs' => l10n.biathlonRangeTime,
  'proneTimeMs' => l10n.biathlonProneTime,
  'standingTimeMs' => l10n.biathlonStandingTime,
  'missesTotal' => l10n.biathlonTotalMisses,
  'proneMisses' => l10n.biathlonProneMisses,
  'standingMisses' => l10n.biathlonStandingMisses,
  'skiRank' => l10n.biathlonSkiRank,
  'netSkiRank' => l10n.biathlonNetSkiRank,
  'shootingRank' => l10n.biathlonShootingRank,
  'shootRank' => l10n.biathlonShootingRank,
  'rangeRank' => l10n.biathlonRangeRank,
  'penaltyRank' => l10n.biathlonPenaltyRank,
  'finishRank' => l10n.biathlonFinishRank,
  'cumMs' => l10n.biathlonPassingTime,
  'legMs' => l10n.biathlonSplitTime,
  'cumRank' => l10n.biathlonPassingRank,
  'legRank' => l10n.biathlonSplitRank,
  'misses' => l10n.biathlonMissesLabel,
  'rangeMs' => l10n.biathlonShootingTime,
  'penaltyMs' => l10n.biathlonPenaltyTime,
  'rangeExitMs' => l10n.biathlonRangeExitTime,
  'approachCumMs' => l10n.biathlonRangeApproach,
  'inCumMs' => l10n.biathlonRangeEntry,
  'shootingCumMs' => l10n.biathlonShootingDone,
  'outCumMs' => l10n.biathlonShootingExit,
  'rangeExitCumMs' => l10n.biathlonRangeExitTotal,
  'cumulativeMisses' => l10n.biathlonCumulativeMisses,
  'skiMs' => l10n.biathlonSkiTime,
  'startCumMs' => l10n.biathlonStartTime,
  'endCumMs' => l10n.biathlonFinishTime,
  _ => field.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match[1]} ${match[2]!.toLowerCase()}',
  ),
};

String _metricValue(_MeasureUnit unit, double? value, AppLocalizations l10n) {
  if (value == null) return '–';
  return switch (unit) {
    _MeasureUnit.time => formatDurationMs(value.round()),
    _MeasureUnit.percent => '${value.toStringAsFixed(1)} %',
    _MeasureUnit.misses => l10n.biathlonDecimalMisses(value.toStringAsFixed(1)),
    _MeasureUnit.rank || _MeasureUnit.number => value.toStringAsFixed(1),
  };
}

String _differenceText(
  _MeasureUnit unit,
  double difference,
  AppLocalizations l10n,
) {
  final sign = difference > 0
      ? '+'
      : difference < 0
      ? '−'
      : '±';
  return switch (unit) {
    _MeasureUnit.time => '$sign${formatDurationMs(difference.abs().round())}',
    _MeasureUnit.percent => l10n.biathlonPercentagePoints(
      '$sign${difference.abs().toStringAsFixed(1)}',
    ),
    _MeasureUnit.misses => l10n.biathlonDecimalMisses(
      '$sign${difference.abs().toStringAsFixed(1)}',
    ),
    _MeasureUnit.rank ||
    _MeasureUnit.number => '$sign${difference.abs().toStringAsFixed(1)}',
  };
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    super.key,
    required this.comparison,
    required this.metricLabel,
    required this.scale,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final _PanelComparison comparison;
  final String metricLabel;
  final double scale;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);
    final advantage = comparison.advantage;
    final height = scale == 0
        ? 3.0
        : math.max(3.0, 74 * advantage.abs() / scale);
    final bar = Container(
      width: 23,
      height: height,
      decoration: BoxDecoration(
        color: advantage >= 0 ? palette.primary : palette.danger,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Tooltip(
      message:
          '$label: ${_differenceText(comparison.unit, comparison.difference, l10n)}',
      child: Semantics(
        button: true,
        selected: selected,
        label:
            '$label, $metricLabel: ${_differenceText(comparison.unit, comparison.difference, l10n)}',
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 72,
            child: Column(
              children: [
                SizedBox(
                  height: 80,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: advantage >= 0 ? bar : null,
                  ),
                ),
                Container(height: 2, color: palette.border),
                SizedBox(
                  height: 80,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: advantage < 0 ? bar : null,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.normal,
                    color: selected ? palette.primary : palette.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricDetail extends StatelessWidget {
  const _MetricDetail({
    required this.keySuffix,
    required this.label,
    required this.unit,
    required this.referenceLabel,
    required this.own,
    required this.benchmark,
  });

  final String keySuffix;
  final String label;
  final _MeasureUnit unit;
  final String referenceLabel;
  final double? own;
  final BiathlonBenchmarkValue? benchmark;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);
    final difference = own != null && benchmark != null
        ? own! - benchmark!.mean
        : null;
    return Padding(
      key: Key('biathlon-detail-$keySuffix'),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            '${l10n.biathlonOwnValue(_metricValue(unit, own, l10n))}  ·  $referenceLabel: ${_metricValue(unit, benchmark?.mean, l10n)}'
            '${benchmark == null ? '' : ' (n=${benchmark!.count})'}',
            style: TextStyle(color: palette.mutedText),
          ),
          if (difference != null)
            Text(
              l10n.biathlonYourDifference(
                _differenceText(unit, difference, l10n),
              ),
              style: TextStyle(
                color: unit == _MeasureUnit.percent
                    ? (difference >= 0 ? palette.primary : palette.danger)
                    : (difference <= 0 ? palette.primary : palette.danger),
              ),
            ),
        ],
      ),
    );
  }
}
