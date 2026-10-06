import 'dart:convert';

import '../domain/split_def.dart';

const resultClassQueryParameter = 'classId';
const resultSplitQueryParameter = 'split';
const resultSplitModeQueryParameter = 'splitMode';
const resultSplitFromQueryParameter = 'splitFrom';
const resultSplitToQueryParameter = 'splitTo';
const resultSplitIdsQueryParameter = 'splitIds';
const compareBaseClassQueryParameter = 'compareBaseClassId';
const compareBaseResultQueryParameter = 'compareBaseResultId';
const compareWithResultQueryParameter = 'compareWithResultId';
const resultStageQueryParameter = 'stageId';
const relayLegQueryParameter = 'relayLeg';
const compareBaseRelayLegQueryParameter = 'compareBaseRelayLeg';
const compareWithRelayLegQueryParameter = 'compareWithRelayLeg';

String? resultSplitQueryValue(Map<String, String> queryParameters) {
  return queryParameters[resultSplitQueryParameter] ??
      queryParameters['splitId'];
}

SplitRangeSelection? resultSplitRangeQueryValue(
  Map<String, String> queryParameters,
) {
  final mode = queryParameters[resultSplitModeQueryParameter];
  final toSplitId =
      _queryValue(queryParameters[resultSplitToQueryParameter]) ??
      resultSplitQueryValue(queryParameters);
  if (mode == 'range') {
    if (toSplitId == null) return null;
    return SplitRangeSelection(
      fromSplitId: _queryValue(queryParameters[resultSplitFromQueryParameter]),
      toSplitId: toSplitId,
    );
  }
  if (mode != 'independent') return null;

  final encodedIds = queryParameters[resultSplitIdsQueryParameter];
  if (encodedIds == null) return null;
  try {
    final decodedIds = jsonDecode(encodedIds);
    if (decodedIds is! List) return null;
    final includedSplitIds = decodedIds
        .whereType<String>()
        .map(_queryValue)
        .whereType<String>()
        .toList(growable: false);
    final focusedSplitId =
        toSplitId ?? (includedSplitIds.isEmpty ? null : includedSplitIds.last);
    if (focusedSplitId == null || includedSplitIds.isEmpty) return null;
    return SplitRangeSelection(
      fromSplitId: _queryValue(queryParameters[resultSplitFromQueryParameter]),
      toSplitId: focusedSplitId,
      includedSplitIds: includedSplitIds,
      isIndependent: true,
    );
  } on FormatException {
    return null;
  }
}

String resultsLocation({
  required String eventId,
  String? classId,
  String? stageId,
  String? splitId,
  SplitRangeSelection? splitRange,
  int? relayLegNumber,
  String? compareBaseClassId,
  String? compareBaseResultId,
  int? compareBaseRelayLegNumber,
}) {
  return Uri(
    path: '/events/${Uri.encodeComponent(eventId)}/results',
    queryParameters: _queryParameters({
      resultClassQueryParameter: classId,
      resultStageQueryParameter: stageId,
      ..._splitQueryParameters(splitId: splitId, splitRange: splitRange),
      relayLegQueryParameter: relayLegNumber?.toString(),
      compareBaseClassQueryParameter: compareBaseClassId,
      compareBaseResultQueryParameter: compareBaseResultId,
      compareBaseRelayLegQueryParameter: compareBaseRelayLegNumber?.toString(),
    }),
  ).toString();
}

String athleteLocation({
  required String eventId,
  required String classId,
  required String resultId,
  String? stageId,
  String? splitId,
  SplitRangeSelection? splitRange,
  int? relayLegNumber,
  String? compareWithResultId,
  int? compareWithRelayLegNumber,
}) {
  return Uri(
    path:
        '/events/${Uri.encodeComponent(eventId)}/results/'
        '${Uri.encodeComponent(classId)}/athletes/'
        '${Uri.encodeComponent(resultId)}',
    queryParameters: _queryParameters({
      ..._splitQueryParameters(splitId: splitId, splitRange: splitRange),
      resultStageQueryParameter: stageId,
      relayLegQueryParameter: relayLegNumber?.toString(),
      compareWithResultQueryParameter: compareWithResultId,
      compareWithRelayLegQueryParameter: compareWithRelayLegNumber?.toString(),
    }),
  ).toString();
}

Map<String, String?> _splitQueryParameters({
  required String? splitId,
  required SplitRangeSelection? splitRange,
}) {
  if (splitRange == null) {
    return {resultSplitQueryParameter: splitId};
  }
  return {
    resultSplitQueryParameter: splitRange.toSplitId,
    resultSplitModeQueryParameter: splitRange.isIndependent
        ? 'independent'
        : 'range',
    resultSplitFromQueryParameter: splitRange.fromSplitId,
    resultSplitToQueryParameter: splitRange.toSplitId,
    resultSplitIdsQueryParameter: splitRange.isIndependent
        ? jsonEncode(splitRange.includedSplitIds)
        : null,
  };
}

String? _queryValue(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

Map<String, String>? _queryParameters(Map<String, String?> values) {
  final query = <String, String>{};
  for (final entry in values.entries) {
    final value = entry.value;
    if (value != null && value.isNotEmpty) {
      query[entry.key] = value;
    }
  }
  return query.isEmpty ? null : query;
}
