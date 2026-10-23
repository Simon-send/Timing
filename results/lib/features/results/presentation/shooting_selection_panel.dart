import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatting/time_formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/domain/biathlon_comparison.dart';
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
/// This deliberately does not pool observations into seasonal statistics.
class ShootingSelectionPanel extends StatefulWidget {
  const ShootingSelectionPanel({super.key, required this.entries});

  final List<ShootingSelectionEntry> entries;

  @override
  State<ShootingSelectionPanel> createState() => _ShootingSelectionPanelState();
}

class _ShootingSelectionPanelState extends State<ShootingSelectionPanel> {
  ShootingMetric _metric = ShootingMetric.hits;
  ShootingSelection _selection = ShootingSelection.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        for (final entry in widget.entries) ...[
          const SizedBox(height: 14),
          _Observations(entry: entry, metric: _metric, selection: _selection),
        ],
      ],
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
