import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/hams_ui.dart';
import '../../../../core/utils/app_error_text.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_retry_view.dart';
import '../../../../core/widgets/shimmer_list_placeholder.dart';
import '../notifications_providers.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final stream = ref.read(notificationsRepositoryProvider).watch(me.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationsRepositoryProvider).markAllRead(uid: me.uid);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: HamsScreenBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          key: ValueKey(_reload),
          stream: stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return ErrorRetryView(
                message: appErrorText(snap.error!),
                onRetry: () => setState(() => _reload++),
              );
            }
            if (!snap.hasData) {
              return const ShimmerListPlaceholder();
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'All caught up',
                subtitle: 'No notifications yet.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final d = docs[index].data();
                final id = docs[index].id;
                final title = (d['title'] ?? 'Notification').toString();
                final body = (d['body'] ?? '').toString();
                final isRead = d['isRead'] == true;
                final targetPath = (d['targetPath'] ?? '').toString();
                final ts = d['createdAt'];
                final when = ts is Timestamp
                    ? _formatDate(ts.toDate())
                    : 'just now';

                return Dismissible(
                  key: ValueKey(id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) async {
                    await ref.read(notificationsRepositoryProvider).delete(uid: me.uid, notifId: id);
                  },
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        await ref
                            .read(notificationsRepositoryProvider)
                            .markRead(uid: me.uid, notifId: id);
                        if (!context.mounted) return;
                        await _openTarget(context, targetPath);
                      },
                      child: HamsGlassCard(
                        borderColor: isRead ? null : Colors.blue.withOpacity(0.5),
                        child: Row(
                          children: [
                            Icon(
                              isRead
                                  ? Icons.notifications_none_rounded
                                  : Icons.notifications_active_rounded,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    when,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color
                                          ?.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isRead)
                              const Icon(
                                Icons.circle,
                                size: 9,
                                color: Colors.blue,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openTarget(BuildContext context, String targetPath) async {
    if (targetPath.startsWith('/')) {
      context.push(targetPath);
      return;
    }

    if (targetPath.startsWith('users/')) {
      final parts = targetPath.split('/');
      if (parts.length >= 2) {
        final uid = parts[1];
        final profileSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final username = (profileSnap.data()?['username'] ?? '').toString();
        if (!context.mounted) return;
        if (username.isNotEmpty) {
          context.push('/u/$username');
          return;
        }
        return;
      }
    }
  }

  String _formatDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $h:$m';
  }
}
