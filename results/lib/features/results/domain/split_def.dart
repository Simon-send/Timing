import '../../../core/firebase/firestore_mappers.dart';

class SplitDef {
  const SplitDef({
    required this.id,
    required this.label,
    required this.sort,
    required this.kind,
    required this.stationName,
    required this.isPublic,
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
    );
  }

  final String id;
  final String label;
  final int sort;
  final String kind;
  final String stationName;
  final bool isPublic;
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
  });

  final String? fromSplitId;
  final String toSplitId;
  final List<String> includedSplitIds;

  SplitRangeSelection copyWith({
    String? fromSplitId,
    bool clearFromSplitId = false,
    String? toSplitId,
    List<String>? includedSplitIds,
  }) {
    return SplitRangeSelection(
      fromSplitId: clearFromSplitId ? null : fromSplitId ?? this.fromSplitId,
      toSplitId: toSplitId ?? this.toSplitId,
      includedSplitIds: includedSplitIds ?? this.includedSplitIds,
    );
  }
}
