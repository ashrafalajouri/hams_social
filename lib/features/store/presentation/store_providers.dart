import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../firebase/firebase_providers.dart';
import '../data/store_repository.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return StoreRepository(db);
});
