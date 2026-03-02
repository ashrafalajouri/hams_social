import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firebase/firestore_paths.dart';

class BlockRepository {
  BlockRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> blockUser({
    required String myUid,
    required String blockedUid,
    required String blockedUsername,
  }) async {
    final ref = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.blocked)
        .doc(blockedUid);

    await ref.set({
      'uid': blockedUid,
      'username': blockedUsername,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser({
    required String myUid,
    required String blockedUid,
  }) async {
    final ref = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.blocked)
        .doc(blockedUid);

    await ref.delete();
  }

  Stream<bool> watchIsBlocked({
    required String myUid,
    required String otherUid,
  }) {
    final ref = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.blocked)
        .doc(otherUid);

    return ref.snapshots().map((s) => s.exists);
  }

  Future<bool> isBlocked({
    required String myUid,
    required String otherUid,
  }) async {
    final ref = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.blocked)
        .doc(otherUid);
    final snap = await ref.get();
    return snap.exists;
  }
}
