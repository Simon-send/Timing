import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/results/domain/race_result.dart';

void main() {
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

  test('matches search against athlete, club, and team', () {
    final result = RaceResult.fromMap('result-1', {
      'name': 'Elle Simensen',
      'clubName': 'Alta Skiskytterlag',
      'teamName': 'Team Nordlys',
    });

    expect(result.matchesSearch('elle'), isTrue);
    expect(result.matchesSearch('SKISKYTTERLAG'), isTrue);
    expect(result.matchesSearch('team nordlys'), isTrue);
    expect(result.matchesSearch('ingen treff'), isFalse);
    expect(result.matchesSearch(''), isTrue);
  });

  test('biathlon ski time uses netSkiTimeMs', () {
    final result = RaceResult.fromMap('result-1', {
      'analysis': {'courseTimeMs': 400000, 'netSkiTimeMs': 335000},
    });

    expect(result.biathlon.netSkiTimeMs, 335000);
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
