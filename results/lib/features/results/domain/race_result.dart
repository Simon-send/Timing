import '../../../core/firebase/firestore_mappers.dart';
import '../../../core/formatting/time_formatters.dart';
import 'split_def.dart';

class SplitValue {
  const SplitValue({
    required this.id,
    required this.label,
    required this.sort,
    required this.cumRank,
    required this.legRank,
    required this.cumMs,
    required this.legMs,
    required this.cumText,
    required this.legText,
    required this.status,
    required this.addition,
    required this.additionParts,
  });

  factory SplitValue.fromMap(String fallbackId, Map<String, dynamic> data) {
    final id =
        asNonEmptyString(data['setupUid']) ??
        asNonEmptyString(data['stasjonsOppsettUID']) ??
        asNonEmptyString(data['StasjonsOppsettUID']) ??
        fallbackId;
    return SplitValue(
      id: id,
      label:
          asNonEmptyString(data['code']) ??
          asNonEmptyString(data['label']) ??
          asNonEmptyString(data['Navn']) ??
          id,
      sort: asInt(data['sort']) ?? asInt(data['Sortering']) ?? 10000,
      cumRank:
          asInt(data['cumRank']) ??
          asInt(data['rank']) ??
          asInt(data['Rank']) ??
          asInt(data['placement']) ??
          asInt(data['Plassering']),
      legRank: asInt(data['legRank']),
      cumMs: asInt(data['cumMs']) ?? asInt(data['cumulativeMs']),
      legMs: asInt(data['legMs']) ?? asInt(data['splitMs']),
      cumText:
          asNonEmptyString(data['cumText']) ??
          asNonEmptyString(data['cumulativeFormatted']) ??
          formatDurationMs(asInt(data['cumMs']) ?? asInt(data['cumulativeMs'])),
      legText:
          asNonEmptyString(data['legText']) ??
          asNonEmptyString(data['splitFormatted']) ??
          formatDurationMs(asInt(data['legMs']) ?? asInt(data['splitMs'])),
      status:
          asNonEmptyString(data['status']) ??
          asNonEmptyString(data['StatusTekst']) ??
          '',
      addition:
          asNonEmptyString(data['addition']) ??
          asNonEmptyString(data['Tillegg']) ??
          '',
      additionParts: _asIntList(data['additionParts']),
    );
  }

  final String id;
  final String label;
  final int sort;
  final int? cumRank;
  final int? legRank;
  final int? cumMs;
  final int? legMs;
  final String cumText;
  final String legText;
  final String status;
  final String addition;
  final List<int> additionParts;
}

class RaceResult {
  const RaceResult({
    required this.id,
    required this.rank,
    this.finishRank,
    required this.bib,
    required this.name,
    required this.club,
    required this.totalMs,
    required this.totalText,
    required this.shooting,
    required this.status,
    required this.splitValues,
    this.biathlon = const BiathlonAnalysis.empty(),
  });

  factory RaceResult.fromMap(String id, Map<String, dynamic> data) {
    final analysis = asStringMap(data['analysis']);
    final shootingData = _readShootingMap(data);
    final splitMaps = _readSplitMaps(data);
    final splitValues = <String, SplitValue>{};

    for (var i = 0; i < splitMaps.length; i++) {
      final split = SplitValue.fromMap('split-$i', splitMaps[i]);
      splitValues[split.id] = split;
    }

    return RaceResult(
      id: id,
      rank:
          asInt(data['rank']) ??
          asInt(data['Rank']) ??
          asInt(data['place']) ??
          asInt(data['Place']) ??
          asInt(data['placement']) ??
          asInt(data['Plassering']) ??
          _asNestedInt(data['placement']) ??
          _asNestedInt(data['Plassering']),
      finishRank:
          asInt(data['finishRank']) ??
          asInt(data['calculatedFinishRank']) ??
          asInt(data['originalFinishRank']),
      bib:
          asNonEmptyString(data['bib']) ??
          asNonEmptyString(data['fullBib']) ??
          '',
      name:
          asNonEmptyString(data['name']) ??
          asNestedString(data['participant'], 'name') ??
          'Ukjent utover',
      club:
          asNonEmptyString(data['teamName']) ??
          asNonEmptyString(data['team']) ??
          asNonEmptyString(data['lagName']) ??
          asNonEmptyString(data['lag']) ??
          asNonEmptyString(data['clubName']) ??
          asNonEmptyString(data['club']) ??
          '',
      totalMs: asInt(data['totalMs']) ?? asInt(data['totalTimeMs']),
      totalText:
          asNonEmptyString(data['totalText']) ??
          asNonEmptyString(data['totalTimeFormatted']) ??
          formatDurationMs(
            asInt(data['totalMs']) ?? asInt(data['totalTimeMs']),
          ),
      shooting:
          _shootingFromSplitMaps(splitMaps) ??
          asNonEmptyString(analysis['shootingResult']) ??
          '',
      status:
          asNonEmptyString(data['status']) ??
          asNonEmptyString(data['StatusTekst']) ??
          asNonEmptyString(data['resultStatus']) ??
          asNonEmptyString(data['statusText']) ??
          '',
      splitValues: splitValues,
      biathlon: BiathlonAnalysis.fromMaps(analysis, shootingData),
    );
  }

  final String id;
  final int? rank;
  final int? finishRank;
  final String bib;
  final String name;
  final String club;
  final int? totalMs;
  final String totalText;
  final String shooting;
  final String status;
  final Map<String, SplitValue> splitValues;
  final BiathlonAnalysis biathlon;

  bool get isFinished {
    final normalizedStatus = status.trim().toUpperCase();
    if (normalizedStatus.contains('DNF') ||
        normalizedStatus.contains('DNS') ||
        normalizedStatus.contains('DSQ') ||
        normalizedStatus.contains('BRUTT') ||
        normalizedStatus.contains('IKKE FULLF')) {
      return false;
    }
    if (totalMs != null && totalMs! > 0) return true;
    return rank != null && totalText.trim().isNotEmpty;
  }

  String get placementLabel {
    if (finishRank != null && finishRank! > 0) return finishRank.toString();
    if (rank != null && rank! > 0) return rank.toString();
    final normalizedStatus = status.trim();
    if (normalizedStatus.isNotEmpty) return normalizedStatus;
    return isFinished ? '-' : 'DNF';
  }

  String gapFrom(int? winnerMs) {
    if (winnerMs == null || totalMs == null) return '';
    final gap = totalMs! - winnerMs;
    if (gap <= 0) return '+0.0';
    return '+${formatDurationMs(gap)}';
  }
}

class ShootingPass {
  const ShootingPass({
    required this.index,
    required this.rangeMs,
    required this.misses,
    required this.position,
  });

  factory ShootingPass.fromMap(String fallbackKey, Map<String, dynamic> data) {
    return ShootingPass(
      index:
          asInt(data['index']) ??
          asInt(data['shootingIndex']) ??
          _indexFromShootingKey(fallbackKey) ??
          0,
      rangeMs:
          asInt(data['rangeMs']) ??
          asInt(data['rangeTimeMs']) ??
          asInt(data['shootingTimeMs']),
      misses:
          asInt(data['misses']) ??
          asInt(data['penalties']) ??
          asInt(data['penalty']),
      position: asNonEmptyString(data['position']) ?? '',
    );
  }

  final int index;
  final int? rangeMs;
  final int? misses;
  final String position;

  bool get hasData => rangeMs != null || misses != null;
}

class BiathlonAnalysis {
  const BiathlonAnalysis({
    required this.netSkiTimeMs,
    required this.shootingTimeMs,
    required this.penaltyTimeMs,
    required this.missesTotal,
    required this.skiRank,
    required this.shootingRank,
    required this.penaltyRank,
    required this.passes,
  });

  const BiathlonAnalysis.empty()
    : netSkiTimeMs = null,
      shootingTimeMs = null,
      penaltyTimeMs = null,
      missesTotal = null,
      skiRank = null,
      shootingRank = null,
      penaltyRank = null,
      passes = const [];

  factory BiathlonAnalysis.fromMaps(
    Map<String, dynamic> analysis,
    Map<String, dynamic> shooting,
  ) {
    final passes =
        shooting.entries
            .map((entry) {
              final data = asStringMap(entry.value);
              if (data.isEmpty) return null;
              return ShootingPass.fromMap(entry.key, data);
            })
            .whereType<ShootingPass>()
            .where((pass) => pass.index > 0 && pass.hasData)
            .toList()
          ..sort((a, b) => a.index - b.index);
    final missesTotal =
        asInt(analysis['missesTotal']) ??
        asInt(analysis['penaltiesTotal']) ??
        _sumPassMisses(passes);

    return BiathlonAnalysis(
      netSkiTimeMs:
          asInt(analysis['netSkiTimeMs']) ??
          asInt(analysis['skiTimeMs']) ??
          asInt(analysis['courseSkiTimeMs']),
      shootingTimeMs:
          asInt(analysis['shootingTimeMs']) ?? asInt(analysis['rangeTimeMs']),
      penaltyTimeMs: asInt(analysis['penaltyTimeMs']),
      missesTotal: missesTotal,
      skiRank: asInt(analysis['skiRank']),
      shootingRank:
          asInt(analysis['shootRank']) ??
          asInt(analysis['rangeRank']) ??
          asInt(analysis['shootingRank']),
      penaltyRank: asInt(analysis['penaltyRank']),
      passes: passes,
    );
  }

  final int? netSkiTimeMs;
  final int? shootingTimeMs;
  final int? penaltyTimeMs;
  final int? missesTotal;
  final int? skiRank;
  final int? shootingRank;
  final int? penaltyRank;
  final List<ShootingPass> passes;

  bool get hasData {
    return netSkiTimeMs != null ||
        shootingTimeMs != null ||
        penaltyTimeMs != null ||
        missesTotal != null ||
        passes.isNotEmpty;
  }

  ShootingPass? passAt(int index) {
    for (final pass in passes) {
      if (pass.index == index) return pass;
    }
    return null;
  }
}

int? _asNestedInt(Object? value) {
  final map = asStringMap(value);
  if (map.isEmpty) return null;
  return asInt(map['value']) ??
      asInt(map['Value']) ??
      asInt(map['verdi']) ??
      asInt(map['Verdi']) ??
      asInt(map['rank']) ??
      asInt(map['Rank']) ??
      asInt(map['plassering']) ??
      asInt(map['Plassering']);
}

List<int> _asIntList(Object? value) {
  if (value is List) return value.map(asInt).whereType<int>().toList();
  final text = asNonEmptyString(value);
  if (text == null || !text.contains('+')) return const [];
  return text.split('+').map(asInt).whereType<int>().toList();
}

String? _shootingFromSplitMaps(List<Map<String, dynamic>> splitMaps) {
  List<int> bestParts = const [];
  String? bestText;

  for (final split in splitMaps) {
    final parts = _asIntList(split['additionParts']);
    final addition =
        asNonEmptyString(split['addition']) ??
        asNonEmptyString(split['Tillegg']);
    final additionParts = parts.isNotEmpty ? parts : _asIntList(addition);

    if (additionParts.length > bestParts.length) {
      bestParts = additionParts;
      bestText = additionParts.join('+');
      continue;
    }

    if (bestText == null && addition != null && addition.contains('+')) {
      bestText = addition;
    }
  }

  if (bestParts.isNotEmpty) return bestParts.join('+');
  return bestText;
}

int? _indexFromShootingKey(String key) {
  final match = RegExp(r'(\d+)').firstMatch(key);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

int? _sumPassMisses(List<ShootingPass> passes) {
  var hasMisses = false;
  var sum = 0;
  for (final pass in passes) {
    final misses = pass.misses;
    if (misses == null) continue;
    hasMisses = true;
    sum += misses;
  }
  return hasMisses ? sum : null;
}

List<SplitOption> buildSplitOptions(
  List<SplitDef> splitDefs,
  List<RaceResult> results,
) {
  final options = <String, SplitOption>{};
  final hiddenSplitIds = <String>{};

  for (final splitDef in splitDefs) {
    if (!splitDef.isPublic) {
      hiddenSplitIds.add(splitDef.id);
      continue;
    }
    options[splitDef.id] = SplitOption(
      id: splitDef.id,
      label: splitDef.label,
      sort: splitDef.sort,
    );
  }

  for (final result in results) {
    for (final split in result.splitValues.values) {
      if (hiddenSplitIds.contains(split.id)) continue;
      options.putIfAbsent(
        split.id,
        () => SplitOption(id: split.id, label: split.label, sort: split.sort),
      );
    }
  }

  final sorted = options.values.toList()
    ..sort((a, b) {
      if (a.sort != b.sort) return a.sort - b.sort;
      return a.label.compareTo(b.label);
    });
  return sorted;
}

List<Map<String, dynamic>> _readSplitMaps(Map<String, dynamic> data) {
  final rawPasses = asMapList(data['rawPasses']);
  if (rawPasses.isNotEmpty) return rawPasses;

  final mergedSplits = asMapList(data['splits']);
  if (mergedSplits.isNotEmpty) return mergedSplits;

  final splitValues = asStringMap(data['splitValues']);
  if (splitValues.isEmpty) return const [];

  return splitValues.entries.map((entry) {
    final value = asStringMap(entry.value);
    return <String, dynamic>{'setupUid': entry.key, ...value};
  }).toList();
}

Map<String, dynamic> _readShootingMap(Map<String, dynamic> data) {
  for (final key in const ['shooting', 'Shooting', 'sooting', 'Sooting']) {
    final map = asStringMap(data[key]);
    if (map.isNotEmpty) return map;
  }
  return const {};
}
