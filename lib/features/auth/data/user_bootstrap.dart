import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../firebase/firestore_paths.dart';
import '../../safety/domain/trust_policy.dart';

Future<void> ensureUserDefaults() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final ref = FirebaseFirestore.instance
      .collection(FirestorePaths.users)
      .doc(user.uid);
  final snap = await ref.get();
  final now = Timestamp.now();

  if (!snap.exists) {
    await ref.set({
      'uid': user.uid,
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
      'dailyResetAt': now,
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
  if (!data.containsKey('dailyResetAt')) patch['dailyResetAt'] = now;

  if (patch.isNotEmpty) {
    await ref.set(patch, SetOptions(merge: true));
  }
}
