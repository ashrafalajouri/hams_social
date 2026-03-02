import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_provider.dart';
import '../../../firebase/firestore_paths.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final userRef = FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(me.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data() ?? <String, dynamic>{};
          final settings = (data['settings'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
          final allowAnonymous = settings['allowAnonymous'] != false;
          final friendsOnly = settings['friendsOnly'] == true;
          final showViews = settings['showViews'] != false;
          final showLastSeen = settings['showLastSeen'] != false;

          Future<void> setSetting(String key, dynamic value) async {
            await userRef.set({
              'settings': {key: value},
            }, SetOptions(merge: true));
          }

          final mode = ref.watch(appThemeModeProvider);

          return ListView(
            children: [
              const ListTile(title: Text('Privacy')),
              SwitchListTile(
                title: const Text('Allow anonymous messages'),
                value: allowAnonymous,
                onChanged: (v) => setSetting('allowAnonymous', v),
              ),
              SwitchListTile(
                title: const Text('Friends only interactions'),
                value: friendsOnly,
                onChanged: (v) => setSetting('friendsOnly', v),
              ),
              SwitchListTile(
                title: const Text('Show profile views'),
                value: showViews,
                onChanged: (v) => setSetting('showViews', v),
              ),
              SwitchListTile(
                title: const Text('Show last seen'),
                value: showLastSeen,
                onChanged: (v) => setSetting('showLastSeen', v),
              ),
              const Divider(),
              const ListTile(title: Text('Theme')),
              RadioListTile<ThemeMode>(
                title: const Text('System'),
                value: ThemeMode.system,
                groupValue: mode,
                onChanged: (v) async {
                  if (v == null) return;
                  await ref.read(appThemeModeProvider.notifier).setMode(v);
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Light'),
                value: ThemeMode.light,
                groupValue: mode,
                onChanged: (v) async {
                  if (v == null) return;
                  await ref.read(appThemeModeProvider.notifier).setMode(v);
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Dark'),
                value: ThemeMode.dark,
                groupValue: mode,
                onChanged: (v) async {
                  if (v == null) return;
                  await ref.read(appThemeModeProvider.notifier).setMode(v);
                },
              ),
              const Divider(),
              const ListTile(title: Text('Legal & Safety')),
              ListTile(
                leading: const Icon(Icons.gavel_rounded),
                title: const Text('Terms of Service'),
                onTap: () => context.push('/legal/terms'),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                onTap: () => context.push('/legal/privacy'),
              ),
              ListTile(
                leading: const Icon(Icons.rule_folder_outlined),
                title: const Text('Community Guidelines'),
                onTap: () => context.push('/legal/guidelines'),
              ),
              ListTile(
                leading: const Icon(Icons.system_update_alt_rounded),
                title: const Text('How to update (APK)'),
                onTap: () => context.push('/legal/update-help'),
              ),
              if (kDebugMode) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.bug_report_rounded),
                  title: const Text('Test Crashlytics Crash'),
                  subtitle: const Text('Debug only'),
                  onTap: () {
                    FirebaseCrashlytics.instance.crash();
                  },
                ),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Logout'),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
