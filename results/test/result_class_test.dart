import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/results/domain/result_class.dart';

void main() {
  test('reads imported etappe metadata', () {
    final raceClass = ResultClass.fromMap('class-1', {
      'name': 'M senior',
      'resultCount': 12,
      'participantCount': 15,
      'etappeUid': 101,
      'etappeName': 'Sprint menn',
      'etappeKm': '7,5',
    });

    expect(raceClass.disciplineName, 'Sprint');
    expect(raceClass.distanceMeters, 7500);
  });

  test('combines disciplines and sorts classes by total distance', () {
    const classes = [
      ResultClass(
        id: 'long',
        name: 'M17, 3 x 1 km',
        resultCount: 8,
        participantCount: 10,
        etappeUid: 2,
        etappeName: 'Fellesstart M17',
      ),
      ResultClass(
        id: 'short',
        name: 'J11-12, 5 x 400 m',
        resultCount: 16,
        participantCount: 20,
        etappeUid: 1,
        etappeName: 'Sprint jenter',
      ),
      ResultClass(
        id: 'middle',
        name: 'G13, 2.5 km',
        resultCount: 10,
        participantCount: 12,
        etappeUid: 3,
        etappeName: 'Sprint gutter',
      ),
    ];

    expect(combinedDisciplineLabel(classes), 'Sprint / Fellesstart');
    expect(
      sortResultClassesByDistance(classes).map((raceClass) => raceClass.id),
      ['short', 'middle', 'long'],
    );
  });

  test('finds every discipline in one combined race name', () {
    const raceClass = ResultClass(
      id: 'combined',
      name: 'M senior, 10 km',
      resultCount: 20,
      participantCount: 20,
      etappeUid: 1,
      etappeName: 'Sprint/Fellestart',
    );

    expect(raceClass.disciplineNames, ['Sprint', 'Fellesstart']);
    expect(combinedDisciplineLabel([raceClass]), 'Sprint / Fellesstart');
  });

  test('initial class has the most participants unless one is preferred', () {
    const classes = [
      ResultClass(
        id: 'most-results',
        name: 'M17',
        resultCount: 30,
        participantCount: 30,
        etappeUid: 1,
      ),
      ResultClass(
        id: 'most-athletes',
        name: 'K17',
        resultCount: 25,
        participantCount: 42,
        etappeUid: 2,
      ),
    ];

    expect(initialResultClass(classes).id, 'most-athletes');
    expect(
      initialResultClass(classes, preferredClassId: 'most-results').id,
      'most-results',
    );
  });

  test('uses result count when an older import lacks participant count', () {
    const classes = [
      ResultClass(
        id: 'small',
        name: 'K17',
        resultCount: 1,
        participantCount: 1,
        etappeUid: 1,
      ),
      ResultClass(
        id: 'legacy-large',
        name: 'M17',
        resultCount: 40,
        participantCount: 0,
        etappeUid: 2,
      ),
    ];

    expect(initialResultClass(classes).id, 'legacy-large');
  });
}
