import 'package:cloud_firestore/cloud_firestore.dart';

class InboxMessage {
  InboxMessage({
    required this.id,
    required this.text,
    required this.senderType,
    required this.isRead,
    required this.status,
    required this.createdAt,
    required this.toUsername,
    required this.replyType,
    required this.replyText,
  });

  final String id;
  final String text;
  final String senderType;
  final bool isRead;
  final String status;
  final DateTime? createdAt;
  final String toUsername;
  final String? replyType;
  final String? replyText;

  factory InboxMessage.fromDoc(String id, Map<String, dynamic> data) {
    return InboxMessage(
      id: id,
      text: (data['text'] ?? '') as String,
      senderType: (data['senderType'] ?? 'anonymous') as String,
      isRead: (data['isRead'] ?? false) as bool,
      status: (data['status'] ?? 'active') as String,
      toUsername: (data['toUsername'] ?? '') as String,
      replyType: data['replyType'] as String?,
      replyText: data['replyText'] as String?,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
