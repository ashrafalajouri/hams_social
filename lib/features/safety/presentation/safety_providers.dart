import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../firebase/firebase_providers.dart';
import '../data/admin_moderation_repository.dart';
import '../data/block_repository.dart';
import '../data/daily_limits_repository.dart';
import '../data/report_repository.dart';

final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return BlockRepository(db);
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return ReportRepository(db);
});

final adminModerationRepositoryProvider =
    Provider<AdminModerationRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return AdminModerationRepository(db);
});

final dailyLimitsRepositoryProvider = Provider<DailyLimitsRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return DailyLimitsRepository(db);
});
