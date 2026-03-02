import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firebase/firestore_paths.dart';
import '../../safety/domain/trust_policy.dart';

class ProfileRepository {
  ProfileRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> ensureUserDoc({required String uid}) async {
    final userRef = _db.collection(FirestorePaths.users).doc(uid);
    final snap = await userRef.get();

    if (!snap.exists) {
      await userRef.set({
        'uid': uid,
        'accountStatus': 'active',
        'reputationScore': 100,
        'trustLevel': TrustPolicy.levelFromScore(100),
        'xp': 0,
        'level': 1,
        'points': 0,
        'badges': <String>[],
        'followersCount': 0,
        'followingCount': 0,
        'onboardingDone': false,
        'settings': {
          'allowAnonymous': true,
          'friendsOnly': false,
          'showViews': true,
          'showLastSeen': true,
        },
        'dailyAnonMsgCount': 0,
        'dailyPostCount': 0,
        'dailyResetAt': Timestamp.now(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final data = snap.data() ?? <String, dynamic>{};
    final patch = <String, dynamic>{};
    if (!data.containsKey('accountStatus')) patch['accountStatus'] = 'active';
    if (!data.containsKey('reputationScore')) patch['reputationScore'] = 100;
    if (!data.containsKey('trustLevel')) {
      final score = ((data['reputationScore'] ?? 100) as num).toInt();
      patch['trustLevel'] = TrustPolicy.levelFromScore(score);
    }
    if (!data.containsKey('xp')) patch['xp'] = 0;
    if (!data.containsKey('level')) patch['level'] = 1;
    if (!data.containsKey('points')) patch['points'] = 0;
    if (!data.containsKey('badges')) patch['badges'] = <String>[];
    if (!data.containsKey('followersCount')) patch['followersCount'] = 0;
    if (!data.containsKey('followingCount')) patch['followingCount'] = 0;
    if (!data.containsKey('onboardingDone')) patch['onboardingDone'] = false;
    if (!data.containsKey('settings')) {
      patch['settings'] = {
        'allowAnonymous': true,
        'friendsOnly': false,
        'showViews': true,
        'showLastSeen': true,
      };
    }
    if (!data.containsKey('dailyAnonMsgCount')) patch['dailyAnonMsgCount'] = 0;
    if (!data.containsKey('dailyPostCount')) patch['dailyPostCount'] = 0;
    if (!data.containsKey('dailyResetAt'))
      patch['dailyResetAt'] = Timestamp.now();
    if (patch.isNotEmpty) {
      await userRef.set(patch, SetOptions(merge: true));
    }
  }

  Future<bool> isUsernameAvailable(String username) async {
    final doc = await _db
        .collection(FirestorePaths.usernames)
        .doc(username)
        .get();
    return !doc.exists;
  }

  Future<void> createProfile({
    required String uid,
    required String username,
    required String displayName,
    String bio = '',
  }) async {
    final userRef = _db.collection(FirestorePaths.users).doc(uid);
    final usernameRef = _db.collection(FirestorePaths.usernames).doc(username);

    await _db.runTransaction((tx) async {
      final usernameSnap = await tx.get(usernameRef);
      if (usernameSnap.exists) {
        throw Exception('USERNAME_TAKEN');
      }

      tx.set(usernameRef, {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(userRef, {
        'coins': 0,
        'daily': {
          'dateKey': '',
          'recvMsg': 0,
          'pubReply': 0,
          'likesGiven': 0,
          'claimed': {'m1': false, 'm2': false, 'm3': false},
        },
        'store': {
          'owned': {'frames': [], 'banners': [], 'themes': []},
          'active': {'frame': null, 'banner': null, 'theme': null},
        },
        'uid': uid,
        'accountStatus': 'active',
        'reputationScore': 100,
        'trustLevel': TrustPolicy.levelFromScore(100),
        'followersCount': 0,
        'followingCount': 0,
        'onboardingDone': false,
        'settings': {
          'allowAnonymous': true,
          'friendsOnly': false,
          'showViews': true,
          'showLastSeen': true,
        },
        'dailyAnonMsgCount': 0,
        'dailyPostCount': 0,
        'dailyResetAt': Timestamp.now(),
        'username': username,
        'displayName': displayName,
        'bio': bio,
        'createdAt': FieldValue.serverTimestamp(),
        'viewsCount': 0,
        'level': 1,
        'xp': 0,
        'totalLikes': 0,
        'publicReplies': 0,
        'messagesReceived': 0,
        'badges': [],
      }, SetOptions(merge: true));
    });
  }

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final doc = await _db.collection(FirestorePaths.users).doc(uid).get();
    return doc.data();
  }

  Future<String?> getUidByUsername(String username) async {
    final doc = await _db
        .collection(FirestorePaths.usernames)
        .doc(username)
        .get();
    if (!doc.exists) return null;
    return doc.data()!['uid'] as String?;
  }

  Future<Map<String, dynamic>?> getProfileByUsername(String username) async {
    final uid = await getUidByUsername(username);
    if (uid == null || uid.isEmpty) return null;

    return getProfile(uid);
  }

  Future<void> registerProfileView({
    required String profileUid,
    required String viewerUid,
  }) async {
    if (profileUid == viewerUid) return;

    final userRef = _db.collection(FirestorePaths.users).doc(profileUid);
    final viewRef = userRef
        .collection(FirestorePaths.profileViews)
        .doc(viewerUid);

    final batch = _db.batch();
    batch.set(viewRef, {
      'viewerUid': viewerUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(userRef, {'viewsCount': FieldValue.increment(1)});

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      // Idempotent: duplicate view attempts are rejected by rules.
      if (e.code == 'permission-denied' || e.code == 'already-exists') return;
      rethrow;
    }
  }
}
