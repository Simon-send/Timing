import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatting/time_formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/domain/athlete_profile.dart';
import '../../profile/domain/biathlon_comparison.dart';
import '../../profile/domain/season_shooting_statistics.dart';
import '../../profile/presentation/season_shooting_distribution_panel.dart';
import '../domain/shooting_selection.dart';

class ShootingSelectionEntry {
  const ShootingSelectionEntry({
    required this.id,
    required this.label,
    required this.metrics,
    this.isRelay = false,
    this.contributes = true,
  });

  final String id;
  final String label;
  final BiathlonRaceMetrics metrics;
  final bool isRelay;
  final bool contributes;
}

/// The same controls and pass observations in race and selected-season views.
/// Season statistics opt in with the full selected scope; race details do not.
class ShootingSelectionPanel extends StatefulWidget {
  const ShootingSelectionPanel({
    super.key,
    required this.entries,
    this.statisticsRaces,
    this.raceLabel,
    this.onRaceSelected,
  });

  final List<ShootingSelectionEntry> entries;
  final List<AthleteRace>? statisticsRaces;
  final String Function(AthleteRace)? raceLabel;
  final ValueChanged<AthleteRace>? onRaceSelected;

  @override
  State<ShootingSelectionPanel> createState() => _ShootingSelectionPanelState();
}

class _ShootingSelectionPanelState extends State<ShootingSelectionPanel> {
  ShootingMetric _metric = ShootingMetric.hits;
  ShootingSelection _selection = ShootingSelection.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final races = widget.statisticsRaces;
    final statistics = races == null
        ? null
        : calculateSeasonShootingStatistics(races, _selection);
    String raceLabel(AthleteRace race) {
      if (widget.raceLabel != null) return widget.raceLabel!(race);
      for (final entry in widget.entries) {
        if (entry.id == '${race.key}/${race.resultId}') return entry.label;
      }
      return [
        race.eventId,
        race.className,
      ].where((value) => value.isNotEmpty).join(' · ');
    }

    return Column(
      key: const Key('shooting-selection-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.shootingSelectionTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<ShootingMetric>(
          key: const Key('shooting-metric-selector'),
          initialValue: _metric,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.shootingMetric),
          items: [
            for (final metric in ShootingMetric.values)
              DropdownMenuItem(
                value: metric,
                child: Text(
                  _metricLabel(metric, l10n),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _metric = value);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<ShootingSelection>(
          key: const Key('shooting-pass-selector'),
          initialValue: _selection,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.shootingSelection),
          items: [
            for (final selection in ShootingSelection.values)
              DropdownMenuItem(
                value: selection,
                child: Text(
                  _selectionLabel(selection, l10n),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _selection = value);
          },
        ),
        if (statistics != null) ...[
          const SizedBox(height: 14),
          _SeasonStatistics(statistics: statistics),
          const SizedBox(height: 14),
          SeasonShootingDistributionPanel(
            statistics: statistics.forMetric(_metric),
            metric: _metric,
            metricLabel: _metricLabel(_metric, l10n),
            raceLabel: raceLabel,
            onRaceSelected: widget.onRaceSelected,
          ),
        ],
        for (final entry in widget.entries) ...[
          const SizedBox(height: 14),
          _Observations(entry: entry, metric: _metric, selection: _selection),
        ],
      ],
    );
  }
}

class _SeasonStatistics extends StatelessWidget {
  const _SeasonStatistics({required this.statistics});

  final SeasonShootingStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String number(double? value) => value?.toStringAsFixed(1) ?? '—';
    String time(double? value) =>
        value == null ? '—' : formatDurationMs(value.round());

    return Container(
      key: const Key('season-shooting-statistics'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.seasonShootingTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.seasonShootingExplanation,
            style: TextStyle(color: context.palette.mutedText, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _Statistic(
                id: 'hit-percent',
                label: l10n.seasonShootingHitPercent,
                value: statistics.hitPercent == null
                    ? '—'
                    : '${number(statistics.hitPercent)} %',
                coverage: statistics.hits,
                detail: statistics.totalHits == null
                    ? null
                    : l10n.seasonShootingKnownShots(
                        statistics.totalHits!,
                        statistics.knownShotCount,
                      ),
              ),
              _Statistic(
                id: 'average-misses',
                label: l10n.seasonShootingAverageMisses,
                value: number(statistics.averageMisses),
                coverage: statistics.misses,
              ),
              _Statistic(
                id: 'mean-range-time',
                label: l10n.seasonShootingMeanRangeTime,
                value: time(statistics.meanRangeTimeMs),
                coverage: statistics.rangeTime,
              ),
              _Statistic(
                id: 'median-range-time',
                label: l10n.seasonShootingMedianRangeTime,
                value: time(statistics.medianRangeTimeMs),
                coverage: statistics.rangeTime,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Statistic extends StatelessWidget {
  const _Statistic({
    required this.id,
    required this.label,
    required this.value,
    required this.coverage,
    this.detail,
  });

  final String id;
  final String label;
  final String value;
  final SeasonShootingMetricStatistics coverage;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        key: Key('season-shooting-$id'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (detail != null) Text(detail!),
          Text(
            l10n.seasonShootingCoverage(
              coverage.validCount,
              coverage.missingCount,
            ),
            style: TextStyle(color: context.palette.mutedText, fontSize: 12),
          ),
          if (coverage.unavailableRaces.isNotEmpty)
            Text(
              l10n.seasonShootingUnavailableRaces(
                coverage.unavailableRaces.length,
              ),
              style: TextStyle(color: context.palette.mutedText, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _Observations extends StatelessWidget {
  const _Observations({
    required this.entry,
    required this.metric,
    required this.selection,
  });

  final ShootingSelectionEntry entry;
  final ShootingMetric metric;
  final ShootingSelection selection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = entry.metrics.shootingSelection(
      metric,
      selection,
      isRelay: entry.isRelay || entry.metrics.isRelay,
    );
    final issue = switch (result.issue) {
      ShootingSelectionIssue.noMatchingShooting => l10n.shootingNoMatch,
      ShootingSelectionIssue.ambiguousOrder => l10n.shootingAmbiguous,
      ShootingSelectionIssue.incompleteData => l10n.shootingIncomplete,
      ShootingSelectionIssue.relayShotDataUnavailable =>
        l10n.shootingRelayUnavailable,
      ShootingSelectionIssue.relayPositionsUnavailable =>
        l10n.shootingRelayPositionsUnavailable,
      null => null,
    };
    return Column(
      key: ValueKey('shooting-observations-${entry.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entry.label.isNotEmpty)
          Text(
            entry.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        if (!entry.contributes)
          Text(
            l10n.shootingExcluded,
            style: TextStyle(color: context.palette.mutedText),
          ),
        Text(
          l10n.shootingValidCount(
            result.validObservations.length,
            result.observations.length,
          ),
          style: TextStyle(color: context.palette.mutedText, fontSize: 12),
        ),
        for (final observation in result.observations)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Wrap(
              key: ValueKey(
                'shooting-observation-${entry.id}-${observation.index}',
              ),
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              children: [
                Text(
                  '${l10n.biathlonShootingNumber(observation.index)} · ${_positionLabel(observation.position, l10n)}',
                ),
                Text(
                  observation.value == null
                      ? '—'
                      : metric == ShootingMetric.rangeTime
                      ? formatDurationMs(observation.value)
                      : '${observation.value}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        if (issue != null)
          Text(
            issue,
            style: TextStyle(color: context.palette.mutedText, fontSize: 12),
          ),
      ],
    );
  }
}

String _metricLabel(ShootingMetric metric, AppLocalizations l10n) =>
    switch (metric) {
      ShootingMetric.hits => l10n.shootingHits,
      ShootingMetric.misses => l10n.biathlonMissesLabel,
      ShootingMetric.rangeTime => l10n.biathlonRangeTime,
    };

String _selectionLabel(ShootingSelection selection, AppLocalizations l10n) =>
    switch (selection) {
      ShootingSelection.all => l10n.shootingAll,
      ShootingSelection.prone => l10n.biathlonPositionProne,
      ShootingSelection.standing => l10n.biathlonPositionStanding,
      ShootingSelection.firstProne => l10n.shootingFirstProne,
      ShootingSelection.secondProne => l10n.shootingSecondProne,
      ShootingSelection.firstStanding => l10n.shootingFirstStanding,
      ShootingSelection.secondStanding => l10n.shootingSecondStanding,
    };

String _positionLabel(String position, AppLocalizations l10n) =>
    switch (position) {
      'prone' => l10n.biathlonPositionProne,
      'standing' => l10n.biathlonPositionStanding,
      _ => l10n.biathlonPositionUnknown,
    };
