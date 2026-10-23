import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:results/features/events/domain/result_event.dart';
import 'package:results/features/profile/data/athlete_profile_repository.dart';
import 'package:results/features/profile/domain/athlete_profile.dart';
import 'package:results/features/profile/domain/athlete_season.dart';

void main() {
  test(
    'streams every legacy and stage result before season selection',
    () async {
      final firestore = FakeFirebaseFirestore();
      final statuses = ['', 'DNF', 'DNS', 'DFQ', 'DSQ', 'DQ'];
      await firestore.doc('athletes/athlete').set({
        'events': [
          for (final id in ['old', 'new']) {'eventId': id, 'classId': 'class'},
        ],
      });
      await firestore.doc('events/old').set({
        'sportName': 'Langrenn',
        'date': DateTime(2025, 4, 30),
      });
      await firestore.doc('events/new').set({
        'sportName': 'Biathlon',
        'date': DateTime(2025, 5, 1),
      });
      await firestore.doc('events/new/stages/final').set({'stageId': 'final'});
      await firestore.doc('events/old/classes/class').set({
        'participantCount': 250,
      });
      await firestore.doc('events/new/stages/final/classes/class').set({
        'participantCount': 20,
      });
      for (var index = 0; index < 205; index++) {
        await firestore.doc('events/old/classes/class/results/r$index').set({
          'athleteId': 'athlete',
          'eventId': 'old',
          'classId': 'class',
          'status': index < statuses.length ? statuses[index] : '',
          'rank': 1,
          'totalMs': 1000,
          'splitValues': {
            'missing': {'id': 'missing', 'sort': 1},
          },
        });
      }
      await firestore
          .doc('events/new/stages/final/classes/class/results/stage')
          .set({
            'athleteId': 'athlete',
            'eventId': 'new',
            'classId': 'class',
            'stageId': 'final',
            'totalMs': 2000,
            'rank': 2,
          });
      final repository = FirestoreAthleteProfileRepository(
        firestore: firestore,
      );
      final first = Completer<List<AthleteRace>>();
      final subscription = repository.watchAthleteRaces('athlete').listen((
        races,
      ) {
        if (!first.isCompleted) first.complete(races);
      }, onError: first.completeError);
      addTearDown(() async {
        await firestore.clearPersistence();
        await subscription.cancel();
      });
      final races = await first.future;
      expect(races, hasLength(206));
      expect(races.any((race) => race.resultId == 'r204'), isTrue);
      expect(
        races.singleWhere((race) => race.resultId == 'stage').stageId,
        'final',
      );
      expect(races.singleWhere((race) => race.resultId == 'r3').status, 'DFQ');
      expect(races.first.biathlonMetrics, isNull);
      expect(
        races.singleWhere((race) => race.resultId == 'r6').splits.single.cumMs,
        isNull,
      );
      final events = [
        for (final doc in (await firestore.collection('events').get()).docs)
          ResultEvent.fromMap(doc.id, doc.data()),
      ];
      final dataset = AthleteSeasonDataset(races: races, events: events);
      final old = dataset.select(AthleteSeasonSelection.only({2024}));
      expect(old.races, hasLength(205));
      expect(old.statisticalRaces, hasLength(200));
      expect(
        dataset
            .select(AthleteSeasonSelection.only({2025}))
            .races
            .single
            .resultId,
        'stage',
      );
    },
  );

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
