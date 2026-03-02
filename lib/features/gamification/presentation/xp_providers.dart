import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../firebase/firebase_providers.dart';
import '../data/xp_repository.dart';

final xpRepositoryProvider = Provider<XpRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return XpRepository(db);
});
