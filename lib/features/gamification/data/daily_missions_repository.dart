import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/date_key.dart';
import '../../../firebase/firestore_paths.dart';

class DailyMissionsRepository {
  DailyMissionsRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection(FirestorePaths.users).doc(uid);

  Future<void> ensureToday(String uid) async {
    final ref = _userRef(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      final daily = (data['daily'] as Map?)?.cast<String, dynamic>() ?? {};
      final key = daily['dateKey'] as String? ?? '';

      final t = todayKey();
      if (key == t) return;

      tx.update(ref, {
        'daily': {
          'dateKey': t,
          'recvMsg': 0,
          'pubReply': 0,
          'likesGiven': 0,
          'claimed': {'m1': false, 'm2': false, 'm3': false},
        }
      });
    });
  }

  Future<void> incReceiveMessage(String uid) async {
    await ensureToday(uid);
    await _userRef(uid).update({'daily.recvMsg': FieldValue.increment(1)});
  }

  Future<void> incPublicReply(String uid) async {
    await ensureToday(uid);
    await _userRef(uid).update({'daily.pubReply': FieldValue.increment(1)});
  }

  Future<void> incLikesGiven(String uid) async {
    await ensureToday(uid);
    await _userRef(uid).update({'daily.likesGiven': FieldValue.increment(1)});
  }

  Future<void> claimMission({
    required String uid,
    required String missionId,
  }) async {
    await ensureToday(uid);

    final ref = _userRef(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      final daily = (data['daily'] as Map).cast<String, dynamic>();
      final claimed = (daily['claimed'] as Map).cast<String, dynamic>();

      if (claimed[missionId] == true) return;

      final recvMsg = (daily['recvMsg'] ?? 0) as int;
      final pubReply = (daily['pubReply'] ?? 0) as int;
      final likesGiven = (daily['likesGiven'] ?? 0) as int;

      var ok = false;
      var reward = 0;

      if (missionId == 'm1') {
        ok = recvMsg >= 1;
        reward = 10;
      }
      if (missionId == 'm2') {
        ok = pubReply >= 1;
        reward = 15;
      }
      if (missionId == 'm3') {
        ok = likesGiven >= 3;
        reward = 5;
      }

      if (!ok) return;

      tx.update(ref, {
        'coins': FieldValue.increment(reward),
        'daily.claimed.$missionId': true,
      });
    });
  }
}
