import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/results/domain/race_result.dart';

RaceResult _relay({bool missingMember = false, bool complete = false}) =>
    RaceResult.fromMap('team', {
      'entrant': {'kind': 'team', 'name': 'Testlag'},
      'team': {
        'members': [
          {'legNumber': 1, 'name': 'Første'},
          if (!missingMember) {'legNumber': 2, 'name': 'Andre'},
          {'legNumber': 3, 'name': 'Tredje'},
        ],
        'legs': [
          {
            'legNumber': 3,
            'biathlon': {
              'metrics': {'skiTimeMs': 50000, 'missesTotal': 2},
            },
          },
        ],
      },
      'timingPoints': [
        {
          'setupUid': 'exchange1',
          'code': 'Veksling',
          'sort': 10,
          'legNumber': 1,
          'cumMs': 60000,
        },
        if (complete)
          {
            'setupUid': 'exchange2',
            'code': 'Veksling',
            'sort': 20,
            'legNumber': 2,
            'cumMs': 130000,
          },
        {
          'setupUid': 'mid3',
          'code': 'Mellomtid',
          'sort': 30,
          'legNumber': 3,
          'cumMs': 190000,
          'legMs': 12000,
        },
        {
          'setupUid': 'finish3',
          'code': 'Mål',
          'sort': 40,
          'legNumber': 3,
          'cumMs': 210000,
        },
      ],
    });

void main() {
  test(
    'BH02 unknown immediate exchange cannot rebase later cumulative split',
    () {
      final team = _relay();
      final legs = effectiveRelayLegs(team);
      final third = relayLegRaceResult(team, 3)!;
      expect(legs.map((l) => l.timeMs), [60000, null, null]);
      expect(third.totalMs, isNull);
      expect(third.splitValues[relayLegFinishSplitId]!.cumMs, isNull);
      expect(third.splitValues['finish3']!.cumMs, isNull);
      expect(third.splitValues['mid3']!.cumMs, isNull);
    },
  );
  test('BH02 absent immediate leg cannot bridge two numbered legs', () {
    final third = relayLegRaceResult(_relay(missingMember: true), 3)!;
    expect(third.totalMs, isNull);
    expect(third.splitValues['finish3']!.cumMs, isNull);
  });
  test(
    'independent split and imported biathlon analysis survive unknown start',
    () {
      final third = relayLegRaceResult(_relay(), 3)!;
      expect(third.splitValues['mid3']!.legMs, 12000);
      expect(effectiveSplitLegMs(third, 'mid3'), 12000);
      expect(third.biathlon!.skiTimeMs, 50000);
      expect(third.biathlon!.missesTotal, 2);
    },
  );
  test('first leg and complete relay retain known times', () {
    final team = _relay(complete: true);
    final first = relayLegRaceResult(team, 1)!;
    final third = relayLegRaceResult(team, 3)!;
    expect(effectiveRelayLegs(team).map((l) => l.timeMs), [
      60000,
      70000,
      80000,
    ]);
    expect(first.totalMs, 60000);
    expect(first.splitValues['exchange1']!.cumMs, 60000);
    expect(third.totalMs, 80000);
    expect(third.splitValues['finish3']!.cumMs, 80000);
    expect(third.splitValues['mid3']!.cumMs, 60000);
    expect(third.splitValues['mid3']!.legMs, 12000);
  });
  test('negative rebased cumulative remains unavailable', () {
    final team = RaceResult.fromMap('negative', {
      'team': {
        'members': [
          {'legNumber': 1, 'name': 'A'},
          {'legNumber': 2, 'name': 'B'},
        ],
      },
      'timingPoints': [
        {
          'setupUid': 'exchange1',
          'code': 'Veksling',
          'sort': 10,
          'legNumber': 1,
          'cumMs': 60000,
        },
        {
          'setupUid': 'finish2',
          'code': 'Mål',
          'sort': 20,
          'legNumber': 2,
          'cumMs': 50000,
          'legMs': 5000,
        },
      ],
    });
    final second = relayLegRaceResult(team, 2)!;
    expect(second.totalMs, isNull);
    expect(second.splitValues['finish2']!.cumMs, isNull);
    expect(second.splitValues['finish2']!.legMs, 5000);
  });

  test('a first represented leg above one has an unknown start', () {
    final team = RaceResult.fromMap('partial', {
      'team': {
        'members': [
          {'legNumber': 2, 'name': 'Second'},
        ],
      },
      'timingPoints': [
        {
          'setupUid': 'finish2',
          'code': 'Mål',
          'sort': 20,
          'legNumber': 2,
          'cumMs': 130000,
          'legMs': 5000,
        },
      ],
    });
    final second = relayLegRaceResult(team, 2)!;
    expect(second.totalMs, isNull);
    expect(second.splitValues['finish2']!.cumMs, isNull);
    expect(second.splitValues['finish2']!.legMs, 5000);
  });
  test(
    'a later leg recovers from its known immediate exchange after a gap',
    () {
      final team = RaceResult.fromMap('recovery', {
        'team': {
          'members': [
            {'legNumber': 4, 'name': 'Fourth'},
            {'legNumber': 1, 'name': 'First'},
            {'legNumber': 3, 'name': 'Third'},
            {'legNumber': 2, 'name': 'Second'},
          ],
        },
        'timingPoints': [
          {
            'setupUid': 'exchange1',
            'code': 'Veksling',
            'sort': 10,
            'legNumber': 1,
            'cumMs': 60000,
          },
          {
            'setupUid': 'exchange3',
            'code': 'Veksling',
            'sort': 30,
            'legNumber': 3,
            'cumMs': 210000,
          },
          {
            'setupUid': 'mid4',
            'code': 'Mellomtid',
            'sort': 40,
            'legNumber': 4,
            'cumMs': 245000,
          },
          {
            'setupUid': 'finish4',
            'code': 'Mål',
            'sort': 50,
            'legNumber': 4,
            'cumMs': 280000,
          },
        ],
      });
      expect(effectiveRelayLegs(team).map((leg) => leg.timeMs), [
        60000,
        null,
        null,
        70000,
      ]);
      final fourth = relayLegRaceResult(team, 4)!;
      expect(fourth.totalMs, 70000);
      expect(fourth.splitValues['mid4']!.cumMs, 35000);
      expect(fourth.splitValues['finish4']!.cumMs, 70000);
    },
  );
  test('a known zero exchange is preserved as a valid start', () {
    final team = RaceResult.fromMap('zero', {
      'team': {
        'members': [
          {'legNumber': 1, 'name': 'First'},
          {'legNumber': 2, 'name': 'Second'},
        ],
      },
      'timingPoints': [
        {
          'setupUid': 'exchange1',
          'code': 'Veksling',
          'sort': 10,
          'legNumber': 1,
          'cumMs': 0,
        },
        {
          'setupUid': 'finish2',
          'code': 'Mål',
          'sort': 20,
          'legNumber': 2,
          'cumMs': 5000,
        },
      ],
    });
    final second = relayLegRaceResult(team, 2)!;
    expect(second.totalMs, 5000);
    expect(second.splitValues['finish2']!.cumMs, 5000);
  });
}
