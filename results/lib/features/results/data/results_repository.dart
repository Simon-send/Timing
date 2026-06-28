import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/race_result.dart';
import '../domain/result_class.dart';
import '../domain/split_def.dart';

abstract class ResultsRepository {
  Stream<List<ResultClass>> watchClasses(String eventId);

  Stream<List<SplitDef>> watchSplitDefs(String eventId, String classId);

  Stream<List<RaceResult>> watchResults(
    String eventId,
    String classId, {
    int limit = initialResultsLimit,
  });

  Future<List<RaceResult>> fetchResults(String eventId, String classId);

  Stream<RaceResult?> watchResult(
    String eventId,
    String classId,
    String resultId,
  );
}

const resultsPageSize = 20;
const initialResultsLimit = resultsPageSize;

class FirestoreResultsRepository implements ResultsRepository {
  FirestoreResultsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<ResultClass>> watchClasses(String eventId) {
    return _eventDoc(eventId).collection('classes').snapshots().map((snapshot) {
      final classes = snapshot.docs
          .map((doc) => ResultClass.fromMap(doc.id, doc.data()))
          .toList();
      classes.sort((a, b) {
        final nameCompare = a.name.compareTo(b.name);
        if (nameCompare != 0) return nameCompare;
        return a.id.compareTo(b.id);
      });
      return classes;
    });
  }

  @override
  Stream<List<SplitDef>> watchSplitDefs(String eventId, String classId) {
    return _classDoc(eventId, classId).collection('splitDefs').snapshots().map((
      snapshot,
    ) {
      final splits = snapshot.docs
          .map((doc) => SplitDef.fromMap(doc.id, doc.data()))
          .toList();
      splits.sort(_compareSplitDefs);
      return splits;
    });
  }

  @override
  Stream<List<RaceResult>> watchResults(
    String eventId,
    String classId, {
    int limit = initialResultsLimit,
  }) {
    return _resultsQuery(eventId, classId).snapshots().map((snapshot) {
      final results = _resultsFromSnapshot(snapshot);
      return results.length <= limit ? results : results.take(limit).toList();
    });
  }

  @override
  Future<List<RaceResult>> fetchResults(String eventId, String classId) async {
    final snapshot = await _resultsQuery(eventId, classId).get();
    return _resultsFromSnapshot(snapshot);
  }

  @override
  Stream<RaceResult?> watchResult(
    String eventId,
    String classId,
    String resultId,
  ) {
    return _classDoc(
      eventId,
      classId,
    ).collection('results').doc(resultId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return RaceResult.fromMap(snapshot.id, data);
    });
  }

  DocumentReference<Map<String, dynamic>> _eventDoc(String eventId) {
    return _firestore.collection('events').doc(eventId);
  }

  DocumentReference<Map<String, dynamic>> _classDoc(
    String eventId,
    String classId,
  ) {
    return _eventDoc(eventId).collection('classes').doc(classId);
  }

  Query<Map<String, dynamic>> _resultsQuery(String eventId, String classId) {
    return _classDoc(eventId, classId).collection('results');
  }
}

List<RaceResult> _resultsFromSnapshot(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) {
  final results = snapshot.docs
      .map((doc) => RaceResult.fromMap(doc.id, doc.data()))
      .toList();
  results.sort(_compareResults);
  return results;
}

int _compareSplitDefs(SplitDef a, SplitDef b) {
  if (a.sort != b.sort) return a.sort - b.sort;
  return a.label.compareTo(b.label);
}

int _compareResults(RaceResult a, RaceResult b) {
  final statusCompare = a.statusSortOrder.compareTo(b.statusSortOrder);
  if (statusCompare != 0) return statusCompare;
  if (a.rank != null && b.rank != null && a.rank != b.rank) {
    return a.rank! - b.rank!;
  }
  if (a.totalMs != null && b.totalMs != null && a.totalMs != b.totalMs) {
    return a.totalMs! - b.totalMs!;
  }
  if (a.rank != null) return -1;
  if (b.rank != null) return 1;
  if (a.totalMs != null) return -1;
  if (b.totalMs != null) return 1;
  return a.name.compareTo(b.name);
}
