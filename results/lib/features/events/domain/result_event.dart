import '../../../core/firebase/firestore_mappers.dart';
import '../../../core/formatting/time_formatters.dart';

class ResultEvent {
  const ResultEvent({
    required this.id,
    required this.name,
    required this.sportName,
    required this.date,
    required this.place,
  });

  factory ResultEvent.fromMap(String id, Map<String, dynamic> data) {
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
    );
  }

  final String id;
  final String name;
  final String sportName;
  final DateTime? date;
  final String place;

  String get dateLabel => formatDate(date);
}
