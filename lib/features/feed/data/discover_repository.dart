import 'package:cloud_firestore/cloud_firestore.dart';

class DiscoverRepository {
  DiscoverRepository(this._db);
  final FirebaseFirestore _db;

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      streamLatestActivePosts() {
    return _db
        .collectionGroup('posts')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((q) => q.docs);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchLatestPage({
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collectionGroup('posts')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    return q.get();
  }
}
