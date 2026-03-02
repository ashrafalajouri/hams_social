import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MessageFollowUpPage extends StatelessWidget {
  const MessageFollowUpPage({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection('message_links').doc(token);

    return Scaffold(
      appBar: AppBar(title: const Text('Reply Link')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: docRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final doc = snapshot.data;
          if (doc == null || !doc.exists) {
            return const Center(child: Text('Invalid or expired link'));
          }

          final data = doc.data()!;
          final text = (data['text'] ?? '') as String;
          final toUsername = (data['toUsername'] ?? '') as String;

          final replyType = data['replyType'] as String?;
          final replyText = data['replyText'] as String?;

          final hasReply =
              replyType == 'private' && replyText != null && replyText.trim().isNotEmpty;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sent to @$toUsername',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your message:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Text(text),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Private reply:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                if (!hasReply)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: const Text('No reply yet. Check again later.'),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Text(replyText.trim()),
                  ),
                const Spacer(),
                Text(
                  'Tip: Save this link. Anyone who has it can view this page.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
