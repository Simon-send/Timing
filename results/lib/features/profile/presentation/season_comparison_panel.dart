import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../results/domain/shooting_selection.dart';
import '../../results/presentation/shooting_selection_panel.dart';
import '../domain/athlete_profile.dart';
import '../domain/athlete_season.dart';
import '../domain/season_shooting_comparison.dart';
import 'season_shooting_distribution_panel.dart';

class SeasonComparisonButton extends StatelessWidget {
  const SeasonComparisonButton({
    super.key,
    required this.dataset,
    this.onRaceSelected,
  });

  final AthleteSeasonDataset dataset;
  final ValueChanged<AthleteRace>? onRaceSelected;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('season-comparison-open'),
    icon: const Icon(Icons.compare_arrows),
    label: Text(AppLocalizations.of(context).comparisonTitle),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        key: const Key('season-comparison-dialog'),
        insetPadding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).comparisonTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    CloseButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SeasonComparisonPanel(
                    dataset: dataset,
                    onRaceSelected: onRaceSelected == null
                        ? null
                        : (race) {
                            Navigator.of(dialogContext).pop();
                            onRaceSelected!(race);
                          },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Uses the complete history independently of the profile's display selection.
/// Both panes always consume the same program, metric and shooting selection.
class SeasonComparisonPanel extends StatefulWidget {
  const SeasonComparisonPanel({
    super.key,
    required this.dataset,
    this.onRaceSelected,
  });

  final AthleteSeasonDataset dataset;
  final ValueChanged<AthleteRace>? onRaceSelected;

  @override
  State<SeasonComparisonPanel> createState() => _SeasonComparisonPanelState();
}

class _SeasonComparisonPanelState extends State<SeasonComparisonPanel> {
  int? _leftYear;
  int? _rightYear;
  BiathlonProgram? _program;
  ShootingMetric _metric = ShootingMetric.hits;
  ShootingSelection _selection = ShootingSelection.all;
  bool _counts = false;
  int _timeBinCount = 8;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = SeasonComparisonDataset(widget.dataset);
    final years = data.seasons.map((season) => season.startYear).toList();
    final programs = data.programs;
    final number = NumberFormat('0.###', l10n.localeName);
    final coverage = Text(
      l10n.comparisonUnknownCoverage(
        data.unknownSeasonCount,
        data.unknownProgramCount,
      ),
      key: const Key('comparison-coverage'),
    );
    if (years.length < 2 || programs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            years.length < 2
                ? l10n.comparisonNeedTwoSeasons
                : l10n.comparisonNoProgram,
            key: const Key('comparison-empty'),
          ),
          const SizedBox(height: 8),
          coverage,
        ],
      );
    }
    final rightYear = years.contains(_rightYear) ? _rightYear! : years.first;
    final leftYear = years.contains(_leftYear) && _leftYear != rightYear
        ? _leftYear!
        : years.firstWhere((year) => year != rightYear);
    final defaultProgram = programs.firstWhere(
      (program) =>
          {
            for (final race in widget.dataset.races)
              if (race.isFinished &&
                  race.biathlonMetrics != null &&
                  data.programOf(race) == program)
                data.seasonOf(race)?.startYear,
          }.whereType<int>().length >=
          2,
      orElse: () => programs.first,
    );
    final program = programs.contains(_program) ? _program! : defaultProgram;
    final comparison = SeasonShootingComparison(
      left: data.sample(
        year: leftYear,
        program: program,
        selection: _selection,
      ),
      right: data.sample(
        year: rightYear,
        program: program,
        selection: _selection,
      ),
      metric: _metric,
      timeBinCount: _timeBinCount,
    );
    String raceLabel(AthleteRace race) => [
      widget.dataset.eventsById[race.eventId]?.name ?? race.eventId,
      widget.dataset.eventsById[race.eventId]?.dateLabel ?? '',
      race.className,
    ].where((text) => text.isNotEmpty).join(' · ');
    Widget pane(SeasonComparisonSample sample, String side) {
      final statistics = sample.statistics.forMetric(_metric);
      return Column(
        key: Key('comparison-$side'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AthleteSeason(sample.year).label,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            l10n.comparisonRaceCoverage(
              sample.finishedRaceCount,
              sample.excludedRaceCount,
            ),
          ),
          Text(
            l10n.seasonShootingCoverage(
              statistics.validCount,
              statistics.missingCount,
            ),
          ),
          if (statistics.unavailableRaces.isNotEmpty)
            Text(
              l10n.seasonShootingUnavailableRaces(
                statistics.unavailableRaces.length,
              ),
            ),
          if (_metric == ShootingMetric.hits) ...[
            Text(
              '${l10n.seasonShootingHitPercent}: ${sample.statistics.hitPercent == null ? '—' : '${number.format(sample.statistics.hitPercent)} %'}',
              key: Key('comparison-$side-hit-percent'),
            ),
            if (sample.statistics.totalHits != null)
              Text(
                l10n.seasonShootingKnownShots(
                  sample.statistics.totalHits!,
                  sample.statistics.knownShotCount,
                ),
              ),
          ],
          const SizedBox(height: 8),
          SeasonShootingDistributionPanel(
            statistics: statistics,
            metric: _metric,
            metricLabel: shootingMetricLabel(_metric, l10n),
            raceLabel: raceLabel,
            onRaceSelected: widget.onRaceSelected,
            commonScale: comparison.scale,
            maximumY: comparison.maximumY(percentages: !_counts),
            showPercentages: !_counts,
          ),
        ],
      );
    }

    final delta = comparison.delta;
    final deltaValue = delta == null
        ? '—'
        : '${delta > 0 ? '+' : ''}${number.format(delta)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _choice<BiathlonProgram>(
          keyName: 'comparison-program-selector',
          label: l10n.comparisonProgram,
          value: program,
          values: programs,
          text: (value) => comparisonProgramLabel(value, l10n),
          onChanged: (value) => setState(() => _program = value),
        ),
        const SizedBox(height: 10),
        _choice<int>(
          keyName: 'comparison-season-left',
          label: l10n.comparisonSeasonA,
          value: leftYear,
          values: years,
          text: (year) => AthleteSeason(year).label,
          onChanged: (year) => setState(() {
            _leftYear = year;
            _rightYear = year == rightYear ? leftYear : rightYear;
          }),
        ),
        const SizedBox(height: 10),
        _choice<int>(
          keyName: 'comparison-season-right',
          label: l10n.comparisonSeasonB,
          value: rightYear,
          values: years,
          text: (year) => AthleteSeason(year).label,
          onChanged: (year) => setState(() {
            _rightYear = year;
            _leftYear = year == leftYear ? rightYear : leftYear;
          }),
        ),
        const SizedBox(height: 10),
        _choice<ShootingMetric>(
          keyName: 'comparison-metric-selector',
          label: l10n.shootingMetric,
          value: _metric,
          values: ShootingMetric.values,
          text: (value) => shootingMetricLabel(value, l10n),
          onChanged: (value) => setState(() => _metric = value),
        ),
        const SizedBox(height: 10),
        _choice<ShootingSelection>(
          keyName: 'comparison-selection-selector',
          label: l10n.shootingSelection,
          value: _selection,
          values: ShootingSelection.values,
          text: (value) => shootingSelectionLabel(value, l10n),
          onChanged: (value) => setState(() => _selection = value),
        ),
        SwitchListTile.adaptive(
          key: const Key('comparison-count-toggle'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.comparisonShowCounts),
          value: _counts,
          onChanged: (value) => setState(() => _counts = value),
        ),
        Text(
          l10n.comparisonFilters(
            l10n.comparisonSport,
            comparisonProgramLabel(program, l10n),
            shootingMetricLabel(_metric, l10n),
            shootingSelectionLabel(_selection, l10n),
          ),
          key: const Key('comparison-filters'),
        ),
        const SizedBox(height: 8),
        coverage,
        Text(l10n.comparisonPositionCaution),
        const SizedBox(height: 8),
        Text(
          switch (_metric) {
            ShootingMetric.hits => l10n.comparisonDeltaPoints(deltaValue),
            ShootingMetric.misses => l10n.comparisonDeltaMisses(deltaValue),
            ShootingMetric.rangeTime => l10n.comparisonDeltaSeconds(deltaValue),
          },
          key: const Key('comparison-delta'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        Text(l10n.comparisonCaution),
        if (_metric == ShootingMetric.rangeTime) ...[
          Text(l10n.seasonDistributionIntervals(_timeBinCount)),
          Slider(
            key: const Key('comparison-intervals'),
            min: 2,
            max: 20,
            divisions: 18,
            value: _timeBinCount.toDouble(),
            label: '$_timeBinCount',
            semanticFormatterCallback: (value) =>
                l10n.seasonDistributionIntervals(value.round()),
            onChanged: (value) => setState(() => _timeBinCount = value.round()),
          ),
        ],
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final left = pane(comparison.left, 'left');
            final right = pane(comparison.right, 'right');
            return constraints.maxWidth >= 760
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 24),
                      Expanded(child: right),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [left, const SizedBox(height: 24), right],
                  );
          },
        ),
      ],
    );
  }
}

Widget _choice<T>({
  required String keyName,
  required String label,
  required T value,
  required Iterable<T> values,
  required String Function(T) text,
  required ValueChanged<T> onChanged,
}) => KeyedSubtree(
  key: Key(keyName),
  child: DropdownButtonFormField<T>(
    key: ValueKey(value),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final option in values)
        DropdownMenuItem(
          value: option,
          child: Text(text(option), overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  ),
);

String comparisonProgramLabel(BiathlonProgram program, AppLocalizations l10n) =>
    switch (program) {
      BiathlonProgram.sprint => l10n.comparisonSprint,
      BiathlonProgram.individual => l10n.comparisonIndividual,
      BiathlonProgram.shortIndividual => l10n.comparisonShortIndividual,
      BiathlonProgram.pursuit => l10n.comparisonPursuit,
      BiathlonProgram.massStart => l10n.comparisonMassStart,
      BiathlonProgram.superSprint => l10n.comparisonSuperSprint,
      BiathlonProgram.relay => l10n.comparisonRelay,
    };
