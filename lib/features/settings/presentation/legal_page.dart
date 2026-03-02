import 'package:flutter/material.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.docType});

  final String docType;

  @override
  Widget build(BuildContext context) {
    final data = _docData(docType);
    return Scaffold(
      appBar: AppBar(title: Text(data.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            data.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...data.sections.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(s, style: const TextStyle(height: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocData {
  const _DocData({required this.title, required this.sections});
  final String title;
  final List<String> sections;
}

_DocData _docData(String type) {
  switch (type) {
    case 'terms':
      return const _DocData(
        title: 'Terms of Service',
        sections: [
          'By using Hams, you agree to follow platform rules and local laws.',
          'Do not post harmful, illegal, or abusive content.',
          'Accounts may be moderated, hidden, suspended, or banned for violations.',
          'Features may change over time to improve safety and reliability.',
        ],
      );
    case 'privacy':
      return const _DocData(
        title: 'Privacy Policy',
        sections: [
          'We store profile, messages, social interactions, and moderation data needed for app operation.',
          'We use Firebase services for authentication, database, and crash diagnostics.',
          'We do not sell personal data.',
          'You can request account deletion through support workflow when available.',
        ],
      );
    case 'guidelines':
      return const _DocData(
        title: 'Community Guidelines',
        sections: [
          'Be respectful. Harassment, hate, and threats are not allowed.',
          'Do not spam, impersonate, or abuse reporting systems.',
          'Use private communication responsibly and report abuse when needed.',
          'Repeated violations may result in content removal or account ban.',
        ],
      );
    case 'update-help':
      return const _DocData(
        title: 'How to Update (APK)',
        sections: [
          'When a new version is available, the app will show an Update dialog.',
          'Tap Update to open APK download link.',
          'If prompted, enable "Install unknown apps" for your browser.',
          'Install the APK over current version to keep your data and account.',
        ],
      );
    default:
      return const _DocData(
        title: 'Policy',
        sections: ['Document not found.'],
      );
  }
}
