import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../controllers/profile_providers.dart';

class CreateProfilePage extends ConsumerStatefulWidget {
  const CreateProfilePage({super.key});

  @override
  ConsumerState<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends ConsumerState<CreateProfilePage> {
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  final _bio = TextEditingController();
  String? _error;
  bool _loading = false;

  String _normalizeUsername(String v) {
    return v.trim().toLowerCase().replaceAll(' ', '');
  }

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final username = _normalizeUsername(_username.text);
      final displayName = _displayName.text.trim();

      if (username.isEmpty || displayName.isEmpty) {
        throw Exception('FILL_REQUIRED');
      }
      if (username.length < 3) {
        throw Exception('USERNAME_TOO_SHORT');
      }

      final repo = ref.read(profileRepositoryProvider);
      await repo.createProfile(
        uid: uid,
        username: username,
        displayName: displayName,
        bio: _bio.text.trim(),
      );

      if (mounted) context.pushReplacement(AppRoutes.profile);
    } catch (e) {
      setState(() {
        _error = e.toString().contains('USERNAME_TAKEN')
            ? 'Username is already taken'
            : 'Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixText: '@',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _displayName,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bio,
              decoration: const InputDecoration(labelText: 'Bio (optional)'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? 'Saving...' : 'Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
