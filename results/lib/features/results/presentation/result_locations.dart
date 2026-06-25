const resultClassQueryParameter = 'classId';
const resultSplitQueryParameter = 'split';
const compareBaseClassQueryParameter = 'compareBaseClassId';
const compareBaseResultQueryParameter = 'compareBaseResultId';
const compareWithResultQueryParameter = 'compareWithResultId';

String? resultSplitQueryValue(Map<String, String> queryParameters) {
  return queryParameters[resultSplitQueryParameter] ??
      queryParameters['splitId'];
}

String resultsLocation({
  required String eventId,
  String? classId,
  String? splitId,
  String? compareBaseClassId,
  String? compareBaseResultId,
}) {
  return Uri(
    path: '/events/${Uri.encodeComponent(eventId)}/results',
    queryParameters: _queryParameters({
      resultClassQueryParameter: classId,
      resultSplitQueryParameter: splitId,
      compareBaseClassQueryParameter: compareBaseClassId,
      compareBaseResultQueryParameter: compareBaseResultId,
    }),
  ).toString();
}

String athleteLocation({
  required String eventId,
  required String classId,
  required String resultId,
  String? splitId,
  String? compareWithResultId,
}) {
  return Uri(
    path:
        '/events/${Uri.encodeComponent(eventId)}/results/'
        '${Uri.encodeComponent(classId)}/athletes/'
        '${Uri.encodeComponent(resultId)}',
    queryParameters: _queryParameters({
      resultSplitQueryParameter: splitId,
      compareWithResultQueryParameter: compareWithResultId,
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
