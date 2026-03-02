import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../firebase/firestore_paths.dart';
import '../../data/profile_repository.dart';
import '../../../friends/presentation/controllers/friends_providers.dart';
import '../../../chat/presentation/controllers/chats_providers.dart';
import '../../../messages/presentation/controllers/likes_providers.dart';
import '../../../messages/presentation/controllers/messages_providers.dart';
import '../../../safety/presentation/report_dialog.dart';
import '../../../safety/presentation/safety_providers.dart';
import '../controllers/profile_providers.dart';
import '../widgets/profile_header.dart';

class PublicProfilePage extends ConsumerWidget {
  const PublicProfilePage({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(profileRepositoryProvider);

    return FutureBuilder<_PublicProfileData?>(
      future: _loadProfile(repo),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final err = snapshot.error.toString();
          final blockedOrDenied = err.contains('permission-denied');
          return Scaffold(
            appBar: AppBar(title: Text('@$username')),
            body: Center(
              child: Text(
                blockedOrDenied
                    ? 'Profile unavailable (blocked or no permission).'
                    : 'Failed to load profile.',
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(body: Center(child: Text('User not found')));
        }

        final loaded = snapshot.data!;
        final data = loaded.data;
        final uid = loaded.uid;
        final badges = ((data['badges'] as List?) ?? [])
            .map((e) => e.toString())
            .toList();
        final store = (data['store'] as Map?)?.cast<String, dynamic>() ?? {};
        final active = (store['active'] as Map?)?.cast<String, dynamic>() ?? {};
        final activeBanner = active['banner'] as String?;
        final activeFrame = active['frame'] as String?;
        final photoUrl = (data['photoUrl'] as String?)?.trim();
        final viewerUid = FirebaseAuth.instance.currentUser?.uid;
        if (viewerUid != null && viewerUid != uid) {
          return StreamBuilder<bool>(
            stream: ref
                .read(blockRepositoryProvider)
                .watchIsBlocked(myUid: viewerUid, otherUid: uid),
            builder: (context, blockSnap) {
              final iBlockedThisUser = blockSnap.data ?? false;
              if (iBlockedThisUser) {
                return Scaffold(
                  appBar: AppBar(title: Text('@$username')),
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'You blocked this user.',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () async {
                              await ref
                                  .read(blockRepositoryProvider)
                                  .unblockUser(
                                    myUid: viewerUid,
                                    blockedUid: uid,
                                  );
                            },
                            child: const Text('Unblock'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () async {
                              final reportData = await showReportDialog(
                                context,
                              );
                              if (reportData == null) return;
                              await ref
                                  .read(reportRepositoryProvider)
                                  .report(
                                    type: 'profile',
                                    targetPath: '${FirestorePaths.users}/$uid',
                                    targetOwnerUid: uid,
                                    reporterUid: viewerUid,
                                    reason: reportData['reason']!,
                                    details: reportData['details'] ?? '',
                                  );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Reported âœ…')),
                              );
                            },
                            child: const Text('Report'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              Future.microtask(() {
                ref
                    .read(profileRepositoryProvider)
                    .registerProfileView(profileUid: uid, viewerUid: viewerUid);
              });

              return _buildProfileScaffold(
                context: context,
                ref: ref,
                username: username,
                data: data,
                uid: uid,
                badges: badges,
                activeBanner: activeBanner,
                activeFrame: activeFrame,
                photoUrl: photoUrl,
              );
            },
          );
        }

        return _buildProfileScaffold(
          context: context,
          ref: ref,
          username: username,
          data: data,
          uid: uid,
          badges: badges,
          activeBanner: activeBanner,
          activeFrame: activeFrame,
          photoUrl: photoUrl,
        );
      },
    );
  }

  Widget _buildProfileScaffold({
    required BuildContext context,
    required WidgetRef ref,
    required String username,
    required Map<String, dynamic> data,
    required String uid,
    required List<String> badges,
    required String? activeBanner,
    required String? activeFrame,
    required String? photoUrl,
  }) {
    return Scaffold(
      appBar: AppBar(title: Text('@$username')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileHeader(
              username: username,
              activeBannerId: activeBanner,
              activeFrameId: activeFrame,
              photoUrl: photoUrl,
            ),
            const SizedBox(height: 12),
            Text(
              data['displayName'] ?? '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (data['bio'] != null && data['bio'] != '') Text(data['bio']),
            const SizedBox(height: 20),
            Row(
              children: [
                Chip(label: Text('Views: ${data['viewsCount'] ?? 0}')),
                const SizedBox(width: 8),
                Chip(label: Text('Level: ${data['level'] ?? 1}')),
                const SizedBox(width: 8),
                Chip(label: Text('Followers: ${data['followersCount'] ?? 0}')),
              ],
            ),
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: badges
                    .map<Widget>((badgeId) => Chip(label: Text(badgeId)))
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
            _FollowActionSection(profileUid: uid, profileUsername: username),
            const SizedBox(height: 8),
            _FriendActionSection(profileUid: uid, profileUsername: username),
            const SizedBox(height: 8),
            _SafetyActionsSection(profileUid: uid, profileUsername: username),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (!context.mounted) return;

                  final token = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        _SendMessageSheet(toUid: uid, toUsername: username),
                  );

                  if (!context.mounted || token == null || token.isEmpty) {
                    return;
                  }
                  ref.read(lastMessageTokenProvider.notifier).setToken(token);

                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Sent'),
                      content: SelectableText('Token: $token'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            context.push('/m/$token');
                          },
                          child: const Text('Open Follow-up'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Send Message'),
              ),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: (() {
                final viewerUid = FirebaseAuth.instance.currentUser?.uid;
                Query<Map<String, dynamic>> q = FirebaseFirestore.instance
                    .collection(FirestorePaths.users)
                    .doc(uid)
                    .collection(FirestorePaths.posts);
                if (viewerUid != uid) {
                  q = q.where('status', isEqualTo: 'active');
                }
                return q.orderBy('createdAt', descending: true).snapshots();
              })(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const SizedBox();
                }
                if (!snapshot.hasData) return const SizedBox();

                final posts = snapshot.data!.docs;

                return Column(
                  children: posts.map((doc) {
                    final postData = doc.data();
                    final postId = doc.id;
                    final likesCount = (postData['likesCount'] ?? 0) as int;
                    final reportsCount =
                        ((postData['reportsCount'] ?? 0) as num).toInt();
                    final status = (postData['status'] ?? 'active').toString();
                    final hidden = status == 'hidden';
                    return Card(
                      margin: const EdgeInsets.only(top: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hidden)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: Colors.orange.withOpacity(0.15),
                                ),
                                child: const Text(
                                  'Hidden',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            Text(
                              hidden ? '[Hidden content]' : (postData['text'] ?? ''),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hidden ? 'This post is currently hidden.' : (postData['replyText'] ?? ''),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () async {
                                  final me = FirebaseAuth.instance.currentUser;
                                  if (me == null) return;

                                  final reportData = await showReportDialog(
                                    context,
                                  );
                                  if (reportData == null) return;

                                  try {
                                    await ref
                                        .read(reportRepositoryProvider)
                                        .reportPost(
                                          reporterUid: me.uid,
                                          postOwnerUid: uid,
                                          postId: postId,
                                          reason: reportData['reason']!,
                                          details: reportData['details'] ?? '',
                                        );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Report submitted'),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    final msg =
                                        e.toString().contains(
                                          'ALREADY_REPORTED',
                                        )
                                        ? 'You already reported this post'
                                        : 'Failed to submit report';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(msg)),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.flag_outlined),
                                label: const Text('Report'),
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.flag, size: 16),
                                const SizedBox(width: 6),
                                Text('$reportsCount'),
                              ],
                            ),
                            _RowLikeBar(
                              profileUid: uid,
                              postId: postId,
                              likesCount: likesCount,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<_PublicProfileData?> _loadProfile(ProfileRepository repo) async {
    final uid = await repo.getUidByUsername(username);
    if (uid == null) return null;
    final data = await repo.getProfile(uid);
    if (data == null) return null;
    return _PublicProfileData(uid: uid, data: data);
  }
}

class _PublicProfileData {
  _PublicProfileData({required this.uid, required this.data});

  final String uid;
  final Map<String, dynamic> data;
}

class _SafetyActionsSection extends ConsumerWidget {
  const _SafetyActionsSection({
    required this.profileUid,
    required this.profileUsername,
  });

  final String profileUid;
  final String profileUsername;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.uid == profileUid) return const SizedBox.shrink();

    return StreamBuilder<bool>(
      stream: ref
          .read(blockRepositoryProvider)
          .watchIsBlocked(myUid: me.uid, otherUid: profileUid),
      builder: (context, snap) {
        final isBlocked = snap.data ?? false;

        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (isBlocked) {
                    await ref
                        .read(blockRepositoryProvider)
                        .unblockUser(myUid: me.uid, blockedUid: profileUid);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User unblocked')),
                    );
                    return;
                  }

                  await ref
                      .read(blockRepositoryProvider)
                      .blockUser(
                        myUid: me.uid,
                        blockedUid: profileUid,
                        blockedUsername: profileUsername,
                      );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User blocked âœ…')),
                  );
                },
                icon: Icon(isBlocked ? Icons.lock_open : Icons.block),
                label: Text(isBlocked ? 'Unblock' : 'Block'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final reportData = await showReportDialog(context);
                  if (reportData == null) return;

                  await ref
                      .read(reportRepositoryProvider)
                      .report(
                        type: 'profile',
                        targetPath: '${FirestorePaths.users}/$profileUid',
                        targetOwnerUid: profileUid,
                        reporterUid: me.uid,
                        reason: reportData['reason']!,
                        details: reportData['details'] ?? '',
                      );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted âœ…')),
                  );
                },
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Report'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FollowActionSection extends ConsumerWidget {
  const _FollowActionSection({
    required this.profileUid,
    required this.profileUsername,
  });

  final String profileUid;
  final String profileUsername;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.uid == profileUid) return const SizedBox.shrink();

    return StreamBuilder<bool>(
      stream: ref
          .read(followRepositoryProvider)
          .watchIsFollowing(myUid: me.uid, targetUid: profileUid),
      builder: (context, snap) {
        final isFollowing = snap.data ?? false;

        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              try {
                if (isFollowing) {
                  await ref
                      .read(followRepositoryProvider)
                      .unfollow(myUid: me.uid, targetUid: profileUid);
                } else {
                  final myProfile = await ref
                      .read(profileRepositoryProvider)
                      .getProfile(me.uid);
                  final myUsername = (myProfile?['username'] ?? '') as String;
                  if (myUsername.isEmpty) return;

                  await ref
                      .read(followRepositoryProvider)
                      .follow(
                        myUid: me.uid,
                        myUsername: myUsername,
                        targetUid: profileUid,
                        targetUsername: profileUsername,
                      );
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Follow action failed: $e')),
                );
              }
            },
            icon: Icon(isFollowing ? Icons.check_circle_outline : Icons.add),
            label: Text(isFollowing ? 'Following' : 'Follow'),
          ),
        );
      },
    );
  }
}

class _FriendActionSection extends ConsumerWidget {
  const _FriendActionSection({
    required this.profileUid,
    required this.profileUsername,
  });

  final String profileUid;
  final String profileUsername;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.uid == profileUid) return const SizedBox.shrink();

    final db = FirebaseFirestore.instance;
    final friendDoc = db
        .collection(FirestorePaths.users)
        .doc(me.uid)
        .collection(FirestorePaths.friends)
        .doc(profileUid)
        .snapshots();

    final outDoc = db
        .collection(FirestorePaths.users)
        .doc(me.uid)
        .collection(FirestorePaths.friendRequestsOut)
        .doc(profileUid)
        .snapshots();

    final inDoc = db
        .collection(FirestorePaths.users)
        .doc(me.uid)
        .collection(FirestorePaths.friendRequestsIn)
        .doc(profileUid)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: friendDoc,
      builder: (context, friendSnap) {
        final isFriend = friendSnap.data?.exists ?? false;
        if (isFriend) {
          return Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final myProfile = await ref
                          .read(profileRepositoryProvider)
                          .getProfile(me.uid);
                      final myUsername =
                          (myProfile?['username'] ?? '') as String;
                      if (myUsername.isEmpty) return;

                      final chatId = await ref
                          .read(chatsRepoProvider)
                          .openChat(
                            myUid: me.uid,
                            myUsername: myUsername,
                            otherUid: profileUid,
                            otherUsername: profileUsername,
                          );

                      if (!context.mounted) return;
                      final encodedName = Uri.encodeComponent(profileUsername);
                      context.push(
                        '/chat/$chatId?otherUid=$profileUid&otherUsername=$encodedName',
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Chat failed: $e')),
                      );
                    }
                  },
                  child: const Text('Chat'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Remove friend?'),
                        content: Text(
                          'Remove @$profileUsername from your friends list?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await ref
                        .read(friendsRepositoryProvider)
                        .removeFriend(myUid: me.uid, friendUid: profileUid);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Friend removed')),
                    );
                  },
                  child: const Text('Remove Friend'),
                ),
              ),
            ],
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: outDoc,
          builder: (context, outSnap) {
            final hasOutgoing = outSnap.data?.exists ?? false;
            if (hasOutgoing) {
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await ref
                        .read(friendsRepositoryProvider)
                        .cancelOutgoing(myUid: me.uid, toUid: profileUid);
                  },
                  child: const Text('Cancel Request'),
                ),
              );
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: inDoc,
              builder: (context, inSnap) {
                final inData = inSnap.data?.data();
                final hasIncoming = inSnap.data?.exists ?? false;
                if (hasIncoming) {
                  final fromUsername =
                      (inData?['fromUsername'] ?? profileUsername) as String;
                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await ref
                                .read(friendsRepositoryProvider)
                                .declineIncoming(
                                  myUid: me.uid,
                                  fromUid: profileUid,
                                );
                          },
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final myProfile = await ref
                                .read(profileRepositoryProvider)
                                .getProfile(me.uid);
                            final myUsername =
                                (myProfile?['username'] ?? '') as String;
                            if (myUsername.isEmpty) return;
                            try {
                              await ref
                                  .read(friendsRepositoryProvider)
                                  .acceptIncoming(
                                    myUid: me.uid,
                                    myUsername: myUsername,
                                    fromUid: profileUid,
                                    fromUsername: fromUsername,
                                  );
                            } catch (e) {
                              if (!context.mounted) return;
                              final raw = e.toString();
                              final msg = raw.contains('BLOCKED_RELATION')
                                  ? 'Cannot accept while one side is blocked.'
                                  : raw.contains('REQUEST_IN_MISSING')
                                  ? 'Request no longer exists.'
                                  : 'Accept failed: $e';
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(msg)));
                            }
                          },
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  );
                }

                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final myProfile = await ref
                          .read(profileRepositoryProvider)
                          .getProfile(me.uid);
                      final myUsername =
                          (myProfile?['username'] ?? '') as String;
                      if (myUsername.isEmpty) return;

                      await ref
                          .read(friendsRepositoryProvider)
                          .sendFriendRequest(
                            myUid: me.uid,
                            myUsername: myUsername,
                            toUid: profileUid,
                            toUsername: profileUsername,
                          );
                    },
                    child: const Text('Add Friend'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RowLikeBar extends ConsumerWidget {
  const _RowLikeBar({
    required this.profileUid,
    required this.postId,
    required this.likesCount,
  });

  final String profileUid;
  final String postId;
  final int likesCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Text('â¤ $likesCount');
    }

    final isLikedStream = ref
        .read(likesRepositoryProvider)
        .watchIsLiked(
          profileUid: profileUid,
          postId: postId,
          likerUid: user.uid,
        );

    return StreamBuilder<bool>(
      stream: isLikedStream,
      builder: (context, snap) {
        final isLiked = snap.data ?? false;

        return Row(
          children: [
            IconButton(
              onPressed: () async {
                try {
                  await ref
                      .read(likesRepositoryProvider)
                      .toggleLike(
                        profileUid: profileUid,
                        postId: postId,
                        likerUid: user.uid,
                      );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Like failed: $e')),
                  );
                }
              },
              icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
            ),
            Text('$likesCount'),
          ],
        );
      },
    );
  }
}

class _SendMessageSheet extends ConsumerStatefulWidget {
  const _SendMessageSheet({required this.toUid, required this.toUsername});

  final String toUid;
  final String toUsername;

  @override
  ConsumerState<_SendMessageSheet> createState() => _SendMessageSheetState();
}

class _SendMessageSheetState extends ConsumerState<_SendMessageSheet> {
  final _text = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final msg = _text.text.trim();
      if (msg.isEmpty) throw Exception('Message is empty');
      if (msg.length > 500) throw Exception('Max 500 characters');

      final repo = ref.read(messagesRepositoryProvider);
      final token = await repo.sendAnonymousMessage(
        toUid: widget.toUid,
        toUsername: widget.toUsername,
        text: msg,
      );

      if (mounted) Navigator.pop(context, token);
    } catch (e) {
      final raw = e.toString();
      String msg;
      if (raw.contains('BLOCKED_USER')) {
        msg = 'You blocked this user. Unblock first.';
      } else if (raw.contains('DAILY_ANON_LIMIT_REACHED')) {
        msg = 'Take a short break and try again tomorrow.';
      } else {
        msg = raw;
      }
      setState(() => _error = msg);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Send to @${widget.toUsername}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Write an anonymous message...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _send,
              child: Text(_loading ? 'Sending...' : 'Send (Anonymous)'),
            ),
          ),
        ],
      ),
    );
  }
}
