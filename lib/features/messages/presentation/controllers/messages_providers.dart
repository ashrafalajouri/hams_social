import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../firebase/firebase_providers.dart';
import '../../data/messages_repository.dart';

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return MessagesRepository(db);
});

class LastMessageTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setToken(String token) {
    state = token;
  }
}

final lastMessageTokenProvider =
    NotifierProvider<LastMessageTokenNotifier, String?>(
  LastMessageTokenNotifier.new,
);
