import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firebase/firestore_paths.dart';
import '../../gamification/domain/xp_rules.dart';
import '../domain/trust_policy.dart';

class AdminModerationRepository {
  AdminModerationRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _refFromPath(String path) {
    return _db.doc(path);
  }

  CollectionReference<Map<String, dynamic>> get _auditRef =>
      _db.collection(FirestorePaths.moderationActions);

  String _targetUidFromPath(String targetPath) {
    final parts = targetPath.split('/');
    if (parts.length >= 2 && parts.first == FirestorePaths.users) {
      return parts[1];
    }
    return '';
  }

  Future<void> _adjustReputation({
    required Transaction tx,
    required String targetUid,
    required int delta,
  }) async {
    if (targetUid.isEmpty) return;
    final userRef = _db.collection(FirestorePaths.users).doc(targetUid);
    final userSnap = await tx.get(userRef);
    final data = userSnap.data() ?? <String, dynamic>{};
    final current = ((data['reputationScore'] ?? 100) as num).toInt();
    final next = (current + delta).clamp(0, 1000000);
    tx.set(userRef, {
      'reputationScore': next,
      'trustLevel': TrustPolicy.levelFromScore(next),
    }, SetOptions(merge: true));
  }

  Future<void> _adjustXp({
    required Transaction tx,
    required String targetUid,
    required int delta,
  }) async {
    if (targetUid.isEmpty) return;
    final userRef = _db.collection(FirestorePaths.users).doc(targetUid);
    final userSnap = await tx.get(userRef);
    final data = userSnap.data() ?? <String, dynamic>{};
    final currentXp = ((data['xp'] ?? 0) as num).toInt();
    final nextXp = (currentXp + delta).clamp(0, 1000000000);
    final nextLevel = XpRules.levelFromXp(nextXp);
    tx.set(userRef, {
      'xp': nextXp,
      'level': nextLevel,
    }, SetOptions(merge: true));
  }

  Future<void> hidePost({
    required String targetPath,
    required String adminUid,
    String reason = '',
  }) async {
    final ref = _refFromPath(targetPath);
    final targetUid = _targetUidFromPath(targetPath);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.data() ?? <String, dynamic>{};
      final status = (current['status'] ?? 'active') as String;
      final shouldApplyPenalty = status != 'hidden';

      tx.set(ref, {
        'status': 'hidden',
        'hiddenBy': adminUid,
        'hiddenAt': FieldValue.serverTimestamp(),
        'moderationReason': reason,
      }, SetOptions(merge: true));
      tx.set(_auditRef.doc(), {
        'action': 'hide_post',
        'targetPath': targetPath,
        'targetUid': targetUid,
        'adminUid': adminUid,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (shouldApplyPenalty) {
        await _adjustReputation(tx: tx, targetUid: targetUid, delta: -5);
        await _adjustXp(tx: tx, targetUid: targetUid, delta: -10);
      }
    });
  }

  Future<void> unhidePost({
    required String targetPath,
    required String adminUid,
    String reason = '',
  }) async {
    final ref = _refFromPath(targetPath);
    final targetUid = _targetUidFromPath(targetPath);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.data() ?? <String, dynamic>{};
      final status = (current['status'] ?? 'active') as String;
      final autoModerated = current['autoModerated'] == true;
      final shouldChangeState = status == 'hidden';

      tx.set(ref, {
        'status': 'active',
        'unhiddenBy': adminUid,
        'unhiddenAt': FieldValue.serverTimestamp(),
        if (autoModerated)
          'autoModeratedResolvedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(_auditRef.doc(), {
        'action': 'unhide_post',
        'targetPath': targetPath,
        'targetUid': targetUid,
        'adminUid': adminUid,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (shouldChangeState) {
        final delta = autoModerated ? 5 : 2;
        await _adjustReputation(tx: tx, targetUid: targetUid, delta: delta);
        if (autoModerated) {
          await _adjustXp(tx: tx, targetUid: targetUid, delta: 10);
        }
      }
    });
  }

  Future<Map<String, dynamic>?> readTarget(String targetPath) async {
    final ref = _refFromPath(targetPath);
    final snap = await ref.get();
    return snap.data();
  }

  Future<void> banUser({
    required String targetUid,
    required String adminUid,
    String reason = '',
  }) async {
    final userRef = _db.collection(FirestorePaths.users).doc(targetUid);
    await _db.runTransaction((tx) async {
      tx.set(userRef, {'accountStatus': 'banned'}, SetOptions(merge: true));
      await _adjustReputation(tx: tx, targetUid: targetUid, delta: -30);
      tx.set(_auditRef.doc(), {
        'action': 'ban_user',
        'targetPath': '${FirestorePaths.users}/$targetUid',
        'targetUid': targetUid,
        'adminUid': adminUid,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> unbanUser({
    required String targetUid,
    required String adminUid,
    String reason = '',
  }) async {
    final userRef = _db.collection(FirestorePaths.users).doc(targetUid);
    await _db.runTransaction((tx) async {
      tx.set(userRef, {'accountStatus': 'active'}, SetOptions(merge: true));
      tx.set(_auditRef.doc(), {
        'action': 'unban_user',
        'targetPath': '${FirestorePaths.users}/$targetUid',
        'targetUid': targetUid,
        'adminUid': adminUid,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
