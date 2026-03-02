import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firebase/firestore_paths.dart';

class DailyLimitsRepository {
  DailyLimitsRepository(this._db);
  final FirebaseFirestore _db;

  bool _isNewDay(Timestamp lastReset) {
    final d = lastReset.toDate();
    final now = DateTime.now();
    return now.year != d.year || now.month != d.month || now.day != d.day;
  }

  Future<Map<String, dynamic>> getAndMaybeReset(String uid) async {
    final ref = _db.collection(FirestorePaths.users).doc(uid);

    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final last = (data['dailyResetAt'] as Timestamp?) ?? Timestamp.now();

      if (_isNewDay(last)) {
        tx.set(ref, {
          'dailyAnonMsgCount': 0,
          'dailyPostCount': 0,
          'dailyResetAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return {
          ...data,
          'dailyAnonMsgCount': 0,
          'dailyPostCount': 0,
          'dailyResetAt': Timestamp.now(),
        };
      }

      return data;
    });
  }

  Future<void> incAnon(String uid) async {
    await _db.collection(FirestorePaths.users).doc(uid).set({
      'dailyAnonMsgCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> incPost(String uid) async {
    await _db.collection(FirestorePaths.users).doc(uid).set({
      'dailyPostCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }
}
