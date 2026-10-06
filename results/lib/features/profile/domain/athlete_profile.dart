import '../../../core/firebase/firestore_mappers.dart';
import 'biathlon_aggregate_profile.dart';
import 'biathlon_comparison.dart';

class AthleteProfile {
  const AthleteProfile({
    required this.athleteId,
    required this.displayName,
    required this.normalizedName,
    required this.primaryClubId,
    required this.primaryTeamId,
    required this.events,
  });

  factory AthleteProfile.fromMap(String id, Map<String, dynamic> data) {
    final events =
        asMapList(data['events'])
            .map(AthleteEvent.fromMap)
            .where((event) => event.eventId.isNotEmpty)
            .toList()
          ..sort((a, b) {
            final eventCompare = _compareStringIdsDesc(a.eventId, b.eventId);
            if (eventCompare != 0) return eventCompare;
            return a.className.compareTo(b.className);
          });

    return AthleteProfile(
      athleteId: asNonEmptyString(data['athleteId']) ?? id,
      displayName: asNonEmptyString(data['displayName']) ?? id,
      normalizedName: asNonEmptyString(data['normalizedName']) ?? '',
      primaryClubId: asNonEmptyString(data['primaryClubId']),
      primaryTeamId: asNonEmptyString(data['primaryTeamId']),
      events: events,
    );
  }

  final String athleteId;
  final String displayName;
  final String normalizedName;
  final String? primaryClubId;
  final String? primaryTeamId;
  final List<AthleteEvent> events;
}

class AthleteEvent {
  const AthleteEvent({
    required this.eventId,
    required this.name,
    required this.classId,
    required this.className,
    required this.rank,
    required this.finishRank,
  });

  factory AthleteEvent.fromMap(Map<String, dynamic> data) {
    return AthleteEvent(
      eventId: asNonEmptyString(data['eventId']) ?? '',
      name: asNonEmptyString(data['name']) ?? '',
      classId: asNonEmptyString(data['classId']) ?? '',
      className: asNonEmptyString(data['className']) ?? '',
      rank: asInt(data['rank']),
      finishRank: asInt(data['finishRank']),
    );
  }

  final String eventId;
  final String name;
  final String classId;
  final String className;
  final int? rank;
  final int? finishRank;

  String get key => '$eventId/$classId';
}

class AthleteRace {
  const AthleteRace({
    required this.eventId,
    required this.classId,
    required this.resultId,
    this.stageId,
    required this.athleteId,
    required this.name,
    required this.className,
    required this.clubName,
    required this.teamName,
    required this.bib,
    required this.rank,
    required this.finishRank,
    required this.totalText,
    required this.shooting,
    required this.status,
    this.participantCount = 0,
    this.totalMs,
    this.isRelay = false,
    this.splits = const [],
    this.biathlonMetrics,
    this.biathlonBenchmark,
    this.biathlonAllProfile,
    this.biathlonTopHalfProfile,
  });

  final String eventId;
  final String classId;
  final String resultId;
  final String? stageId;
  final String athleteId;
  final String name;
  final String className;
  final String clubName;
  final String teamName;
  final String bib;
  final int? rank;
  final int? finishRank;
  final String totalText;
  final String shooting;
  final String status;
  final int participantCount;
  final int? totalMs;
  final bool isRelay;
  final List<AthleteRaceSplit> splits;
  final BiathlonRaceMetrics? biathlonMetrics;
  final BiathlonTopHalfBenchmark? biathlonBenchmark;
  final BiathlonAggregateProfile? biathlonAllProfile;
  final BiathlonAggregateProfile? biathlonTopHalfProfile;

  BiathlonAggregateProfile? referenceFor(BiathlonReferenceGroup group) {
    if (group == BiathlonReferenceGroup.all) return biathlonAllProfile;
    if (biathlonTopHalfProfile != null) return biathlonTopHalfProfile;
    final legacy = biathlonBenchmark;
    return legacy == null
        ? null
        : BiathlonAggregateProfile.fromLegacyTopHalf(legacy);
  }

  String get key => '$eventId/$classId/${stageId ?? ''}';

  /// Old imports can contain zero-valued analysis for non-finishers.
  bool get isCompletedIndividualBiathlonRace {
    if (isRelay || biathlonMetrics == null || (totalMs ?? 0) <= 0) {
      return false;
    }
    final upperStatus = status.trim().toUpperCase();
    return !RegExp(
      r'\b(DNS|DNF|DSQ|DQ|NC|NQ|DID NOT START|DID NOT FINISH|DISQUALIFIED|BRUTT|IKKE STARTET|IKKE FULLFØRT|DISKVALIFISERT)\b',
    ).hasMatch(upperStatus);
  }

  String get placementLabel {
    if (finishRank != null && finishRank! > 0) return finishRank.toString();
    if (rank != null && rank! > 0) return rank.toString();
    final statusText = status.trim();
    return statusText.isEmpty ? '-' : statusText;
  }
}

class AthleteRaceSplit {
  const AthleteRaceSplit({
    required this.id,
    required this.label,
    required this.sort,
    required this.cumRank,
    required this.cumMs,
    this.participantCount,
  });

  final String id;
  final String label;
  final int sort;
  final int? cumRank;
  final int? cumMs;
  final int? participantCount;
}

class AthleteAffiliations {
  const AthleteAffiliations({this.clubName, this.teamName});

  final String? clubName;
  final String? teamName;
}

int _compareStringIdsDesc(String a, String b) {
  final aNumber = int.tryParse(a);
  final bNumber = int.tryParse(b);
  if (aNumber != null && bNumber != null && aNumber != bNumber) {
    return bNumber.compareTo(aNumber);
  }
  return b.compareTo(a);
}
