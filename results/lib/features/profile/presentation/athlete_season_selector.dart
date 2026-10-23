import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/athlete_season.dart';

class AthleteSeasonSelector extends StatelessWidget {
  const AthleteSeasonSelector({
    super.key,
    required this.dataset,
    required this.selection,
    required this.onChanged,
  });

  final AthleteSeasonDataset dataset;
  final AthleteSeasonSelection selection;
  final ValueChanged<AthleteSeasonSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = dataset.select(selection);
    final unassigned = dataset.racesIn(null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.seasonTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              key: const Key('season-all'),
              label: Text(l10n.seasonAll),
              selected: selection.isAll,
              onSelected: (_) => onChanged(const AthleteSeasonSelection.all()),
            ),
            for (final season in dataset.seasons)
              FilterChip(
                key: Key('season-${season.startYear}'),
                label: Text(
                  '${season.label} · ${l10n.seasonRaceCount(dataset.racesIn(season).length)}',
                ),
                selected:
                    !selection.isAll &&
                    selection.startYears!.contains(season.startYear),
                onSelected: (selected) {
                  final years = {...?selection.startYears};
                  if (selected) {
                    years.add(season.startYear);
                  } else {
                    years.remove(season.startYear);
                  }
                  onChanged(
                    years.isEmpty
                        ? const AthleteSeasonSelection.all()
                        : AthleteSeasonSelection.only(years),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Text(
              l10n.seasonRaceCount(scope.races.length),
              key: const Key('season-race-count'),
            ),
            Text(
              l10n.seasonCompletedCount(scope.statisticalRaces.length),
              key: const Key('season-completed-count'),
            ),
          ],
        ),
        if (unassigned > 0) ...[
          const SizedBox(height: 6),
          Text(l10n.seasonUnassignedNotice(unassigned)),
        ],
        const SizedBox(height: 6),
        Text(l10n.seasonStatisticsHint),
      ],
    );
  }
}
