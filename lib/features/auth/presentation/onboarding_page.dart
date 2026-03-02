import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../firebase/firestore_paths.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _saving = false;

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      icon: Icons.forum_rounded,
      title: 'Whispers, honestly',
      subtitle: 'Send anonymous or named messages. You choose.',
    ),
    _OnboardingItem(
      icon: Icons.reply_all_rounded,
      title: 'Reply your way',
      subtitle: 'Reply privately or publish as a post on your profile.',
    ),
    _OnboardingItem(
      icon: Icons.auto_awesome_rounded,
      title: 'Play & Customize',
      subtitle: 'Earn points, unlock frames, banners, themes.',
    ),
  ];

  Future<void> _finish() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      context.go(AppRoutes.signIn);
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(user.uid)
          .set({'onboardingDone': true}, SetOptions(merge: true));
      if (!mounted) return;
      context.go(AppRoutes.home);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _items.length - 1;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _items.length,
                onPageChanged: (v) => setState(() => _index = v),
                itemBuilder: (_, i) {
                  final item = _items[i];
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 42,
                          child: Icon(item.icon, size: 42),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      _items.length,
                      (i) => Container(
                        margin: const EdgeInsets.only(left: 6),
                        width: i == _index ? 18 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: i == _index
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.primary.withOpacity(0.25),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            if (last) {
                              await _finish();
                              return;
                            }
                            await _controller.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          },
                    child: Text(last ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}
