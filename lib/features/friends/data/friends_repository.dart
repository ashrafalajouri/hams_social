import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firebase/firestore_paths.dart';

class FriendsRepository {
  FriendsRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> sendFriendRequest({
    required String myUid,
    required String myUsername,
    required String toUid,
    required String toUsername,
  }) async {
    final outRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.friendRequestsOut)
        .doc(toUid);

    final inRef = _db
        .collection(FirestorePaths.users)
        .doc(toUid)
        .collection(FirestorePaths.friendRequestsIn)
        .doc(myUid);
    final notifRef = _db
        .collection(FirestorePaths.users)
        .doc(toUid)
        .collection(FirestorePaths.notifications)
        .doc();

    final outSnap = await outRef.get();
    if (outSnap.exists) return;

    final batch = _db.batch();
    batch.set(outRef, {
      'toUid': toUid,
      'toUsername': toUsername,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(inRef, {
      'fromUid': myUid,
      'fromUsername': myUsername,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(notifRef, {
      'type': 'friend_request',
      'title': 'Friend request',
      'body': '@$myUsername sent you a friend request',
      'targetPath': '/friends',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> cancelOutgoing({
    required String myUid,
    required String toUid,
  }) async {
    final outRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.friendRequestsOut)
        .doc(toUid);

    final inRef = _db
        .collection(FirestorePaths.users)
        .doc(toUid)
        .collection(FirestorePaths.friendRequestsIn)
        .doc(myUid);

    await _db.runTransaction((tx) async {
      tx.delete(outRef);
      tx.delete(inRef);
    });
  }

  Future<void> declineIncoming({
    required String myUid,
    required String fromUid,
  }) async {
    final inRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.friendRequestsIn)
        .doc(fromUid);

    final outRef = _db
        .collection(FirestorePaths.users)
        .doc(fromUid)
        .collection(FirestorePaths.friendRequestsOut)
        .doc(myUid);

    await _db.runTransaction((tx) async {
      tx.delete(inRef);
      tx.delete(outRef);
    });
  }

  Future<void> acceptIncoming({
    required String myUid,
    required String myUsername,
    required String fromUid,
    required String fromUsername,
  }) async {
    final myBlockedRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.blocked)
        .doc(fromUid);
    final otherBlockedRef = _db
        .collection(FirestorePaths.users)
        .doc(fromUid)
        .collection(FirestorePaths.blocked)
        .doc(myUid);
    final myIncomingRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.friendRequestsIn)
        .doc(fromUid);

    final preChecks = await Future.wait([
      myBlockedRef.get(),
      otherBlockedRef.get(),
      myIncomingRef.get(),
      _db
          .collection(FirestorePaths.users)
          .doc(myUid)
          .collection(FirestorePaths.friends)
          .doc(fromUid)
          .get(),
      _db
          .collection(FirestorePaths.users)
          .doc(fromUid)
          .collection(FirestorePaths.friends)
          .doc(myUid)
          .get(),
    ]);
    if (preChecks[0].exists || preChecks[1].exists) {
      throw Exception('BLOCKED_RELATION');
    }
    if (!preChecks[2].exists) {
      throw Exception('REQUEST_IN_MISSING');
    }

    final safeMyUsername = myUsername.trim().isEmpty
        ? myUid
        : myUsername.trim();
    final safeFromUsername = fromUsername.trim().isEmpty
        ? fromUid
        : fromUsername.trim();

    final myFriendRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.friends)
        .doc(fromUid);

    final otherFriendRef = _db
        .collection(FirestorePaths.users)
        .doc(fromUid)
        .collection(FirestorePaths.friends)
        .doc(myUid);

    final inRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.friendRequestsIn)
        .doc(fromUid);

    final outRef = _db
        .collection(FirestorePaths.users)
        .doc(fromUid)
        .collection(FirestorePaths.friendRequestsOut)
        .doc(myUid);

    // Keep acceptance in two phases to avoid rules race conditions where
    // request docs are required for friend creation and deleted in same tx.
    final createBatch = _db.batch();
    final myFriendExists = preChecks[3].exists;
    final otherFriendExists = preChecks[4].exists;

    if (!myFriendExists) {
      createBatch.set(myFriendRef, {
        'uid': fromUid,
        'username': safeFromUsername,
        'sinceAt': FieldValue.serverTimestamp(),
      });
    }
    if (!otherFriendExists) {
      createBatch.set(otherFriendRef, {
        'uid': myUid,
        'username': safeMyUsername,
        'sinceAt': FieldValue.serverTimestamp(),
      });
    }
    if (!myFriendExists || !otherFriendExists) {
      try {
        await createBatch.commit();
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        // Handle concurrent accept case where doc may have been created
        // between our pre-check and commit, turning write into forbidden update.
        final nowMyFriend = await myFriendRef.get();
        if (!nowMyFriend.exists) rethrow;
      }
    }

    final cleanupBatch = _db.batch();
    cleanupBatch.delete(inRef);
    cleanupBatch.delete(outRef);
    await cleanupBatch.commit();
  }

  Future<void> removeFriend({
    required String myUid,
    required String friendUid,
  }) async {
    final myFriendRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.friends)
        .doc(friendUid);

    final otherFriendRef = _db
        .collection(FirestorePaths.users)
        .doc(friendUid)
        .collection(FirestorePaths.friends)
        .doc(myUid);

    try {
      await _db.runTransaction((tx) async {
        tx.delete(myFriendRef);
        tx.delete(otherFriendRef);
      });
    } catch (_) {
      // Fallback for strict rules: ensure at least local side is removed.
      await myFriendRef.delete();
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncomingRequests({
    required String myUid,
  }) {
    return _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.friendRequestsIn)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFriends({
    required String myUid,
  }) {
    return _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.friends)
        .orderBy('sinceAt', descending: true)
        .snapshots();
  }
}
