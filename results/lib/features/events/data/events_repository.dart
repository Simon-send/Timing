import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_mappers.dart';
import '../domain/result_event.dart';

abstract class EventsRepository {
  Stream<List<ResultEvent>> watchEvents();
}

class FirestoreEventsRepository implements EventsRepository {
  FirestoreEventsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<ResultEvent>> watchEvents() {
    return _firestore.collection('events').snapshots().map((snapshot) {
      final events = snapshot.docs
          .map((doc) => ResultEvent.fromMap(doc.id, doc.data()))
          .toList();
      events.sort((a, b) {
        final dateCompare = compareNullableDateDesc(a.date, b.date);
        if (dateCompare != 0) return dateCompare;
        return a.name.compareTo(b.name);
      });
      return events;
    });
  }
}
