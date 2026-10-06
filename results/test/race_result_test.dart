import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/results/domain/race_result.dart';

void main() {
  test('reads whether a result advanced to a later stage', () {
    expect(
      RaceResult.fromMap('qualified', {'advanced': true}).advanced,
      isTrue,
    );
    expect(RaceResult.fromMap('unknown', const {}).advanced, isFalse);
  });

  test('derives missing leg time from cumulative split times', () {
    final result = RaceResult.fromMap('result', {
      'rawPasses': [
        {'setupUid': 'first', 'cumMs': 1000},
        {'setupUid': 'second', 'cumMs': 2400},
      ],
    });

    expect(effectiveSplitLegMs(result, 'first'), 1000);
    expect(effectiveSplitLegMs(result, 'second'), 1400);
  });

  test('sums independent split legs without accepting partial data', () {
    final result = RaceResult.fromMap('result', {
      'rawPasses': [
        {'setupUid': 'first', 'cumMs': 1000, 'legMs': 1000},
        {'setupUid': 'middle', 'cumMs': 2400, 'legMs': 1400},
        {'setupUid': 'last', 'cumMs': 3900, 'legMs': 1500},
      ],
    });

    expect(combinedSplitLegMs(result, ['last', 'first']), 2500);
    expect(combinedSplitLegMs(result, ['first', 'missing']), isNull);
    expect(combinedSplitLegMs(result, const []), isNull);
  });

  test('matches search against athlete, club, team, and bib', () {
    final result = RaceResult.fromMap('result-1', {
      'name': 'Elle Simensen',
      'clubName': 'Alta Skiskytterlag',
      'teamName': 'Team Nordlys',
      'bib': '314',
    });

    expect(result.matchesSearch('elle'), isTrue);
    expect(result.matchesSearch('SKISKYTTERLAG'), isTrue);
    expect(result.matchesSearch('team nordlys'), isTrue);
    expect(result.matchesSearch('314'), isTrue);
    expect(result.matchesSearch('ingen treff'), isFalse);
    expect(result.matchesSearch(''), isTrue);
  });

  test('biathlon ski time uses netSkiTimeMs', () {
    final result = RaceResult.fromMap('result-1', {
      'analysis': {'courseTimeMs': 400000, 'netSkiTimeMs': 335000},
    });

    expect(result.biathlon?.netSkiTimeMs, 335000);
  });

  test('reads public biathlon analysis with ski laps', () {
    final result = RaceResult.fromMap('result-1', {
      'analysisSummary': {
        'biathlon': {
          'metrics': {
            'skiTimeMs': 310000,
            'netSkiTimeMs': 335000,
            'shootingTimeMs': 65000,
          },
          'passes': {
            'shoot1': {
              'index': 1,
              'rangeMs': 30000,
              'rangeRank': 2,
              'misses': 1,
            },
          },
          'laps': {
            'lap1': {
              'skiMs': 100000,
              'startCode': 'start',
              'endCode': 'INS1',
              'beforeShooting': 1,
            },
            'lap2': {
              'skiMs': 120000,
              'startCode': 'UTS1',
              'endCode': 'INS2',
              'beforeShooting': 2,
            },
          },
        },
      },
    });

    expect(result.biathlon?.skiTimeMs, 310000);
    expect(result.biathlon?.netSkiTimeMs, 335000);
    expect(result.biathlon?.shootingTimeMs, 65000);
    expect(result.biathlon?.passAt(1)?.rangeRank, 2);
    expect(result.biathlon?.laps, hasLength(2));
    expect(result.biathlon?.lapAt(2)?.skiMs, 120000);
    expect(result.biathlon?.lapAt(2)?.startCode, 'UTS1');
  });

  test('derives ski time from US-to-INS laps when the metric is missing', () {
    final result = RaceResult.fromMap('result-1', {
      'analysisSummary': {
        'biathlon': {
          'metrics': {'netSkiTimeMs': 1153900, 'penaltyTimeMs': 21300},
          'laps': {
            'lap1': {'skiMs': 304000, 'startCode': 'start', 'endCode': 'INS1'},
            'lap2': {'skiMs': 424600, 'startCode': 'US1', 'endCode': 'INS2'},
            'lap3': {'skiMs': 404000, 'startCode': 'US2', 'endCode': 'Mål'},
          },
        },
      },
    });

    expect(result.biathlon?.skiTimeMs, 1132600);
    expect(result.biathlon?.netSkiTimeMs, 1153900);
  });

  test('schema v3 leaves irrelevant sport analysis absent', () {
    final result = RaceResult.fromMap('result-1', {
      'schemaVersion': 3,
      'entrant': {'kind': 'athlete', 'name': 'Ada', 'bib': '7'},
      'timingPoints': [
        {'setupUid': 'finish', 'cumMs': 120000},
      ],
    });

    expect(result.biathlon, isNull);
    expect(result.name, 'Ada');
    expect(result.splitValues['finish']?.cumMs, 120000);
  });

  test('relay legs are calculated from cumulative exchange times', () {
    final result = RaceResult.fromMap('team-1', {
      'entrant': {'kind': 'team', 'name': 'Oslo lag 1'},
      'team': {
        'members': [
          {'legNumber': 1, 'name': 'Ada'},
          {'legNumber': 2, 'name': 'Grace'},
        ],
      },
      'timingPoints': [
        {
          'setupUid': 'exchange-1',
          'code': '1. Veksling',
          'sort': 1,
          'legNumber': 1,
          'cumMs': 60000,
          'cumRank': 3,
        },
        {
          'setupUid': 'finish',
          'code': 'Mål',
          'sort': 2,
          'legNumber': 2,
          'cumMs': 130000,
        },
      ],
    });

    final legs = effectiveRelayLegs(result);
    expect(legs.map((leg) => leg.timeMs), [60000, 70000]);
    expect(legs.map((leg) => leg.member?.name), ['Ada', 'Grace']);
    expect(legs.map((leg) => leg.splitId), ['exchange-1', 'finish']);
    expect(legs.first.totalRank, 3);
  });

  test('relay leg results rebase splits and add a shared leg finish', () {
    final team = RaceResult.fromMap('team-1', {
      'stageId': 'relay-stage',
      'rank': 5,
      'entrant': {'kind': 'team', 'name': 'Oslo lag 1', 'bib': '7'},
      'team': {
        'members': [
          {'legNumber': 1, 'name': 'Ada', 'athleteId': 'athlete:1'},
          {'legNumber': 2, 'name': 'Grace', 'athleteId': 'athlete:2'},
        ],
      },
      'timingPoints': [
        {
          'setupUid': 'leg-1-finish',
          'code': 'Veksling',
          'sort': 10,
          'legNumber': 1,
          'cumMs': 60000,
        },
        {
          'setupUid': 'leg-2-mid',
          'code': 'Etappe 2 mellomtid',
          'sort': 20,
          'legNumber': 2,
          'cumMs': 90000,
        },
        {
          'setupUid': 'leg-2-finish',
          'code': 'Mål',
          'sort': 30,
          'legNumber': 2,
          'cumMs': 130000,
        },
      ],
    });

    final leg = relayLegRaceResult(team, 2)!;

    expect(leg.id, 'team-1::relay-leg-2');
    expect(leg.detailResultId, 'team-1');
    expect(leg.relayLegNumber, 2);
    expect(leg.relayOverallRank, 5);
    expect(leg.name, 'Grace');
    expect(leg.athleteId, 'athlete:2');
    expect(leg.team, 'Oslo lag 1');
    expect(leg.totalMs, 70000);
    expect(leg.splitValues['leg-2-mid']?.cumMs, 30000);
    expect(leg.splitValues['leg-2-finish']?.cumMs, 70000);
    expect(leg.splitValues, isNot(contains('leg-1-finish')));
    expect(leg.splitValues[relayLegFinishSplitId]?.cumMs, 70000);
  });

  test('different relay legs share only the synthetic full-leg split', () {
    RaceResult team(String id, int offset) => RaceResult.fromMap(id, {
      'entrant': {'kind': 'team', 'name': 'Lag $id'},
      'team': {
        'members': [
          {'legNumber': 1, 'name': 'Første $id'},
          {'legNumber': 2, 'name': 'Andre $id'},
        ],
      },
      'timingPoints': [
        {
          'setupUid': 'short-course-finish',
          'code': 'Veksling',
          'sort': 10,
          'legNumber': 1,
          'cumMs': 60000 + offset,
        },
        {
          'setupUid': 'long-course-mid',
          'code': 'Mellomtid',
          'sort': 20,
          'legNumber': 2,
          'cumMs': 90000 + offset,
        },
        {
          'setupUid': 'long-course-finish',
          'code': 'Mål',
          'sort': 30,
          'legNumber': 2,
          'cumMs': 130000 + offset,
        },
      ],
    });

    final teams = [team('a', 0), team('b', 1000)];
    final firstLeg = relayLegRaceResults(teams, 1);
    final secondLeg = relayLegRaceResults(teams, 2);
    final sharedIds = firstLeg.first.splitValues.keys.toSet().intersection(
      secondLeg.first.splitValues.keys.toSet(),
    );

    expect(sharedIds, {relayLegFinishSplitId});
    expect(firstLeg.map((result) => result.totalMs), [60000, 61000]);
    expect(secondLeg.map((result) => result.totalMs), [70000, 70000]);
  });

  test('biathlon relay leg keeps only its shooting analysis', () {
    final team = RaceResult.fromMap('biathlon-team', {
      'rank': 4,
      'entrant': {'kind': 'team', 'name': 'Alta lag 1'},
      'team': {
        'members': [
          {'legNumber': 1, 'name': 'Ada'},
          {'legNumber': 2, 'name': 'Grace'},
        ],
      },
      'analysis': {
        'biathlon': {
          'metrics': {
            'skiTimeMs': 110000,
            'netSkiTimeMs': 115000,
            'shootingTimeMs': 15000,
            'penaltyTimeMs': 5000,
            'missesTotal': 3,
          },
          'passes': {
            'shoot1': {
              'index': 1,
              'rangeMs': 4000,
              'misses': 1,
              'penaltyMs': 2000,
              'position': 'prone',
            },
            'shoot2': {
              'index': 2,
              'rangeMs': 4000,
              'misses': 1,
              'penaltyMs': 2000,
              'position': 'standing',
            },
            'shoot3': {
              'index': 3,
              'rangeMs': 5000,
              'misses': 1,
              'penaltyMs': 1000,
              'position': 'prone',
            },
            'shoot4': {
              'index': 4,
              'rangeMs': 6000,
              'misses': 0,
              'penaltyMs': 0,
              'position': 'standing',
            },
          },
        },
      },
      'timingPoints': [
        {
          'setupUid': 'shoot-1',
          'code': 'S1',
          'kind': 'shooting',
          'sort': 10,
          'legNumber': 1,
          'cumMs': 25000,
          'additionParts': [1],
        },
        {
          'setupUid': 'shoot-2',
          'code': 'S2',
          'kind': 'shooting',
          'sort': 20,
          'legNumber': 1,
          'cumMs': 45000,
          'additionParts': [1, 1],
        },
        {
          'setupUid': 'exchange',
          'code': 'Veksling',
          'sort': 30,
          'legNumber': 1,
          'cumMs': 60000,
          'additionParts': [1, 1],
        },
        {
          'setupUid': 'shoot-3',
          'code': 'S3',
          'kind': 'shooting',
          'sort': 40,
          'legNumber': 2,
          'cumMs': 85000,
          'additionParts': [1, 1, 1],
        },
        {
          'setupUid': 'shoot-4',
          'code': 'S4',
          'kind': 'shooting',
          'sort': 50,
          'legNumber': 2,
          'cumMs': 110000,
          'additionParts': [1, 1, 1, 0],
        },
        {
          'setupUid': 'finish',
          'code': 'Mål',
          'kind': 'finish',
          'sort': 60,
          'legNumber': 2,
          'cumMs': 130000,
          'additionParts': [1, 1, 1, 0],
        },
      ],
    });

    final leg = relayLegRaceResult(team, 2)!;
    final analysis = leg.biathlon!;

    expect(analysis.passes.map((pass) => pass.index), [3, 4]);
    expect(analysis.shootingTimeMs, 11000);
    expect(analysis.penaltyTimeMs, 1000);
    expect(analysis.missesTotal, 1);
    expect(analysis.netSkiTimeMs, 59000);
    expect(analysis.skiTimeMs, 58000);
    expect(leg.shooting, '1+0');
    expect(leg.splitValues['finish']?.additionParts, [1, 0]);
    expect(leg.relayOverallRank, 4);
  });

  test('relay leg prefers analysis calculated by the importer', () {
    final team = RaceResult.fromMap('team', {
      'entrant': {'kind': 'team', 'name': 'Alta lag'},
      'team': {
        'members': [
          {'legNumber': 2, 'name': 'Grace'},
        ],
        'legs': [
          {
            'legNumber': 2,
            'biathlon': {
              'metrics': {
                'skiTimeMs': 50000,
                'netSkiTimeMs': 51000,
                'shootingTimeMs': 9000,
                'penaltyTimeMs': 1000,
                'missesTotal': 2,
              },
              'passes': {
                'shoot1': {
                  'index': 1,
                  'rangeMs': 4000,
                  'misses': 1,
                  'penaltyMs': 500,
                  'position': 'prone',
                },
                'shoot2': {
                  'index': 2,
                  'rangeMs': 5000,
                  'misses': 1,
                  'penaltyMs': 500,
                  'position': 'standing',
                },
              },
            },
          },
        ],
      },
      'timingPoints': [
        {
          'setupUid': 'finish',
          'code': 'Mål',
          'kind': 'finish',
          'sort': 10,
          'legNumber': 2,
          'cumMs': 60000,
        },
      ],
    });

    final leg = relayLegRaceResult(team, 2)!;

    expect(leg.biathlon?.passes.map((pass) => pass.index), [1, 2]);
    expect(leg.biathlon?.skiTimeMs, 50000);
    expect(leg.biathlon?.missesTotal, 2);
    expect(leg.shooting, '1+1');
  });

  test('reads DNF and DNS from split data and sorts them last', () {
    final finished = RaceResult.fromMap('finished', {
      'rank': 3,
      'totalMs': 120000,
      'totalText': '2:00.0',
      'status': 'TIME',
    });
    final dnf = RaceResult.fromMap('dnf', {
      'rank': 1,
      'totalMs': 60000,
      'totalText': '1:00.0',
      'rawPasses': [
        {'status': 'DNF', 'cumMs': 60000},
      ],
    });
    final dns = RaceResult.fromMap('dns', {
      'rank': 2,
      'rawPasses': [
        {'StatusTekst': 'DNS'},
      ],
    });

    final results = [dns, dnf, finished]
      ..sort((a, b) => a.statusSortOrder.compareTo(b.statusSortOrder));

    expect(results.map((result) => result.id), ['finished', 'dnf', 'dns']);
    expect(dnf.isFinished, isFalse);
    expect(dns.isFinished, isFalse);
  });
}
