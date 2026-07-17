import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/events/domain/result_event.dart';
import 'package:results/features/events/presentation/event_filters.dart';

void main() {
  test('maps optional event filter metadata from Firestore data', () {
    final event = ResultEvent.fromMap('event-1', {
      'name': 'Sommerløpet',
      'sportName': 'Friidrett',
      'date': '2026-06-20',
      'place': 'Lillehammer',
      'country': {'name': 'Norge'},
      'county': 'Innlandet',
      'municipality': 'Lillehammer',
      'participantCount': 245,
      'discipline': {'name': 'Terrengløp'},
      'disciplines': ['5 km', '10 km', '5 km'],
      'ageFrom': 12,
      'ageTo': 80,
    });

    expect(event.country, 'Norge');
    expect(event.county, 'Innlandet');
    expect(event.area, 'Lillehammer');
    expect(event.participantCount, 245);
    expect(event.disciplines, ['10 km', '5 km', 'Terrengløp']);
    expect(event.ageFrom, 12);
    expect(event.ageTo, 80);
  });

  test('combines event filters and treats age as an overlapping interval', () {
    final event = ResultEvent(
      id: 'event-1',
      name: 'Sommerløpet',
      sportName: 'Friidrett',
      date: DateTime(2026, 6, 20),
      place: 'Lillehammer stadion',
      country: 'Norge',
      county: 'Innlandet',
      area: 'Lillehammer',
      participantCount: 245,
      disciplines: const ['10 km'],
      ageFrom: 12,
      ageTo: 80,
    );
    final filters = EventFilterCriteria(
      country: 'Norge',
      sport: 'Friidrett',
      discipline: '10 km',
      county: 'Innlandet',
      area: 'stadion',
      dateFrom: DateTime(2026, 6, 1),
      dateTo: DateTime(2026, 6, 30),
      participantsFrom: 200,
      participantsTo: 300,
      ageFrom: 65,
      ageTo: 90,
    );

    expect(filters.matches(event, 'sommer'), isTrue);
    expect(filters.copyWith(country: 'Sverige').matches(event, ''), isFalse);
    expect(filters.copyWith(participantsFrom: 300).matches(event, ''), isFalse);
    expect(filters.copyWith(ageFrom: 81).matches(event, ''), isFalse);
  });

  test('excludes unknown metadata only when its filter is active', () {
    final event = ResultEvent(
      id: 'legacy-event',
      name: 'Eldre event',
      sportName: 'Ski',
      date: DateTime(2025),
      place: 'Oslo',
    );

    expect(const EventFilterCriteria().matches(event, ''), isTrue);
    expect(
      const EventFilterCriteria(participantsFrom: 1).matches(event, ''),
      isFalse,
    );
    expect(const EventFilterCriteria(ageFrom: 10).matches(event, ''), isFalse);
  });
}
