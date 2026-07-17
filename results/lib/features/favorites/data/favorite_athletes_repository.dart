import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FavoriteAthletesRepository {
  Stream<Set<String>> watchFavoriteAthleteIds(String uid);

  Future<void> setFavorite({
    required String uid,
    required String athleteId,
    required String athleteName,
    required bool isFavorite,
  });
}

class FirestoreFavoriteAthletesRepository
    implements FavoriteAthletesRepository {
  FirestoreFavoriteAthletesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<Set<String>> watchFavoriteAthleteIds(String uid) {
    return _favorites(uid).snapshots().map(
      (snapshot) => snapshot.docs.map((document) => document.id).toSet(),
    );
  }

  @override
  Future<void> setFavorite({
    required String uid,
    required String athleteId,
    required String athleteName,
    required bool isFavorite,
  }) {
    final document = _favorites(uid).doc(athleteId);
    if (!isFavorite) return document.delete();
    return document.set({
      'athleteId': athleteId,
      'athleteName': athleteName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  CollectionReference<Map<String, dynamic>> _favorites(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('favoriteAthletes');
  }
}
