import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../firebase/firebase_providers.dart';
import '../../data/follow_repository.dart';
import '../../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return ProfileRepository(db);
});

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return FollowRepository(db);
});
