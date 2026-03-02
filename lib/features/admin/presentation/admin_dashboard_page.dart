import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/utils/app_error_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/shimmer_list_placeholder.dart';
import '../../../firebase/firestore_paths.dart';
import '../../safety/data/admin_moderation_repository.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _onlyHidden = false;
  bool _reportsTodayOnly = false;
  int _reload = 0;

  AdminModerationRepository get _moderationRepo =>
      AdminModerationRepository(FirebaseFirestore.instance);

  Future<bool> _isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final snap = await FirebaseFirestore.instance
        .collection(FirestorePaths.config)
        .doc(FirestorePaths.admins)
        .get();
    final uids = (snap.data()?['uids'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return uids[user.uid] == true;
  }

  DateTime get _todayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isSameDay(DateTime dt) {
    final t = _todayStart;
    return dt.year == t.year && dt.month == t.month && dt.day == t.day;
  }

  Future<int> _count(Query<Map<String, dynamic>> query) async {
    final snap = await query.count().get();
    return snap.count ?? 0;
  }

  Future<Map<String, int>> _loadStats() async {
    final db = FirebaseFirestore.instance;
    final todayTs = Timestamp.fromDate(_todayStart);

    final usersTotal = await _count(db.collection(FirestorePaths.users));
    final usersBanned = await _count(
      db.collection(FirestorePaths.users).where('accountStatus', isEqualTo: 'banned'),
    );
    final reportsTotal = await _count(db.collection(FirestorePaths.reports));
    final reportsToday = await _count(
      db.collection(FirestorePaths.reports).where('createdAt', isGreaterThanOrEqualTo: todayTs),
    );
    final postsTotal = await _count(db.collectionGroup(FirestorePaths.posts));
    final postsHidden = await _count(
      db.collectionGroup(FirestorePaths.posts).where('status', isEqualTo: 'hidden'),
    );

    return {
      'Users': usersTotal,
      'Banned': usersBanned,
      'Reports': reportsTotal,
      'Reports Today': reportsToday,
      'Posts': postsTotal,
      'Hidden Posts': postsHidden,
    };
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _topReportedPostsStream() {
    return FirebaseFirestore.instance
        .collectionGroup(FirestorePaths.posts)
        .orderBy('reportsCount', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _latestActionsStream() {
    return FirebaseFirestore.instance
        .collection(FirestorePaths.moderationActions)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> _openProfileByUid(BuildContext context, String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(uid)
        .get();
    final username = (snap.data()?['username'] ?? '').toString();
    if (!context.mounted) return;
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username not available for this user')),
      );
      return;
    }
    context.push('/u/$username');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAdmin(),
      builder: (context, adminSnap) {
        if (adminSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: ShimmerListPlaceholder(itemCount: 4));
        }
        if (adminSnap.data != true) {
          return const Scaffold(body: Center(child: Text('Access denied')));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Dashboard'),
            actions: [
              IconButton(
                onPressed: () => setState(() => _reload++),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: FutureBuilder<Map<String, int>>(
            key: ValueKey(_reload),
            future: _loadStats(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const ShimmerListPlaceholder(itemCount: 6);
              }
              if (snap.hasError) {
                return ErrorRetryView(
                  message: appErrorText(snap.error!),
                  onRetry: () => setState(() => _reload++),
                );
              }
              final stats = snap.data ?? const <String, int>{};

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.push(AppRoutes.adminReports),
                        icon: const Icon(Icons.report_rounded),
                        label: const Text('Open Reports'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(AppRoutes.adminReports),
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('Moderation History'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: stats.entries
                        .map(
                          (e) => Chip(
                            label: Text('${e.key}: ${e.value}'),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Top Reported Posts',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        selected: _onlyHidden,
                        label: const Text('Only hidden'),
                        onSelected: (v) => setState(() => _onlyHidden = v),
                      ),
                      FilterChip(
                        selected: _reportsTodayOnly,
                        label: const Text('Reports today'),
                        onSelected: (v) => setState(() => _reportsTodayOnly = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _topReportedPostsStream(),
                    builder: (context, postsSnap) {
                      if (postsSnap.hasError) {
                        return ErrorRetryView(
                          message: appErrorText(postsSnap.error!),
                          onRetry: () => setState(() => _reload++),
                        );
                      }
                      if (!postsSnap.hasData) {
                        return const SizedBox(
                          height: 150,
                          child: ShimmerListPlaceholder(itemCount: 2),
                        );
                      }

                      var docs = postsSnap.data!.docs;
                      if (_onlyHidden) {
                        docs = docs
                            .where((d) => (d.data()['status'] ?? 'active') == 'hidden')
                            .toList();
                      }
                      if (_reportsTodayOnly) {
                        docs = docs.where((d) {
                          final ts = d.data()['lastReportedAt'];
                          if (ts is! Timestamp) return false;
                          return _isSameDay(ts.toDate());
                        }).toList();
                      }

                      if (docs.isEmpty) {
                        return const Card(
                          child: EmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'No matching posts',
                            subtitle: 'Try changing current filters.',
                          ),
                        );
                      }

                      return Card(
                        child: Column(
                          children: docs.take(20).map((d) {
                            final m = d.data();
                            final path = d.reference.path;
                            final reports = ((m['reportsCount'] ?? 0) as num).toInt();
                            final status = (m['status'] ?? 'active').toString();
                            final parts = path.split('/');
                            final ownerUid = parts.length >= 2 ? parts[1] : '';

                            return ListTile(
                              dense: true,
                              title: Text(
                                path,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text('reports: $reports • status: $status'),
                              trailing: Wrap(
                                spacing: 2,
                                children: [
                                  IconButton(
                                    tooltip: 'Open profile',
                                    icon: const Icon(Icons.person_outline_rounded, size: 18),
                                    onPressed: ownerUid.isEmpty
                                        ? null
                                        : () => _openProfileByUid(context, ownerUid),
                                  ),
                                  IconButton(
                                    tooltip: status == 'hidden' ? 'Unhide' : 'Hide',
                                    icon: Icon(
                                      status == 'hidden'
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () async {
                                      final adminUid = FirebaseAuth.instance.currentUser!.uid;
                                      if (status == 'hidden') {
                                        await _moderationRepo.unhidePost(
                                          targetPath: path,
                                          adminUid: adminUid,
                                          reason: 'dashboard_quick_action',
                                        );
                                      } else {
                                        await _moderationRepo.hidePost(
                                          targetPath: path,
                                          adminUid: adminUid,
                                          reason: 'dashboard_quick_action',
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Latest Moderation Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _latestActionsStream(),
                    builder: (context, actionSnap) {
                      if (actionSnap.hasError) {
                        return ErrorRetryView(
                          message: appErrorText(actionSnap.error!),
                          onRetry: () => setState(() => _reload++),
                        );
                      }
                      if (!actionSnap.hasData) {
                        return const SizedBox(
                          height: 150,
                          child: ShimmerListPlaceholder(itemCount: 2),
                        );
                      }

                      final docs = actionSnap.data!.docs;
                      if (docs.isEmpty) {
                        return const Card(
                          child: EmptyState(
                            icon: Icons.history_toggle_off_rounded,
                            title: 'No moderation actions',
                            subtitle: 'Actions history is empty.',
                          ),
                        );
                      }

                      return Card(
                        child: Column(
                          children: docs.take(20).map((d) {
                            final m = d.data();
                            final action = (m['action'] ?? '').toString();
                            final targetUid = (m['targetUid'] ?? '').toString();
                            final reason = (m['reason'] ?? '').toString();
                            final ts = m['createdAt'];
                            final when = ts is Timestamp
                                ? ts.toDate().toString()
                                : 'pending timestamp';

                            return ListTile(
                              dense: true,
                              title: Text('$action • $targetUid'),
                              subtitle: Text(
                                '$reason\n$when',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: targetUid.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Open target profile',
                                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                      onPressed: () => _openProfileByUid(context, targetUid),
                                    ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
