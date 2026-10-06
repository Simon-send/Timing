import '../../../core/firebase/firestore_mappers.dart';
import 'biathlon_comparison.dart';

enum BiathlonReferenceGroup {
  all('biathlon-all'),
  topHalf('biathlon-top-half');

  const BiathlonReferenceGroup(this.documentId);

  final String documentId;
}

/// One read-only, synthetic class profile. It is never a result or athlete.
class BiathlonAggregateProfile {
  const BiathlonAggregateProfile({
    required this.group,
    required this.finishersCount,
    required this.cohortCount,
    required this.metrics,
    this.timingPoints = const {},
    this.shootingPasses = const {},
    this.laps = const {},
  });

  static BiathlonAggregateProfile? fromMap(
    Object? raw,
    BiathlonReferenceGroup expectedGroup,
  ) {
    final data = asStringMap(raw);
    if (data['kind'] != expectedGroup.documentId ||
        data['schemaVersion'] != 1) {
      return null;
    }
    final finishersCount = data['finishersCount'];
    final cohortCount = data['cohortCount'];
    if (finishersCount is! int ||
        cohortCount is! int ||
        finishersCount <= 0 ||
        cohortCount !=
            (expectedGroup == BiathlonReferenceGroup.all
                ? finishersCount
                : (finishersCount + 1) ~/ 2)) {
      return null;
    }

    final metrics = _valuesFromMap(data['metrics'], cohortCount);
    final finish = metrics['finishTimeMs']?.mean;
    if (finish == null || finish <= 0) return null;
    return BiathlonAggregateProfile(
      group: expectedGroup,
      finishersCount: finishersCount,
      cohortCount: cohortCount,
      metrics: metrics,
      timingPoints: _pointsFromMap(data['timingPoints'], cohortCount),
      shootingPasses: _pointsFromMap(data['shootingPasses'], cohortCount),
      laps: _pointsFromMap(data['laps'], cohortCount),
    );
  }

  /// Keep the old class-field contract usable until all classes are reimported.
  factory BiathlonAggregateProfile.fromLegacyTopHalf(
    BiathlonTopHalfBenchmark legacy,
  ) {
    return BiathlonAggregateProfile(
      group: BiathlonReferenceGroup.topHalf,
      finishersCount: legacy.finishersCount,
      cohortCount: legacy.cohortCount,
      metrics: {
        for (final entry in legacy.metrics.entries)
          entry.key.fieldName: entry.value,
      },
    );
  }

  final BiathlonReferenceGroup group;
  final int finishersCount;
  final int cohortCount;
  final Map<String, BiathlonBenchmarkValue> metrics;
  final Map<String, BiathlonAggregatePoint> timingPoints;
  final Map<String, BiathlonAggregatePoint> shootingPasses;
  final Map<String, BiathlonAggregatePoint> laps;

  BiathlonBenchmarkValue? valueForMetric(BiathlonMetric metric) =>
      metrics[metric.fieldName];
}

class BiathlonAggregatePoint {
  const BiathlonAggregatePoint({
    required this.id,
    required this.values,
    this.code,
    this.label,
    this.sort,
    this.index,
    this.position,
    this.beforeShooting,
    this.startCode,
    this.endCode,
  });

  final String id;
  final String? code;
  final String? label;
  final int? sort;
  final int? index;
  final String? position;
  final int? beforeShooting;
  final String? startCode;
  final String? endCode;
  final Map<String, BiathlonBenchmarkValue> values;

  BiathlonBenchmarkValue? valueFor(String field) => values[field];
}

Map<String, BiathlonBenchmarkValue> _valuesFromMap(Object? raw, int maxCount) {
  final values = <String, BiathlonBenchmarkValue>{};
  for (final entry in asStringMap(raw).entries) {
    final data = asStringMap(entry.value);
    final mean = data['mean'];
    final count = data['count'];
    if (mean is! num || count is! int || count < 1 || count > maxCount) {
      continue;
    }
    final normalized = mean.toDouble();
    if (!normalized.isFinite) continue;
    values[entry.key] = BiathlonBenchmarkValue(mean: normalized, count: count);
  }
  return values;
}

Map<String, BiathlonAggregatePoint> _pointsFromMap(Object? raw, int maxCount) {
  final points = <String, BiathlonAggregatePoint>{};
  for (final entry in asStringMap(raw).entries) {
    if (entry.key.isEmpty) continue;
    final data = asStringMap(entry.value);
    final values = _valuesFromMap(data['values'], maxCount);
    if (values.isEmpty) continue;
    points[entry.key] = BiathlonAggregatePoint(
      id: entry.key,
      code: asNonEmptyString(data['code']),
      label: asNonEmptyString(data['label']),
      sort: asInt(data['sort']),
      index: asInt(data['index']),
      position: asNonEmptyString(data['position']),
      beforeShooting: asInt(data['beforeShooting']),
      startCode: asNonEmptyString(data['startCode']),
      endCode: asNonEmptyString(data['endCode']),
      values: values,
    );
  }
  return points;
}

/// Reassemble large importer profiles only when every declared section exists.
/// A missing section must not silently produce an incomplete class reference.
Map<String, dynamic>? mergeBiathlonAggregateSections(
  Map<String, dynamic> root,
  Map<String, Map<String, dynamic>> sectionDocs,
) {
  if (root.containsKey('sections') && root['sections'] is! Map) return null;
  final manifest = asStringMap(root['sections']);
  if (manifest.isEmpty) return root;
  const fields = {'timingPoints', 'shootingPasses', 'laps'};
  if (manifest.keys.any((field) => !fields.contains(field))) return null;
  final merged = Map<String, dynamic>.from(root);
  final usedIds = <String>{};
  for (final field in fields) {
    final ids = manifest[field];
    if (ids == null) continue;
    if (ids is! List || ids.any((id) => id is! String || id.isEmpty)) {
      return null;
    }
    final entries = Map<String, dynamic>.from(asStringMap(root[field]));
    for (final id in ids.cast<String>()) {
      if (!usedIds.add(id)) return null;
      final section = sectionDocs[id];
      if (section == null ||
          section['schemaVersion'] != 1 ||
          section['field'] != field ||
          section['entries'] is! Map) {
        return null;
      }
      final sectionEntries = asStringMap(section['entries']);
      if (sectionEntries.isEmpty) return null;
      for (final entry in sectionEntries.entries) {
        if (entries.containsKey(entry.key)) return null;
        entries[entry.key] = entry.value;
      }
    }
    merged[field] = entries;
  }
  return merged;
}
