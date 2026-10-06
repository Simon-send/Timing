import '../../../core/firebase/firestore_mappers.dart';
import '../../results/domain/race_result.dart';

enum BiathlonMetric {
  finishTime,
  skiTime,
  shootingTime,
  proneHitPercent,
  standingHitPercent,
  totalHitPercent;

  String get fieldName => switch (this) {
    BiathlonMetric.finishTime => 'finishTimeMs',
    BiathlonMetric.skiTime => 'skiTimeMs',
    BiathlonMetric.shootingTime => 'shootingTimeMs',
    BiathlonMetric.proneHitPercent => 'proneHitPercent',
    BiathlonMetric.standingHitPercent => 'standingHitPercent',
    BiathlonMetric.totalHitPercent => 'totalHitPercent',
  };

  bool get isPercentage => switch (this) {
    proneHitPercent || standingHitPercent || totalHitPercent => true,
    _ => false,
  };
}

/// Arithmetic mean of valid race percentages; missing data is not a zero.
BiathlonBenchmarkValue? averageBiathlonHitPercent(
  Iterable<BiathlonRaceMetrics> races,
  BiathlonMetric metric,
) {
  if (!metric.isPercentage) return null;
  final values = races
      .map((race) => race.valueFor(metric))
      .whereType<double>()
      .where((value) => value.isFinite && value >= 0 && value <= 100)
      .toList();
  if (values.isEmpty) return null;
  return BiathlonBenchmarkValue(
    mean: values.reduce((a, b) => a + b) / values.length,
    count: values.length,
  );
}

class BiathlonRaceMetrics {
  const BiathlonRaceMetrics({
    this.finishTimeMs,
    this.skiTimeMs,
    this.shootingTimeMs,
    this.proneHitPercent,
    this.standingHitPercent,
    this.totalHitPercent,
    this.extraMetrics = const {},
    this.timingPoints = const {},
    this.shootingPasses = const {},
    this.extraPassValues = const {},
    this.laps = const {},
  });

  static BiathlonRaceMetrics? fromResult(
    RaceResult result, {
    Map<String, dynamic> publicMetrics = const {},
    Map<String, dynamic> publicPasses = const {},
    int? expectedShootingCount,
  }) {
    final finishRank =
        result.isFinished && result.finishRank != null && result.finishRank! > 0
        ? result.finishRank!.toDouble()
        : null;
    final analysis = result.biathlon;
    if (analysis == null || !analysis.hasData) {
      return result.totalMs != null && result.totalMs! > 0
          ? BiathlonRaceMetrics(
              finishTimeMs: result.totalMs,
              extraMetrics: {'finishRank': ?finishRank},
            )
          : null;
    }

    final passes = analysis.passes;
    final declaredShootingCount = asInt(publicMetrics['shootingCount']);
    final shootingCount =
        expectedShootingCount != null && expectedShootingCount > 0
        ? expectedShootingCount
        : declaredShootingCount != null && declaredShootingCount > 0
        ? declaredShootingCount
        : passes.fold<int>(
            0,
            (maxIndex, pass) => pass.index > maxIndex ? pass.index : maxIndex,
          );
    final completeShooting =
        passes.isNotEmpty &&
        passes.length == shootingCount &&
        {for (final pass in passes) pass.index}.length == shootingCount &&
        passes.every(
          (pass) => pass.index >= 1 && pass.index <= shootingCount,
        ) &&
        passes.every(
          (pass) =>
              pass.misses != null && pass.misses! >= 0 && pass.misses! <= 5,
        );
    double? hitPercentFor(Iterable<ShootingPass> selected) {
      final values = selected.toList();
      if (!completeShooting || values.isEmpty) return null;
      final hits = values.fold<int>(0, (sum, pass) => sum + 5 - pass.misses!);
      return hits * 100 / (values.length * 5);
    }

    final allPositionsKnown = passes.every((pass) {
      final position = pass.position.trim().toLowerCase();
      return position == 'prone' || position == 'standing';
    });
    final prone = passes.where(
      (pass) => pass.position.trim().toLowerCase() == 'prone',
    );
    final standing = passes.where(
      (pass) => pass.position.trim().toLowerCase() == 'standing',
    );

    return BiathlonRaceMetrics(
      finishTimeMs: result.totalMs != null && result.totalMs! > 0
          ? result.totalMs
          : null,
      skiTimeMs: analysis.skiTimeMs != null && analysis.skiTimeMs! > 0
          ? analysis.skiTimeMs
          : null,
      shootingTimeMs:
          analysis.shootingTimeMs != null && analysis.shootingTimeMs! > 0
          ? analysis.shootingTimeMs
          : null,
      proneHitPercent: allPositionsKnown ? hitPercentFor(prone) : null,
      standingHitPercent: allPositionsKnown ? hitPercentFor(standing) : null,
      totalHitPercent: hitPercentFor(passes),
      extraMetrics: {
        for (final entry in publicMetrics.entries)
          if (entry.key != 'finishRank' &&
              entry.value is num &&
              (entry.value as num).toDouble().isFinite)
            entry.key: (entry.value as num).toDouble(),
        'finishRank': ?finishRank,
        if (analysis.netSkiTimeMs != null)
          'netSkiTimeMs': analysis.netSkiTimeMs!.toDouble(),
        if (analysis.penaltyTimeMs != null)
          'penaltyTimeMs': analysis.penaltyTimeMs!.toDouble(),
        if (analysis.missesTotal != null)
          'missesTotal': analysis.missesTotal!.toDouble(),
        if (analysis.skiRank != null) 'skiRank': analysis.skiRank!.toDouble(),
        if (analysis.netSkiRank != null)
          'netSkiRank': analysis.netSkiRank!.toDouble(),
        if (analysis.shootingRank != null)
          'shootingRank': analysis.shootingRank!.toDouble(),
        if (analysis.penaltyRank != null)
          'penaltyRank': analysis.penaltyRank!.toDouble(),
      },
      timingPoints: result.splitValues,
      shootingPasses: {for (final pass in passes) pass.index: pass},
      extraPassValues: _parsePublicPassValues(publicPasses),
      laps: {for (final lap in analysis.laps) lap.index: lap},
    );
  }

  final int? finishTimeMs;
  final int? skiTimeMs;
  final int? shootingTimeMs;
  final double? proneHitPercent;
  final double? standingHitPercent;
  final double? totalHitPercent;
  final Map<String, double> extraMetrics;
  final Map<String, SplitValue> timingPoints;
  final Map<int, ShootingPass> shootingPasses;
  final Map<int, Map<String, double>> extraPassValues;
  final Map<int, BiathlonLap> laps;

  double? valueFor(BiathlonMetric metric) => switch (metric) {
    BiathlonMetric.finishTime => finishTimeMs?.toDouble(),
    BiathlonMetric.skiTime => skiTimeMs?.toDouble(),
    BiathlonMetric.shootingTime => shootingTimeMs?.toDouble(),
    BiathlonMetric.proneHitPercent => proneHitPercent,
    BiathlonMetric.standingHitPercent => standingHitPercent,
    BiathlonMetric.totalHitPercent => totalHitPercent,
  };

  double? valueForMetricField(String field) => switch (field) {
    'finishTimeMs' => finishTimeMs?.toDouble(),
    'skiTimeMs' => skiTimeMs?.toDouble(),
    'shootingTimeMs' => shootingTimeMs?.toDouble(),
    'proneHitPercent' => proneHitPercent,
    'standingHitPercent' => standingHitPercent,
    'totalHitPercent' => totalHitPercent,
    _ => extraMetrics[field],
  };

  double? valueForTimingPoint(String id, String field) {
    final split = timingPoints[id];
    if (split == null) return null;
    return switch (field) {
      'cumMs' => split.cumMs?.toDouble(),
      'legMs' => split.legMs?.toDouble(),
      'cumRank' => split.cumRank?.toDouble(),
      'legRank' => split.legRank?.toDouble(),
      _ => null,
    };
  }

  double? valueForShootingPass(int index, String? position, String field) {
    final pass = shootingPasses[index];
    if (pass == null) return null;
    if (position != null &&
        position.isNotEmpty &&
        pass.position.toLowerCase() != position.toLowerCase()) {
      return null;
    }
    return switch (field) {
      'misses' =>
        pass.misses != null && pass.misses! >= 0 && pass.misses! <= 5
            ? pass.misses!.toDouble()
            : null,
      'rangeMs' => pass.rangeMs?.toDouble(),
      'penaltyMs' => pass.penaltyMs?.toDouble(),
      'rangeRank' => pass.rangeRank?.toDouble(),
      _ => extraPassValues[index]?[field],
    };
  }

  double? valueForLap(
    int index,
    String field, {
    int? beforeShooting,
    String? startCode,
    String? endCode,
  }) {
    final lap = laps[index];
    if (lap == null) return null;
    if (lap.beforeShooting != beforeShooting ||
        lap.startCode != startCode ||
        lap.endCode != endCode) {
      return null;
    }
    return switch (field) {
      'skiMs' => lap.skiMs?.toDouble(),
      'startCumMs' => lap.startCumMs?.toDouble(),
      'endCumMs' => lap.endCumMs?.toDouble(),
      _ => null,
    };
  }
}

Map<int, Map<String, double>> _parsePublicPassValues(
  Map<String, dynamic> publicPasses,
) {
  final values = <int, Map<String, double>>{};
  for (final raw in publicPasses.values) {
    final pass = asStringMap(raw);
    final index = asInt(pass['index']);
    if (index == null || index < 1) continue;
    values[index] = {
      for (final field in const [
        'rangeExitMs',
        'approachCumMs',
        'inCumMs',
        'shootingCumMs',
        'outCumMs',
        'rangeExitCumMs',
        'cumulativeMisses',
      ])
        if (pass[field] case final num value)
          if (value.toDouble().isFinite) field: value.toDouble(),
    };
  }
  return values;
}

class BiathlonBenchmarkValue {
  const BiathlonBenchmarkValue({required this.mean, required this.count});

  final double mean;
  final int count;
}

/// Importer-owned summary stored on a stage/class document.
class BiathlonTopHalfBenchmark {
  const BiathlonTopHalfBenchmark({
    required this.finishersCount,
    required this.cohortCount,
    required this.metrics,
  });

  static BiathlonTopHalfBenchmark? fromMap(Object? raw) {
    final data = asStringMap(raw);
    if (asInt(data['version']) != 1) return null;
    final finishersCount = asInt(data['finishersCount']);
    final cohortCount = asInt(data['cohortCount']);
    if (finishersCount == null ||
        cohortCount == null ||
        cohortCount != (finishersCount + 1) ~/ 2 ||
        cohortCount <= 0) {
      return null;
    }

    final metricData = asStringMap(data['metrics']);
    final metrics = <BiathlonMetric, BiathlonBenchmarkValue>{};
    for (final metric in BiathlonMetric.values) {
      final field = switch (metric) {
        BiathlonMetric.finishTime => 'finishTimeMs',
        BiathlonMetric.skiTime => 'skiTimeMs',
        BiathlonMetric.shootingTime => 'shootingTimeMs',
        BiathlonMetric.proneHitPercent => 'proneHitPercent',
        BiathlonMetric.standingHitPercent => 'standingHitPercent',
        BiathlonMetric.totalHitPercent => 'totalHitPercent',
      };
      final entry = asStringMap(metricData[field]);
      final rawMean = entry['mean'];
      final count = asInt(entry['count']);
      if (rawMean is! num ||
          count == null ||
          count <= 0 ||
          count > cohortCount) {
        continue;
      }
      final mean = rawMean.toDouble();
      if (!mean.isFinite ||
          (metric.isPercentage ? mean < 0 || mean > 100 : mean <= 0)) {
        continue;
      }
      metrics[metric] = BiathlonBenchmarkValue(mean: mean, count: count);
    }
    if (!metrics.containsKey(BiathlonMetric.finishTime)) return null;
    return BiathlonTopHalfBenchmark(
      finishersCount: finishersCount,
      cohortCount: cohortCount,
      metrics: metrics,
    );
  }

  final int finishersCount;
  final int cohortCount;
  final Map<BiathlonMetric, BiathlonBenchmarkValue> metrics;

  BiathlonBenchmarkValue? valueFor(BiathlonMetric metric) => metrics[metric];
}

class BiathlonComparison {
  const BiathlonComparison({
    required this.own,
    required this.benchmark,
    required this.metric,
  });

  final double own;
  final BiathlonBenchmarkValue benchmark;
  final BiathlonMetric metric;

  /// Positive means faster skiing/shooting or a higher hit percentage.
  double get advantage =>
      metric.isPercentage ? own - benchmark.mean : benchmark.mean - own;

  double get difference => own - benchmark.mean;
}

BiathlonComparison? compareBiathlonMetric(
  BiathlonRaceMetrics? own,
  BiathlonTopHalfBenchmark? benchmark,
  BiathlonMetric metric,
) {
  final ownValue = own?.valueFor(metric);
  final average = benchmark?.valueFor(metric);
  if (ownValue == null || average == null) return null;
  return BiathlonComparison(own: ownValue, benchmark: average, metric: metric);
}
