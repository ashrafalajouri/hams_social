import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../firebase/firestore_paths.dart';
import '../safety_providers.dart';

class BlockedUsersPage extends ConsumerWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final stream = FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(me.uid)
        .collection(FirestorePaths.blocked)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Users')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No blocked users'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final uid = (d['uid'] ?? docs[i].id) as String;
              final username = (d['username'] ?? 'Unknown') as String;

              return ListTile(
                title: Text(username),
                subtitle: Text(
                  uid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: TextButton(
                  onPressed: () async {
                    await ref.read(blockRepositoryProvider).unblockUser(
                          myUid: me.uid,
                          blockedUid: uid,
                        );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unblocked ✅')),
                    );
                  },
                  child: const Text('Unblock'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
