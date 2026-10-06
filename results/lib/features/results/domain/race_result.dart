import '../../../core/firebase/firestore_mappers.dart';
import '../../../core/formatting/time_formatters.dart';
import 'split_def.dart';

const relayLegFinishSplitId = '__relay_leg_finish__';

class SplitValue {
  const SplitValue({
    required this.id,
    required this.label,
    required this.sort,
    required this.cumRank,
    required this.legRank,
    this.cumRankCount,
    required this.cumMs,
    required this.legMs,
    required this.cumText,
    required this.legText,
    required this.status,
    required this.addition,
    required this.additionParts,
    this.kind = '',
    this.legNumber,
    this.roundNumber,
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
      cumRankCount:
          asInt(data['cumRankCount']) ?? asInt(data['cumParticipantCount']),
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
      kind: asNonEmptyString(data['kind']) ?? '',
      legNumber: asInt(data['legNumber']) ?? asInt(data['etappeNumber']),
      roundNumber: asInt(data['roundNumber']),
    );
  }

  final String id;
  final String label;
  final int sort;
  final int? cumRank;
  final int? legRank;
  final int? cumRankCount;
  final int? cumMs;
  final int? legMs;
  final String cumText;
  final String legText;
  final String status;
  final String addition;
  final List<int> additionParts;
  final String kind;
  final int? legNumber;
  final int? roundNumber;

  SplitValue withRanks({int? cumRank, int? legRank, int? cumRankCount}) {
    return SplitValue(
      id: id,
      label: label,
      sort: sort,
      cumRank: cumRank,
      legRank: legRank,
      cumRankCount: cumRankCount,
      cumMs: cumMs,
      legMs: legMs,
      cumText: cumText,
      legText: legText,
      status: status,
      addition: addition,
      additionParts: additionParts,
      kind: kind,
      legNumber: legNumber,
      roundNumber: roundNumber,
    );
  }
}

typedef TimingPoint = SplitValue;

enum ResultEntrantKind { athlete, team }

class ResultEntrant {
  const ResultEntrant({
    required this.kind,
    required this.name,
    required this.bib,
    this.participantUid,
    this.athleteId,
    this.clubName = '',
    this.teamName = '',
  });

  final ResultEntrantKind kind;
  final String name;
  final String bib;
  final String? participantUid;
  final String? athleteId;
  final String clubName;
  final String teamName;
}

class RelayMember {
  const RelayMember({
    required this.legNumber,
    required this.name,
    this.athleteId,
    this.countryCode,
  });

  factory RelayMember.fromMap(Map<String, dynamic> data) {
    final country = asStringMap(data['country']);
    return RelayMember(
      legNumber: asInt(data['legNumber']) ?? 0,
      name: asNonEmptyString(data['name']) ?? '-',
      athleteId: asNonEmptyString(data['athleteId']),
      countryCode:
          asNonEmptyString(country['iso3']) ??
          asNonEmptyString(country['iso2']),
    );
  }

  final int legNumber;
  final String name;
  final String? athleteId;
  final String? countryCode;
}

class RelayLegResult {
  const RelayLegResult({
    required this.legNumber,
    required this.member,
    required this.timeMs,
    required this.cumulativeMs,
    required this.checkpointLabel,
    required this.splitId,
    required this.totalRank,
  });

  final int legNumber;
  final RelayMember? member;
  final int? timeMs;
  final int? cumulativeMs;
  final String checkpointLabel;
  final String? splitId;
  final int? totalRank;
}

class RaceResult {
  const RaceResult({
    required this.id,
    this.athleteId,
    required this.rank,
    this.finishRank,
    required this.bib,
    required this.name,
    required this.club,
    this.team = '',
    required this.totalMs,
    required this.totalText,
    required this.shooting,
    required this.status,
    required this.splitValues,
    this.advanced = false,
    this.stageId,
    this.sourceResultId,
    this.relayLegNumber,
    this.relayOverallRank,
    this.relayTeamName = '',
    this.relayLegBiathlon = const {},
    this.entrant,
    this.relayMembers = const [],
    this.biathlon,
  });

  factory RaceResult.fromMap(String id, Map<String, dynamic> data) {
    final analysisRoot = asStringMap(
      data['analysis'] ?? data['analysisSummary'],
    );
    final biathlonRoot = asStringMap(analysisRoot['biathlon']);
    final analysis = biathlonRoot.isNotEmpty
        ? asStringMap(biathlonRoot['metrics'])
        : analysisRoot;
    final shootingData = biathlonRoot.isNotEmpty
        ? asStringMap(biathlonRoot['passes'])
        : _readShootingMap(data);
    final biathlonLaps = biathlonRoot.isNotEmpty
        ? asStringMap(biathlonRoot['laps'])
        : const <String, dynamic>{};
    final entrantData = asStringMap(data['entrant']);
    final teamData = asStringMap(data['team']);
    final splitMaps = _readSplitMaps(data);
    final splitValues = <String, SplitValue>{};

    for (var i = 0; i < splitMaps.length; i++) {
      final split = SplitValue.fromMap('split-$i', splitMaps[i]);
      splitValues[split.id] = split;
    }

    final fallbackName =
        asNonEmptyString(data['name']) ??
        asNestedString(data['participant'], 'name') ??
        'Ukjent utøver';
    final fallbackBib =
        asNonEmptyString(data['bib']) ??
        asNonEmptyString(data['fullBib']) ??
        '';
    final entrantName = asNonEmptyString(entrantData['name']) ?? fallbackName;
    final entrantBib = asNonEmptyString(entrantData['bib']) ?? fallbackBib;
    final entrantKind = asNonEmptyString(entrantData['kind']) == 'team'
        ? ResultEntrantKind.team
        : ResultEntrantKind.athlete;
    final clubName =
        asNonEmptyString(entrantData['clubName']) ??
        asNonEmptyString(data['clubName']) ??
        asNonEmptyString(data['club']) ??
        '';
    final teamName =
        asNonEmptyString(entrantData['teamName']) ??
        asNonEmptyString(data['teamName']) ??
        asNonEmptyString(data['team']) ??
        asNonEmptyString(data['lagName']) ??
        asNonEmptyString(data['lag']) ??
        '';
    final athleteId =
        asNonEmptyString(entrantData['athleteId']) ??
        asNonEmptyString(data['athleteId']) ??
        asNestedString(data['participant'], 'athleteId');
    final relayMembers =
        asMapList(teamData['members'])
            .map(RelayMember.fromMap)
            .where((member) => member.legNumber > 0)
            .toList()
          ..sort((a, b) => a.legNumber.compareTo(b.legNumber));
    final relayLegBiathlon = <int, BiathlonAnalysis>{};
    for (final legData in asMapList(teamData['legs'])) {
      final legNumber = asInt(legData['legNumber']);
      final biathlonData = asStringMap(legData['biathlon']);
      final metrics = asStringMap(biathlonData['metrics']);
      final passes = asStringMap(biathlonData['passes']);
      if (legNumber == null || (metrics.isEmpty && passes.isEmpty)) continue;
      final legAnalysis = BiathlonAnalysis.fromMaps(metrics, passes);
      if (legAnalysis.hasData) relayLegBiathlon[legNumber] = legAnalysis;
    }
    final hasBiathlon =
        biathlonRoot.isNotEmpty ||
        analysis.values.any((value) => value != null) ||
        shootingData.isNotEmpty;

    return RaceResult(
      id: id,
      stageId:
          asNonEmptyString(data['stageId']) ??
          asNonEmptyString(data['etappeUid']),
      relayOverallRank: asInt(data['relayOverallRank']),
      athleteId: athleteId,
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
      bib: entrantBib,
      name: entrantName,
      club: clubName,
      team: teamName,
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
          _resultStatusFromSplitMaps(splitMaps) ??
          '',
      advanced: asBool(data['advanced']) ?? false,
      splitValues: splitValues,
      entrant: ResultEntrant(
        kind: entrantKind,
        participantUid: asNonEmptyString(entrantData['participantUid']),
        athleteId: athleteId,
        name: entrantName,
        bib: entrantBib,
        clubName: clubName,
        teamName: teamName,
      ),
      relayMembers: relayMembers,
      relayLegBiathlon: relayLegBiathlon,
      biathlon: hasBiathlon
          ? BiathlonAnalysis.fromMaps(analysis, shootingData, biathlonLaps)
          : null,
    );
  }

  final String id;
  final String? stageId;
  final String? sourceResultId;
  final int? relayLegNumber;
  final int? relayOverallRank;
  final String relayTeamName;
  final Map<int, BiathlonAnalysis> relayLegBiathlon;
  final String? athleteId;
  final int? rank;
  final int? finishRank;
  final String bib;
  final String name;
  final String club;
  final String team;
  final int? totalMs;
  final String totalText;
  final String shooting;
  final String status;
  final bool advanced;
  final Map<String, SplitValue> splitValues;
  final ResultEntrant? entrant;
  final List<RelayMember> relayMembers;
  final BiathlonAnalysis? biathlon;

  String get detailResultId => sourceResultId ?? id;

  String affiliationName(ResultAffiliationView view) {
    return switch (view) {
      ResultAffiliationView.club => club,
      ResultAffiliationView.team => team,
    };
  }

  bool matchesSearch(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    final searchableText = '$name $club $team $bib'.toLowerCase();
    return searchableText.contains(normalizedQuery);
  }

  bool get isFinished {
    if (_resultStatusSortOrder(status) > 0) return false;
    if (totalMs != null && totalMs! > 0) return true;
    return rank != null && totalText.trim().isNotEmpty;
  }

  /// Fullførte løpere kommer først. DNF og DNS får de to høyeste
  /// verdiene slik at de alltid havner helt nederst i resultatlister.
  int get statusSortOrder {
    final statusOrder = _resultStatusSortOrder(status);
    if (statusOrder > 0) return statusOrder;
    return isFinished ? 0 : 1;
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

/// Returns the explicit leg time, or derives it from consecutive cumulative
/// passings for result documents imported before leg times were persisted.
int? effectiveSplitLegMs(RaceResult result, String splitId) {
  final split = result.splitValues[splitId];
  if (split == null) return null;
  final explicitLegMs = split.legMs;
  if (explicitLegMs != null && explicitLegMs > 0) return explicitLegMs;

  final cumulativeMs = split.cumMs;
  if (cumulativeMs == null || cumulativeMs <= 0) return null;

  SplitValue? previous;
  for (final candidate in result.splitValues.values) {
    final candidateMs = candidate.cumMs;
    if (candidate.id == split.id ||
        candidateMs == null ||
        candidateMs <= 0 ||
        candidateMs >= cumulativeMs) {
      continue;
    }
    if (previous == null || candidateMs > previous.cumMs!) {
      previous = candidate;
    }
  }

  final previousMs = previous?.cumMs;
  return previousMs == null ? cumulativeMs : cumulativeMs - previousMs;
}

/// Sums explicitly selected split legs. A missing leg makes the combined time
/// unavailable instead of silently producing a partial result.
int? combinedSplitLegMs(RaceResult result, Iterable<String> splitIds) {
  final ids = splitIds.toSet();
  if (ids.isEmpty) return null;

  var totalMs = 0;
  for (final splitId in ids) {
    final legMs = effectiveSplitLegMs(result, splitId);
    if (legMs == null || legMs <= 0) return null;
    totalMs += legMs;
  }
  return totalMs;
}

List<RelayLegResult> effectiveRelayLegs(RaceResult result) {
  final legNumbers = <int>{
    ...result.relayMembers.map((member) => member.legNumber),
    ...result.splitValues.values
        .map((point) => point.legNumber)
        .whereType<int>(),
  }.toList()..sort();
  final legs = <RelayLegResult>[];
  int? previousCumulativeMs = 0;
  var previousLegNumber = 0;

  for (final legNumber in legNumbers) {
    final points =
        result.splitValues.values
            .where(
              (point) => point.legNumber == legNumber && point.cumMs != null,
            )
            .toList()
          ..sort((a, b) => a.sort.compareTo(b.sort));
    final preferred = points.where((point) {
      final label = point.label.toLowerCase();
      return label.contains('veksling') ||
          label.contains('mål') ||
          label.contains('maal') ||
          label.contains('finish');
    }).lastOrNull;
    final endpoint = preferred ?? points.lastOrNull;
    final cumulativeMs = endpoint?.cumMs;
    // A numeric gap cannot supply the immediately preceding exchange.
    final previousMs = previousLegNumber == legNumber - 1
        ? previousCumulativeMs
        : null;
    final timeMs =
        cumulativeMs != null && previousMs != null && cumulativeMs >= previousMs
        ? cumulativeMs - previousMs
        : null;
    previousCumulativeMs = cumulativeMs;
    previousLegNumber = legNumber;
    legs.add(
      RelayLegResult(
        legNumber: legNumber,
        member: result.relayMembers
            .where((member) => member.legNumber == legNumber)
            .firstOrNull,
        timeMs: timeMs,
        cumulativeMs: cumulativeMs,
        checkpointLabel: endpoint?.label ?? '',
        splitId: endpoint?.id,
        totalRank: endpoint?.cumRank,
      ),
    );
  }
  return legs;
}

/// All numbered relay legs represented by either the team roster or timing
/// points. The result is stable and suitable for selector UI.
List<int> relayLegNumbers(Iterable<RaceResult> results) {
  final numbers = <int>{};
  for (final result in results) {
    numbers.addAll(
      result.relayMembers
          .map((member) => member.legNumber)
          .where((number) => number > 0),
    );
    numbers.addAll(
      result.splitValues.values
          .map((point) => point.legNumber)
          .whereType<int>()
          .where((number) => number > 0),
    );
  }
  return numbers.toList()..sort();
}

/// Turns a team result into the athlete result for one relay leg. Cumulative
/// times are rebased at the previous exchange, so rankings and split charts
/// compare the athlete with the other athletes on that same leg.
RaceResult? relayLegRaceResult(RaceResult teamResult, int legNumber) {
  final legs = effectiveRelayLegs(teamResult);
  final selectedLeg = legs
      .where((leg) => leg.legNumber == legNumber)
      .firstOrNull;
  final member =
      selectedLeg?.member ??
      teamResult.relayMembers
          .where((candidate) => candidate.legNumber == legNumber)
          .firstOrNull;
  final legPoints =
      teamResult.splitValues.values
          .where((point) => point.legNumber == legNumber)
          .toList()
        ..sort((a, b) {
          if (a.sort != b.sort) return a.sort.compareTo(b.sort);
          return a.id.compareTo(b.id);
        });
  if (member == null && legPoints.isEmpty) return null;
  final shootingIndexes =
      legPoints.map(_shootingIndexForPoint).whereType<int>().toSet().toList()
        ..sort();

  final startMs = legNumber == 1
      ? 0
      : legs
            .where((leg) => leg.legNumber == legNumber - 1)
            .firstOrNull
            ?.cumulativeMs;
  final rebasedSplits = <String, SplitValue>{};

  for (final point in legPoints) {
    final rawCumulativeMs = point.cumMs;
    final cumulativeMs = rawCumulativeMs == null || startMs == null
        ? null
        : rawCumulativeMs - startMs;
    final localizedAdditionParts = shootingIndexes
        .where((index) => index <= point.additionParts.length)
        .map((index) => point.additionParts[index - 1])
        .toList(growable: false);
    rebasedSplits[point.id] = SplitValue(
      id: point.id,
      label: point.label,
      sort: point.sort,
      cumRank: null,
      legRank: point.legRank,
      cumMs: cumulativeMs != null && cumulativeMs >= 0 ? cumulativeMs : null,
      legMs: point.legMs,
      cumText: formatDurationMs(
        cumulativeMs != null && cumulativeMs >= 0 ? cumulativeMs : null,
      ),
      legText: point.legText,
      status: point.status,
      addition: localizedAdditionParts.isEmpty
          ? ''
          : localizedAdditionParts.join('+'),
      additionParts: localizedAdditionParts,
      kind: point.kind,
      legNumber: legNumber,
      roundNumber: point.roundNumber,
    );
  }

  final totalMs = selectedLeg?.timeMs;
  final biathlon =
      teamResult.relayLegBiathlon[legNumber] ??
      _relayLegBiathlon(teamResult.biathlon, shootingIndexes, totalMs);
  final finishSort = legPoints.isEmpty ? 1000000 : legPoints.last.sort + 1;
  rebasedSplits[relayLegFinishSplitId] = SplitValue(
    id: relayLegFinishSplitId,
    label: 'Etappetid',
    sort: finishSort,
    cumRank: null,
    legRank: null,
    cumMs: totalMs,
    legMs: totalMs,
    cumText: formatDurationMs(totalMs),
    legText: formatDurationMs(totalMs),
    status: teamResult.status,
    addition: '',
    additionParts: const [],
    kind: 'finish',
    legNumber: legNumber,
  );

  final teamName = teamResult.name;
  final athleteName = member?.name.trim();
  final name = athleteName == null || athleteName.isEmpty || athleteName == '-'
      ? '$teamName – etappe $legNumber'
      : athleteName;
  final viewId = relayLegViewResultId(teamResult.detailResultId, legNumber);
  return RaceResult(
    id: viewId,
    sourceResultId: teamResult.detailResultId,
    relayLegNumber: legNumber,
    relayOverallRank: teamResult.finishRank ?? teamResult.rank,
    relayTeamName: teamName,
    stageId: teamResult.stageId,
    athleteId: member?.athleteId,
    rank: null,
    finishRank: null,
    bib: teamResult.bib,
    name: name,
    club: teamResult.club,
    team: teamName,
    totalMs: totalMs,
    totalText: formatDurationMs(totalMs),
    shooting:
        biathlon?.passes
            .map((pass) => pass.misses)
            .whereType<int>()
            .join('+') ??
        '',
    status: totalMs == null ? teamResult.status : '',
    splitValues: rebasedSplits,
    entrant: ResultEntrant(
      kind: ResultEntrantKind.athlete,
      athleteId: member?.athleteId,
      name: name,
      bib: teamResult.bib,
      clubName: teamResult.club,
      teamName: teamName,
    ),
    biathlon: biathlon,
  );
}

List<RaceResult> relayLegRaceResults(
  Iterable<RaceResult> teamResults,
  int legNumber,
) {
  return teamResults
      .map((result) => relayLegRaceResult(result, legNumber))
      .whereType<RaceResult>()
      .toList(growable: false);
}

String relayLegViewResultId(String resultId, int legNumber) {
  return '$resultId::relay-leg-$legNumber';
}

int? _shootingIndexForPoint(SplitValue point) {
  const shootingKinds = {
    'rangeApproach',
    'rangeIn',
    'shooting',
    'rangeOut',
    'rangeExit',
  };
  final normalized = point.label.trim().toUpperCase();
  final match = RegExp(r'^(?:INS|UTS|IS|US|S)(\d+)$').firstMatch(normalized);
  if (match == null && !shootingKinds.contains(point.kind)) return null;
  return match == null ? point.roundNumber : int.tryParse(match.group(1)!);
}

BiathlonAnalysis? _relayLegBiathlon(
  BiathlonAnalysis? teamAnalysis,
  Iterable<int> shootingIndexes,
  int? totalMs,
) {
  if (teamAnalysis == null) return null;
  final indexes = shootingIndexes.toSet();
  final passes = teamAnalysis.passes
      .where((pass) => indexes.contains(pass.index))
      .toList(growable: false);
  if (passes.isEmpty) return null;

  int? sumComplete(Iterable<int?> values) {
    final completeValues = <int>[...values.whereType<int>()];
    if (completeValues.length != passes.length) return null;
    var total = 0;
    for (final value in completeValues) {
      total += value;
    }
    return total;
  }

  final shootingTimeMs = sumComplete(passes.map((pass) => pass.rangeMs));
  final missesTotal = sumComplete(passes.map((pass) => pass.misses));
  final penaltyTimeMs = sumComplete(passes.map((pass) => pass.penaltyMs));
  final netSkiTimeMs = totalMs == null || shootingTimeMs == null
      ? null
      : (totalMs - shootingTimeMs).clamp(0, totalMs);

  return BiathlonAnalysis(
    skiTimeMs: _deriveSkiTimeMs(netSkiTimeMs, penaltyTimeMs),
    netSkiTimeMs: netSkiTimeMs,
    shootingTimeMs: shootingTimeMs,
    penaltyTimeMs: penaltyTimeMs,
    missesTotal: missesTotal,
    skiRank: null,
    netSkiRank: null,
    shootingRank: null,
    penaltyRank: null,
    passes: passes,
  );
}

/// Split metadata for one relay leg, plus a common finish split. The common
/// split is deliberately shared by every leg, allowing whole-leg comparisons
/// even when checkpoints and courses differ.
List<SplitDef> relayLegSplitDefs(
  Iterable<SplitDef> splitDefs,
  int legNumber,
  Iterable<RaceResult> legResults,
) {
  final byId = <String, SplitDef>{
    for (final split in splitDefs.where(
      (split) =>
          split.legNumber == legNumber && split.id != relayLegFinishSplitId,
    ))
      split.id: split,
  };
  for (final result in legResults) {
    for (final point in result.splitValues.values) {
      if (point.id == relayLegFinishSplitId) continue;
      byId.putIfAbsent(
        point.id,
        () => SplitDef(
          id: point.id,
          label: point.label,
          sort: point.sort,
          kind: 'split',
          stationName: '',
          isPublic: true,
          legNumber: legNumber,
          roundNumber: point.roundNumber,
        ),
      );
    }
  }
  final definitions = byId.values.toList();
  definitions.sort((a, b) {
    if (a.sort != b.sort) return a.sort.compareTo(b.sort);
    return a.id.compareTo(b.id);
  });
  final finishSort = definitions.isEmpty ? 1000000 : definitions.last.sort + 1;
  return [
    ...definitions,
    SplitDef(
      id: relayLegFinishSplitId,
      label: 'Etappetid',
      sort: finishSort,
      kind: 'finish',
      stationName: '',
      isPublic: true,
      legNumber: legNumber,
    ),
  ];
}

enum ResultAffiliationView { club, team }

class ShootingPass {
  const ShootingPass({
    required this.index,
    required this.rangeMs,
    required this.misses,
    required this.position,
    this.penaltyMs,
    this.rangeRank,
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
      penaltyMs: asInt(data['penaltyMs']) ?? asInt(data['penaltyTimeMs']),
      rangeRank: asInt(data['rangeRank']),
    );
  }

  final int index;
  final int? rangeMs;
  final int? misses;
  final String position;
  final int? penaltyMs;
  final int? rangeRank;

  bool get hasData => rangeMs != null || misses != null || penaltyMs != null;
}

class BiathlonLap {
  const BiathlonLap({
    required this.index,
    required this.skiMs,
    required this.startCumMs,
    required this.endCumMs,
    required this.startCode,
    required this.endCode,
    required this.beforeShooting,
  });

  factory BiathlonLap.fromMap(String fallbackKey, Map<String, dynamic> data) {
    return BiathlonLap(
      index: asInt(data['index']) ?? _indexFromLapKey(fallbackKey) ?? 0,
      skiMs: asInt(data['skiMs']) ?? asInt(data['skiTimeMs']),
      startCumMs: asInt(data['startCumMs']),
      endCumMs: asInt(data['endCumMs']),
      startCode: asNonEmptyString(data['startCode']),
      endCode: asNonEmptyString(data['endCode']),
      beforeShooting: asInt(data['beforeShooting']),
    );
  }

  final int index;
  final int? skiMs;
  final int? startCumMs;
  final int? endCumMs;
  final String? startCode;
  final String? endCode;
  final int? beforeShooting;

  bool get hasData => skiMs != null;
}

class BiathlonAnalysis {
  const BiathlonAnalysis({
    required this.skiTimeMs,
    required this.netSkiTimeMs,
    required this.shootingTimeMs,
    required this.penaltyTimeMs,
    required this.missesTotal,
    required this.skiRank,
    required this.netSkiRank,
    required this.shootingRank,
    required this.penaltyRank,
    required this.passes,
    this.laps = const [],
  });

  const BiathlonAnalysis.empty()
    : skiTimeMs = null,
      netSkiTimeMs = null,
      shootingTimeMs = null,
      penaltyTimeMs = null,
      missesTotal = null,
      skiRank = null,
      netSkiRank = null,
      shootingRank = null,
      penaltyRank = null,
      passes = const [],
      laps = const [];

  factory BiathlonAnalysis.fromMaps(
    Map<String, dynamic> analysis,
    Map<String, dynamic> shooting, [
    Map<String, dynamic> laps = const {},
  ]) {
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
    final parsedLaps =
        laps.entries
            .map((entry) {
              final data = asStringMap(entry.value);
              if (data.isEmpty) return null;
              return BiathlonLap.fromMap(entry.key, data);
            })
            .whereType<BiathlonLap>()
            .where((lap) => lap.index > 0 && lap.hasData)
            .toList()
          ..sort((a, b) => a.index - b.index);
    final missesTotal =
        asInt(analysis['missesTotal']) ??
        asInt(analysis['penaltiesTotal']) ??
        _sumPassMisses(passes);
    final netSkiTimeMs = asInt(analysis['netSkiTimeMs']);
    final penaltyTimeMs = asInt(analysis['penaltyTimeMs']);
    final skiTimeMs =
        asInt(analysis['skiTimeMs']) ??
        _sumCompleteLapSkiTime(parsedLaps) ??
        _deriveSkiTimeMs(netSkiTimeMs, penaltyTimeMs);

    return BiathlonAnalysis(
      skiTimeMs: skiTimeMs,
      netSkiTimeMs: netSkiTimeMs,
      shootingTimeMs:
          asInt(analysis['shootingTimeMs']) ?? asInt(analysis['rangeTimeMs']),
      penaltyTimeMs: penaltyTimeMs,
      missesTotal: missesTotal,
      skiRank: asInt(analysis['skiRank']),
      netSkiRank: asInt(analysis['netSkiRank']) ?? asInt(analysis['skiRank']),
      shootingRank:
          asInt(analysis['shootRank']) ??
          asInt(analysis['rangeRank']) ??
          asInt(analysis['shootingRank']),
      penaltyRank: asInt(analysis['penaltyRank']),
      passes: passes,
      laps: parsedLaps,
    );
  }

  final int? skiTimeMs;
  final int? netSkiTimeMs;
  final int? shootingTimeMs;
  final int? penaltyTimeMs;
  final int? missesTotal;
  final int? skiRank;
  final int? netSkiRank;
  final int? shootingRank;
  final int? penaltyRank;
  final List<ShootingPass> passes;
  final List<BiathlonLap> laps;

  bool get hasData {
    return skiTimeMs != null ||
        netSkiTimeMs != null ||
        shootingTimeMs != null ||
        penaltyTimeMs != null ||
        missesTotal != null ||
        passes.isNotEmpty ||
        laps.isNotEmpty;
  }

  ShootingPass? passAt(int index) {
    for (final pass in passes) {
      if (pass.index == index) return pass;
    }
    return null;
  }

  BiathlonLap? lapAt(int index) {
    for (final lap in laps) {
      if (lap.index == index) return lap;
    }
    return null;
  }
}

int? _indexFromLapKey(String value) {
  final match = RegExp(r'(\d+)$').firstMatch(value);
  return match == null ? null : int.tryParse(match.group(1)!);
}

int? _deriveSkiTimeMs(int? netSkiTimeMs, int? penaltyTimeMs) {
  if (netSkiTimeMs == null) return null;
  if (penaltyTimeMs == null) return netSkiTimeMs;
  final skiTimeMs = netSkiTimeMs - penaltyTimeMs;
  return skiTimeMs < 0 ? 0 : skiTimeMs;
}

int? _sumCompleteLapSkiTime(List<BiathlonLap> laps) {
  if (laps.isEmpty || laps.any((lap) => lap.skiMs == null)) return null;
  return laps.fold(0, (sum, lap) => sum! + lap.skiMs!);
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

String? _resultStatusFromSplitMaps(List<Map<String, dynamic>> splitMaps) {
  String? latestStatus;
  for (final split in splitMaps) {
    final status =
        asNonEmptyString(split['status']) ??
        asNonEmptyString(split['StatusTekst']) ??
        asNonEmptyString(split['statusText']);
    if (status == null) continue;
    latestStatus = status;
    if (_resultStatusSortOrder(status) > 0) return status;
  }
  return latestStatus;
}

int _resultStatusSortOrder(String status) {
  final normalized = status.trim().toUpperCase();
  if (normalized.contains('DNS') ||
      normalized.contains('DID NOT START') ||
      normalized.contains('IKKE STARTET') ||
      normalized.contains('STARTET IKKE')) {
    return 3;
  }
  if (normalized.contains('DNF') ||
      normalized.contains('DID NOT FINISH') ||
      normalized.contains('BRUTT') ||
      normalized.contains('IKKE FULLF')) {
    return 2;
  }
  if (normalized.contains('DSQ') ||
      normalized.contains('DQ') ||
      normalized.contains('DISQUAL')) {
    return 1;
  }
  return 0;
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
      kind: splitDef.kind,
    );
  }

  for (final result in results) {
    for (final split in result.splitValues.values) {
      if (hiddenSplitIds.contains(split.id)) continue;
      options.putIfAbsent(
        split.id,
        () => SplitOption(
          id: split.id,
          label: split.label,
          sort: split.sort,
          kind: _looksLikeFinishSplit(split.label) ? 'finish' : 'split',
        ),
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

bool _looksLikeFinishSplit(String value) {
  final normalized = value.trim().toLowerCase().replaceAll('å', 'aa');
  return normalized == 'maal' || normalized == 'finish' || normalized == 'goal';
}

List<Map<String, dynamic>> _readSplitMaps(Map<String, dynamic> data) {
  final timingPoints = asMapList(data['timingPoints']);
  if (timingPoints.isNotEmpty) return timingPoints;

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
