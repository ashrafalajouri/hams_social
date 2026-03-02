import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../firebase/firestore_paths.dart';
import '../../../firebase/firebase_providers.dart';
import '../../safety/presentation/blocked_ids_provider.dart';
import '../data/discover_repository.dart';
import '../domain/discover_post_item.dart';
import '../domain/post_ranker.dart';

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return DiscoverRepository(db);
});

final discoverFeedProvider = StreamProvider<List<DiscoverPostItem>>((ref) {
  final repo = ref.watch(discoverRepositoryProvider);
  final db = ref.watch(firestoreProvider);
  final blocked = ref.watch(blockedIdsProvider).value ?? const <String>[];
  final blockedSet = blocked.toSet();

  return repo.streamLatestActivePosts().asyncMap((docs) async {
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
        authorIds.map(
          (uid) => db.collection(FirestorePaths.users).doc(uid).get(),
        ),
      );
      for (final s in snaps) {
        if (!s.exists) continue;
        final data = s.data() ?? <String, dynamic>{};
        final rep = ((data['reputationScore'] ?? 100) as num).toInt();
        authorRep[s.id] = rep;
      }
    }

    final items = visible.map((doc) {
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
      final score = PostRanker.score(
        likes: likes,
        reports: reports,
        authorRep: rep,
        createdAt: createdDate,
      );

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
        score: score,
      );
    }).toList();

    items.sort((a, b) => b.score.compareTo(a.score));
    return items;
  });
});
