import '../../events/domain/result_event.dart';
import 'athlete_profile.dart';

/// Winter sport seasons use the event's recorded calendar date, inclusive of
/// April 30. Other sports and missing dates deliberately have no season.
class AthleteSeason {
  const AthleteSeason(this.startYear);

  final int startYear;

  String get label =>
      '$startYear/${((startYear + 1) % 100).toString().padLeft(2, '0')}';
}

AthleteSeason? seasonFor({
  required String? sportName,
  required DateTime? date,
}) {
  if (date == null) return null;
  final sport = sportName?.trim().toLowerCase().replaceAll(
    RegExp(r'[-_\s]+'),
    ' ',
  );
  const winterSports = {
    'langrenn',
    'cross country',
    'cross country skiing',
    'xc',
    'xc skiing',
    'skiskyting',
    'biathlon',
  };
  if (!winterSports.contains(sport)) return null;
  return AthleteSeason(date.month >= 5 ? date.year : date.year - 1);
}

class AthleteSeasonSelection {
  const AthleteSeasonSelection.all() : startYears = null;

  AthleteSeasonSelection.only(Set<int> years)
    : startYears = Set.unmodifiable(years);

  final Set<int>? startYears;
  bool get isAll => startYears == null;

  /// Unassigned races stay visible in every selection; never guess a season.
  bool includes(AthleteSeason? season) =>
      season == null || isAll || startYears!.contains(season.startYear);
}

/// Built from the complete repository stream, before any presentation paging.
/// Every result/analysis panel must consume the same selected scope.
class AthleteSeasonDataset {
  AthleteSeasonDataset({
    required Iterable<AthleteRace> races,
    required Iterable<ResultEvent> events,
  }) : races = List.unmodifiable(races),
       eventsById = {for (final event in events) event.id: event};

  final List<AthleteRace> races;
  final Map<String, ResultEvent> eventsById;

  AthleteSeason? seasonOf(AthleteRace race) {
    final event = eventsById[race.eventId];
    return seasonFor(sportName: event?.sportName, date: event?.date);
  }

  List<AthleteSeason> get seasons {
    final years = {
      for (final race in races)
        if (seasonOf(race) case final season?) season.startYear,
    }.toList()..sort((a, b) => b.compareTo(a));
    return [for (final year in years) AthleteSeason(year)];
  }

  List<AthleteRace> racesIn(AthleteSeason? season) => [
    for (final race in races)
      if (seasonOf(race)?.startYear == season?.startYear) race,
  ];

  AthleteSeasonScope select(AthleteSeasonSelection selection) {
    final visible = [
      for (final race in races)
        if (selection.includes(seasonOf(race))) race,
    ];
    return AthleteSeasonScope(
      races: visible,
      statisticalRaces: [
        for (final race in visible)
          if (race.isFinished && (selection.isAll || seasonOf(race) != null))
            race,
      ],
    );
  }
}

class AthleteSeasonScope {
  AthleteSeasonScope({
    required Iterable<AthleteRace> races,
    required Iterable<AthleteRace> statisticalRaces,
  }) : races = List.unmodifiable(races),
       statisticalRaces = List.unmodifiable(statisticalRaces);

  final List<AthleteRace> races;
  final List<AthleteRace> statisticalRaces;
}
