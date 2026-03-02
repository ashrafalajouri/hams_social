import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firebase/firestore_paths.dart';

class StoreRepository {
  StoreRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> buyItem({
    required String uid,
    required String type,
    required String itemId,
    required int price,
  }) async {
    final userRef = _db.collection(FirestorePaths.users).doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) throw Exception('USER_NOT_FOUND');

      final data = snap.data()!;
      final coins = (data['coins'] ?? 0) as int;

      final store = (data['store'] as Map?)?.cast<String, dynamic>() ?? {};
      final owned = (store['owned'] as Map?)?.cast<String, dynamic>() ?? {};
      final listKey = '${type}s';
      final ownedList = (owned[listKey] as List?)?.cast<String>() ?? [];

      if (ownedList.contains(itemId)) {
        throw Exception('ALREADY_OWNED');
      }

      if (coins < price) {
        throw Exception('NOT_ENOUGH_COINS');
      }

      tx.update(userRef, {
        'coins': coins - price,
        'store.owned.$listKey': FieldValue.arrayUnion([itemId]),
      });
    });
  }

  Future<void> activateItem({
    required String uid,
    required String type,
    required String itemId,
  }) async {
    final userRef = _db.collection(FirestorePaths.users).doc(uid);

    final snap = await userRef.get();
    final data = snap.data() ?? {};
    final store = (data['store'] as Map?)?.cast<String, dynamic>() ?? {};
    final owned = (store['owned'] as Map?)?.cast<String, dynamic>() ?? {};
    final listKey = '${type}s';
    final ownedList = (owned[listKey] as List?)?.cast<String>() ?? [];

    if (!ownedList.contains(itemId)) {
      throw Exception('NOT_OWNED');
    }

    await userRef.update({'store.active.$type': itemId});
  }
}
