import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firebase/firestore_paths.dart';

class ReportRepository {
  ReportRepository(this._db);
  final FirebaseFirestore _db;
  static const int _smallAccountThreshold = 12;
  static const int _mediumAccountThreshold = 20;
  static const int _largeAccountThreshold = 35;

  int _thresholdForFollowers(int followers) {
    if (followers < 50) return _smallAccountThreshold;
    if (followers < 200) return _mediumAccountThreshold;
    return _largeAccountThreshold;
  }

  int _safeInt(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
  }

  Future<void> report({
    required String type,
    required String targetPath,
    required String targetOwnerUid,
    required String reporterUid,
    required String reason,
    String details = '',
  }) async {
    await _db.collection(FirestorePaths.reports).add({
      'type': type,
      'targetPath': targetPath,
      'targetOwnerUid': targetOwnerUid,
      'reporterUid': reporterUid,
      'reason': reason,
      'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reportPost({
    required String reporterUid,
    required String postOwnerUid,
    required String postId,
    required String reason,
    String details = '',
  }) async {
    final postRef = _db
        .collection(FirestorePaths.users)
        .doc(postOwnerUid)
        .collection(FirestorePaths.posts)
        .doc(postId);
    final reporterRef = postRef
        .collection(FirestorePaths.reporters)
        .doc(reporterUid);
    final reportRef = _db.collection(FirestorePaths.reports).doc();
    final ownerRef = _db.collection(FirestorePaths.users).doc(postOwnerUid);

    await _db.runTransaction((tx) async {
      final postSnap = await tx.get(postRef);
      if (!postSnap.exists) throw Exception('Post not found');
      final ownerSnap = await tx.get(ownerRef);

      final reporterSnap = await tx.get(reporterRef);
      if (reporterSnap.exists) throw Exception('ALREADY_REPORTED');

      final postData = postSnap.data() ?? <String, dynamic>{};
      final ownerData = ownerSnap.data() ?? <String, dynamic>{};
      final current = (postData['reportsCount'] ?? 0) as int;
      final followers = _safeInt(ownerData['followersCount']);
      final threshold = _thresholdForFollowers(followers);

      tx.set(reporterRef, {'createdAt': FieldValue.serverTimestamp()});

      tx.set(reportRef, {
        'type': 'public_post',
        'targetPath':
            '${FirestorePaths.users}/$postOwnerUid/${FirestorePaths.posts}/$postId',
        'targetOwnerUid': postOwnerUid,
        'reporterUid': reporterUid,
        'reason': reason,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final next = current + 1;
      final updates = <String, dynamic>{
        'reportsCount': next,
        'lastReportedAt': FieldValue.serverTimestamp(),
        'autoModerationThreshold': threshold,
      };
      if (next >= threshold) {
        updates['status'] = 'hidden';
        updates['autoModerated'] = true;
        updates['autoModeratedAt'] = FieldValue.serverTimestamp();
        updates['hiddenReason'] = 'Auto-hidden: too many reports';
      }

      tx.update(postRef, updates);
    });
  }
}
