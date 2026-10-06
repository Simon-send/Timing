import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/results/domain/race_result.dart';
import 'package:results/features/results/domain/split_def.dart';
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

  test('uses visible splits and shows US2 instead of UTS2', () {
    final results = [
      _shootingResult('a', totalMs: 1000, legMs: 100),
      _shootingResult('b', totalMs: 4000, legMs: 200),
      _shootingResult('c', totalMs: 2000, legMs: 300),
      _shootingResult('d', totalMs: 3000, legMs: 400),
    ];
    const visibleSplits = [
      SplitOption(
        id: 'first-leg',
        label: 'Første etappe',
        sort: 1,
        kind: 'split',
      ),
      SplitOption(id: 'uts2', label: 'UTS2', sort: 3, kind: 'rangeOut'),
      SplitOption(id: 'us2', label: 'US2', sort: 4, kind: 'rangeExit'),
    ];

    final data = buildResultSplitAnalysis(
      results,
      visibleSplits: visibleSplits,
    );
    expect(data, isNotNull);
    expect(data!.points.map((point) => point.splitId), ['first-leg', 'us2']);
    expect(data.points.last.label, 'US2');

    final withoutExit = buildResultSplitAnalysis(
      results,
      visibleSplits: visibleSplits.where((split) => split.id != 'us2'),
    );
    expect(withoutExit!.points.map((point) => point.splitId), [
      'first-leg',
      'uts2',
    ]);
  });
}

RaceResult _shootingResult(
  String id, {
  required int totalMs,
  required int legMs,
}) {
  final base = _result(id, totalMs: totalMs, legMs: legMs);
  return RaceResult(
    id: base.id,
    rank: null,
    bib: id,
    name: id,
    club: '',
    totalMs: totalMs,
    totalText: '$totalMs',
    shooting: '',
    status: '',
    splitValues: {
      ...base.splitValues,
      'uts2': _split(
        id: 'uts2',
        label: 'UTS2',
        sort: 3,
        cumMs: legMs * 3,
        legMs: legMs * 3,
      ),
      'us2': _split(
        id: 'us2',
        label: 'US2',
        sort: 4,
        cumMs: legMs * 4,
        legMs: legMs * 4,
      ),
      'hidden': _split(
        id: 'hidden',
        label: 'Intern',
        sort: 5,
        cumMs: legMs * 5,
        legMs: legMs * 5,
      ),
    },
  );
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
