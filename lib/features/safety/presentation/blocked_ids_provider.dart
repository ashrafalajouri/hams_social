import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../firebase/firestore_paths.dart';

final blockedIdsProvider = StreamProvider<List<String>>((ref) {
  final me = FirebaseAuth.instance.currentUser;
  if (me == null) {
    return const Stream<List<String>>.empty();
  }

  return FirebaseFirestore.instance
      .collection(FirestorePaths.users)
      .doc(me.uid)
      .collection(FirestorePaths.blocked)
      .snapshots()
      .map((q) => q.docs.map((d) => d.id).toList());
});

