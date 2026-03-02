import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firebase/firestore_paths.dart';

class NotificationsRepository {
  NotificationsRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _ref(String uid) {
    return _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.notifications);
  }

  Future<void> create({
    required String uid,
    required String type,
    required String title,
    required String body,
    required String targetPath,
  }) async {
    await _ref(uid).add({
      'type': type,
      'title': title,
      'body': body,
      'targetPath': targetPath,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watch(String uid) {
    return _ref(uid).orderBy('createdAt', descending: true).limit(100).snapshots();
  }

  Stream<int> watchUnreadCount(String uid) {
    return _ref(uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markRead({
    required String uid,
    required String notifId,
  }) async {
    await _ref(uid).doc(notifId).set({'isRead': true}, SetOptions(merge: true));
  }

  Future<void> markAllRead({required String uid}) async {
    final snap = await _ref(uid).where('isRead', isEqualTo: false).limit(300).get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.set(doc.reference, {'isRead': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> delete({
    required String uid,
    required String notifId,
  }) async {
    await _ref(uid).doc(notifId).delete();
  }
}
