import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../firebase/firebase_providers.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return NotificationsRepository(db);
});

final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final me = FirebaseAuth.instance.currentUser;
  if (me == null) return const Stream<int>.empty();
  return ref.watch(notificationsRepositoryProvider).watchUnreadCount(me.uid);
});
