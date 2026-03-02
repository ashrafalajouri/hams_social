import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firebase/firestore_paths.dart';

class BadgeRepository {
  BadgeRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> awardBadge({
    required String uid,
    required String badgeId,
  }) async {
    final userRef = _db.collection(FirestorePaths.users).doc(uid);

    await userRef.update({
      'badges': FieldValue.arrayUnion([badgeId]),
    });
  }
}
