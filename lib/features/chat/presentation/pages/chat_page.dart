import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/hams_ui.dart';
import '../../../../firebase/firestore_paths.dart';
import '../../../safety/presentation/is_blocked_provider.dart';
import '../../../safety/presentation/safety_providers.dart';
import '../../data/chats_repository.dart';
import '../controllers/chats_providers.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUid,
    required this.otherUsername,
  });

  final String chatId;
  final String otherUid;
  final String otherUsername;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _c = TextEditingController();
  bool _marked = false;
  Timer? _typingTimer;
  late final ChatsRepository _chatsRepo;

  @override
  void initState() {
    super.initState();
    _chatsRepo = ref.read(chatsRepoProvider);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    final me = FirebaseAuth.instance.currentUser;
    if (me != null) {
      unawaited(
        _chatsRepo.setTyping(chatId: widget.chatId, uid: me.uid, typing: false),
      );
    }
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final blockedAsync = ref.watch(
      isBlockedProvider((myUid: me.uid, otherUid: widget.otherUid)),
    );
    final blocked = blockedAsync.value ?? false;
    if (blocked) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.otherUsername)),
        body: Center(
          child: HamsGlassCard(
            margin: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('You blocked this user.'),
                const SizedBox(height: 10),
                HamsGradientButton(
                  label: 'Unblock',
                  icon: Icons.lock_open_rounded,
                  onPressed: () async {
                    await ref
                        .read(blockRepositoryProvider)
                        .unblockUser(
                          myUid: me.uid,
                          blockedUid: widget.otherUid,
                        );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_marked) {
      _marked = true;
      Future.microtask(() async {
        try {
          await _chatsRepo.markAsRead(chatId: widget.chatId, myUid: me.uid);
        } catch (_) {
          // Can fail with permission-denied when other side blocked this user.
        }
      });
    }

    final msgStream = _chatsRepo.watchMessages(widget.chatId);
    final chatDocStream = FirebaseFirestore.instance
        .collection(FirestorePaths.chats)
        .doc(widget.chatId)
        .snapshots();
    final statusStream = FirebaseDatabase.instance
        .ref('status/${widget.otherUid}')
        .onValue;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: StreamBuilder<DatabaseEvent>(
          stream: statusStream,
          builder: (context, snap) {
            String statusText = 'Offline';
            final raw = snap.data?.snapshot.value;
            if (raw is Map) {
              final state = raw['state']?.toString() ?? 'offline';
              final ts = raw['lastChangedAt'];
              if (state == 'online') {
                statusText = 'Online';
              } else if (state == 'away') {
                statusText = 'Away';
              } else if (ts is int) {
                final dt = DateTime.fromMillisecondsSinceEpoch(ts);
                statusText = 'Last seen ${_ago(dt)}';
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.otherUsername),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withOpacity(0.8),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: () {
              final uname = Uri.encodeComponent(widget.otherUsername);
              context.push('/u/$uname');
            },
            icon: const Icon(Icons.person_outline),
            tooltip: 'Open profile',
          ),
        ],
      ),
      body: HamsScreenBackground(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: chatDocStream,
                builder: (context, chatSnap) {
                  if (chatSnap.hasError) {
                    return const Center(
                      child: Text(
                        'Chat unavailable (blocked or no permission).',
                      ),
                    );
                  }
                  final chatData = chatSnap.data?.data() ?? const {};
                  final readAtMap =
                      (chatData['readAtMap'] as Map?)
                          ?.cast<String, dynamic>() ??
                      const {};
                  final typingMap =
                      (chatData['typingMap'] as Map?)
                          ?.cast<String, dynamic>() ??
                      const {};
                  final otherTyping = typingMap[widget.otherUid] == true;
                  final otherReadTs = readAtMap[widget.otherUid];
                  final otherReadAt = otherReadTs is Timestamp
                      ? otherReadTs
                      : null;

                  return Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: otherTyping ? 36 : 0,
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                        padding: otherTyping
                            ? const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              )
                            : EdgeInsets.zero,
                        decoration: BoxDecoration(
                          color: HamsColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: otherTyping
                            ? Row(
                                children: [
                                  const Icon(Icons.edit_rounded, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${widget.otherUsername} is typing...',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              )
                            : null,
                      ),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: msgStream,
                          builder: (context, snap) {
                            if (snap.hasError) {
                              return const Center(
                                child: Text(
                                  'Messages unavailable (blocked or no permission).',
                                ),
                              );
                            }
                            if (!snap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final docs = snap.data!.docs;
                            DocumentSnapshot<Map<String, dynamic>>? lastMine;
                            for (final doc in docs) {
                              final d = doc.data();
                              if ((d['senderUid'] ?? '') == me.uid) {
                                lastMine = doc;
                                break;
                              }
                            }

                            return ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                              itemCount: docs.length,
                              itemBuilder: (context, i) {
                                final doc = docs[i];
                                final d = doc.data();
                                final sender = (d['senderUid'] ?? '') as String;
                                final text = (d['text'] ?? '') as String;
                                final mine = sender == me.uid;
                                final ts = d['createdAt'];
                                final createdAt = ts is Timestamp ? ts : null;
                                final isSeen =
                                    (createdAt != null && otherReadAt != null)
                                    ? (otherReadAt.toDate().isAfter(
                                            createdAt.toDate(),
                                          ) ||
                                          otherReadAt.toDate().isAtSameMomentAs(
                                            createdAt.toDate(),
                                          ))
                                    : false;

                                return Align(
                                  alignment: mine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                          0.76,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: mine
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: mine
                                                ? HamsGradients.brand
                                                : null,
                                            color: mine
                                                ? null
                                                : Theme.of(context)
                                                      .cardTheme
                                                      .color
                                                      ?.withOpacity(0.9),
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(
                                                16,
                                              ),
                                              topRight: const Radius.circular(
                                                16,
                                              ),
                                              bottomLeft: Radius.circular(
                                                mine ? 16 : 4,
                                              ),
                                              bottomRight: Radius.circular(
                                                mine ? 4 : 16,
                                              ),
                                            ),
                                            border: mine
                                                ? null
                                                : Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.08),
                                                  ),
                                          ),
                                          child: Text(
                                            text,
                                            style: TextStyle(
                                              color: mine
                                                  ? Colors.white
                                                  : Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.color,
                                            ),
                                          ),
                                        ),
                                        if (mine &&
                                            lastMine != null &&
                                            doc.id == lastMine.id)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              isSeen ? 'Seen' : 'Delivered',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall?.color,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: HamsGlassCard(
                padding: const EdgeInsets.all(8),
                radius: 22,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _c,
                        onChanged: (_) {
                          unawaited(
                            _chatsRepo
                                .setTyping(
                                  chatId: widget.chatId,
                                  uid: me.uid,
                                  typing: true,
                                )
                                .catchError((_) {}),
                          );

                          _typingTimer?.cancel();
                          _typingTimer = Timer(const Duration(seconds: 2), () {
                            unawaited(
                              _chatsRepo
                                  .setTyping(
                                    chatId: widget.chatId,
                                    uid: me.uid,
                                    typing: false,
                                  )
                                  .catchError((_) {}),
                            );
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Write a message...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        final text = _c.text;
                        _c.clear();
                        _typingTimer?.cancel();
                        await _chatsRepo.setTyping(
                          chatId: widget.chatId,
                          uid: me.uid,
                          typing: false,
                        );
                        try {
                          await _chatsRepo.sendMessage(
                            chatId: widget.chatId,
                            myUid: me.uid,
                            otherUid: widget.otherUid,
                            text: text,
                          );
                        } catch (e) {
                          if (!mounted) return;
                          final msg = e.toString().contains('BLOCKED_USER')
                              ? 'You blocked this user. Unblock first.'
                              : 'Send failed: $e';
                          ScaffoldMessenger.of(
                            this.context,
                          ).showSnackBar(SnackBar(content: Text(msg)));
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: HamsGradients.brand,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.send_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _ago(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
