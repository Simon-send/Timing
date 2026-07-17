import '../../../core/firebase/firestore_mappers.dart';

class SplitDef {
  const SplitDef({
    required this.id,
    required this.label,
    required this.sort,
    required this.kind,
    required this.stationName,
    required this.isPublic,
    this.legNumber,
    this.roundNumber,
  });

  factory SplitDef.fromMap(String id, Map<String, dynamic> data) {
    return SplitDef(
      id:
          asNonEmptyString(data['setupUid']) ??
          asNonEmptyString(data['stasjonsOppsettUID']) ??
          id,
      label:
          asNonEmptyString(data['code']) ??
          asNonEmptyString(data['label']) ??
          asNonEmptyString(data['Navn']) ??
          id,
      sort: asInt(data['sort']) ?? asInt(data['Sortering']) ?? 10000,
      kind: asNonEmptyString(data['kind']) ?? 'split',
      stationName: asNonEmptyString(data['stationName']) ?? '',
      isPublic:
          asBool(data['isPublic']) ??
          asBool(data['Er_offentlig']) ??
          asBool(data['erOffentlig']) ??
          true,
      legNumber: asInt(data['legNumber']) ?? asInt(data['etappeNumber']),
      roundNumber: asInt(data['roundNumber']),
    );
  }

  final String id;
  final String label;
  final int sort;
  final String kind;
  final String stationName;
  final bool isPublic;
  final int? legNumber;
  final int? roundNumber;
}

class SplitOption {
  const SplitOption({
    required this.id,
    required this.label,
    required this.sort,
    required this.kind,
  });

  final String id;
  final String label;
  final int sort;
  final String kind;
}

class SplitRangeSelection {
  const SplitRangeSelection({
    required this.fromSplitId,
    required this.toSplitId,
    this.includedSplitIds = const [],
    this.isIndependent = false,
  });

  final String? fromSplitId;
  final String toSplitId;
  final List<String> includedSplitIds;
  final bool isIndependent;

  SplitRangeSelection copyWith({
    String? fromSplitId,
    bool clearFromSplitId = false,
    String? toSplitId,
    List<String>? includedSplitIds,
    bool? isIndependent,
  }) {
    return SplitRangeSelection(
      fromSplitId: clearFromSplitId ? null : fromSplitId ?? this.fromSplitId,
      toSplitId: toSplitId ?? this.toSplitId,
      includedSplitIds: includedSplitIds ?? this.includedSplitIds,
      isIndependent: isIndependent ?? this.isIndependent,
    );
  }
}
