import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_mappers.dart';
import '../../results/domain/race_result.dart';
import '../domain/athlete_profile.dart';

abstract class AthleteProfileRepository {
  Stream<String?> watchLinkedAthleteId(String uid);

  Future<void> linkAthlete({
    required String uid,
    required AthleteProfile athlete,
  });

  Future<void> clearLinkedAthlete(String uid);

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
  Stream<String?> watchLinkedAthleteId(String uid) async* {
    try {
      await for (final snapshot in _profileDoc(uid).snapshots()) {
        yield asNonEmptyString(snapshot.data()?['athleteId']);
      }
    } on FirebaseException catch (error) {
      if (_isRecoverableProfileReadError(error)) {
        yield null;
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> linkAthlete({
    required String uid,
    required AthleteProfile athlete,
  }) {
    return _profileDoc(uid).set({
      'athleteId': athlete.athleteId,
      'athleteName': athlete.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
      'linkedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> clearLinkedAthlete(String uid) {
    return _profileDoc(uid).delete();
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
    return _firestore
        .collectionGroup('results')
        .where('athleteId', isEqualTo: athleteId)
        .snapshots()
        .asyncMap((snapshot) async {
          final participantCounts = await _participantCountsFor(snapshot.docs);
          final races =
              snapshot.docs
                  .map(
                    (doc) => _athleteRaceFromDoc(
                      doc,
                      participantCount:
                          participantCounts[doc
                              .reference
                              .parent
                              .parent
                              ?.path] ??
                          0,
                    ),
                  )
                  .toList()
                ..sort(_compareRacesDesc);
          return races;
        });
  }

  Future<Map<String, int>> _participantCountsFor(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> resultDocs,
  ) async {
    final classDocs = <String, DocumentReference<Map<String, dynamic>>>{};
    for (final resultDoc in resultDocs) {
      final classDoc = resultDoc.reference.parent.parent;
      if (classDoc != null) classDocs[classDoc.path] = classDoc;
    }

    final entries = await Future.wait(
      classDocs.entries.map((entry) async {
        try {
          final data = (await entry.value.get()).data();
          final participants = asInt(data?['participantCount']) ?? 0;
          final results = asInt(data?['resultCount']) ?? 0;
          return MapEntry(
            entry.key,
            participants > results ? participants : results,
          );
        } on FirebaseException {
          // Class metadata is supplementary. Keep the race list available if
          // an older database rule does not expose the parent class document.
          return MapEntry(entry.key, 0);
        }
      }),
    );
    return Map.fromEntries(entries);
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
}) {
  final data = doc.data();
  final parsedResult = RaceResult.fromMap(doc.id, data);
  final classDoc = doc.reference.parent.parent;
  final eventDoc = classDoc?.parent.parent;
  final eventId = asNonEmptyString(data['eventId']) ?? eventDoc?.id ?? '';
  final classId = asNonEmptyString(data['classId']) ?? classDoc?.id ?? '';

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
    status:
        asNonEmptyString(data['status']) ??
        asNonEmptyString(data['StatusTekst']) ??
        '',
    participantCount: participantCount,
    totalMs: parsedResult.totalMs,
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
