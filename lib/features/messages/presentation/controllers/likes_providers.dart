import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../firebase/firebase_providers.dart';
import '../../data/likes_repository.dart';

final likesRepositoryProvider = Provider<LikesRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return LikesRepository(db);
});
