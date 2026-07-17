const resultClassQueryParameter = 'classId';
const resultSplitQueryParameter = 'split';
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

String resultsLocation({
  required String eventId,
  String? classId,
  String? stageId,
  String? splitId,
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
      resultSplitQueryParameter: splitId,
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
      resultSplitQueryParameter: splitId,
      resultStageQueryParameter: stageId,
      relayLegQueryParameter: relayLegNumber?.toString(),
      compareWithResultQueryParameter: compareWithResultId,
      compareWithRelayLegQueryParameter: compareWithRelayLegNumber?.toString(),
    }),
  ).toString();
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
