import '../../../core/firebase/firestore_mappers.dart';
import '../../../core/formatting/time_formatters.dart';

class ResultEvent {
  const ResultEvent({
    required this.id,
    required this.name,
    required this.sportName,
    required this.date,
    required this.place,
    this.country = '',
    this.county = '',
    this.area = '',
    this.participantCount,
    this.disciplines = const [],
    this.ageFrom,
    this.ageTo,
  });

  factory ResultEvent.fromMap(String id, Map<String, dynamic> data) {
    final discipline = _firstText([
      data['disciplineName'],
      asStringMap(data['discipline'])['name'],
      asStringMap(data['Disiplin'])['Navn'],
    ]);
    final disciplineValues = <String>[
      ..._asStringValues(data['disciplines']),
      ..._asStringValues(data['Disipliner']),
      ?discipline,
    ];

    return ResultEvent(
      id: id,
      name:
          asNonEmptyString(data['name']) ??
          asNonEmptyString(data['Navn']) ??
          'Event $id',
      sportName:
          asNonEmptyString(data['sportName']) ??
          asNestedString(data['sport'], 'name') ??
          asNestedString(data['Gren'], 'Navn') ??
          'Ukjent idrett',
      date:
          asDateTime(data['date']) ??
          asDateTime(data['Dato']) ??
          asDateTime(data['Aktiv']),
      place:
          asNonEmptyString(data['place']) ??
          asNonEmptyString(data['Sted']) ??
          '',
      country:
          _firstText([
            data['countryName'],
            asStringMap(data['country'])['name'],
            asStringMap(data['Land'])['Navn'],
            data['country'],
            data['Land'],
          ]) ??
          '',
      county:
          _firstText([
            data['county'],
            data['countyName'],
            data['fylke'],
            data['Fylke'],
            data['region'],
            asStringMap(data['region'])['name'],
          ]) ??
          '',
      area:
          _firstText([
            data['area'],
            data['areaName'],
            data['municipality'],
            data['municipalityName'],
            data['kommune'],
            data['Kommune'],
            data['district'],
          ]) ??
          '',
      participantCount: _firstInt([
        data['participantCount'],
        data['participantsCount'],
        data['contestantCount'],
        data['numberOfParticipants'],
        data['antallDeltakere'],
      ]),
      disciplines: _uniqueSorted(disciplineValues),
      ageFrom: _firstInt([
        data['ageFrom'],
        data['minAge'],
        data['alderFra'],
        data['AlderFom'],
      ]),
      ageTo: _firstInt([
        data['ageTo'],
        data['maxAge'],
        data['alderTil'],
        data['AlderTom'],
      ]),
    );
  }

  final String id;
  final String name;
  final String sportName;
  final DateTime? date;
  final String place;
  final String country;
  final String county;
  final String area;
  final int? participantCount;
  final List<String> disciplines;
  final int? ageFrom;
  final int? ageTo;

  String get dateLabel => formatDate(date);
}

String? _firstText(Iterable<Object?> values) {
  for (final value in values) {
    final text = asNonEmptyString(value);
    if (text != null && value is! Map && value is! List) return text;
  }
  return null;
}

int? _firstInt(Iterable<Object?> values) {
  for (final value in values) {
    final number = asInt(value);
    if (number != null) return number;
  }
  return null;
}

List<String> _asStringValues(Object? value) {
  if (value is! List) return const [];
  return value
      .map((entry) {
        if (entry is Map) {
          final map = asStringMap(entry);
          return _firstText([map['name'], map['Navn'], map['label']]);
        }
        return asNonEmptyString(entry);
      })
      .whereType<String>()
      .toList();
}

List<String> _uniqueSorted(Iterable<String> values) {
  final byNormalizedValue = <String, String>{};
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      byNormalizedValue.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
    }
  }
  final result = byNormalizedValue.values.toList();
  result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
}
