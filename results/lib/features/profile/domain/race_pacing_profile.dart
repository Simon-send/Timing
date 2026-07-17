import 'dart:math' as math;

import 'athlete_profile.dart';

class RacePacingProfile {
  const RacePacingProfile({
    required this.samples,
    required this.raceCount,
    required this.splitCount,
    required this.excludedRelayCount,
  });

  final List<RacePacingSample> samples;
  final int raceCount;
  final int splitCount;
  final int excludedRelayCount;
}

class RacePacingSample {
  const RacePacingSample({
    required this.timeFraction,
    required this.averageRankFraction,
    required this.lowerRankFraction,
    required this.upperRankFraction,
    required this.raceCount,
  });

  final double timeFraction;
  final double averageRankFraction;
  final double lowerRankFraction;
  final double upperRankFraction;
  final int raceCount;
}

RacePacingProfile buildRacePacingProfile(
  Iterable<AthleteRace> races, {
  int intervalCount = 40,
}) {
  assert(intervalCount > 0);
  final curves = <_RaceCurve>[];
  var splitCount = 0;
  var excludedRelayCount = 0;

  for (final race in races) {
    if (race.isRelay) {
      excludedRelayCount++;
      continue;
    }
    final curve = _curveFor(race);
    if (curve == null) continue;
    curves.add(curve);
    splitCount += curve.splitCount;
  }

  final samples = <RacePacingSample>[];
  for (var interval = 1; interval <= intervalCount; interval++) {
    final timeFraction = interval / intervalCount;
    final values = <double>[
      for (final curve in curves) ?curve.valueAt(timeFraction),
    ]..sort();
    if (values.isEmpty) continue;

    samples.add(
      RacePacingSample(
        timeFraction: timeFraction,
        averageRankFraction:
            values.reduce((sum, value) => sum + value) / values.length,
        lowerRankFraction: _percentile(values, 0.25),
        upperRankFraction: _percentile(values, 0.75),
        raceCount: values.length,
      ),
    );
  }

  return RacePacingProfile(
    samples: samples,
    raceCount: curves.length,
    splitCount: splitCount,
    excludedRelayCount: excludedRelayCount,
  );
}

_RaceCurve? _curveFor(AthleteRace race) {
  final totalMs = race.totalMs;
  final participantCount = race.participantCount;
  if (totalMs == null || totalMs <= 0 || participantCount <= 0) return null;

  final pointsByTime = <double, _RacePoint>{};
  var validSplitCount = 0;
  for (final split in race.splits) {
    final cumMs = split.cumMs;
    final cumRank = split.cumRank;
    if (cumMs == null || cumMs <= 0 || cumRank == null || cumRank <= 0) {
      continue;
    }
    final timeFraction = (cumMs / totalMs).clamp(0.0, 1.0);
    final rankFraction = _rankFraction(
      cumRank,
      split.participantCount ?? participantCount,
    );
    pointsByTime[timeFraction] = _RacePoint(timeFraction, rankFraction);
    validSplitCount++;
  }

  final finishRank = race.finishRank ?? race.rank;
  if (finishRank != null && finishRank > 0) {
    pointsByTime[1] = _RacePoint(
      1,
      _rankFraction(finishRank, participantCount),
    );
  }

  final points = pointsByTime.values.toList()
    ..sort((a, b) => a.timeFraction.compareTo(b.timeFraction));
  if (points.length < 2 || !points.any((point) => point.timeFraction < 0.995)) {
    return null;
  }
  return _RaceCurve(points: points, splitCount: validSplitCount);
}

double _rankFraction(int rank, int participantCount) {
  return rank / math.max(rank, participantCount);
}

double _percentile(List<double> sortedValues, double percentile) {
  if (sortedValues.length == 1) return sortedValues.first;
  final position = (sortedValues.length - 1) * percentile;
  final lowerIndex = position.floor();
  final upperIndex = position.ceil();
  if (lowerIndex == upperIndex) return sortedValues[lowerIndex];
  final weight = position - lowerIndex;
  return sortedValues[lowerIndex] * (1 - weight) +
      sortedValues[upperIndex] * weight;
}

class _RaceCurve {
  const _RaceCurve({required this.points, required this.splitCount});

  final List<_RacePoint> points;
  final int splitCount;

  double? valueAt(double timeFraction) {
    if (timeFraction < points.first.timeFraction ||
        timeFraction > points.last.timeFraction) {
      return null;
    }

    for (var index = 0; index < points.length; index++) {
      final current = points[index];
      if ((current.timeFraction - timeFraction).abs() < 0.000001) {
        return current.rankFraction;
      }
      if (current.timeFraction > timeFraction && index > 0) {
        final previous = points[index - 1];
        final width = current.timeFraction - previous.timeFraction;
        if (width <= 0) return current.rankFraction;
        final ratio = (timeFraction - previous.timeFraction) / width;
        return previous.rankFraction +
            (current.rankFraction - previous.rankFraction) * ratio;
      }
    }
    return points.last.rankFraction;
  }
}

class _RacePoint {
  const _RacePoint(this.timeFraction, this.rankFraction);

  final double timeFraction;
  final double rankFraction;
}
