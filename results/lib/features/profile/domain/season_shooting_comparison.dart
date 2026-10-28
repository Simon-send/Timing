import 'dart:math' as math;

import '../../events/domain/result_event.dart';
import '../../results/domain/shooting_selection.dart';
import 'athlete_profile.dart';
import 'athlete_season.dart';
import 'season_shooting_distribution.dart';
import 'season_shooting_statistics.dart';

enum BiathlonProgram {
  sprint,
  individual,
  shortIndividual,
  pursuit,
  massStart,
  superSprint,
  relay,
}

/// Recognized explicit program words only. Never uses event names, age classes,
/// distance or the number of recorded series to infer a program.
Set<BiathlonProgram> _programs(Iterable<String> labels) {
  final result = <BiathlonProgram>{};
  for (final label in labels) {
    var remaining = label.toLowerCase().replaceAll(RegExp(r'[-_]'), ' ');
    for (final (pattern, program) in <(String, BiathlonProgram)>[
      (r'kort\s+normal|short\s+individual', BiathlonProgram.shortIndividual),
      (r'supersprint|super\s+sprint', BiathlonProgram.superSprint),
      (r'fellesstart|fellestart|mass\s+start', BiathlonProgram.massStart),
      (r'jaktstart|pursuit', BiathlonProgram.pursuit),
      (r'stafett|relay', BiathlonProgram.relay),
      (r'normal|individuell|individual', BiathlonProgram.individual),
      (r'sprint', BiathlonProgram.sprint),
    ]) {
      final expression = RegExp('\\b(?:$pattern)\\b');
      if (expression.hasMatch(remaining)) {
        result.add(program);
        remaining = remaining.replaceAll(expression, ' ');
      }
    }
  }
  return result;
}

bool _isBiathlon(ResultEvent? event) => const {
  'biathlon',
  'skiskyting',
}.contains(event?.sportName.trim().toLowerCase());

BiathlonProgram? comparisonProgramFor(AthleteRace race, ResultEvent? event) {
  if (!_isBiathlon(event)) return null;
  final fromClass = _programs(race.programLabels);
  final fromEvent = _programs(event!.disciplines);
  // A known unsupported class discipline must not inherit a broader event's
  // Sprint label. Word boundaries also keep Supersprint/Sprintathlon separate.
  final unsupportedClass = race.programLabels.any(
    (label) => RegExp(
      r'\b(?:prolog|prologue)\b',
      caseSensitive: false,
    ).hasMatch(label),
  );
  if (fromClass.length > 1 || unsupportedClass) return null;
  final unambiguousEvent =
      event.disciplines.isNotEmpty &&
      event.disciplines.every((label) => _programs([label]).length == 1) &&
      fromEvent.length == 1;
  final program = fromClass.isNotEmpty
      ? fromClass.single
      : unambiguousEvent
      ? fromEvent.single
      : null;
  if (program == null ||
      (fromClass.isNotEmpty &&
          fromEvent.isNotEmpty &&
          !fromEvent.contains(program))) {
    return null;
  }
  final isRelay = race.isRelay || (race.biathlonMetrics?.isRelay ?? false);
  if ((program == BiathlonProgram.relay) != isRelay) return null;
  return program;
}

/// The historical importer assigns positions from the recorded series count.
/// Only sequences compatible with the explicit program can supply positions.
/// Normal/short individual (P,S,P,S), supersprint variants and unknown formats
/// cannot validate that inference. Their measured All values remain usable.
ShootingSelectionResult? _comparisonObservations(
  AthleteRace race,
  BiathlonProgram program,
  ShootingMetric metric,
  ShootingSelection selection,
) {
  final metrics = race.biathlonMetrics;
  if (metrics == null) return null;
  // Supersprint additions can represent penalties after reserve shots. The
  // source has no fired-shot/target semantics to establish five-shot hits or
  // misses. Measured stand time remains usable independently of ammunition.
  if (program == BiathlonProgram.superSprint &&
      metric != ShootingMetric.rangeTime) {
    return null;
  }
  final passes = metrics.shootingSeries.isNotEmpty
      ? metrics.shootingSeries
      : metrics.shootingPasses.values;
  final expectedPositions = switch (program) {
    BiathlonProgram.sprint => ['prone', 'standing'],
    BiathlonProgram.pursuit ||
    BiathlonProgram.massStart => ['prone', 'prone', 'standing', 'standing'],
    _ => <String>[],
  };
  final isRelay = race.isRelay || metrics.isRelay;
  final positionsReliable = isRelay
      ? metrics.isRelayLeg
      : expectedPositions.isNotEmpty &&
            passes.every(
              (pass) =>
                  pass.index > 0 &&
                  pass.index <= expectedPositions.length &&
                  pass.position.trim().toLowerCase() ==
                      expectedPositions[pass.index - 1],
            );
  return selectShootingObservations(
    passes,
    metric,
    selection,
    isRelay: isRelay,
    expectedShootingCount: metrics.expectedShootingCount,
    positionsReliable: positionsReliable,
  );
}

class SeasonComparisonDataset {
  const SeasonComparisonDataset(this.source);

  final AthleteSeasonDataset source;

  AthleteSeason? seasonOf(AthleteRace race) =>
      _isBiathlon(source.eventsById[race.eventId])
      ? source.seasonOf(race)
      : null;

  BiathlonProgram? programOf(AthleteRace race) =>
      comparisonProgramFor(race, source.eventsById[race.eventId]);

  List<AthleteSeason> get seasons {
    final years = {
      for (final race in source.races)
        if (seasonOf(race) case final season?) season.startYear,
    }.toList()..sort((a, b) => b.compareTo(a));
    return [for (final year in years) AthleteSeason(year)];
  }

  List<BiathlonProgram> get programs => [
    for (final program in BiathlonProgram.values)
      if (source.races.any((race) => programOf(race) == program)) program,
  ];

  int get unknownSeasonCount =>
      source.races.where((race) => seasonOf(race) == null).length;
  int get unknownProgramCount => source.races
      .where((race) => seasonOf(race) != null && programOf(race) == null)
      .length;

  SeasonComparisonSample sample({
    required int year,
    required BiathlonProgram program,
    required ShootingSelection selection,
  }) {
    final races = [
      for (final race in source.races)
        if (seasonOf(race)?.startYear == year && programOf(race) == program)
          race,
    ];
    return SeasonComparisonSample(
      year: year,
      races: races,
      statistics: calculateSeasonShootingStatistics(
        races,
        selection,
        selectObservations: (race, metric, selection) =>
            _comparisonObservations(race, program, metric, selection),
      ),
    );
  }
}

class SeasonComparisonSample {
  SeasonComparisonSample({
    required this.year,
    required Iterable<AthleteRace> races,
    required this.statistics,
  }) : races = List.unmodifiable(races);

  final int year;
  final List<AthleteRace> races;
  final SeasonShootingStatistics statistics;
  int get excludedRaceCount => races.where((race) => !race.isFinished).length;
  int get finishedRaceCount => races.length - excludedRaceCount;
}

/// Both panes share union bins and a common count or percentage maximum.
/// Delta is right minus left: hits use percentage points, time uses seconds.
class SeasonShootingComparison {
  SeasonShootingComparison({
    required this.left,
    required this.right,
    required this.metric,
    this.timeBinCount = 8,
  }) {
    if (left.year == right.year) {
      throw ArgumentError('Choose two distinct seasons');
    }
    scale = ShootingDistributionScale.forValues(
      [
        for (final sample in [left, right])
          for (final observation
              in sample.statistics.forMetric(metric).validObservations)
            observation.value!,
      ],
      metric,
      timeBinCount: timeBinCount,
    );
    leftDistribution = SeasonShootingDistribution.fromStatistics(
      left.statistics.forMetric(metric),
      metric,
      scale: scale,
    );
    rightDistribution = SeasonShootingDistribution.fromStatistics(
      right.statistics.forMetric(metric),
      metric,
      scale: scale,
    );
  }

  final SeasonComparisonSample left;
  final SeasonComparisonSample right;
  final ShootingMetric metric;
  final int timeBinCount;
  late final ShootingDistributionScale scale;
  late final SeasonShootingDistribution leftDistribution;
  late final SeasonShootingDistribution rightDistribution;

  double maximumY({required bool percentages}) => [
    for (final distribution in [leftDistribution, rightDistribution])
      for (final bin in distribution.bins)
        percentages ? bin.percentage : bin.count.toDouble(),
  ].fold<double>(0, math.max);

  double? get delta {
    final a = metric == ShootingMetric.hits
        ? left.statistics.hitPercent
        : leftDistribution.mean;
    final b = metric == ShootingMetric.hits
        ? right.statistics.hitPercent
        : rightDistribution.mean;
    if (a == null || b == null) return null;
    return (b - a) / (metric == ShootingMetric.rangeTime ? 1000 : 1);
  }
}
