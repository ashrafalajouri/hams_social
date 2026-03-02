import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../firebase/firebase_providers.dart';
import '../../data/chats_repository.dart';

final chatsRepoProvider = Provider<ChatsRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return ChatsRepository(db);
});
