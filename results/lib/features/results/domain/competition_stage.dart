import '../../../core/firebase/firestore_mappers.dart';

enum ResultProfile { standard, sprint, relay, biathlon }

enum ResultProfileSource { eq, override }

class CompetitionStage {
  const CompetitionStage({
    required this.id,
    required this.name,
    required this.type,
    required this.level,
    required this.order,
    required this.classIds,
    required this.profile,
    required this.profileSource,
    this.hasRelayCapability = false,
    this.hasBiathlonCapability = false,
  });

  factory CompetitionStage.fromMap(String id, Map<String, dynamic> data) {
    return CompetitionStage(
      id: asNonEmptyString(data['stageId']) ?? id,
      name: asNonEmptyString(data['name']) ?? 'Etappe $id',
      type: asNonEmptyString(data['type']) ?? '',
      level: asInt(data['level']),
      order: asInt(data['order']) ?? 10000,
      classIds: _stringList(data['classIds']),
      profile: _profile(data['resultProfile']),
      profileSource: asNonEmptyString(data['resultProfileSource']) == 'override'
          ? ResultProfileSource.override
          : ResultProfileSource.eq,
      hasRelayCapability: asBool(data['isRelay']) ?? false,
      hasBiathlonCapability: asBool(data['isBiathlon']) ?? false,
    );
  }

  final String id;
  final String name;
  final String type;
  final int? level;
  final int order;
  final List<String> classIds;
  final ResultProfile profile;
  final ResultProfileSource profileSource;
  final bool hasRelayCapability;
  final bool hasBiathlonCapability;

  bool get isRelay => hasRelayCapability || profile == ResultProfile.relay;
  bool get isBiathlon =>
      hasBiathlonCapability || profile == ResultProfile.biathlon;

  bool supportsClass(String classId) {
    return classIds.isEmpty || classIds.contains(classId);
  }

  bool get isQualification {
    return profile == ResultProfile.sprint &&
        (type == 'interval' ||
            level == 1 ||
            name.toLowerCase().contains('prolog'));
  }
}

ResultProfile _profile(Object? value) {
  return switch (asNonEmptyString(value)) {
    'sprint' => ResultProfile.sprint,
    'relay' => ResultProfile.relay,
    'biathlon' => ResultProfile.biathlon,
    _ => ResultProfile.standard,
  };
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map(asNonEmptyString)
      .whereType<String>()
      .toList(growable: false);
}
