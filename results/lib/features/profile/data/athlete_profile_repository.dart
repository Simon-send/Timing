import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_mappers.dart';
import '../../../core/firebase/switch_latest.dart';
import '../../results/domain/race_result.dart';
import '../domain/athlete_link_state.dart';
import '../domain/athlete_profile.dart';
import '../domain/biathlon_aggregate_profile.dart';
import '../domain/biathlon_comparison.dart';

abstract class AthleteProfileRepository {
  Stream<AthleteLinkState> watchAthleteLinkState(String uid);

  Stream<String?> watchLinkedAthleteId(String uid);

  Future<void> linkAthlete({
    required String uid,
    required AthleteProfile athlete,
  });

  Future<void> clearLinkedAthlete(String uid);

  Future<void> completeAthleteLinkOnboarding(String uid);

  Future<List<AthleteProfile>> searchAthletesByFullName(String fullName);

  Stream<AthleteProfile?> watchAthlete(String athleteId);

  Stream<List<AthleteRace>> watchAthleteRaces(String athleteId);

  Future<AthleteAffiliations> fetchAffiliations({
    required String? clubId,
    required String? teamId,
  });
}

class FirestoreAthleteProfileRepository implements AthleteProfileRepository {
  FirestoreAthleteProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<AthleteLinkState> watchAthleteLinkState(String uid) async* {
    try {
      await for (final snapshot in _profileDoc(uid).snapshots()) {
        yield AthleteLinkState.fromMap(snapshot.data());
      }
    } on FirebaseException catch (error) {
      if (_isRecoverableProfileReadError(error)) {
        yield const AthleteLinkState(
          athleteId: null,
          onboardingCompleted: false,
        );
        return;
      }
      rethrow;
    }
  }

  @override
  Stream<String?> watchLinkedAthleteId(String uid) {
    return watchAthleteLinkState(uid).map((state) => state.athleteId);
  }

  @override
  Future<void> linkAthlete({
    required String uid,
    required AthleteProfile athlete,
  }) {
    return _profileDoc(uid).set({
      'athleteId': athlete.athleteId,
      'athleteName': athlete.displayName,
      'athleteLinkOnboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'linkedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> clearLinkedAthlete(String uid) {
    return _profileDoc(uid).set({
      'athleteId': FieldValue.delete(),
      'athleteName': FieldValue.delete(),
      'linkedAt': FieldValue.delete(),
      'athleteLinkOnboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> completeAthleteLinkOnboarding(String uid) {
    return _profileDoc(uid).set({
      'athleteLinkOnboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<List<AthleteProfile>> searchAthletesByFullName(String fullName) async {
    final normalized = normalizeAthleteName(fullName);
    if (normalized == null) return const [];

    final snapshot = await _firestore
        .collection('athletes')
        .where('normalizedName', isEqualTo: normalized)
        .limit(12)
        .get();

    final athletes = snapshot.docs
        .map((doc) => AthleteProfile.fromMap(doc.id, doc.data()))
        .toList();
    athletes.sort((a, b) {
      final nameCompare = a.displayName.compareTo(b.displayName);
      if (nameCompare != 0) return nameCompare;
      return a.athleteId.compareTo(b.athleteId);
    });
    return athletes;
  }

  @override
  Stream<AthleteProfile?> watchAthlete(String athleteId) {
    return _firestore.collection('athletes').doc(athleteId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (data == null) return null;
      return AthleteProfile.fromMap(snapshot.id, data);
    });
  }

  @override
  Stream<List<AthleteRace>> watchAthleteRaces(String athleteId) {
    return switchLatest(
      _firestore.collection('athletes').doc(athleteId).snapshots(),
      (snapshot) {
        final data = snapshot.data();
        if (data == null) return Stream.value(const <AthleteRace>[]);
        return _watchIndexedAthleteRaces(
          athleteId,
          AthleteProfile.fromMap(snapshot.id, data),
        );
      },
    );
  }

  Stream<List<AthleteRace>> _watchIndexedAthleteRaces(
    String athleteId,
    AthleteProfile profile,
  ) async* {
    final stageIdsByEvent = <String, List<String>>{};
    await Future.wait(
      profile.events.map((event) async {
        final snapshot = await _firestore
            .collection('events')
            .doc(event.eventId)
            .collection('stages')
            .get();
        stageIdsByEvent[event.eventId] = snapshot.docs
            .map((doc) => doc.id)
            .toList();
      }),
    );

    final paths = buildAthleteRaceResultCollectionPaths(
      profile: profile,
      stageIdsByEvent: stageIdsByEvent,
    );
    if (paths.isEmpty) {
      yield const <AthleteRace>[];
      return;
    }

    final queries = paths.map(
      (path) =>
          _firestore.collection(path).where('athleteId', isEqualTo: athleteId),
    );
    await for (final docs in _combineResultQueries(queries.toList())) {
      final classMetadata = await _classMetadataFor(docs);
      final races =
          docs
              .map(
                (doc) => _athleteRaceFromDoc(
                  doc,
                  participantCount:
                      classMetadata[doc.reference.parent.parent?.path]
                          ?.participantCount ??
                      0,
                  biathlonBenchmark:
                      classMetadata[doc.reference.parent.parent?.path]
                          ?.biathlonBenchmark,
                  biathlonAllProfile:
                      classMetadata[doc.reference.parent.parent?.path]
                          ?.biathlonAllProfile,
                  biathlonTopHalfProfile:
                      classMetadata[doc.reference.parent.parent?.path]
                          ?.biathlonTopHalfProfile,
                ),
              )
              .toList()
            ..sort(_compareRacesDesc);
      yield races;
    }
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _combineResultQueries(List<Query<Map<String, dynamic>>> queries) {
    late StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    controller;
    final latest = List<QuerySnapshot<Map<String, dynamic>>?>.filled(
      queries.length,
      null,
    );
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    controller =
        StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          onListen: () {
            for (var index = 0; index < queries.length; index++) {
              subscriptions.add(
                queries[index].snapshots().listen((snapshot) {
                  latest[index] = snapshot;
                  if (latest.every((value) => value != null)) {
                    controller.add([
                      for (final value in latest) ...value!.docs,
                    ]);
                  }
                }, onError: controller.addError),
              );
            }
          },
          onCancel: () async {
            await Future.wait(
              subscriptions.map((subscription) => subscription.cancel()),
            );
          },
        );
    return controller.stream;
  }

  Future<Map<String, _ClassRaceMetadata>> _classMetadataFor(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> resultDocs,
  ) async {
    final classDocs = <String, DocumentReference<Map<String, dynamic>>>{};
    final biathlonClassPaths = <String>{};
    for (final resultDoc in resultDocs) {
      final classDoc = resultDoc.reference.parent.parent;
      if (classDoc == null) continue;
      classDocs[classDoc.path] = classDoc;
      final data = resultDoc.data();
      if (asBool(data['isBiathlon']) == true ||
          asStringMap(
            asStringMap(data['analysisSummary'])['biathlon'],
          ).isNotEmpty) {
        biathlonClassPaths.add(classDoc.path);
      }
    }

    final entries = await Future.wait(
      classDocs.entries.map((entry) async {
        try {
          final data = (await entry.value.get()).data();
          final participants = asInt(data?['participantCount']) ?? 0;
          final results = asInt(data?['resultCount']) ?? 0;
          final profiles = biathlonClassPaths.contains(entry.key)
              ? await Future.wait([
                  _readAggregateProfile(
                    entry.value,
                    BiathlonReferenceGroup.all,
                  ),
                  _readAggregateProfile(
                    entry.value,
                    BiathlonReferenceGroup.topHalf,
                  ),
                ])
              : const <BiathlonAggregateProfile?>[null, null];
          return MapEntry(
            entry.key,
            _ClassRaceMetadata(
              participantCount: participants > results ? participants : results,
              biathlonBenchmark: BiathlonTopHalfBenchmark.fromMap(
                data?['biathlonTopHalf'],
              ),
              biathlonAllProfile: profiles[0],
              biathlonTopHalfProfile: profiles[1],
            ),
          );
        } on FirebaseException {
          // Class metadata is supplementary. Keep the race list available if
          // an older database rule does not expose the parent class document.
          return MapEntry(
            entry.key,
            const _ClassRaceMetadata(participantCount: 0),
          );
        }
      }),
    );
    return Map.fromEntries(entries);
  }

  Future<BiathlonAggregateProfile?> _readAggregateProfile(
    DocumentReference<Map<String, dynamic>> classDoc,
    BiathlonReferenceGroup group,
  ) async {
    try {
      final rootRef = classDoc
          .collection('aggregateProfiles')
          .doc(group.documentId);
      final root = (await rootRef.get()).data();
      if (root == null) return null;
      final manifest = asStringMap(root['sections']);
      final sectionIds = <String>[
        for (final ids in manifest.values)
          if (ids is List)
            for (final id in ids)
              if (id is String) id,
      ];
      if (sectionIds.length > 128) return null;
      final sections = await Future.wait(
        sectionIds.map((id) => rootRef.collection('sections').doc(id).get()),
      );
      final sectionDocs = <String, Map<String, dynamic>>{};
      for (final section in sections) {
        final data = section.data();
        if (data != null) sectionDocs[section.id] = data;
      }
      final merged = mergeBiathlonAggregateSections(root, sectionDocs);
      return BiathlonAggregateProfile.fromMap(merged, group);
    } on FirebaseException {
      // Old rules deny the new collection until the importer rollout.
      return null;
    }
  }

  @override
  Future<AthleteAffiliations> fetchAffiliations({
    required String? clubId,
    required String? teamId,
  }) async {
    if (clubId != null && clubId == teamId) {
      final name = await _fetchClubName(clubId);
      return AthleteAffiliations(clubName: name, teamName: name);
    }

    final names = await Future.wait([
      _fetchClubName(clubId),
      _fetchClubName(teamId),
    ]);
    return AthleteAffiliations(clubName: names[0], teamName: names[1]);
  }

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('main');
  }

  Future<String?> _fetchClubName(String? clubId) async {
    if (clubId == null || clubId.trim().isEmpty) return null;
    final snapshot = await _firestore.collection('clubs').doc(clubId).get();
    return asNonEmptyString(snapshot.data()?['name']);
  }
}

class _ClassRaceMetadata {
  const _ClassRaceMetadata({
    required this.participantCount,
    this.biathlonBenchmark,
    this.biathlonAllProfile,
    this.biathlonTopHalfProfile,
  });

  final int participantCount;
  final BiathlonTopHalfBenchmark? biathlonBenchmark;
  final BiathlonAggregateProfile? biathlonAllProfile;
  final BiathlonAggregateProfile? biathlonTopHalfProfile;
}

List<String> buildAthleteRaceResultCollectionPaths({
  required AthleteProfile profile,
  required Map<String, List<String>> stageIdsByEvent,
}) {
  final paths = <String>{};
  for (final event in profile.events) {
    if (event.eventId.isEmpty || event.classId.isEmpty) continue;

    paths.add('events/${event.eventId}/classes/${event.classId}/results');
    for (final stageId in stageIdsByEvent[event.eventId] ?? const <String>[]) {
      if (stageId.isEmpty) continue;
      paths.add(
        'events/${event.eventId}/stages/$stageId/classes/'
        '${event.classId}/results',
      );
    }
  }
  return paths.toList()..sort();
}

String? normalizeAthleteName(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return null;
  return normalized.toLowerCase();
}

String athleteProfileErrorMessage(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'Firestore nekter tilgang. Kontroller at reglene er publisert og at innlogget bruker bare leser/skriver sin egen profil.',
      'failed-precondition' =>
        'Firestore mangler en indeks for dette søket. Åpne indeks-lenken i Firebase-feilen og opprett indeksen.',
      'unavailable' =>
        'Kunne ikke nå Firestore akkurat nå. Sjekk nettverket og prøv igjen.',
      _ =>
        error.message?.trim().isNotEmpty == true
            ? error.message!
            : error.toString(),
    };
  }
  return error.toString();
}

bool _isRecoverableProfileReadError(FirebaseException error) {
  return error.code == 'permission-denied' || error.code == 'unavailable';
}

AthleteRace _athleteRaceFromDoc(
  QueryDocumentSnapshot<Map<String, dynamic>> doc, {
  required int participantCount,
  BiathlonTopHalfBenchmark? biathlonBenchmark,
  BiathlonAggregateProfile? biathlonAllProfile,
  BiathlonAggregateProfile? biathlonTopHalfProfile,
}) {
  final data = doc.data();
  final parsedResult = RaceResult.fromMap(doc.id, data);
  final classDoc = doc.reference.parent.parent;
  final eventDoc = classDoc?.parent.parent;
  final eventId = asNonEmptyString(data['eventId']) ?? eventDoc?.id ?? '';
  final classId = asNonEmptyString(data['classId']) ?? classDoc?.id ?? '';
  final biathlonSummary = asStringMap(
    asStringMap(data['analysisSummary'])['biathlon'],
  );
  final isBiathlon =
      asBool(data['isBiathlon']) == true ||
      biathlonSummary.isNotEmpty ||
      parsedResult.biathlon?.hasData == true;
  final expectedShootingCount = biathlonAllProfile?.shootingPasses.values
      .fold<int>(
        0,
        (maxIndex, point) => point.index != null && point.index! > maxIndex
            ? point.index!
            : maxIndex,
      );

  return AthleteRace(
    eventId: eventId,
    classId: classId,
    resultId: doc.id,
    stageId: asNonEmptyString(data['stageId']),
    athleteId: asNonEmptyString(data['athleteId']) ?? '',
    name: asNonEmptyString(data['name']) ?? '',
    className: asNonEmptyString(data['className']) ?? '',
    clubName:
        asNonEmptyString(data['clubName']) ??
        asNonEmptyString(data['club']) ??
        '',
    teamName:
        asNonEmptyString(data['teamName']) ??
        asNonEmptyString(data['team']) ??
        asNonEmptyString(data['lagName']) ??
        asNonEmptyString(data['lag']) ??
        '',
    bib:
        asNonEmptyString(data['bib']) ??
        asNonEmptyString(data['fullBib']) ??
        '',
    rank: asInt(data['rank']),
    finishRank:
        asInt(data['finishRank']) ?? asInt(data['calculatedFinishRank']),
    totalText:
        asNonEmptyString(data['totalText']) ??
        asNonEmptyString(data['totalTimeFormatted']) ??
        '',
    shooting:
        asNonEmptyString(asStringMap(data['analysis'])['shootingResult']) ?? '',
    status: parsedResult.status,
    participantCount: participantCount,
    totalMs: parsedResult.totalMs,
    biathlonMetrics: isBiathlon
        ? BiathlonRaceMetrics.fromResult(
            parsedResult,
            publicMetrics: asStringMap(biathlonSummary['metrics']),
            publicPasses: asStringMap(biathlonSummary['passes']),
            expectedShootingCount: expectedShootingCount,
          )
        : null,
    biathlonBenchmark: biathlonBenchmark,
    biathlonAllProfile: biathlonAllProfile,
    biathlonTopHalfProfile: biathlonTopHalfProfile,
    isRelay:
        asBool(data['isRelay']) ??
        (asNonEmptyString(asStringMap(data['entrant'])['kind']) == 'team'),
    splits:
        parsedResult.splitValues.values
            .map(
              (split) => AthleteRaceSplit(
                id: split.id,
                label: split.label,
                sort: split.sort,
                cumRank: split.cumRank,
                cumMs: split.cumMs,
                participantCount: split.cumRankCount,
              ),
            )
            .toList()
          ..sort((a, b) {
            if (a.sort != b.sort) return a.sort - b.sort;
            final aMs = a.cumMs ?? 1 << 62;
            final bMs = b.cumMs ?? 1 << 62;
            return aMs.compareTo(bMs);
          }),
  );
}

int _compareRacesDesc(AthleteRace a, AthleteRace b) {
  final eventCompare = _compareNullableIntDesc(
    int.tryParse(a.eventId),
    int.tryParse(b.eventId),
  );
  if (eventCompare != 0) return eventCompare;

  final classCompare = a.className.compareTo(b.className);
  if (classCompare != 0) return classCompare;
  return a.resultId.compareTo(b.resultId);
}

int _compareNullableIntDesc(int? a, int? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}
