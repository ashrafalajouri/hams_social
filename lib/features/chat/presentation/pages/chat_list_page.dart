import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/hams_ui.dart';
import '../../../../firebase/firestore_paths.dart';
import '../../data/chats_repository.dart';
import 'chat_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final stream = FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(me.uid)
        .collection(FirestorePaths.chats)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Ø§Ù„Ù…Ø­Ø§Ø¯Ø«Ø§Øª')),
      body: HamsScreenBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return Center(
                child: HamsGlassCard(
                  margin: const EdgeInsets.all(18),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 44),
                      SizedBox(height: 8),
                      Text('No chats yet'),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              itemCount: docs.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final doc = docs[i];
                final d = doc.data();

                final otherUid = (d['otherUid'] ?? '') as String;
                final otherUsername =
                    (d['otherUsername'] ?? 'Unknown') as String;
                final myLastMessage = (d['lastMessage'] ?? '') as String;
                final unread = (d['unreadCount'] ?? 0) as int;
                final shownLastMessage = myLastMessage.trim();

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                              try {
                                final meDoc = await FirebaseFirestore.instance
                                    .collection(FirestorePaths.users)
                                    .doc(me.uid)
                                    .get();
                                final myUsername =
                                    (meDoc.data()?['username'] ?? '') as String;
                                if (myUsername.trim().isEmpty) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Set your username first to open chat.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final ensuredChatId = await ChatsRepository(
                                  FirebaseFirestore.instance,
                                ).openChat(
                                  myUid: me.uid,
                                  myUsername: myUsername,
                                  otherUid: otherUid,
                                  otherUsername: otherUsername,
                                );

                                if (!context.mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatPage(
                                      chatId: ensuredChatId,
                                      otherUid: otherUid,
                                      otherUsername: otherUsername,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                final raw = e.toString();
                                final msg =
                                    raw.contains('CHAT_REQUIRES_MUTUAL_FRIEND')
                                    ? 'Chat needs mutual friendship. Remove and re-add friend.'
                                    : raw.contains('BLOCKED_USER')
                                    ? 'Chat unavailable because one side blocked the other.'
                                    : 'Unable to open chat: $e';
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(msg)));
                              }
                            },
                    child: HamsGlassCard(
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              final uname = Uri.encodeComponent(
                                otherUsername,
                              );
                              context.push('/u/$uname');
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: HamsGradients.brand,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                otherUsername.isNotEmpty
                                    ? otherUsername[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
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
                                  otherUsername,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  shownLastMessage.isEmpty
                                      ? 'Tap to chat'
                                      : shownLastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withOpacity(0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (unread > 0)
                            Container(
                              constraints:
                                  const BoxConstraints(minWidth: 24),
                              height: 24,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: HamsGradients.brand,
                                borderRadius: BorderRadius.circular(
                                  999,
                                ),
                              ),
                              child: Text(
                                '$unread',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          else
                            const Icon(Icons.chevron_right_rounded),
                        ],
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
}
