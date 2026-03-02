import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firebase/firestore_paths.dart';

class BadgeChecker {
  BadgeChecker(this._db);
  final FirebaseFirestore _db;

  Future<void> checkAndAward(String uid) async {
    final userRef = _db.collection(FirestorePaths.users).doc(uid);
    final snap = await userRef.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final totalLikes = (data['totalLikes'] ?? 0) as int;
    final publicReplies = (data['publicReplies'] ?? 0) as int;
    final messagesReceived = (data['messagesReceived'] ?? 0) as int;

    final toAdd = <String>[];

    if (totalLikes >= 20) toAdd.add('popular');
    if (publicReplies >= 10) toAdd.add('open_speaker');
    if (messagesReceived >= 50) toAdd.add('trusted_profile');

    if (toAdd.isNotEmpty) {
      await userRef.update({
        'badges': FieldValue.arrayUnion(toAdd),
      });
    }
  }
}
