import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/events/domain/result_event.dart';
import 'package:results/features/profile/domain/athlete_profile.dart';
import 'package:results/features/profile/domain/athlete_season.dart';
import 'package:results/features/profile/domain/season_shooting_comparison.dart';
import 'package:results/features/results/domain/shooting_selection.dart';

import 'support/season_shooting_fixtures.dart';

ResultEvent event(
  String id,
  DateTime? date, {
  String sport = 'Biathlon',
  List<String> disciplines = const ['Sprint'],
}) => ResultEvent(
  id: id,
  name: 'Friendly $id',
  sportName: sport,
  date: date,
  place: '',
  disciplines: disciplines,
);

SeasonComparisonDataset dataset(
  List<AthleteRace> races,
  List<ResultEvent> events,
) =>
    SeasonComparisonDataset(AthleteSeasonDataset(races: races, events: events));

List<AthleteRace> comparisonRaces() => [
  race(
    event: 'old',
    passes: [
      pass(1, misses: 1, time: 35000),
      pass(2, position: 'standing', misses: 1, time: 40000),
    ],
  ),
  race(
    event: 'new',
    resultId: 'first',
    passes: [
      pass(1, time: 30000),
      pass(2, position: 'standing', misses: 1, time: 31000),
    ],
  ),
  race(
    event: 'new',
    resultId: 'second',
    passes: [
      pass(1, misses: 2, time: 28000),
      pass(2, position: 'standing', misses: 2, time: 32000),
    ],
  ),
];

List<ResultEvent> comparisonEvents() => [
  event('old', DateTime(2025, 4, 30, 23, 59, 59, 999)),
  event('new', DateTime(2025, 5, 1)),
];

void main() {
  test(
    'unequal samples use series, whole-status exclusion and absolute delta units',
    () {
      final data = dataset(
        [
          ...comparisonRaces(),
          for (final status in [' dnf ', 'DNS', 'DFQ', 'DSQ', 'DQ'])
            race(event: 'new', status: status, passes: [pass(1)]),
          race(event: 'new', programLabels: ['Mass start'], passes: [pass(1)]),
          race(event: 'relay', relay: true, passes: [pass(1)]),
        ],
        [
          ...comparisonEvents(),
          event('relay', DateTime(2025, 6, 1), disciplines: ['Relay']),
        ],
      );
      SeasonShootingComparison comparison(ShootingMetric metric) =>
          SeasonShootingComparison(
            left: data.sample(
              year: 2024,
              program: BiathlonProgram.sprint,
              selection: ShootingSelection.all,
            ),
            right: data.sample(
              year: 2025,
              program: BiathlonProgram.sprint,
              selection: ShootingSelection.all,
            ),
            metric: metric,
          );
      final hits = comparison(ShootingMetric.hits);
      expect(hits.leftDistribution.count, 2);
      expect(hits.rightDistribution.count, 4);
      expect(hits.right.excludedRaceCount, 5);
      expect(hits.left.statistics.hitPercent, 80);
      expect(hits.right.statistics.hitPercent, 75);
      expect(hits.delta, -5); // percentage points, never -6.25 relative percent
      expect(hits.maximumY(percentages: true), 100);
      expect(hits.maximumY(percentages: false), 2);
      for (final distribution in [
        hits.leftDistribution,
        hits.rightDistribution,
      ]) {
        expect(
          distribution.bins.fold<int>(0, (sum, bin) => sum + bin.count),
          distribution.count,
        );
        expect(
          distribution.bins.fold<double>(0, (sum, bin) => sum + bin.percentage),
          closeTo(100, 0.000001),
        );
      }
      expect(comparison(ShootingMetric.rangeTime).delta, -7.25);
      expect(comparison(ShootingMetric.misses).delta, .25);
    },
  );

  test(
    'union time bins share boundaries, equal widths and inclusive final edge',
    () {
      final data = dataset(comparisonRaces(), comparisonEvents());
      final comparison = SeasonShootingComparison(
        left: data.sample(
          year: 2024,
          program: BiathlonProgram.sprint,
          selection: ShootingSelection.all,
        ),
        right: data.sample(
          year: 2025,
          program: BiathlonProgram.sprint,
          selection: ShootingSelection.all,
        ),
        metric: ShootingMetric.rangeTime,
      );
      expect(
        comparison.leftDistribution.scale,
        same(comparison.rightDistribution.scale),
      );
      final edges = comparison.scale.edges;
      expect(edges.first, 28000);
      expect(edges.last, 40000);
      expect({
        for (var i = 1; i < edges.length; i++) edges[i] - edges[i - 1],
      }, hasLength(1));
      expect(comparison.scale.indexOf(edges[1]), 1);
      expect(
        comparison.scale.indexOf(edges.last),
        comparison.scale.binCount - 1,
      );
      expect(
        comparison.leftDistribution.bins.last.observations.single.value,
        40000,
      );
    },
  );

  test(
    'unknown sport/date/program and contradictory labels never infer cohorts',
    () {
      final data = dataset(
        [
          race(event: 'no-date'),
          race(event: 'other-sport'),
          race(event: 'no-program'),
          race(event: 'ambiguous'),
          race(event: 'contradiction', programLabels: ['Normal']),
          race(event: 'specific', programLabels: ['Sprint']),
          race(event: 'super'),
          race(event: 'sprint-relay', relay: true),
        ],
        [
          event('no-date', null),
          event('other-sport', DateTime(2025, 6, 1), sport: 'Unknown'),
          event('no-program', DateTime(2025, 6, 1), disciplines: []),
          event(
            'ambiguous',
            DateTime(2025, 6, 1),
            disciplines: ['Sprint', 'Normal'],
          ),
          event('contradiction', DateTime(2025, 6, 1)),
          event(
            'specific',
            DateTime(2025, 6, 1),
            disciplines: ['Sprint', 'Normal'],
          ),
          event('super', DateTime(2025, 6, 1), disciplines: ['Supersprint']),
          event('sprint-relay', DateTime(2025, 6, 1)),
        ],
      );
      expect(data.unknownSeasonCount, 2);
      expect(data.unknownProgramCount, 4);
      expect(data.programOf(data.source.races[5]), BiathlonProgram.sprint);
      expect(data.programOf(data.source.races[6]), BiathlonProgram.superSprint);
      expect(
        comparisonProgramFor(
          race(programLabels: ['Prolog']),
          event('event', DateTime(2025, 6, 1)),
        ),
        isNull,
      );
      expect(
        comparisonProgramFor(
          race(),
          event(
            'event',
            DateTime(2025, 6, 1),
            disciplines: ['Sprint', 'Unknown format'],
          ),
        ),
        isNull,
      );
      for (final labels in [
        ['Sprint', 'Normal'],
        ['Sprint/Normal'],
        ['G15', '10 km'],
        ['Sprintathlon'],
        ['Prolog'],
      ]) {
        expect(
          comparisonProgramFor(
            race(programLabels: labels),
            event('event', DateTime(2025, 6, 1), disciplines: []),
          ),
          isNull,
        );
      }
    },
  );

  test(
    'normal historical positions remain unknown; All retains measured values',
    () {
      final data = dataset(
        [
          race(
            event: 'normal',
            passes: [
              pass(1),
              pass(2),
              pass(3, position: 'standing'),
              pass(4, position: 'standing'),
            ],
          ),
        ],
        [
          event('normal', DateTime(2025, 5, 1), disciplines: ['Normal']),
        ],
      );
      final all = data.sample(
        year: 2025,
        program: BiathlonProgram.individual,
        selection: ShootingSelection.all,
      );
      expect(all.statistics.hits.validCount, 4);
      expect(
        all.statistics.hits.observations.every(
          (observation) => observation.position.isEmpty,
        ),
        isTrue,
      );
      final selected = data.sample(
        year: 2025,
        program: BiathlonProgram.individual,
        selection: ShootingSelection.standing,
      );
      expect(selected.statistics.hits.validCount, 0);
      expect(selected.statistics.hits.unavailableRaces, hasLength(1));
    },
  );

  test(
    'missing second series, empty season and same-year calls stay explicit',
    () {
      final data = dataset([
        race(event: 'old', passes: [pass(1)]),
      ], comparisonEvents());
      final missing = data.sample(
        year: 2024,
        program: BiathlonProgram.sprint,
        selection: ShootingSelection.secondProne,
      );
      final empty = data.sample(
        year: 2025,
        program: BiathlonProgram.sprint,
        selection: ShootingSelection.all,
      );
      expect(missing.statistics.hits.observations, isEmpty);
      expect(missing.statistics.hits.unavailableRaces, hasLength(1));
      expect(empty.statistics.hitPercent, isNull);
      final comparison = SeasonShootingComparison(
        left: missing,
        right: empty,
        metric: ShootingMetric.rangeTime,
      );
      expect(comparison.delta, isNull);
      expect(comparison.scale.edges, isEmpty);
      expect(
        () => SeasonShootingComparison(
          left: empty,
          right: empty,
          metric: ShootingMetric.hits,
        ),
        throwsArgumentError,
      );
      expect(data.seasons.single.startYear, 2024);
    },
  );
}
