import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firebase/firestore_paths.dart';

class FollowRepository {
  FollowRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _followingRef({
    required String myUid,
    required String targetUid,
  }) {
    return _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.following)
        .doc(targetUid);
  }

  DocumentReference<Map<String, dynamic>> _followerRef({
    required String targetUid,
    required String myUid,
  }) {
    return _db
        .collection(FirestorePaths.users)
        .doc(targetUid)
        .collection(FirestorePaths.followers)
        .doc(myUid);
  }

  Stream<bool> watchIsFollowing({
    required String myUid,
    required String targetUid,
  }) {
    return _followingRef(
      myUid: myUid,
      targetUid: targetUid,
    ).snapshots().map((snap) => snap.exists);
  }

  Future<void> follow({
    required String myUid,
    required String myUsername,
    required String targetUid,
    required String targetUsername,
  }) async {
    if (myUid == targetUid) return;

    final followingRef = _followingRef(myUid: myUid, targetUid: targetUid);
    final followerRef = _followerRef(targetUid: targetUid, myUid: myUid);
    final myUserRef = _db.collection(FirestorePaths.users).doc(myUid);
    final targetUserRef = _db.collection(FirestorePaths.users).doc(targetUid);

    await _db.runTransaction((tx) async {
      final followingSnap = await tx.get(followingRef);
      if (followingSnap.exists) return;

      tx.set(followingRef, {
        'uid': targetUid,
        'username': targetUsername,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(followerRef, {
        'uid': myUid,
        'username': myUsername,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(myUserRef, {
        'followingCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      tx.set(targetUserRef, {
        'followersCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    });
  }

  Future<void> unfollow({
    required String myUid,
    required String targetUid,
  }) async {
    if (myUid == targetUid) return;

    final followingRef = _followingRef(myUid: myUid, targetUid: targetUid);
    final followerRef = _followerRef(targetUid: targetUid, myUid: myUid);
    final myUserRef = _db.collection(FirestorePaths.users).doc(myUid);
    final targetUserRef = _db.collection(FirestorePaths.users).doc(targetUid);

    await _db.runTransaction((tx) async {
      final followingSnap = await tx.get(followingRef);
      if (!followingSnap.exists) return;

      final mySnap = await tx.get(myUserRef);
      final targetSnap = await tx.get(targetUserRef);
      final myCurrent = ((mySnap.data()?['followingCount'] ?? 0) as num)
          .toInt();
      final targetCurrent = ((targetSnap.data()?['followersCount'] ?? 0) as num)
          .toInt();

      tx.delete(followingRef);
      tx.delete(followerRef);

      tx.set(myUserRef, {
        'followingCount': (myCurrent - 1).clamp(0, 1000000000),
      }, SetOptions(merge: true));
      tx.set(targetUserRef, {
        'followersCount': (targetCurrent - 1).clamp(0, 1000000000),
      }, SetOptions(merge: true));
    });
  }
}
