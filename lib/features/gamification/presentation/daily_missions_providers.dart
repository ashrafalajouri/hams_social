import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../firebase/firebase_providers.dart';
import '../data/daily_missions_repository.dart';

final dailyMissionsRepositoryProvider = Provider<DailyMissionsRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return DailyMissionsRepository(db);
});
