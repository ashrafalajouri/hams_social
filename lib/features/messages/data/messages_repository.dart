import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../firebase/firestore_paths.dart';
import '../../gamification/data/badge_checker.dart';
import '../../gamification/data/daily_missions_repository.dart';
import '../../gamification/data/xp_repository.dart';
import '../../safety/data/daily_limits_repository.dart';
import '../../safety/domain/trust_policy.dart';
import '../domain/message_entity.dart';

class MessagesRepository {
  MessagesRepository(this._db);
  final FirebaseFirestore _db;
  static const _dailyAnonLimitPrefix = 'DAILY_ANON_LIMIT_REACHED';
  static const _dailyPostLimitPrefix = 'DAILY_POST_LIMIT_REACHED';

  Future<void> _ensureNotBlocked({
    required String myUid,
    required String otherUid,
  }) async {
    final blockedRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.blocked)
        .doc(otherUid);
    final blockedSnap = await blockedRef.get();
    if (blockedSnap.exists) {
      throw Exception('BLOCKED_USER');
    }
  }

  Future<String> sendAnonymousMessage({
    required String toUid,
    required String toUsername,
    required String text,
  }) async {
    final msg = text.trim();
    if (msg.isEmpty) throw Exception('Empty message');
    if (msg.length > 500) throw Exception('Max 500 chars');
    final senderUid = FirebaseAuth.instance.currentUser?.uid;
    if (senderUid == null) throw Exception('Not signed in');
    await _ensureNotBlocked(myUid: senderUid, otherUid: toUid);
    final limitsRepo = DailyLimitsRepository(_db);
    final dailyState = await limitsRepo.getAndMaybeReset(senderUid);
    final score = ((dailyState['reputationScore'] ?? 100) as num).toInt();
    final used = ((dailyState['dailyAnonMsgCount'] ?? 0) as num).toInt();
    final maxPerDay = TrustPolicy.anonLimitPerDay(score);
    if (used >= maxPerDay) {
      throw Exception('$_dailyAnonLimitPrefix:$maxPerDay');
    }
    final replyToken = _db.collection(FirestorePaths.messageLinks).doc().id;

    final inboxRef = _db
        .collection(FirestorePaths.users)
        .doc(toUid)
        .collection(FirestorePaths.inbox)
        .doc();
    final createdAt = FieldValue.serverTimestamp();

    await inboxRef.set({
      'toUid': toUid,
      'toUsername': toUsername,
      'text': msg,
      'senderType': 'anonymous',
      'senderUid': senderUid,
      'replyToken': replyToken,
      'isRead': false,
      'status': 'active',
      'createdAt': createdAt,
    });

    // Best-effort gamification updates. These can be denied by rules when a
    // non-owner tries to modify another user's aggregate stats.
    try {
      await XpRepository(_db).addXp(uid: toUid, amount: 5);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
    try {
      await _db.collection(FirestorePaths.users).doc(toUid).update({
        'messagesReceived': FieldValue.increment(1),
      });
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
    try {
      await DailyMissionsRepository(_db).incReceiveMessage(toUid);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
    try {
      await BadgeChecker(_db).checkAndAward(toUid);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }

    await _db.collection(FirestorePaths.messageLinks).doc(replyToken).set({
      'token': replyToken,
      'messageId': inboxRef.id,
      'toUid': toUid,
      'toUsername': toUsername,
      'text': msg,
      'senderUid': senderUid,
      'replyType': null,
      'replyText': null,
      'repliedAt': null,
      'createdAt': createdAt,
    });

    await limitsRepo.incAnon(senderUid);

    return replyToken;
  }

  Stream<List<InboxMessage>> watchMyInbox({required String myUid}) {
    final ref = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.inbox)
        .orderBy('createdAt', descending: true)
        .limit(50);

    return ref.snapshots().map((snap) {
      return snap.docs
          .map((d) => InboxMessage.fromDoc(d.id, d.data()))
          .toList();
    });
  }

  Future<void> markAsRead({
    required String myUid,
    required String messageId,
  }) async {
    final docRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.inbox)
        .doc(messageId);

    await docRef.update({'isRead': true});
  }

  Future<void> replyToMessage({
    required String myUid,
    required String messageId,
    required String replyText,
    required String replyType,
  }) async {
    final reply = replyText.trim();
    if (reply.isEmpty) throw Exception('Reply is empty');

    final docRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.inbox)
        .doc(messageId);
    final snap = await docRef.get();
    if (!snap.exists) throw Exception('Message not found');

    final data = snap.data() ?? <String, dynamic>{};
    final existingType = data['replyType'];
    if (existingType != null) {
      throw Exception('ALREADY_REPLIED');
    }
    final replyToken = (data['replyToken'] ?? '') as String;
    final senderUid = (data['senderUid'] ?? '') as String;
    final now = FieldValue.serverTimestamp();

    await docRef.update({
      'replyText': reply,
      'replyType': replyType,
      'repliedAt': now,
    });

    if (replyToken.isNotEmpty) {
      await _db.collection(FirestorePaths.messageLinks).doc(replyToken).set({
        'replyText': reply,
        'replyType': replyType,
        'repliedAt': now,
      }, SetOptions(merge: true));
    }

    if (replyType == 'private' && senderUid.isNotEmpty) {
      await _db
          .collection(FirestorePaths.users)
          .doc(senderUid)
          .collection(FirestorePaths.privateReplies)
          .doc()
          .set({
            'messageId': messageId,
            'replyToken': replyToken,
            'fromUid': myUid,
            'toUid': senderUid,
            'toUsername': data['toUsername'],
            'text': data['text'],
            'replyText': reply,
            'replyType': 'private',
            'createdAt': now,
          });
    }
  }

  Future<void> createPublicPost({
    required String myUid,
    required String originalText,
    required String replyText,
    required String messageId,
  }) async {
    final reply = replyText.trim();
    if (reply.isEmpty) throw Exception('Reply is empty');
    final limitsRepo = DailyLimitsRepository(_db);
    final dailyState = await limitsRepo.getAndMaybeReset(myUid);
    final score = ((dailyState['reputationScore'] ?? 100) as num).toInt();
    final usedPosts = ((dailyState['dailyPostCount'] ?? 0) as num).toInt();
    final maxPosts = TrustPolicy.postLimitPerDay(score);
    if (usedPosts >= maxPosts) {
      throw Exception('$_dailyPostLimitPrefix:$maxPosts');
    }

    final inboxRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.inbox)
        .doc(messageId);
    final inboxSnap = await inboxRef.get();
    if (!inboxSnap.exists) throw Exception('Message not found');
    final inboxData = inboxSnap.data() ?? <String, dynamic>{};
    final existingType = inboxData['replyType'];
    if (existingType != null) {
      throw Exception('ALREADY_REPLIED');
    }

    final postRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.posts)
        .doc();
    final myUserSnap = await _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .get();
    final myData = myUserSnap.data() ?? <String, dynamic>{};
    final myUsername = (myData['username'] ?? '') as String;

    await postRef.set({
      'text': originalText,
      'replyText': reply,
      'messageId': messageId,
      'authorUid': myUid,
      'authorUsername': myUsername,
      'likesCount': 0,
      'reportsCount': 0,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await inboxRef.update({
      'replyType': 'public',
      'replyText': reply,
      'repliedAt': FieldValue.serverTimestamp(),
    });

    final replyToken = (inboxData['replyToken'] ?? '') as String;
    if (replyToken.isNotEmpty) {
      await _db.collection(FirestorePaths.messageLinks).doc(replyToken).set({
        'replyText': reply,
        'replyType': 'public',
        'repliedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await limitsRepo.incPost(myUid);

    await XpRepository(_db).addXp(uid: myUid, amount: 5);
    await _db.collection(FirestorePaths.users).doc(myUid).update({
      'publicReplies': FieldValue.increment(1),
    });

    final senderUid = (inboxData['senderUid'] ?? '') as String;
    if (senderUid.isNotEmpty && senderUid != myUid) {
      await _db
          .collection(FirestorePaths.users)
          .doc(senderUid)
          .collection(FirestorePaths.notifications)
          .add({
            'type': 'reply_public',
            'title': 'New public reply',
            'body': '@$myUsername posted a public reply',
            'targetPath': myUsername.isEmpty
                ? 'users/$myUid'
                : '/u/$myUsername',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
    }

    await DailyMissionsRepository(_db).incPublicReply(myUid);
    await BadgeChecker(_db).checkAndAward(myUid);
  }
}
