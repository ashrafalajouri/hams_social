import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firebase/firestore_paths.dart';
import '../domain/xp_rules.dart';

class XpRepository {
  XpRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> addXp({
    required String uid,
    required int amount,
  }) async {
    final userRef = _db.collection(FirestorePaths.users).doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      int xp = (data['xp'] ?? 0) as int;
      int level = (data['level'] ?? 1) as int;
      final previousLevel = level;

      xp = (xp + amount).clamp(0, 1000000000);
      level = XpRules.levelFromXp(xp);

      final updateData = <String, dynamic>{
        'xp': xp,
        'level': level,
      };

      if (previousLevel < 2 && level >= 2) {
        updateData['badges'] = FieldValue.arrayUnion(['rising_voice']);
      }

      tx.update(userRef, updateData);
    });
  }

  Future<void> checkActivityBadges(String uid) async {
    final userRef = _db.collection(FirestorePaths.users).doc(uid);
    final snap = await userRef.get();

    if (!snap.exists) return;

    final data = snap.data()!;
    final totalLikes = (data['totalLikes'] ?? 0) as int;
    final publicReplies = (data['publicReplies'] ?? 0) as int;
    final messagesReceived = (data['messagesReceived'] ?? 0) as int;

    final updates = <String>[];

    if (totalLikes >= 20) updates.add('popular');
    if (publicReplies >= 10) updates.add('open_speaker');
    if (messagesReceived >= 50) updates.add('trusted_profile');

    if (updates.isNotEmpty) {
      await userRef.update({
        'badges': FieldValue.arrayUnion(updates),
      });
    }
  }
}
