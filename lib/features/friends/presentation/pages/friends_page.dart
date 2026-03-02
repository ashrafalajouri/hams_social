import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/hams_ui.dart';
import '../../../../core/utils/app_error_text.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_retry_view.dart';
import '../../../../core/widgets/shimmer_list_placeholder.dart';
import '../../../chat/presentation/controllers/chats_providers.dart';
import '../../../profile/presentation/controllers/profile_providers.dart';
import '../controllers/friends_providers.dart';

class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage> {
  final _searchController = TextEditingController();
  bool _searching = false;
  String? _searchError;
  _UserSearchResult? _result;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final raw = _searchController.text.trim().toLowerCase();
    final username = raw.replaceAll(' ', '');

    setState(() {
      _searching = true;
      _searchError = null;
      _result = null;
    });

    try {
      if (username.isEmpty) {
        throw Exception('Type a username');
      }

      final profileRepo = ref.read(profileRepositoryProvider);
      final uid = await profileRepo.getUidByUsername(username);
      if (uid == null) {
        throw Exception('User not found');
      }
      final profile = await profileRepo.getProfile(uid);
      final displayName = (profile?['displayName'] ?? '') as String;

      setState(() {
        _result = _UserSearchResult(
          username: username,
          uid: uid,
          displayName: displayName,
        );
      });
    } catch (e) {
      setState(() {
        _searchError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Friends')),
        body: const Center(child: Text('Not signed in')),
      );
    }

    final repo = ref.watch(friendsRepositoryProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الأصدقاء'),
          leading: IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.profile);
              }
            },
            icon: const Icon(Icons.arrow_back),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الطلبات'),
              Tab(text: 'قائمة الأصدقاء'),
            ],
          ),
        ),
        body: HamsScreenBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: HamsGlassCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _search(),
                              decoration: const InputDecoration(
                                labelText: 'Search by username',
                                prefixText: '@',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          HamsGradientButton(
                            label: _searching ? '...' : 'Search',
                            icon: Icons.search_rounded,
                            onPressed: _searching ? null : _search,
                            height: 46,
                          ),
                        ],
                      ),
                      if (_searchError != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _searchError!,
                            style: const TextStyle(color: HamsColors.danger),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_result != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: HamsGlassCard(
                    borderColor: HamsColors.primary.withOpacity(0.5),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_rounded),
                      ),
                      title: Text('@${_result!.username}'),
                      subtitle: Text(
                        _result!.displayName.isEmpty
                            ? _result!.uid
                            : _result!.displayName,
                      ),
                      trailing: FilledButton.tonalIcon(
                        onPressed: () =>
                            context.push('/u/${_result!.username}'),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open'),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    StreamBuilder(
                      stream: repo.watchIncomingRequests(myUid: user.uid),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return ErrorRetryView(
                            message: appErrorText(snapshot.error!),
                            onRetry: () => setState(() {}),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const ShimmerListPlaceholder();
                        }

                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return const EmptyState(
                            icon: Icons.mark_email_read_outlined,
                            title: 'No requests',
                            subtitle: 'No incoming friend requests now.',
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final fromUid = (data['fromUid'] ?? '') as String;
                            final fromUsername =
                                (data['fromUsername'] ?? '') as String;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: HamsGlassCard(
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 22,
                                      child: Icon(
                                        Icons.person_add_alt_1_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '@$fromUsername',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            fromUid,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withOpacity(0.75),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await repo.declineIncoming(
                                          myUid: user.uid,
                                          fromUid: fromUid,
                                        );
                                      },
                                      child: const Text('Decline'),
                                    ),
                                    const SizedBox(width: 4),
                                    FilledButton(
                                      onPressed: () async {
                                        final myProfile = await ref
                                            .read(profileRepositoryProvider)
                                            .getProfile(user.uid);
                                        final myUsername =
                                            (myProfile?['username'] ?? '')
                                                as String;
                                        if (myUsername.isEmpty) return;
                                        try {
                                          await repo.acceptIncoming(
                                            myUid: user.uid,
                                            myUsername: myUsername,
                                            fromUid: fromUid,
                                            fromUsername: fromUsername,
                                          );
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          final raw = e.toString();
                                          final msg =
                                              raw.contains('BLOCKED_RELATION')
                                              ? 'Cannot accept while one side is blocked.'
                                              : raw.contains(
                                                  'REQUEST_IN_MISSING',
                                                )
                                              ? 'Request no longer exists.'
                                              : 'Accept failed: $e';
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(content: Text(msg)),
                                          );
                                        }
                                      },
                                      child: const Text('Accept'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    StreamBuilder(
                      stream: repo.watchFriends(myUid: user.uid),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return ErrorRetryView(
                            message: appErrorText(snapshot.error!),
                            onRetry: () => setState(() {}),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const ShimmerListPlaceholder();
                        }

                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return const EmptyState(
                            icon: Icons.people_outline_rounded,
                            title: 'No friends yet',
                            subtitle: 'Start connecting with people.',
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final friendUid = (data['uid'] ?? '') as String;
                            final friendUsername =
                                (data['username'] ?? '') as String;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: HamsGlassCard(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: HamsGradients.brand,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        friendUsername.isNotEmpty
                                            ? friendUsername[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '@$friendUsername',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            friendUid,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withOpacity(0.75),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        HamsGradientButton(
                                          label: 'Chat',
                                          icon: Icons.chat_bubble_rounded,
                                          height: 40,
                                          onPressed: () async {
                                            try {
                                              final myProfile = await ref
                                                  .read(
                                                    profileRepositoryProvider,
                                                  )
                                                  .getProfile(user.uid);
                                              final myUsername =
                                                  (myProfile?['username'] ?? '')
                                                      as String;
                                              if (myUsername.isEmpty) return;

                                              final chatId = await ref
                                                  .read(chatsRepoProvider)
                                                  .openChat(
                                                    myUid: user.uid,
                                                    myUsername: myUsername,
                                                    otherUid: friendUid,
                                                    otherUsername:
                                                        friendUsername,
                                                  );

                                              if (!context.mounted) return;
                                              final encodedName =
                                                  Uri.encodeComponent(
                                                    friendUsername,
                                                  );
                                              context.push(
                                                '/chat/$chatId?otherUid=$friendUid&otherUsername=$encodedName',
                                              );
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              final raw = e.toString();
                                              final msg =
                                                  raw.contains('BLOCKED_USER')
                                                  ? 'Cannot open chat: one side blocked the other.'
                                                  : raw.contains(
                                                      'CHAT_REQUIRES_MUTUAL_FRIEND',
                                                    )
                                                  ? 'Cannot open chat: friendship is not mutual yet. Remove and re-add friend.'
                                                  : 'Chat failed: $e';
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(content: Text(msg)),
                                              );
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          tooltip: 'Remove friend',
                                          icon: const Icon(
                                            Icons.person_remove_rounded,
                                          ),
                                          onPressed: () async {
                                            final ok = await showDialog<bool>(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                title: const Text(
                                                  'Remove friend?',
                                                ),
                                                content: Text(
                                                  'Remove @$friendUsername from your friends list?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    child: const Text('Remove'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (ok != true) return;
                                            await repo.removeFriend(
                                              myUid: user.uid,
                                              friendUid: friendUid,
                                            );
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('Friend removed'),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserSearchResult {
  _UserSearchResult({
    required this.username,
    required this.uid,
    required this.displayName,
  });

  final String username;
  final String uid;
  final String displayName;
}
