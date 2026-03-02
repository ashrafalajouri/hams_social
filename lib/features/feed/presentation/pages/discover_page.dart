import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/hams_ui.dart';
import '../../../../core/config/remote_config_service.dart';
import '../../../../core/utils/app_error_text.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_retry_view.dart';
import '../../../../core/widgets/shimmer_list_placeholder.dart';
import '../../../../firebase/firestore_paths.dart';
import '../../../../firebase/firebase_providers.dart';
import '../../../messages/presentation/controllers/likes_providers.dart';
import '../../../safety/presentation/blocked_ids_provider.dart';
import '../../../safety/presentation/report_dialog.dart';
import '../../../safety/presentation/safety_providers.dart';
import '../../domain/discover_post_item.dart';
import '../../domain/post_ranker.dart';
import '../discover_providers.dart';

class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Discover'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Latest'),
              Tab(text: 'Trending'),
            ],
          ),
        ),
        body: const HamsScreenBackground(
          child: TabBarView(
            children: [
              _LatestTab(),
              _TrendingTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatestTab extends ConsumerStatefulWidget {
  const _LatestTab();

  @override
  ConsumerState<_LatestTab> createState() => _LatestTabState();
}

class _LatestTabState extends ConsumerState<_LatestTab> {
  int get _pageSize => RemoteConfigService.instance.discoverFeedLimit;
  final _scroll = ScrollController();
  final _items = <DiscoverPostItem>[];

  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 220) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (!reset && !_hasMore) return;

    setState(() {
      _loading = true;
      if (reset) _error = null;
    });

    try {
      final repo = ref.read(discoverRepositoryProvider);
      final db = ref.read(firestoreProvider);
      final blocked = ref.read(blockedIdsProvider).value ?? const <String>[];
      final blockedSet = blocked.toSet();

      if (reset) {
        _items.clear();
        _lastDoc = null;
        _hasMore = true;
      }

      final page = await repo.fetchLatestPage(
        limit: _pageSize,
        startAfter: _lastDoc,
      );
      if (page.docs.isNotEmpty) {
        _lastDoc = page.docs.last;
      }
      if (page.docs.length < _pageSize) {
        _hasMore = false;
      }

      final mapped = await _mapDocsToItems(db, page.docs, blockedSet);
      _items.addAll(mapped);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<List<DiscoverPostItem>> _mapDocsToItems(
    FirebaseFirestore db,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Set<String> blockedSet,
  ) async {
    final visible = docs.where((doc) {
      final data = doc.data();
      final pathParts = doc.reference.path.split('/');
      final ownerUid = pathParts.length >= 2 ? pathParts[1] : '';
      final authorUid = (data['authorUid'] ?? ownerUid).toString();
      return authorUid.isNotEmpty && !blockedSet.contains(authorUid);
    }).toList();

    final authorIds = visible
        .map((d) {
          final data = d.data();
          final pathParts = d.reference.path.split('/');
          final ownerUid = pathParts.length >= 2 ? pathParts[1] : '';
          return (data['authorUid'] ?? ownerUid).toString();
        })
        .where((uid) => uid.isNotEmpty)
        .toSet()
        .toList();

    final authorRep = <String, int>{};
    if (authorIds.isNotEmpty) {
      final snaps = await Future.wait(
        authorIds.map((uid) => db.collection(FirestorePaths.users).doc(uid).get()),
      );
      for (final s in snaps) {
        if (!s.exists) continue;
        final data = s.data() ?? <String, dynamic>{};
        final rep = ((data['reputationScore'] ?? 100) as num).toInt();
        authorRep[s.id] = rep;
      }
    }

    return visible.map((doc) {
      final data = doc.data();
      final pathParts = doc.reference.path.split('/');
      final ownerUid = pathParts.length >= 2 ? pathParts[1] : '';
      final authorUid = (data['authorUid'] ?? ownerUid).toString();
      final createdAt = data['createdAt'];
      final createdDate = createdAt is DateTime
          ? createdAt
          : (createdAt is Timestamp)
          ? createdAt.toDate()
          : DateTime.now();
      final likes = ((data['likesCount'] ?? 0) as num).toInt();
      final reports = ((data['reportsCount'] ?? 0) as num).toInt();
      final rep = authorRep[authorUid] ?? 100;

      return DiscoverPostItem(
        postId: doc.id,
        path: doc.reference.path,
        authorUid: authorUid,
        authorUsername: (data['authorUsername'] ?? '').toString(),
        text: (data['text'] ?? '').toString(),
        replyText: (data['replyText'] ?? '').toString(),
        likesCount: likes,
        reportsCount: reports,
        createdAt: createdDate,
        authorRep: rep,
        score: PostRanker.score(
          likes: likes,
          reports: reports,
          authorRep: rep,
          createdAt: createdDate,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const ShimmerListPlaceholder();
    }
    if (_error != null && _items.isEmpty) {
      return ErrorRetryView(
        message: appErrorText(_error!),
        onRetry: () => _load(reset: true),
      );
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.explore_off_rounded,
        title: 'No posts yet',
        subtitle: 'Discover feed is empty for now.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
        itemCount: _items.length + (_loading ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _DiscoverCard(item: _items[index]);
        },
      ),
    );
  }
}

class _TrendingTab extends ConsumerWidget {
  const _TrendingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(discoverFeedProvider);

    return feedAsync.when(
      loading: ShimmerListPlaceholder.new,
      error: (e, _) => EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Failed to load',
        subtitle: appErrorText(e),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.explore_off_rounded,
            title: 'No posts yet',
            subtitle: 'Trending is empty right now.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(discoverFeedProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _DiscoverCard(item: items[index]),
          ),
        );
      },
    );
  }
}

class _DiscoverCard extends ConsumerWidget {
  const _DiscoverCard({required this.item});

  final DiscoverPostItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = FirebaseAuth.instance.currentUser;
    final myUid = me?.uid;
    final canLike = myUid != null && myUid != item.authorUid;

    return HamsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: item.authorUsername.isEmpty
                      ? null
                      : () => context.push('/u/${item.authorUsername}'),
                  child: Text(
                    item.authorUsername.isEmpty
                        ? item.authorUid
                        : '@${item.authorUsername}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Text(
                _formatDate(item.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (item.text.isNotEmpty)
            Text(
              item.text,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          if (item.text.isNotEmpty) const SizedBox(height: 6),
          Text(
            item.replyText,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetaPill(
                icon: Icons.favorite_rounded,
                label: '${item.likesCount}',
                color: Colors.pink,
              ),
              const SizedBox(width: 8),
              _MetaPill(
                icon: Icons.flag_rounded,
                label: '${item.reportsCount}',
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              _MetaPill(
                icon: Icons.workspace_premium_rounded,
                label: '${item.authorRep}',
                color: Colors.blue,
              ),
              const Spacer(),
              Text(
                item.score.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (canLike)
                _LikeButton(
                  ownerUid: item.authorUid,
                  postId: item.postId,
                  likesCount: item.likesCount,
                ),
              if (!canLike)
                Text(
                  'Likes ${item.likesCount}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: myUid == null
                    ? null
                    : () async {
                        final reportData = await showReportDialog(context);
                        if (reportData == null) return;
                        await ref
                            .read(reportRepositoryProvider)
                            .reportPost(
                              reporterUid: myUid,
                              postOwnerUid: item.authorUid,
                              postId: item.postId,
                              reason: reportData['reason']!,
                              details: reportData['details'] ?? '',
                            );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Report submitted')),
                        );
                      },
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Report'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LikeButton extends ConsumerWidget {
  const _LikeButton({
    required this.ownerUid,
    required this.postId,
    required this.likesCount,
  });

  final String ownerUid;
  final String postId;
  final int likesCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return Text('Likes $likesCount');
    }

    return StreamBuilder<bool>(
      stream: ref
          .read(likesRepositoryProvider)
          .watchIsLiked(profileUid: ownerUid, postId: postId, likerUid: me.uid),
      builder: (context, snap) {
        final isLiked = snap.data ?? false;
        return TextButton.icon(
          onPressed: () async {
            try {
              await ref
                  .read(likesRepositoryProvider)
                  .toggleLike(
                    profileUid: ownerUid,
                    postId: postId,
                    likerUid: me.uid,
                  );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Like failed: $e')),
              );
            }
          },
          icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
          label: Text('$likesCount'),
        );
      },
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $h:$m';
}
