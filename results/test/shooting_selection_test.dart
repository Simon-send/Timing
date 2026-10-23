import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/results/domain/race_result.dart';
import 'package:results/features/results/domain/shooting_selection.dart';
import 'package:results/features/profile/domain/athlete_profile.dart';
import 'package:results/features/profile/domain/biathlon_comparison.dart';

ShootingPass pass(
  int index,
  String position, {
  int? misses = 1,
  int? time = 10000,
}) => ShootingPass(
  index: index,
  position: position,
  misses: misses,
  rangeMs: time,
);

void main() {
  test(
    'real team versus persisted leg mapping does not trust global relay positions',
    () {
      Map<String, Object> shooting(int index, String position) => {
        'index': index,
        'position': position,
        'rangeMs': 10000,
        'misses': 0,
      };
      final team = RaceResult.fromMap('team', {
        'isRelay': true,
        'totalMs': 120000,
        'entrant': {'kind': 'team'},
        'analysisSummary': {
          'biathlon': {
            'passes': {
              'shoot1': shooting(1, 'prone'),
              'shoot2': shooting(2, 'prone'),
              'shoot3': shooting(3, 'standing'),
              'shoot4': shooting(4, 'standing'),
            },
          },
        },
        'team': {
          'members': [
            {'legNumber': 2, 'name': 'Athlete'},
          ],
          'legs': [
            {
              'legNumber': 2,
              'biathlon': {
                'metrics': {'shootingCount': 2},
                'passes': {
                  'shoot1': shooting(1, 'prone'),
                  'shoot2': shooting(2, 'standing'),
                },
              },
            },
          ],
        },
      });
      final teamMetrics = BiathlonRaceMetrics.fromResult(team)!;
      final all = teamMetrics.shootingSelection(
        ShootingMetric.rangeTime,
        ShootingSelection.all,
      );
      expect(all.validObservations, hasLength(4));
      expect(all.observations.every((pass) => pass.position.isEmpty), isTrue);
      expect(all.issue, ShootingSelectionIssue.relayPositionsUnavailable);
      for (final selection in ShootingSelection.values.where(
        (selection) => selection != ShootingSelection.all,
      )) {
        final selected = teamMetrics.shootingSelection(
          ShootingMetric.rangeTime,
          selection,
        );
        expect(selected.validObservations, isEmpty);
        expect(
          selected.issue,
          ShootingSelectionIssue.relayPositionsUnavailable,
        );
      }
      final leg = relayLegRaceResult(team, 2)!;
      final legMetrics = BiathlonRaceMetrics.fromResult(leg)!;
      expect(legMetrics.isRelayLeg, isTrue);
      expect(
        legMetrics
            .shootingSelection(
              ShootingMetric.rangeTime,
              ShootingSelection.firstStanding,
            )
            .validObservations
            .single
            .index,
        2,
      );
      expect(
        legMetrics
            .shootingSelection(ShootingMetric.hits, ShootingSelection.all)
            .issue,
        ShootingSelectionIssue.relayShotDataUnavailable,
      );
    },
  );
  test('mapping keeps missing-data slots and declared shooting count', () {
    final metrics = BiathlonRaceMetrics.fromResult(
      RaceResult.fromMap('mapped', {
        'totalMs': 60000,
        'analysisSummary': {
          'biathlon': {
            'metrics': {'shootingCount': 4},
            'passes': {
              'shoot1': {'index': 1, 'position': 'prone'},
              'shoot2': {'index': 2, 'position': 'prone', 'misses': 0},
              'shoot3': {'index': 3, 'position': 'standing', 'rangeMs': 12345},
            },
          },
        },
      }),
    )!;
    expect(metrics.expectedShootingCount, 4);
    final result = metrics.shootingSelection(
      ShootingMetric.hits,
      ShootingSelection.secondProne,
    );
    expect(result.validObservations.single.index, 2);
    expect(result.validObservations.single.value, 5);
    final all = metrics.shootingSelection(
      ShootingMetric.hits,
      ShootingSelection.all,
    );
    expect(all.observations.map((item) => item.value), [null, 5, null]);
    expect(all.issue, ShootingSelectionIssue.incompleteData);
  });

  test(
    'mapping preserves duplicate-index ambiguity instead of overwriting it',
    () {
      final metrics = BiathlonRaceMetrics.fromResult(
        RaceResult.fromMap('mapped', {
          'totalMs': 60000,
          'analysisSummary': {
            'biathlon': {
              'passes': {
                'a': {'index': 1, 'position': 'prone', 'misses': 0},
                'b': {'index': 1, 'position': 'standing', 'misses': 1},
                'c': {'index': 2, 'position': 'standing', 'misses': 2},
              },
            },
          },
        }),
      )!;
      expect(
        metrics
            .shootingSelection(
              ShootingMetric.hits,
              ShootingSelection.firstStanding,
            )
            .issue,
        ShootingSelectionIssue.ambiguousOrder,
      );
    },
  );

  for (final status in ['DNF', 'DNS', 'DFQ', 'DSQ', 'DQ']) {
    test('entire $status race supplies no statistical observations', () {
      final race = AthleteRace(
        eventId: 'event',
        classId: 'class',
        resultId: status,
        athleteId: 'athlete',
        name: 'Athlete',
        className: 'Class',
        clubName: '',
        teamName: '',
        bib: '1',
        rank: 1,
        finishRank: 1,
        totalMs: 60000,
        totalText: '1:00',
        shooting: '',
        status: status,
        biathlonMetrics: BiathlonRaceMetrics(
          shootingPasses: {1: pass(1, 'prone', misses: 0)},
        ),
      );
      expect(
        race.shootingSelection(ShootingMetric.hits, ShootingSelection.all),
        isNull,
      );
    });
  }

  test(
    'relay flag without team metadata prevents inferred percentages and hits',
    () {
      final metrics = BiathlonRaceMetrics.fromResult(
        RaceResult.fromMap('relay', {
          'totalMs': 60000,
          'isRelay': true,
          'analysisSummary': {
            'biathlon': {
              'passes': {
                'shoot1': {
                  'index': 1,
                  'position': 'prone',
                  'misses': 0,
                  'hits': 5,
                },
              },
            },
          },
        }),
      )!;
      expect(metrics.totalHitPercent, isNull);
      expect(
        metrics
            .shootingSelection(ShootingMetric.hits, ShootingSelection.all)
            .validObservations,
        isEmpty,
      );
    },
  );

  test('invalid shot counts and range times stay missing', () {
    for (final misses in [-1, 6]) {
      expect(
        selectShootingObservations(
          [pass(1, 'prone', misses: misses)],
          ShootingMetric.hits,
          ShootingSelection.all,
        ).validObservations,
        isEmpty,
      );
    }
    for (final time in [-1, 0]) {
      expect(
        selectShootingObservations(
          [pass(1, 'prone', time: time)],
          ShootingMetric.rangeTime,
          ShootingSelection.all,
        ).validObservations,
        isEmpty,
      );
    }
  });
  test('four shootings number within position after sorting race order', () {
    final passes = [
      pass(4, 'standing'),
      pass(2, 'prone'),
      pass(3, 'standing'),
      pass(1, 'prone'),
    ];
    for (final entry in {
      ShootingSelection.firstProne: 1,
      ShootingSelection.secondProne: 2,
      ShootingSelection.firstStanding: 3,
      ShootingSelection.secondStanding: 4,
    }.entries) {
      final result = selectShootingObservations(
        passes,
        ShootingMetric.hits,
        entry.key,
      );
      expect(result.observations.single.index, entry.value);
      expect(result.validObservations.single.value, 4);
    }
  });

  test(
    'two shootings have no second prone or standing; missing is never zero',
    () {
      final passes = [pass(1, 'prone'), pass(2, 'standing')];
      expect(
        selectShootingObservations(
          passes,
          ShootingMetric.misses,
          ShootingSelection.firstStanding,
        ).observations.single.index,
        2,
      );
      for (final selection in [
        ShootingSelection.secondProne,
        ShootingSelection.secondStanding,
      ]) {
        final result = selectShootingObservations(
          passes,
          ShootingMetric.misses,
          selection,
        );
        expect(result.observations, isEmpty);
        expect(result.issue, ShootingSelectionIssue.noMatchingShooting);
      }
    },
  );

  test(
    'earlier unknown, missing and duplicate indices never guess an ordinal',
    () {
      for (final passes in [
        [pass(1, 'unknown'), pass(2, 'standing')],
        [pass(1, 'prone'), pass(3, 'standing')],
        [pass(1, 'prone'), pass(1, 'standing'), pass(2, 'standing')],
      ]) {
        final result = selectShootingObservations(
          passes,
          ShootingMetric.rangeTime,
          ShootingSelection.firstStanding,
        );
        expect(result.validObservations, isEmpty);
        expect(result.issue, ShootingSelectionIssue.ambiguousOrder);
      }
      final known = selectShootingObservations(
        [pass(1, 'unknown'), pass(2, 'standing')],
        ShootingMetric.rangeTime,
        ShootingSelection.standing,
      );
      expect(known.validObservations.single.index, 2);
    },
  );

  test('missing data stays null while valid zero misses is retained', () {
    final result = selectShootingObservations(
      [pass(1, 'prone', misses: 0), pass(2, 'standing', misses: null)],
      ShootingMetric.misses,
      ShootingSelection.all,
    );
    expect(result.observations.map((item) => item.value), [0, null]);
    expect(result.validObservations, hasLength(1));
  });

  test('relay penalties and inferred hits do not become shot observations', () {
    final passes = [
      pass(1, 'prone', misses: 0),
      pass(2, 'standing', misses: 2),
    ];
    for (final metric in [ShootingMetric.hits, ShootingMetric.misses]) {
      final result = selectShootingObservations(
        passes,
        metric,
        ShootingSelection.all,
        isRelay: true,
      );
      expect(result.validObservations, isEmpty);
      expect(result.issue, ShootingSelectionIssue.relayShotDataUnavailable);
    }
    expect(
      selectShootingObservations(
        passes,
        ShootingMetric.rangeTime,
        ShootingSelection.firstStanding,
        isRelay: true,
      ).validObservations.single.index,
      2,
    );
  });

  test(
    'relay missing first index does not turn a later pass into first standing',
    () {
      final result = selectShootingObservations(
        [pass(2, 'standing')],
        ShootingMetric.rangeTime,
        ShootingSelection.firstStanding,
        isRelay: true,
      );
      expect(result.validObservations, isEmpty);
      expect(result.issue, ShootingSelectionIssue.ambiguousOrder);
      final known = selectShootingObservations(
        [pass(2, 'standing')],
        ShootingMetric.rangeTime,
        ShootingSelection.standing,
        isRelay: true,
      );
      expect(known.validObservations.single.value, 10000);
    },
  );
}
