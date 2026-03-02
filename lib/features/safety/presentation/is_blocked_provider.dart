import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'safety_providers.dart';

final isBlockedProvider =
    StreamProvider.family<bool, ({String myUid, String otherUid})>((ref, p) {
  final repo = ref.watch(blockRepositoryProvider);
  return repo.watchIsBlocked(myUid: p.myUid, otherUid: p.otherUid);
});

