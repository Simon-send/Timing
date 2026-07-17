import '../../../core/firebase/firestore_mappers.dart';

class ResultClass {
  const ResultClass({
    required this.id,
    required this.name,
    required this.resultCount,
    required this.participantCount,
    required this.etappeUid,
    this.etappeName,
    this.etappeKm,
    this.primaryStageId,
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
      etappeName: asNonEmptyString(data['etappeName']),
      etappeKm: _asPositiveDouble(data['etappeKm']),
      primaryStageId: asNonEmptyString(data['primaryStageId']),
    );
  }

  final String id;
  final String name;
  final int resultCount;
  final int participantCount;
  final int? etappeUid;
  final String? etappeName;
  final double? etappeKm;
  final String? primaryStageId;

  List<String> get disciplineNames => _disciplineNames('$etappeName $name');

  String? get disciplineName {
    final names = disciplineNames;
    return names.isEmpty ? null : names.first;
  }

  /// Participant data was not stored by older imports, so result count is the
  /// best available athlete count for those documents.
  int get athleteCount => participantCount > 0 ? participantCount : resultCount;

  int? get distanceMeters {
    final importedKm = etappeKm;
    if (importedKm != null) return (importedKm * 1000).round();
    return _distanceMetersFromText('$etappeName $name');
  }
}

/// Returns a new class list ordered by total distance. Classes on the same
/// etappe stay together so compatible comparison choices are not scattered.
List<ResultClass> sortResultClassesByDistance(Iterable<ResultClass> classes) {
  final sorted = classes.toList();
  sorted.sort((a, b) {
    final distanceCompare = _compareNullableInt(
      a.distanceMeters,
      b.distanceMeters,
    );
    if (distanceCompare != 0) return distanceCompare;

    final etappeCompare = _compareNullableInt(a.etappeUid, b.etappeUid);
    if (etappeCompare != 0) return etappeCompare;

    final disciplineCompare = (a.disciplineName ?? '').compareTo(
      b.disciplineName ?? '',
    );
    if (disciplineCompare != 0) return disciplineCompare;

    final nameCompare = _naturalCompare(a.name, b.name);
    if (nameCompare != 0) return nameCompare;
    return a.id.compareTo(b.id);
  });
  return sorted;
}

/// A single label for all disciplines represented by the class choices, for
/// example "Sprint / Fellesstart".
String? combinedDisciplineLabel(Iterable<ResultClass> classes) {
  final disciplines = <String>[];
  for (final raceClass in classes) {
    for (final discipline in raceClass.disciplineNames) {
      if (!disciplines.contains(discipline)) disciplines.add(discipline);
    }
  }
  disciplines.sort((a, b) {
    final orderCompare = _disciplineOrder(a).compareTo(_disciplineOrder(b));
    return orderCompare != 0 ? orderCompare : a.compareTo(b);
  });
  return disciplines.isEmpty ? null : disciplines.join(' / ');
}

/// Uses an explicit/athlete class when available, otherwise the class with the
/// largest participant field.
ResultClass initialResultClass(
  List<ResultClass> classes, {
  String? preferredClassId,
}) {
  assert(classes.isNotEmpty);
  for (final raceClass in classes) {
    if (raceClass.id == preferredClassId) return raceClass;
  }

  return classes.reduce((best, candidate) {
    if (candidate.athleteCount != best.athleteCount) {
      return candidate.athleteCount > best.athleteCount ? candidate : best;
    }
    if (candidate.resultCount != best.resultCount) {
      return candidate.resultCount > best.resultCount ? candidate : best;
    }
    final distanceCompare = _compareNullableInt(
      candidate.distanceMeters,
      best.distanceMeters,
    );
    if (distanceCompare != 0) return distanceCompare < 0 ? candidate : best;
    return _naturalCompare(candidate.name, best.name) < 0 ? candidate : best;
  });
}

double? _asPositiveDouble(Object? value) {
  if (value == null) return null;
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value.toString().replaceAll(',', '.'));
  return parsed != null && parsed > 0 ? parsed : null;
}

List<String> _disciplineNames(String text) {
  var remaining = text.trim().toLowerCase();
  if (remaining.isEmpty) return const [];

  const disciplines = <(String, String)>[
    ('kort normal', 'Kort normal'),
    ('supersprint', 'Supersprint'),
    ('fellesstart', 'Fellesstart'),
    ('fellestart', 'Fellesstart'),
    ('jaktstart', 'Jaktstart'),
    ('sprint', 'Sprint'),
    ('normal', 'Normal'),
    ('stafett', 'Stafett'),
    ('prolog', 'Prolog'),
    ('individuell', 'Individuell'),
  ];
  final found = <String>[];
  for (final (needle, label) in disciplines) {
    if (!remaining.contains(needle)) continue;
    if (!found.contains(label)) found.add(label);
    // Avoid also finding "sprint" inside "supersprint" while still allowing
    // combined names such as "Sprint/Fellestart" to yield both disciplines.
    remaining = remaining.replaceAll(needle, ' ');
  }
  found.sort((a, b) {
    final orderCompare = _disciplineOrder(a).compareTo(_disciplineOrder(b));
    return orderCompare != 0 ? orderCompare : a.compareTo(b);
  });
  return found;
}

int? _distanceMetersFromText(String text) {
  final normalized = text.toLowerCase().replaceAll(',', '.');
  final multiplied = RegExp(
    r'(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*(km|m)\b',
  ).firstMatch(normalized);
  if (multiplied != null) {
    final laps = double.parse(multiplied.group(1)!);
    final length = double.parse(multiplied.group(2)!);
    return _meters(length, multiplied.group(3)!) * laps.round();
  }

  final direct = RegExp(
    r'(\d+(?:\.\d+)?)\s*(km|kilometer|m|meter)\b',
  ).firstMatch(normalized);
  if (direct == null) return null;
  return _meters(double.parse(direct.group(1)!), direct.group(2)!);
}

int _meters(double value, String unit) {
  return (value * (unit.startsWith('km') ? 1000 : 1)).round();
}

int _disciplineOrder(String discipline) {
  const order = [
    'Sprint',
    'Supersprint',
    'Fellesstart',
    'Jaktstart',
    'Kort normal',
    'Normal',
    'Individuell',
    'Prolog',
    'Stafett',
  ];
  final index = order.indexOf(discipline);
  return index < 0 ? order.length : index;
}

int _compareNullableInt(int? a, int? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

int _naturalCompare(String a, String b) {
  final chunks = RegExp(
    r'\d+|\D+',
  ).allMatches(a.toLowerCase()).map((match) => match.group(0)!).toList();
  final otherChunks = RegExp(
    r'\d+|\D+',
  ).allMatches(b.toLowerCase()).map((match) => match.group(0)!).toList();
  final count = chunks.length < otherChunks.length
      ? chunks.length
      : otherChunks.length;
  for (var index = 0; index < count; index++) {
    final leftNumber = int.tryParse(chunks[index]);
    final rightNumber = int.tryParse(otherChunks[index]);
    final compare = leftNumber != null && rightNumber != null
        ? leftNumber.compareTo(rightNumber)
        : chunks[index].compareTo(otherChunks[index]);
    if (compare != 0) return compare;
  }
  return chunks.length.compareTo(otherChunks.length);
}
