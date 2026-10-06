import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/profile/data/athlete_profile_repository.dart';
import 'package:results/features/profile/domain/athlete_profile.dart';

void main() {
  test('builds only explicit legacy and stage result collection paths', () {
    const profile = AthleteProfile(
      athleteId: 'athlete-1',
      displayName: 'Ada Lovelace',
      normalizedName: 'ada lovelace',
      primaryClubId: null,
      primaryTeamId: null,
      events: [
        AthleteEvent(
          eventId: 'event-1',
          name: 'Race',
          classId: 'class-1',
          className: 'Women',
          rank: 1,
          finishRank: 1,
        ),
      ],
    );

    final paths = buildAthleteRaceResultCollectionPaths(
      profile: profile,
      stageIdsByEvent: const {
        'event-1': ['prologue', 'final'],
      },
    );

    expect(paths, [
      'events/event-1/classes/class-1/results',
      'events/event-1/stages/final/classes/class-1/results',
      'events/event-1/stages/prologue/classes/class-1/results',
    ]);
    expect(paths, isNot(contains('results')));
  });

  test('ignores incomplete event index entries and duplicate stages', () {
    const profile = AthleteProfile(
      athleteId: 'athlete-1',
      displayName: 'Ada Lovelace',
      normalizedName: 'ada lovelace',
      primaryClubId: null,
      primaryTeamId: null,
      events: [
        AthleteEvent(
          eventId: 'event-1',
          name: 'Race',
          classId: 'class-1',
          className: 'Women',
          rank: null,
          finishRank: null,
        ),
        AthleteEvent(
          eventId: 'event-2',
          name: 'Missing class',
          classId: '',
          className: '',
          rank: null,
          finishRank: null,
        ),
      ],
    );

    final paths = buildAthleteRaceResultCollectionPaths(
      profile: profile,
      stageIdsByEvent: const {
        'event-1': ['final', 'final', ''],
      },
    );

    expect(paths, [
      'events/event-1/classes/class-1/results',
      'events/event-1/stages/final/classes/class-1/results',
    ]);
  });
}
