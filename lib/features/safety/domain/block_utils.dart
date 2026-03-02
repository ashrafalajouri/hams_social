import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firebase/firestore_paths.dart';

Future<bool> isBlockedOnce({
  required FirebaseFirestore db,
  required String myUid,
  required String otherUid,
}) async {
  final doc = await db
      .collection(FirestorePaths.users)
      .doc(myUid)
      .collection(FirestorePaths.blocked)
      .doc(otherUid)
      .get();
  return doc.exists;
}

