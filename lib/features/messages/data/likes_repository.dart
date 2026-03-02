import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firebase/firestore_paths.dart';

class LikesRepository {
  LikesRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> toggleLike({
    required String profileUid,
    required String postId,
    required String likerUid,
  }) async {
    final postRef = _db
        .collection(FirestorePaths.users)
        .doc(profileUid)
        .collection(FirestorePaths.posts)
        .doc(postId);

    final likeRef = postRef.collection('likes').doc(likerUid);
    final xpClaimRef = postRef
        .collection(FirestorePaths.likeXpClaims)
        .doc(likerUid);
    final notifRef = _db
        .collection(FirestorePaths.users)
        .doc(profileUid)
        .collection(FirestorePaths.notifications)
        .doc();

    await _db.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      final claimSnap = await tx.get(xpClaimRef);
      final postSnap = await tx.get(postRef);

      if (!postSnap.exists) {
        throw Exception('POST_NOT_FOUND');
      }

      final data = postSnap.data() as Map<String, dynamic>;
      final current = (data['likesCount'] ?? 0) as int;

      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.update(postRef, {'likesCount': max(0, current - 1)});
      } else {
        tx.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
        tx.update(postRef, {'likesCount': current + 1});
        if (!claimSnap.exists) {
          tx.set(xpClaimRef, {'createdAt': FieldValue.serverTimestamp()});
        }
        if (likerUid != profileUid) {
          tx.set(notifRef, {
            'type': 'like',
            'title': 'New like',
            'body': 'Someone liked your post',
            'targetPath': 'users/$profileUid/posts/$postId',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  Stream<bool> watchIsLiked({
    required String profileUid,
    required String postId,
    required String likerUid,
  }) {
    final likeRef = _db
        .collection(FirestorePaths.users)
        .doc(profileUid)
        .collection(FirestorePaths.posts)
        .doc(postId)
        .collection('likes')
        .doc(likerUid);

    return likeRef.snapshots().map((d) => d.exists);
  }
}
