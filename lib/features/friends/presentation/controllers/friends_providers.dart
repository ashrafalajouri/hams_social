import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../firebase/firebase_providers.dart';
import '../../data/friends_repository.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return FriendsRepository(db);
});
