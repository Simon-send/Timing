import '../../../core/firebase/firestore_mappers.dart';

class ResultClass {
  const ResultClass({
    required this.id,
    required this.name,
    required this.resultCount,
    required this.participantCount,
    required this.etappeUid,
  });

  factory ResultClass.fromMap(String id, Map<String, dynamic> data) {
    return ResultClass(
      id: id,
      name:
          asNonEmptyString(data['name']) ??
          asNonEmptyString(data['Navn']) ??
          'Klasse $id',
      resultCount: asInt(data['resultCount']) ?? 0,
      participantCount: asInt(data['participantCount']) ?? 0,
      etappeUid: asInt(data['etappeUid']) ?? asInt(data['etappeUID']),
    );
  }

  final String id;
  final String name;
  final int resultCount;
  final int participantCount;
  final int? etappeUid;
}
