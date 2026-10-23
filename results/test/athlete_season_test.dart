import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/events/domain/result_event.dart';
import 'package:results/features/profile/domain/athlete_profile.dart';
import 'package:results/features/profile/domain/athlete_season.dart';

void main() {
  test('winter seasons include April 30 and begin May 1', () {
    for (final sport in [
      'Langrenn',
      'Skiskyting',
      'Cross-country skiing',
      'Biathlon',
    ]) {
      expect(
        seasonFor(sportName: sport, date: DateTime(2026, 4, 30, 23, 59))?.label,
        '2025/26',
      );
      expect(
        seasonFor(sportName: sport, date: DateTime(2026, 5, 1))?.label,
        '2026/27',
      );
    }
    expect(
      seasonFor(sportName: 'Biathlon', date: DateTime(2025, 1, 1))?.startYear,
      2024,
    );
  });

  test('missing date, sport and unsupported sports remain unassigned', () {
    expect(seasonFor(sportName: 'Running', date: DateTime(2026, 2)), isNull);
    expect(seasonFor(sportName: '', date: DateTime(2026, 2)), isNull);
    expect(seasonFor(sportName: 'Biathlon', date: null), isNull);
  });

  test('one, multiple and all seasons share the complete result set', () {
    final races = [
      for (var index = 0; index < 250; index++) race('old', '$index'),
      race('new', 'new'),
      race('unknown', 'unknown'),
      race('old', 'dnf', status: 'DNF'),
    ];
    final data = AthleteSeasonDataset(
      races: races,
      events: [
        event('old', DateTime(2025, 4, 30)),
        event('new', DateTime(2025, 5, 1)),
      ],
    );
    expect(data.seasons.map((season) => season.label), ['2025/26', '2024/25']);
    expect(
      data.select(const AthleteSeasonSelection.all()).races,
      hasLength(253),
    );
    final selected = data.select(AthleteSeasonSelection.only({2024}));
    expect(selected.races, hasLength(252));
    expect(selected.statisticalRaces, hasLength(250));
    expect(selected.races.last.status, 'DNF');
    expect(
      selected.statisticalRaces.any((race) => race.resultId == 'unknown'),
      isFalse,
    );
    expect(
      data.select(const AthleteSeasonSelection.all()).statisticalRaces,
      hasLength(252),
    );
    expect(selected.races.any((race) => race.resultId == 'unknown'), isTrue);
    expect(
      data.select(AthleteSeasonSelection.only({2024, 2025})).races,
      hasLength(253),
    );
    expect(
      data.select(AthleteSeasonSelection.only({2030})).races.single.resultId,
      'unknown',
    );
  });

  test('empty history and missing measurements stay empty and null', () {
    final data = AthleteSeasonDataset(races: [], events: []);
    expect(data.seasons, isEmpty);
    expect(data.select(const AthleteSeasonSelection.all()).races, isEmpty);
    final missing = race('missing', 'missing', totalMs: null);
    expect(missing.totalMs, isNull);
  });
}

ResultEvent event(String id, DateTime? date, {String sport = 'Langrenn'}) =>
    ResultEvent(id: id, name: id, sportName: sport, date: date, place: '');

AthleteRace race(
  String eventId,
  String resultId, {
  String status = '',
  int? totalMs = 1000,
  String? stageId,
  String classId = 'class',
}) => AthleteRace(
  eventId: eventId,
  classId: classId,
  stageId: stageId,
  resultId: resultId,
  athleteId: 'athlete',
  name: 'Athlete',
  className: 'Senior',
  clubName: '',
  teamName: '',
  bib: '1',
  rank: 1,
  finishRank: 1,
  totalText: totalMs == null ? '' : '1:00',
  shooting: '',
  status: status,
  totalMs: totalMs,
);
