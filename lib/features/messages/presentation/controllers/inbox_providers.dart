import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/message_entity.dart';
import 'messages_providers.dart';

final myInboxProvider = StreamProvider<List<InboxMessage>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();
  final repo = ref.watch(messagesRepositoryProvider);
  return repo.watchMyInbox(myUid: user.uid);
});
