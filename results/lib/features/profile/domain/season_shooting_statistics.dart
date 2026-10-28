import '../../results/domain/shooting_selection.dart';
import 'athlete_profile.dart';

/// Keeps the source race and series for later distributions and navigation.
class SeasonShootingObservation {
  const SeasonShootingObservation({
    required this.race,
    required this.index,
    required this.position,
    required this.value,
  });

  final AthleteRace race;
  final int index;
  final String position;
  final int? value;
}

class SeasonShootingMetricStatistics {
  SeasonShootingMetricStatistics({
    required Iterable<SeasonShootingObservation> observations,
    required Iterable<AthleteRace> unavailableRaces,
  }) : observations = List.unmodifiable(observations),
       unavailableRaces = List.unmodifiable(unavailableRaces);

  /// Recorded selected series only. Never invent slots from an expected count.
  final List<SeasonShootingObservation> observations;

  /// No selectable recorded series (including absent data or ambiguous order).
  /// These races have no known number of missing selected measurements.
  final List<AthleteRace> unavailableRaces;

  Iterable<SeasonShootingObservation> get validObservations =>
      observations.where((observation) => observation.value != null);
  int get validCount => validObservations.length;
  int get missingCount => observations.length - validCount;

  double? get mean {
    final values = validObservations.map((observation) => observation.value!);
    return values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
  }

  double? get median {
    final values =
        validObservations.map((observation) => observation.value!).toList()
          ..sort();
    if (values.isEmpty) return null;
    final middle = values.length ~/ 2;
    return values.length.isOdd
        ? values[middle].toDouble()
        : (values[middle - 1] + values[middle]) / 2;
  }
}

class SeasonShootingStatistics {
  const SeasonShootingStatistics({
    required this.hits,
    required this.misses,
    required this.rangeTime,
  });

  final SeasonShootingMetricStatistics hits;
  final SeasonShootingMetricStatistics misses;
  final SeasonShootingMetricStatistics rangeTime;

  SeasonShootingMetricStatistics forMetric(ShootingMetric metric) =>
      switch (metric) {
        ShootingMetric.hits => hits,
        ShootingMetric.misses => misses,
        ShootingMetric.rangeTime => rangeTime,
      };

  /// The current individual source has five shots per validated measured pass.
  /// Relay penalties/reserve shots never supply hits or this denominator.
  int get knownShotCount => hits.validCount * 5;
  int? get totalHits => hits.validCount == 0
      ? null
      : hits.validObservations.fold<int>(
          0,
          (sum, observation) => sum + observation.value!,
        );
  double? get hitPercent =>
      knownShotCount == 0 ? null : totalHits! * 100 / knownShotCount;
  double? get averageMisses => misses.mean;
  double? get meanRangeTimeMs => rangeTime.mean;
  double? get medianRangeTimeMs => rangeTime.median;
}

/// Call with the full selected season scope, before presentation paging.
/// Reuses selection's raw-series, ordinal and relay safeguards for every metric;
/// excludes whole non-finishers before looking at any of their measurements.
SeasonShootingStatistics calculateSeasonShootingStatistics(
  Iterable<AthleteRace> races,
  ShootingSelection selection,
) {
  final eligible = races.where((race) => race.isFinished).toList();
  SeasonShootingMetricStatistics collect(ShootingMetric metric) {
    final observations = <SeasonShootingObservation>[];
    final unavailableRaces = <AthleteRace>[];
    for (final race in eligible) {
      final result = race.shootingSelection(metric, selection);
      if (result == null || result.observations.isEmpty) {
        unavailableRaces.add(race);
        continue;
      }
      for (final observation in result.observations) {
        observations.add(
          SeasonShootingObservation(
            race: race,
            index: observation.index,
            position: observation.position,
            value: observation.value,
          ),
        );
      }
    }
    return SeasonShootingMetricStatistics(
      observations: observations,
      unavailableRaces: unavailableRaces,
    );
  }

  return SeasonShootingStatistics(
    hits: collect(ShootingMetric.hits),
    misses: collect(ShootingMetric.misses),
    rangeTime: collect(ShootingMetric.rangeTime),
  );
}
