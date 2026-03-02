import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firebase/firestore_paths.dart';

String chatIdFor(String a, String b) {
  final x = a.compareTo(b) < 0 ? a : b;
  final y = a.compareTo(b) < 0 ? b : a;
  return 'chat_${x}_$y';
}

List<String> _orderedMembers(String a, String b) {
  final x = a.compareTo(b) < 0 ? a : b;
  final y = a.compareTo(b) < 0 ? b : a;
  return [x, y];
}

class ChatsRepository {
  ChatsRepository(this._db);
  final FirebaseFirestore _db;

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

  Future<void> _ensureFriend({
    required String myUid,
    required String otherUid,
  }) async {
    final friendRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.friends)
        .doc(otherUid);
    final friendSnap = await friendRef.get();
    if (!friendSnap.exists) {
      throw Exception('CHAT_REQUIRES_FRIEND');
    }
  }

  Future<String> openChat({
    required String myUid,
    required String myUsername,
    required String otherUid,
    required String otherUsername,
  }) async {
    await _ensureNotBlocked(myUid: myUid, otherUid: otherUid);
    await _ensureFriend(myUid: myUid, otherUid: otherUid);

    final chatId = chatIdFor(myUid, otherUid);
    final members = _orderedMembers(myUid, otherUid);
    final chatRef = _db.collection(FirestorePaths.chats).doc(chatId);
    final chatSnap = await chatRef.get();

    final myListRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.chats)
        .doc(chatId);
    final otherListRef = _db
        .collection(FirestorePaths.users)
        .doc(otherUid)
        .collection(FirestorePaths.chats)
        .doc(chatId);

    final batch = _db.batch();

    if (!chatSnap.exists) {
      batch.set(chatRef, {
        'members': members,
        'memberMap': {myUid: true, otherUid: true},
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageAt': null,
        'readAtMap': {myUid: FieldValue.serverTimestamp()},
        'typingMap': {},
        'typingAtMap': {},
      });
    } else {
      batch.update(chatRef, {'readAtMap.$myUid': FieldValue.serverTimestamp()});
    }

    batch.set(myListRef, {
      'chatId': chatId,
      'otherUid': otherUid,
      'otherUsername': otherUsername,
      'unreadCount': 0,
      'lastReadAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(otherListRef, {
      'chatId': chatId,
      'otherUid': myUid,
      'otherUsername': myUsername,
      'unreadCount': 0,
    }, SetOptions(merge: true));

    await batch.commit();

    return chatId;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String chatId) {
    return _db
        .collection(FirestorePaths.chats)
        .doc(chatId)
        .collection(FirestorePaths.messages)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> sendMessage({
    required String chatId,
    required String myUid,
    required String otherUid,
    required String text,
  }) async {
    final msg = text.trim();
    if (msg.isEmpty) return;
    await _ensureNotBlocked(myUid: myUid, otherUid: otherUid);

    final chatRef = _db.collection(FirestorePaths.chats).doc(chatId);
    final msgRef = chatRef.collection(FirestorePaths.messages).doc();

    final myListRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.chats)
        .doc(chatId);
    final otherListRef = _db
        .collection(FirestorePaths.users)
        .doc(otherUid)
        .collection(FirestorePaths.chats)
        .doc(chatId);

    await _db.runTransaction((tx) async {
      tx.set(msgRef, {
        'senderUid': myUid,
        'text': msg,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.update(chatRef, {
        'lastMessage': msg,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'readAtMap.$myUid': FieldValue.serverTimestamp(),
      });

      tx.set(myListRef, {
        'lastMessage': msg,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      }, SetOptions(merge: true));

      tx.set(otherListRef, {
        'lastMessage': msg,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    });
  }

  Future<void> setTyping({
    required String chatId,
    required String uid,
    required bool typing,
  }) async {
    final chatRef = _db.collection(FirestorePaths.chats).doc(chatId);
    await chatRef.set({
      'typingMap': {uid: typing},
      'typingAtMap': {uid: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }

  Future<void> markAsRead({
    required String chatId,
    required String myUid,
  }) async {
    final chatRef = _db.collection(FirestorePaths.chats).doc(chatId);
    final myListRef = _db
        .collection(FirestorePaths.users)
        .doc(myUid)
        .collection(FirestorePaths.chats)
        .doc(chatId);

    await _db.runTransaction((tx) async {
      tx.update(chatRef, {'readAtMap.$myUid': FieldValue.serverTimestamp()});

      tx.set(myListRef, {
        'unreadCount': 0,
        'lastReadAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
