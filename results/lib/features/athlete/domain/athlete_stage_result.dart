import '../../results/domain/competition_stage.dart';
import '../../results/domain/race_result.dart';

class AthleteStageResult {
  const AthleteStageResult({
    required this.stage,
    required this.athleteResult,
    required this.results,
    this.relayLegNumber,
  });

  final CompetitionStage stage;
  final RaceResult athleteResult;
  final List<RaceResult> results;
  final int? relayLegNumber;
}

List<AthleteStageResult> buildAthleteStageResults({
  required Iterable<CompetitionStage> stages,
  required Map<String, List<RaceResult>> resultsByStageId,
  required String? athleteId,
  required String athleteName,
}) {
  final sortedStages = [...stages]
    ..sort((a, b) {
      if (a.order != b.order) return a.order.compareTo(b.order);
      return a.name.compareTo(b.name);
    });
  final stageResults = <AthleteStageResult>[];

  for (final stage in sortedStages) {
    final rawResults = resultsByStageId[stage.id] ?? const <RaceResult>[];
    final match = _findAthleteResult(
      rawResults,
      athleteId: athleteId,
      athleteName: athleteName,
    );
    if (match == null) continue;

    final displayedResults = match.relayLegNumber == null
        ? [...rawResults]
        : relayLegRaceResults(rawResults, match.relayLegNumber!);
    displayedResults.sort(_compareResults);

    stageResults.add(
      AthleteStageResult(
        stage: stage,
        athleteResult: match.result,
        results: displayedResults,
        relayLegNumber: match.relayLegNumber,
      ),
    );
  }

  return stageResults;
}

({RaceResult result, int? relayLegNumber})? _findAthleteResult(
  Iterable<RaceResult> results, {
  required String? athleteId,
  required String athleteName,
}) {
  for (final result in results) {
    final isTeam =
        result.entrant?.kind == ResultEntrantKind.team ||
        result.relayMembers.isNotEmpty;
    if (!isTeam &&
        _matchesAthlete(
          candidateId: result.athleteId,
          candidateName: result.name,
          athleteId: athleteId,
          athleteName: athleteName,
        )) {
      return (result: result, relayLegNumber: null);
    }

    for (final member in result.relayMembers) {
      if (!_matchesAthlete(
        candidateId: member.athleteId,
        candidateName: member.name,
        athleteId: athleteId,
        athleteName: athleteName,
      )) {
        continue;
      }
      final relayResult = relayLegRaceResult(result, member.legNumber);
      if (relayResult != null) {
        return (result: relayResult, relayLegNumber: member.legNumber);
      }
    }
  }
  return null;
}

bool _matchesAthlete({
  required String? candidateId,
  required String candidateName,
  required String? athleteId,
  required String athleteName,
}) {
  final targetId = athleteId?.trim();
  final currentId = candidateId?.trim();
  if (targetId != null && targetId.isNotEmpty) {
    if (currentId != null && currentId.isNotEmpty) {
      return currentId == targetId;
    }
  }

  final targetName = _normalizeName(athleteName);
  return targetName.isNotEmpty && _normalizeName(candidateName) == targetName;
}

String _normalizeName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

int _compareResults(RaceResult a, RaceResult b) {
  final statusCompare = a.statusSortOrder.compareTo(b.statusSortOrder);
  if (statusCompare != 0) return statusCompare;
  final aTime = a.totalMs;
  final bTime = b.totalMs;
  if (aTime != null && bTime != null && aTime != bTime) {
    return aTime.compareTo(bTime);
  }
  if (aTime != null) return -1;
  if (bTime != null) return 1;
  return a.name.compareTo(b.name);
}
