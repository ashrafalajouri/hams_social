import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/hams_ui.dart';
import '../../../../core/utils/app_error_text.dart';
import '../../../../core/widgets/error_retry_view.dart';
import '../../../../core/widgets/shimmer_list_placeholder.dart';
import '../../../safety/presentation/report_dialog.dart';
import '../../../safety/presentation/safety_providers.dart';
import '../../domain/message_entity.dart';
import '../controllers/inbox_providers.dart';
import '../controllers/messages_providers.dart';

class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(myInboxProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('صندوق الرسائل')),
      body: HamsScreenBackground(
        child: inboxAsync.when(
          loading: () => const ShimmerListPlaceholder(),
          error: (e, _) => ErrorRetryView(
            message: appErrorText(e),
            onRetry: () => ref.refresh(myInboxProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: HamsGlassCard(
                  margin: const EdgeInsets.all(20),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mark_email_unread_rounded, size: 44),
                      SizedBox(height: 10),
                      Text('لا توجد رسائل بعد'),
                    ],
                  ),
                ),
              );
            }

            final unreadCount = items.where((e) => !e.isRead).length;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: HamsGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.mail_rounded,
                          color: HamsColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text('Total: ${items.length}'),
                        const SizedBox(width: 12),
                        Text('Unread: $unreadCount'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final m = items[index];
                      return _MessageCard(message: m);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MessageCard extends ConsumerWidget {
  const _MessageCard({required this.message});

  final InboxMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        if (!message.isRead) {
          try {
            await ref
                .read(messagesRepositoryProvider)
                .markAsRead(myUid: myUid, messageId: message.id);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Mark as read failed: $e')),
              );
            }
          }
        }

        if (!context.mounted) return;
        final pageContext = context;

        showDialog(
          context: pageContext,
          builder: (dialogContext) {
            final alreadyReplied = message.replyType != null;
            String replyText = '';

            return AlertDialog(
              title: const Text('Message'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message.text),
                  const SizedBox(height: 12),
                  if (alreadyReplied)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: Text(
                        'Replied (${message.replyType})\n${message.replyText ?? ''}',
                      ),
                    )
                  else
                    TextField(
                      onChanged: (value) => replyText = value,
                      decoration: const InputDecoration(
                        hintText: 'Write a reply...',
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();

                    final reportData = await showReportDialog(pageContext);
                    if (reportData == null) return;

                    await ref
                        .read(reportRepositoryProvider)
                        .report(
                          type: 'inbox_message',
                          targetPath: 'users/$myUid/inbox/${message.id}',
                          targetOwnerUid: myUid,
                          reporterUid: myUid,
                          reason: reportData['reason']!,
                          details: reportData['details'] ?? '',
                        );
                    if (!pageContext.mounted) return;
                    ScaffoldMessenger.of(pageContext).showSnackBar(
                      const SnackBar(content: Text('Report submitted ?')),
                    );
                  },
                  child: const Text('Report'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                if (!alreadyReplied)
                  TextButton(
                    onPressed: () async {
                      final reply = replyText.trim();
                      if (reply.isEmpty) return;

                      try {
                        await ref
                            .read(messagesRepositoryProvider)
                            .replyToMessage(
                              myUid: myUid,
                              messageId: message.id,
                              replyText: reply,
                              replyType: 'private',
                            );

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (e) {
                        if (pageContext.mounted) {
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            SnackBar(content: Text('Private reply failed: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Reply Private'),
                  ),
                if (!alreadyReplied)
                  TextButton(
                    onPressed: () async {
                      final reply = replyText.trim();
                      if (reply.isEmpty) return;

                      try {
                        await ref
                            .read(messagesRepositoryProvider)
                            .createPublicPost(
                              myUid: myUid,
                              originalText: message.text,
                              replyText: reply,
                              messageId: message.id,
                            );

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (e) {
                        if (pageContext.mounted) {
                          final raw = e.toString();
                          final msg = raw.contains('DAILY_POST_LIMIT_REACHED')
                              ? 'Take a short break and try again tomorrow.'
                              : 'Public reply failed: $e';
                          ScaffoldMessenger.of(
                            pageContext,
                          ).showSnackBar(SnackBar(content: Text(msg)));
                        }
                      }
                    },
                    child: const Text('Reply Public'),
                  ),
              ],
            );
          },
        );
      },
      child: HamsGlassCard(
        borderColor: !message.isRead
            ? HamsColors.primary.withOpacity(0.5)
            : null,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: message.senderType == 'anonymous'
                        ? HamsGradients.brand
                        : const LinearGradient(
                            colors: [HamsColors.accent, HamsColors.secondary],
                          ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    message.senderType == 'anonymous' ? '🎭' : '👤',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.senderType == 'anonymous'
                            ? 'Anonymous message'
                            : message.senderType,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _formatDate(message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!message.isRead)
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: HamsColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (message.replyType != null)
                  _MiniTag(
                    label: 'Replied (${message.replyType})',
                    color: HamsColors.success,
                  )
                else
                  const _MiniTag(label: 'New', color: HamsColors.primary),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).iconTheme.color?.withOpacity(0.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatDate(DateTime? dt) {
  if (dt == null) return '';
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $h:$m';
}
