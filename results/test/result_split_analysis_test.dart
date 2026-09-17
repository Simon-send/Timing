import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/results/domain/race_result.dart';
import 'package:results/features/results/presentation/results_page.dart';

void main() {
  test('uses leg times and excludes the finish marker from split analysis', () {
    final data = buildResultSplitAnalysis([
      _result('a', totalMs: 1000, legMs: 100),
      _result('b', totalMs: 4000, legMs: 200),
      _result('c', totalMs: 2000, legMs: 300),
      _result('d', totalMs: 3000, legMs: 400),
    ]);

    expect(data, isNotNull);
    expect(data!.points, hasLength(2));
    expect(data.points.map((point) => point.splitId), [
      'first-leg',
      'second-leg',
    ]);

    final firstLeg = data.points.first;
    expect(firstLeg.timeCorrelation, closeTo(0.4, 0.0001));
    expect(firstLeg.rankCorrelation, closeTo(0.4, 0.0001));
  });
}

RaceResult _result(String id, {required int totalMs, required int legMs}) {
  return RaceResult(
    id: id,
    rank: null,
    bib: id,
    name: id,
    club: '',
    totalMs: totalMs,
    totalText: '$totalMs',
    shooting: '',
    status: '',
    splitValues: {
      'first-leg': _split(
        id: 'first-leg',
        label: 'Første etappe',
        sort: 1,
        cumMs: totalMs,
        legMs: legMs,
      ),
      'second-leg': _split(
        id: 'second-leg',
        label: 'Andre etappe',
        sort: 2,
        cumMs: totalMs,
        legMs: legMs * 2,
      ),
      'finish': _split(
        id: 'finish',
        label: 'Mål',
        sort: 3,
        cumMs: totalMs,
        legMs: totalMs,
        kind: 'finish',
      ),
    },
  );
}

SplitValue _split({
  required String id,
  required String label,
  required int sort,
  required int cumMs,
  required int legMs,
  String kind = 'split',
}) {
  return SplitValue(
    id: id,
    label: label,
    sort: sort,
    cumRank: null,
    legRank: null,
    cumMs: cumMs,
    legMs: legMs,
    cumText: '$cumMs',
    legText: '$legMs',
    status: '',
    addition: '',
    additionParts: const [],
    kind: kind,
  );
}
