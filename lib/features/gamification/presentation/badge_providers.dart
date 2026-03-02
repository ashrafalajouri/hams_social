import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../firebase/firebase_providers.dart';
import '../data/badge_repository.dart';

final badgeRepositoryProvider = Provider<BadgeRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return BadgeRepository(db);
});
