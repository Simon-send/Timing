import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/events/domain/result_event.dart';
import 'package:results/features/profile/domain/athlete_profile.dart';
import 'package:results/features/profile/domain/athlete_season.dart';
import 'package:results/features/profile/domain/biathlon_comparison.dart';
import 'package:results/features/profile/domain/season_shooting_statistics.dart';
import 'package:results/features/results/domain/race_result.dart';
import 'package:results/features/results/domain/shooting_selection.dart';

ShootingPass pass(
  int index, {
  String position = 'prone',
  int? misses = 0,
  int? rangeMs = 10000,
}) => ShootingPass(
  index: index,
  position: position,
  misses: misses,
  rangeMs: rangeMs,
);

AthleteRace race(
  String id, {
  String eventId = 'event',
  String status = '',
  List<ShootingPass> passes = const [],
  BiathlonRaceMetrics? metrics,
  bool relay = false,
  bool relayLeg = false,
  int? expectedCount,
  int? totalMs = 60000,
  bool? finishConfirmed,
}) => AthleteRace(
  finishConfirmed: finishConfirmed,
  eventId: eventId,
  classId: 'class',
  resultId: id,
  athleteId: 'athlete',
  name: 'Athlete',
  className: 'Senior',
  clubName: '',
  teamName: '',
  bib: '1',
  rank: 1,
  finishRank: 1,
  totalText: totalMs == null ? '' : '1:00',
  totalMs: totalMs,
  shooting: '',
  status: status,
  isRelay: relay,
  biathlonMetrics:
      metrics ??
      BiathlonRaceMetrics(
        shootingSeries: passes,
        isRelay: relay,
        isRelayLeg: relayLeg,
        expectedShootingCount: expectedCount,
      ),
);

SeasonShootingStatistics summarize(
  List<AthleteRace> races, [
  ShootingSelection selection = ShootingSelection.all,
]) => calculateSeasonShootingStatistics(races, selection);

void main() {
  test('unconfirmed finish supplies no season shooting observations', () {
    final partial = race('partial', finishConfirmed: false, passes: [pass(1)]);
    expect(partial.isFinished, isFalse);
    expect(partial.isCompletedIndividualBiathlonRace, isFalse);
    final stats = summarize([partial]);
    expect(stats.hits.validCount, 0);
    expect(stats.misses.validCount, 0);
    expect(stats.rangeTime.validCount, 0);
  });

  test('conflicting source and class counts cannot classify partial series', () {
    // The importer infers positions from its two recorded series, although the
    // class reference establishes four. Source index two is not known standing.
    final parsed = RaceResult.fromMap('partial', {
      'totalMs': 60000,
      'analysisSummary': {
        'biathlon': {
          'metrics': {'shootingCount': 2},
          'passes': {
            'shoot1': {
              'index': 1,
              'position': 'prone',
              'misses': 0,
              'rangeMs': 10000,
            },
            'shoot2': {
              'index': 2,
              'position': 'standing',
              'misses': 5,
              'rangeMs': 20000,
            },
          },
        },
      },
    });
    final metrics = BiathlonRaceMetrics.fromResult(
      parsed,
      expectedShootingCount: 4,
    )!;
    final input = [race('partial', metrics: metrics)];
    final all = summarize(input);
    expect(all.knownShotCount, 10);
    expect(all.hitPercent, 50);
    expect(all.rangeTime.validCount, 2);
    for (final selection in ShootingSelection.values.where(
      (value) => value.position != null,
    )) {
      final selected = summarize(input, selection);
      expect(selected.hits.validCount, 0);
      expect(selected.hitPercent, isNull);
      expect(selected.hits.unavailableRaces, hasLength(1));
      expect(selected.rangeTime.validCount, 0);
    }
  });

  test(
    'pools known shots across two- and four-series races with provenance',
    () {
      final short = race('short', passes: [pass(1), pass(2)]);
      final long = race(
        'long',
        passes: [for (var i = 1; i <= 4; i++) pass(i, misses: 5)],
      );
      final result = summarize([short, long]);
      expect(result.totalHits, 10);
      expect(result.knownShotCount, 30);
      expect(result.hitPercent, closeTo(100 / 3, 0.000001));
      expect(result.averageMisses, closeTo(20 / 6, 0.000001));
      expect(result.hits.validCount, 6);
      expect(result.hits.missingCount, 0);
      expect(result.hits.validObservations.first.race, same(short));
      expect(result.hits.validObservations.last.race, same(long));
      expect(result.hits.validObservations.last.index, 4);
      expect(result.hits.validObservations.last.value, 0);
    },
  );

  test('each metric has independent coverage, mean and median', () {
    final result = summarize([
      race(
        'partial',
        expectedCount: 4,
        passes: [
          pass(1, misses: 0, rangeMs: null),
          pass(2, misses: null, rangeMs: 10000),
          pass(3, misses: 2, rangeMs: 20000),
          pass(4, misses: null, rangeMs: 60000),
        ],
      ),
    ]);
    expect(result.hitPercent, 80);
    expect(result.totalHits, 8);
    expect(result.knownShotCount, 10);
    expect(result.averageMisses, 1);
    expect(result.hits.validCount, 2);
    expect(result.hits.missingCount, 2);
    expect(result.misses.validCount, 2);
    expect(result.misses.missingCount, 2);
    expect(result.rangeTime.validCount, 3);
    expect(result.rangeTime.missingCount, 1);
    expect(result.meanRangeTimeMs, 30000);
    expect(result.medianRangeTimeMs, 20000);
  });

  test('even median keeps precision and invalid values stay missing', () {
    final result = summarize([
      race(
        'invalid',
        passes: [
          pass(1, misses: -1, rangeMs: -1),
          pass(2, misses: 6, rangeMs: 0),
          pass(3, rangeMs: 10000),
          pass(4, misses: 5, rangeMs: 10001),
        ],
      ),
    ]);
    expect(result.hits.validCount, 2);
    expect(result.hits.missingCount, 2);
    expect(result.rangeTime.validCount, 2);
    expect(result.rangeTime.missingCount, 2);
    expect(result.averageMisses, 2.5);
    expect(result.meanRangeTimeMs, 10000.5);
    expect(result.medianRangeTimeMs, 10000.5);
  });

  for (final status in ['DNF', 'DNS', 'DFQ', 'DSQ', 'DQ']) {
    test('excludes the entire $status race before observing valid series', () {
      final result = summarize([
        race('finished', passes: [pass(1, misses: 1)]),
        race(status, status: status, passes: [pass(1), pass(2)]),
      ]);
      expect(result.totalHits, 4);
      expect(result.knownShotCount, 5);
      expect(result.rangeTime.validCount, 1);
      for (final metric in ShootingMetric.values) {
        expect(result.forMetric(metric).unavailableRaces, isEmpty);
      }
    });
  }

  test('no recorded counts never falls back to stored rounded percentages', () {
    final result = summarize([
      race('legacy', metrics: const BiathlonRaceMetrics(totalHitPercent: 99)),
      race('uncompleted', totalMs: null, passes: [pass(1)]),
    ]);
    expect(result.hitPercent, isNull);
    expect(result.totalHits, isNull);
    expect(result.knownShotCount, 0);
    expect(result.averageMisses, isNull);
    expect(result.meanRangeTimeMs, isNull);
    expect(result.medianRangeTimeMs, isNull);
    expect(result.hits.missingCount, 0);
    expect(result.hits.unavailableRaces.single.resultId, 'legacy');
    expect(summarize([]).hitPercent, isNull);
  });

  test(
    'missing entire series is not invented; known partial series contribute',
    () {
      final result = summarize([
        race(
          'partial',
          expectedCount: 4,
          passes: [pass(1), pass(3, misses: 1)],
        ),
      ]);
      expect(result.hitPercent, 90);
      expect(result.knownShotCount, 10);
      expect(result.hits.validCount, 2);
      expect(result.hits.missingCount, 0);
    },
  );

  test('relay has range measurements but no known shot denominator', () {
    final result = summarize([
      race('relay', relay: true, passes: [pass(1), pass(2, misses: 2)]),
    ]);
    expect(result.hitPercent, isNull);
    expect(result.averageMisses, isNull);
    expect(result.hits.validCount, 0);
    expect(result.hits.missingCount, 2);
    expect(result.knownShotCount, 0);
    expect(result.rangeTime.validCount, 2);
    expect(result.meanRangeTimeMs, 10000);
  });

  test(
    'numbered samples preserve gaps, unknown positions and raw duplicates',
    () {
      final result = summarize([
        race(
          'known',
          passes: [
            pass(1),
            pass(2, position: 'standing', misses: 2),
          ],
        ),
        race(
          'gap',
          passes: [
            pass(1),
            pass(3, position: 'standing'),
          ],
        ),
        race(
          'unknown',
          passes: [
            pass(1, position: ''),
            pass(2, position: 'standing'),
          ],
        ),
        race(
          'duplicate',
          metrics: BiathlonRaceMetrics(
            shootingPasses: {
              1: pass(1),
              2: pass(2, position: 'standing'),
            },
            shootingSeries: [
              pass(1),
              pass(1),
              pass(2, position: 'standing'),
            ],
          ),
        ),
      ], ShootingSelection.firstStanding);
      expect(result.totalHits, 3);
      expect(result.knownShotCount, 5);
      expect(result.hits.unavailableRaces, hasLength(3));
      expect(result.hits.validObservations.single.index, 2);
    },
  );

  test(
    'persisted local relay positions work; legacy unknown ones cannot guess',
    () {
      final local = race(
        'local',
        relay: true,
        relayLeg: true,
        passes: [
          pass(1),
          pass(2, position: 'standing', rangeMs: 30000),
        ],
      );
      final legacy = race(
        'legacy',
        relay: true,
        relayLeg: true,
        passes: [
          pass(3, position: ''),
          pass(4, position: ''),
        ],
      );
      final team = race(
        'team',
        relay: true,
        passes: [
          pass(1),
          pass(2, position: 'standing'),
        ],
      );
      final result = summarize([
        local,
        legacy,
        team,
      ], ShootingSelection.firstStanding);
      expect(result.rangeTime.validCount, 1);
      expect(result.rangeTime.validObservations.single.race, same(local));
      expect(result.rangeTime.validObservations.single.index, 2);
      expect(result.rangeTime.unavailableRaces, hasLength(2));
      expect(result.hitPercent, isNull);
      expect(summarize([local, legacy, team]).rangeTime.validCount, 6);
    },
  );

  test('full selected season union respects April 30 and May 1 boundaries', () {
    final data = AthleteSeasonDataset(
      races: [
        for (var i = 0; i < 205; i++)
          race('$i', eventId: 'old', passes: [pass(1)]),
        race('new', eventId: 'new', passes: [pass(1, misses: 5)]),
        race('unknown', eventId: 'unknown', passes: [pass(1)]),
      ],
      events: [
        for (final item in {
          'old': DateTime(2025, 4, 30, 23, 59),
          'new': DateTime(2025, 5, 1),
        }.entries)
          ResultEvent(
            id: item.key,
            name: item.key,
            sportName: 'Biathlon',
            date: item.value,
            place: '',
          ),
      ],
    );
    final old = summarize(
      data.select(AthleteSeasonSelection.only({2024})).statisticalRaces,
    );
    final next = summarize(
      data.select(AthleteSeasonSelection.only({2025})).statisticalRaces,
    );
    final both = summarize(
      data.select(AthleteSeasonSelection.only({2024, 2025})).statisticalRaces,
    );
    expect(old.knownShotCount, 1025);
    expect(old.hitPercent, 100);
    expect(next.knownShotCount, 5);
    expect(next.hitPercent, 0);
    expect(both.knownShotCount, 1030);
    expect(both.hits.validCount, 206);
  });
}
