import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/firebase/switch_latest.dart';

import '../domain/race_result.dart';
import '../domain/competition_stage.dart';
import '../domain/result_class.dart';
import '../domain/split_def.dart';

abstract class ResultsRepository {
  Stream<List<ResultClass>> watchClasses(String eventId);

  Stream<List<CompetitionStage>> watchStages(String eventId);

  Stream<List<SplitDef>> watchStageSplitDefs(
    String eventId,
    String stageId,
    String classId,
  );

  Stream<List<RaceResult>> watchStageResults(
    String eventId,
    String stageId,
    String classId, {
    int limit = initialResultsLimit,
  });

  Future<List<RaceResult>> fetchStageResults(
    String eventId,
    String stageId,
    String classId,
  );

  Stream<RaceResult?> watchStageResult(
    String eventId,
    String stageId,
    String classId,
    String resultId,
  );

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

const resultsPageSize = 50;
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
  Stream<List<CompetitionStage>> watchStages(String eventId) {
    return _eventDoc(eventId).collection('stages').snapshots().map((snapshot) {
      final stages = snapshot.docs
          .map((doc) => CompetitionStage.fromMap(doc.id, doc.data()))
          .toList();
      stages.sort((a, b) {
        if (a.order != b.order) return a.order - b.order;
        final level = (a.level ?? 10000) - (b.level ?? 10000);
        if (level != 0) return level;
        return a.name.compareTo(b.name);
      });
      return stages;
    });
  }

  @override
  Stream<List<SplitDef>> watchSplitDefs(String eventId, String classId) {
    return switchLatest(_watchPrimaryStageId(eventId, classId), (stageId) {
      if (stageId == null) return Stream.value(const <SplitDef>[]);
      return watchStageSplitDefs(eventId, stageId, classId);
    });
  }

  @override
  Stream<List<SplitDef>> watchStageSplitDefs(
    String eventId,
    String stageId,
    String classId,
  ) {
    return _stageClassDoc(
      eventId,
      stageId,
      classId,
    ).collection('splitDefs').snapshots().map((snapshot) {
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
    return switchLatest(_watchPrimaryStageId(eventId, classId), (stageId) {
      if (stageId == null) return Stream.value(const <RaceResult>[]);
      return watchStageResults(eventId, stageId, classId, limit: limit);
    });
  }

  @override
  Stream<List<RaceResult>> watchStageResults(
    String eventId,
    String stageId,
    String classId, {
    int limit = initialResultsLimit,
  }) {
    return switchLatest(
      _stageClassDoc(eventId, stageId, classId)
          .snapshots()
          .map((snapshot) => snapshot.data()?['resultOrderVersion'] == 1)
          .distinct(),
      (hasServerOrder) {
        final baseQuery = _stageResultsQuery(eventId, stageId, classId);
        final query = hasServerOrder
            ? baseQuery.orderBy('displayOrder').limit(limit)
            : baseQuery;
        return query.snapshots().map((snapshot) {
          final results = _resultsFromSnapshot(snapshot);
          return hasServerOrder || results.length <= limit
              ? results
              : results.take(limit).toList();
        });
      },
    );
  }

  @override
  Future<List<RaceResult>> fetchResults(String eventId, String classId) async {
    final classSnapshot = await _classDoc(eventId, classId).get();
    final stageId = _primaryStageId(classSnapshot.data());
    if (stageId == null) return const [];
    return fetchStageResults(eventId, stageId, classId);
  }

  @override
  Future<List<RaceResult>> fetchStageResults(
    String eventId,
    String stageId,
    String classId,
  ) async {
    final snapshot = await _stageResultsQuery(eventId, stageId, classId).get();
    return _resultsFromSnapshot(snapshot);
  }

  @override
  Stream<RaceResult?> watchStageResult(
    String eventId,
    String stageId,
    String classId,
    String resultId,
  ) {
    return _stageClassDoc(
      eventId,
      stageId,
      classId,
    ).collection('results').doc(resultId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return RaceResult.fromMap(snapshot.id, data);
    });
  }

  @override
  Stream<RaceResult?> watchResult(
    String eventId,
    String classId,
    String resultId,
  ) {
    return switchLatest(_watchPrimaryStageId(eventId, classId), (stageId) {
      if (stageId == null) return Stream.value(null);
      return watchStageResult(eventId, stageId, classId, resultId);
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

  DocumentReference<Map<String, dynamic>> _stageClassDoc(
    String eventId,
    String stageId,
    String classId,
  ) {
    return _eventDoc(
      eventId,
    ).collection('stages').doc(stageId).collection('classes').doc(classId);
  }

  Stream<String?> _watchPrimaryStageId(String eventId, String classId) {
    return _classDoc(
      eventId,
      classId,
    ).snapshots().map((snapshot) => _primaryStageId(snapshot.data()));
  }

  Query<Map<String, dynamic>> _stageResultsQuery(
    String eventId,
    String stageId,
    String classId,
  ) {
    return _stageClassDoc(eventId, stageId, classId).collection('results');
  }
}

String? _primaryStageId(Map<String, dynamic>? data) {
  final value = data?['primaryStageId'];
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
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
