import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/results/domain/race_result.dart';
import 'package:results/features/results/domain/race_result_order.dart';

RaceResult result(String name, {int? rank, int? totalMs, String status = ''}) =>
    RaceResult.fromMap(name, {
      'name': name,
      'rank': rank,
      'totalMs': totalMs,
      'status': status,
    });

void main() {
  test('identical names and times use the existing stable document ID', () {
    final a = RaceResult.fromMap('101', {
      'name': 'Ada',
      'rank': 1,
      'totalMs': 1000,
    });
    final b = RaceResult.fromMap('102', {
      'name': 'Ada',
      'rank': 1,
      'totalMs': 1000,
    });
    expect(compareRaceResults(a, b), lessThan(0));
    expect(compareRaceResults(b, a), greaterThan(0));
  });
  test('a result compares equal to itself with present or missing fields', () {
    final results = [
      result('ranked', rank: 1, totalMs: 1000),
      result('unranked', totalMs: 1000),
      result('untimed', rank: 1),
      result('empty'),
      result('disqualified', rank: 1, totalMs: 1000, status: 'DSQ'),
      result('unfinished', status: 'DNF'),
      result('not started', status: 'DNS'),
    ];
    for (final value in results) {
      expect(compareRaceResults(value, value), 0, reason: value.name);
    }
  });

  test('equal ranks and times use names symmetrically', () {
    for (final rank in [null, 1]) {
      for (final totalMs in [null, 1000]) {
        final a = result('Ada', rank: rank, totalMs: totalMs);
        final b = result('Bert', rank: rank, totalMs: totalMs);
        expect(compareRaceResults(a, b), lessThan(0));
        expect(compareRaceResults(b, a), greaterThan(0));
        expect(compareRaceResults(a, b).sign, -compareRaceResults(b, a).sign);
        expect(
          compareRaceResults(a, result('Ada', rank: rank, totalMs: totalMs)),
          0,
        );
        final sorted = [b, a]..sort(compareRaceResults);
        expect(sorted.map((value) => value.name), ['Ada', 'Bert']);
      }
    }
  });

  test('available rank and time precede missing values in both directions', () {
    final pairs = [
      (result('Z', rank: 1, totalMs: 1000), result('A', totalMs: 1000)),
      (result('Z', rank: 1), result('A')),
      (result('Z', totalMs: 1000), result('A')),
      (result('Z', rank: 1, totalMs: 1000), result('A', rank: 1)),
    ];
    for (final (available, missing) in pairs) {
      expect(compareRaceResults(available, missing), lessThan(0));
      expect(compareRaceResults(missing, available), greaterThan(0));
    }
  });

  test('different ranks precede time and name when both ranks exist', () {
    final faster = result('Ada', rank: 2, totalMs: 900);
    final rankedFirst = result('Zoe', rank: 1, totalMs: 1000);
    expect(compareRaceResults(rankedFirst, faster), lessThan(0));
    expect(compareRaceResults(faster, rankedFirst), greaterThan(0));
  });

  test(
    'known rank precedes missing rank even when the unranked time is faster',
    () {
      final faster = result('Zoe', totalMs: 900);
      final slowerRanked = result('Ada', rank: 1, totalMs: 1000);
      expect(compareRaceResults(slowerRanked, faster), lessThan(0));
      expect(compareRaceResults(faster, slowerRanked), greaterThan(0));
    },
  );

  test('equal ranks compare different times before names', () {
    for (final rank in [null, 1]) {
      final faster = result('Zoe', rank: rank, totalMs: 900);
      final slower = result('Ada', rank: rank, totalMs: 1000);
      expect(compareRaceResults(faster, slower), lessThan(0));
      expect(compareRaceResults(slower, faster), greaterThan(0));
    }
  });

  test('mixed ranks and times do not form the previous three-result cycle', () {
    final a = result('A', rank: 1, totalMs: 1000);
    final b = result('B', rank: 2, totalMs: 500);
    final c = result('C', totalMs: 750);
    expect(compareRaceResults(a, b), lessThan(0));
    expect(compareRaceResults(b, c), lessThan(0));
    expect(compareRaceResults(a, c), lessThan(0));
    for (final permutation in [
      [a, b, c],
      [a, c, b],
      [b, a, c],
      [b, c, a],
      [c, a, b],
      [c, b, a],
    ]) {
      expect(permutation..sort(compareRaceResults), [a, b, c]);
    }
  });

  test('mixed null and status values obey pair and triple ordering laws', () {
    final values = [
      result('A', rank: 1, totalMs: 1000),
      result('B', rank: 2, totalMs: 500),
      result('C', totalMs: 750),
      result('D', rank: 1),
      result('E'),
      result('A', rank: 1, totalMs: 1000),
      result('F', rank: 1, totalMs: 900),
      result('G', totalMs: 500),
      result('DSQ', rank: 1, totalMs: 1, status: 'DSQ'),
      result('DNF', totalMs: 1, status: 'DNF'),
      result('DNS', status: 'DNS'),
    ];
    for (final a in values) {
      expect(compareRaceResults(a, a), 0);
      for (final b in values) {
        final ab = compareRaceResults(a, b);
        expect(
          ab.sign,
          -compareRaceResults(b, a).sign,
          reason: '${a.name}/${b.name}',
        );
        for (final c in values) {
          if (ab <= 0 && compareRaceResults(b, c) <= 0) {
            expect(
              compareRaceResults(a, c),
              lessThanOrEqualTo(0),
              reason: '${a.name}/${b.name}/${c.name}',
            );
          }
        }
      }
    }
  });

  test('completion status precedes rank and time', () {
    final finished = result('Zoe', rank: 9, totalMs: 9000);
    final disqualified = result('DSQ', rank: 1, totalMs: 1, status: 'DSQ');
    final unfinished = result('DNF', rank: 1, totalMs: 1, status: 'DNF');
    final notStarted = result('DNS', rank: 1, totalMs: 1, status: 'DNS');
    final values = [notStarted, unfinished, disqualified, finished]
      ..sort(compareRaceResults);
    expect(values, [finished, disqualified, unfinished, notStarted]);
    expect(compareRaceResults(finished, disqualified), lessThan(0));
    expect(compareRaceResults(disqualified, finished), greaterThan(0));
  });
}
