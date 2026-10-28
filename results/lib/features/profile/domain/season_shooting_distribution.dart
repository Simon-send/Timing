import 'dart:math' as math;

import '../../results/domain/shooting_selection.dart';
import 'season_shooting_statistics.dart';

/// An explicit scale can be built from the union of several samples so that
/// their bins remain comparable. Times and boundaries are integer milliseconds.
class ShootingDistributionScale {
  ShootingDistributionScale._(this.metric, Iterable<int> edges)
    : edges = List.unmodifiable(edges);

  factory ShootingDistributionScale.forValues(
    Iterable<int> values,
    ShootingMetric metric, {
    int timeBinCount = 8,
  }) {
    if (timeBinCount < 1 || timeBinCount > 40) {
      throw ArgumentError.value(timeBinCount, 'timeBinCount');
    }
    if (metric != ShootingMetric.rangeTime) {
      return ShootingDistributionScale._(metric, [0, 1, 2, 3, 4, 5]);
    }
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return ShootingDistributionScale._(metric, []);
    final start = sorted.first ~/ 1000 * 1000;
    final end = math.max(start + 1000, (sorted.last / 1000).ceil() * 1000);
    final width = ((end - start) / timeBinCount / 1000).ceil() * 1000;
    final count = ((end - start) / width).ceil();
    return ShootingDistributionScale._(metric, [
      for (var i = 0; i < count; i++) start + i * width,
      start + count * width,
    ]);
  }

  final ShootingMetric metric;

  /// For hits/misses each edge is a discrete value; for time these are the
  /// boundaries of adjacent intervals. Only the final time interval includes
  /// its upper boundary. Empty time samples have no inferred boundaries.
  final List<int> edges;

  int get binCount => metric == ShootingMetric.rangeTime
      ? math.max(0, edges.length - 1)
      : edges.length;

  int indexOf(int value) {
    if (metric != ShootingMetric.rangeTime) {
      return value >= 0 && value <= 5 ? value : -1;
    }
    for (var i = 0; i < binCount; i++) {
      if (value >= edges[i] &&
          (value < edges[i + 1] ||
              (i == binCount - 1 && value == edges[i + 1]))) {
        return i;
      }
    }
    return -1;
  }
}

class SeasonShootingBin {
  SeasonShootingBin({
    required this.start,
    required this.end,
    required this.includesEnd,
    required Iterable<SeasonShootingObservation> observations,
    required this.totalCount,
  }) : observations = List.unmodifiable(observations);

  final int start;
  final int end;
  final bool includesEnd;
  final List<SeasonShootingObservation> observations;
  final int totalCount;
  int get count => observations.length;
  double get percentage => totalCount == 0 ? 0 : count * 100 / totalCount;
}

/// Never derives series counts from rounded percentages or race aggregates.
/// Call with calculateSeasonShootingStatistics(fullSelectedScope, selection)
/// so status, source-order and relay safeguards have already been applied.
class SeasonShootingDistribution {
  SeasonShootingDistribution.fromStatistics(
    SeasonShootingMetricStatistics statistics,
    ShootingMetric metric, {
    ShootingDistributionScale? scale,
  }) : scale =
           scale ??
           ShootingDistributionScale.forValues(
             statistics.validObservations.map(
               (observation) => observation.value!,
             ),
             metric,
           ),
       count = statistics.validCount,
       mean = statistics.mean,
       median = statistics.median {
    if (this.scale.metric != metric) {
      throw ArgumentError('Distribution scale must use the selected metric');
    }
    final groups = List.generate(
      this.scale.binCount,
      (_) => <SeasonShootingObservation>[],
    );
    for (final observation in statistics.validObservations) {
      final index = this.scale.indexOf(observation.value!);
      if (index < 0) {
        throw ArgumentError('Distribution scale does not cover the sample');
      }
      groups[index].add(observation);
    }
    bins = List.unmodifiable([
      for (var i = 0; i < groups.length; i++)
        SeasonShootingBin(
          start: this.scale.edges[i],
          end: metric == ShootingMetric.rangeTime
              ? this.scale.edges[i + 1]
              : this.scale.edges[i],
          includesEnd:
              metric != ShootingMetric.rangeTime || i == groups.length - 1,
          observations: groups[i],
          totalCount: count,
        ),
    ]);
  }

  final ShootingDistributionScale scale;
  late final List<SeasonShootingBin> bins;
  final int count;
  final double? mean;
  final double? median;
}
