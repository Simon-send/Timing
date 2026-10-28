import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/profile/domain/season_shooting_distribution.dart';
import 'package:results/features/results/domain/shooting_selection.dart';

import 'support/season_shooting_fixtures.dart';

void main() {
  test(
    'five-shot bins retain both extremes, empty bins, counts and shares',
    () {
      final input = race(passes: [pass(1), pass(2, misses: 5), pass(3)]);
      final hits = distribution([input]);
      expect(hits.bins.map((bin) => bin.start), [0, 1, 2, 3, 4, 5]);
      expect(hits.bins.map((bin) => bin.count), [1, 0, 0, 0, 0, 2]);
      expect(hits.bins.first.percentage, closeTo(100 / 3, 0.000001));
      expect(hits.bins.last.percentage, closeTo(200 / 3, 0.000001));
      expect(hits.mean, closeTo(10 / 3, 0.000001));
      expect(hits.median, 5);
      expect(hits.count, 3);
      expect(hits.bins.last.observations.first.race, same(input));
      expect(hits.bins.last.observations.last.index, 3);
      expect(
        distribution([input], metric: ShootingMetric.misses).bins.first.count,
        2,
      );
    },
  );

  test(
    'time edges are lower inclusive, upper exclusive, last upper inclusive',
    () {
      final scale = ShootingDistributionScale.forValues(
        [10000, 30000],
        ShootingMetric.rangeTime,
        timeBinCount: 2,
      );
      final result = distribution(
        [
          race(
            passes: [
              pass(1, time: 10000),
              pass(2, time: 19999),
              pass(3, time: 20000),
              pass(4, time: 30000),
            ],
          ),
        ],
        metric: ShootingMetric.rangeTime,
        scale: scale,
      );
      expect(result.bins.map((bin) => bin.start), [10000, 20000]);
      expect(result.bins.map((bin) => bin.end), [20000, 30000]);
      expect(result.bins.map((bin) => bin.count), [2, 2]);
      expect(result.bins.map((bin) => bin.includesEnd), [false, true]);
      expect(result.bins.last.observations.map((o) => o.value), [20000, 30000]);
      expect(result.bins.map((bin) => bin.percentage), [50, 50]);
    },
  );

  test('common scale preserves empty bins and never loses an observation', () {
    final scale = ShootingDistributionScale.forValues(
      [10000, 50000],
      ShootingMetric.rangeTime,
      timeBinCount: 4,
    );
    final a = distribution(
      [
        race(passes: [pass(1)]),
      ],
      metric: ShootingMetric.rangeTime,
      scale: scale,
    );
    final b = distribution(
      [
        race(passes: [pass(1, time: 50000)]),
      ],
      metric: ShootingMetric.rangeTime,
      scale: scale,
    );
    expect(a.bins.map((bin) => bin.start), b.bins.map((bin) => bin.start));
    expect(a.bins.map((bin) => bin.count), [1, 0, 0, 0]);
    expect(b.bins.map((bin) => bin.count), [0, 0, 0, 1]);
    expect(
      () => distribution(
        [
          race(passes: [pass(1, time: 50001)]),
        ],
        metric: ShootingMetric.rangeTime,
        scale: scale,
      ),
      throwsArgumentError,
    );
    expect(() => distribution([], scale: scale), throwsArgumentError);
  });

  test(
    'rounded time intervals keep equal widths for the chart value scale',
    () {
      final scale = ShootingDistributionScale.forValues(
        [10000, 40000],
        ShootingMetric.rangeTime,
        timeBinCount: 8,
      );
      final result = distribution(
        [
          race(passes: [pass(1), pass(2, time: 40000)]),
        ],
        metric: ShootingMetric.rangeTime,
        scale: scale,
      );
      expect(result.bins.map((bin) => bin.end - bin.start), everyElement(4000));
      expect(result.bins.last.end, 42000);
      expect(result.bins.map((bin) => bin.count).reduce((a, b) => a + b), 2);
    },
  );

  test(
    'provenance does not collapse result IDs across event, stage or class',
    () {
      final inputs = [
        race(passes: [pass(1), pass(2)]),
        race(event: 'other', passes: [pass(1)]),
        race(stage: 'final', passes: [pass(1)]),
        race(classId: 'other-class', passes: [pass(1)]),
      ];
      final result = distribution(inputs);
      expect(result.count, 5);
      expect(result.bins.last.observations.map((o) => o.race), [
        inputs[0],
        inputs[0],
        ...inputs.skip(1),
      ]);
    },
  );

  test(
    'null measurements, whole nonfinishers and relay shot guesses stay out',
    () {
      final result = distribution([
        race(passes: [pass(1, misses: null), pass(2, misses: 2)]),
        race(relay: true, passes: [pass(1)]),
        for (final status in ['DNF', 'DNS', 'DFQ', 'DSQ', 'DQ'])
          race(status: status, passes: [pass(1)]),
      ]);
      expect(result.count, 1);
      expect(result.bins[3].count, 1);
      expect(result.mean, 3);
      expect(result.median, 3);
    },
  );

  test(
    'ambiguous raw duplicate series remain excluded by numbered selection',
    () {
      final result = distribution([
        race(passes: [pass(1), pass(1), pass(2)]),
      ], selection: ShootingSelection.secondProne);
      expect(result.count, 0);
    },
  );

  test('empty and one-point distributions are finite and keep their units', () {
    final empty = distribution([]);
    expect(empty.count, 0);
    expect(empty.mean, isNull);
    expect(empty.median, isNull);
    expect(empty.bins.map((bin) => bin.percentage), everyElement(0));
    final one = distribution([
      race(passes: [pass(1, time: 10001)]),
    ], metric: ShootingMetric.rangeTime);
    expect(one.count, 1);
    expect(one.mean, 10001);
    expect(one.bins.single.count, 1);
    expect(one.bins.single.start, 10000);
    expect(one.bins.single.end, 11000);
    expect(one.bins.single.percentage, 100);
    expect(distribution([], metric: ShootingMetric.rangeTime).bins, isEmpty);
  });
}
