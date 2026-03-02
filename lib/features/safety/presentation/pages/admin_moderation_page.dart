import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../firebase/firestore_paths.dart';
import '../safety_providers.dart';

class AdminReportsPage extends ConsumerStatefulWidget {
  const AdminReportsPage({super.key});

  @override
  ConsumerState<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends ConsumerState<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<bool> _isAdmin(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection(FirestorePaths.config)
        .doc(FirestorePaths.admins)
        .get();
    final uids =
        (snap.data()?['uids'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return uids[uid] == true;
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return FutureBuilder<bool>(
      future: _isAdmin(me.uid),
      builder: (context, adminSnap) {
        if (adminSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (adminSnap.data != true) {
          return const Scaffold(body: Center(child: Text('Access denied')));
        }

        final stream = FirebaseFirestore.instance
            .collection(FirestorePaths.reports)
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin: Reports'),
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Posts'),
                Tab(text: 'Profiles'),
                Tab(text: 'All'),
              ],
            ),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final all = snap.data!.docs;
              final posts = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final profiles = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              for (final doc in all) {
                final d = doc.data();
                final type = (d['type'] ?? '') as String;
                final targetPath = (d['targetPath'] ?? '') as String;

                final isPost = targetPath.contains('/posts/');
                final isProfile = type == 'profile' || (targetPath.startsWith('users/') && !isPost);

                if (isPost) posts.add(doc);
                if (isProfile) profiles.add(doc);
              }

              return TabBarView(
                controller: _tabs,
                children: [
                  _ReportsList(items: posts, adminUid: me.uid),
                  _ReportsList(items: profiles, adminUid: me.uid),
                  _ReportsList(items: all, adminUid: me.uid),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ReportsList extends ConsumerWidget {
  const _ReportsList({required this.items, required this.adminUid});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> items;
  final String adminUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const Center(child: Text('No reports'));

    final repo = ref.read(adminModerationRepositoryProvider);

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final doc = items[i];
        final d = doc.data();

        final type = (d['type'] ?? '') as String;
        final reason = (d['reason'] ?? '') as String;
        final targetPath = (d['targetPath'] ?? '') as String;
        final targetOwnerUid = (d['targetOwnerUid'] ?? '') as String;
        final details = (d['details'] ?? '') as String;

        final isPost = targetPath.contains('/posts/');
        final isProfile = type == 'profile' || (targetPath.startsWith('users/') && !isPost);

        return ListTile(
          title: Text('$type • $reason'),
          subtitle: Text(
            '$targetPath${details.isNotEmpty ? "\n$details" : ""}',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _StatusIndicator(targetPath: targetPath),
          onTap: () async {
            if (isPost) {
              final target = await repo.readTarget(targetPath);
              final status = (target?['status'] ?? 'active') as String;

              if (!context.mounted) return;

              showModalBottomSheet(
                context: context,
                builder: (_) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Target status: $status'),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            final ownerSnap = await FirebaseFirestore.instance
                                .collection(FirestorePaths.users)
                                .doc(targetOwnerUid)
                                .get();
                            final username =
                                (ownerSnap.data()?['username'] ?? '').toString();
                            if (!context.mounted || username.isEmpty) return;
                            Navigator.pop(context);
                            context.push('/u/$username');
                          },
                          icon: const Icon(Icons.person_outline_rounded),
                          label: const Text('Open target profile'),
                        ),
                        const SizedBox(height: 8),
                        if (status != 'hidden')
                          ElevatedButton.icon(
                            icon: const Icon(Icons.visibility_off),
                            label: const Text('Hide Post'),
                            onPressed: () async {
                              Navigator.pop(context);
                              await repo.hidePost(
                                targetPath: targetPath,
                                adminUid: adminUid,
                                reason: reason,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Post hidden ✅')),
                                );
                              }
                            },
                          )
                        else
                          ElevatedButton.icon(
                            icon: const Icon(Icons.visibility),
                            label: const Text('Unhide Post'),
                            onPressed: () async {
                              Navigator.pop(context);
                              await repo.unhidePost(
                                targetPath: targetPath,
                                adminUid: adminUid,
                                reason: reason,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Post unhidden ✅')),
                                );
                              }
                            },
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              );
              return;
            }

            if (isProfile) {
              final userSnap = await FirebaseFirestore.instance
                  .collection(FirestorePaths.users)
                  .doc(targetOwnerUid)
                  .get();
              final status = (userSnap.data()?['accountStatus'] ?? 'active') as String;

              if (!context.mounted) return;

              showModalBottomSheet(
                context: context,
                builder: (_) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('User status: $status'),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            final ownerSnap = await FirebaseFirestore.instance
                                .collection(FirestorePaths.users)
                                .doc(targetOwnerUid)
                                .get();
                            final username =
                                (ownerSnap.data()?['username'] ?? '').toString();
                            if (!context.mounted || username.isEmpty) return;
                            Navigator.pop(context);
                            context.push('/u/$username');
                          },
                          icon: const Icon(Icons.person_outline_rounded),
                          label: const Text('Open target profile'),
                        ),
                        const SizedBox(height: 8),
                        if (status != 'banned')
                          ElevatedButton.icon(
                            icon: const Icon(Icons.block),
                            label: const Text('Ban User'),
                            onPressed: () async {
                              Navigator.pop(context);
                              await repo.banUser(
                                targetUid: targetOwnerUid,
                                adminUid: adminUid,
                                reason: reason,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('User banned ✅')),
                                );
                              }
                            },
                          )
                        else
                          ElevatedButton.icon(
                            icon: const Icon(Icons.lock_open),
                            label: const Text('Unban User'),
                            onPressed: () async {
                              Navigator.pop(context);
                              await repo.unbanUser(
                                targetUid: targetOwnerUid,
                                adminUid: adminUid,
                                reason: reason,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('User unbanned ✅')),
                                );
                              }
                            },
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              );
            }
          },
        );
      },
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.targetPath});

  final String targetPath;

  @override
  Widget build(BuildContext context) {
    if (!targetPath.contains('/posts/')) {
      return const Icon(Icons.info_outline_rounded);
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.doc(targetPath).get(),
      builder: (context, snap) {
        final status = (snap.data?.data()?['status'] ?? 'active').toString();
        final hidden = status == 'hidden';
        return Icon(
          hidden ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
          color: hidden ? Colors.green : Colors.orange,
        );
      },
    );
  }
}
