import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/config/remote_config_service.dart';
import '../../../../core/update/update_dialog.dart';
import '../../../../core/update/update_service.dart';
import '../../../chat/presentation/pages/chat_list_page.dart';
import '../../../feed/presentation/pages/discover_page.dart';
import '../../../friends/presentation/pages/friends_page.dart';
import '../../../messages/presentation/pages/inbox_page.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../notifications/presentation/notifications_providers.dart';
import '../../../profile/presentation/pages/profile_page.dart';

class HomeShellPage extends ConsumerStatefulWidget {
  const HomeShellPage({super.key});

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage> {
  int _index = 0;
  bool _updateChecked = false;

  static const _tabs = <Widget>[
    DiscoverPage(),
    InboxPage(),
    FriendsPage(),
    ChatListPage(),
    NotificationsPage(),
    ProfilePage(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_updateChecked) return;
    _updateChecked = true;
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final versionJsonUrl = RemoteConfigService.instance.versionJsonUrl;
    if (versionJsonUrl.isEmpty) return;

    final service = UpdateService(versionJsonUrl: versionJsonUrl);
    try {
      final latest = await service.fetchLatest();
      if (latest == null) return;
      final hasUpdate = await service.isUpdateAvailable(latest);
      if (!hasUpdate || !mounted) return;
      final force = await service.isForceUpdate(latest);
      if (!mounted) return;
      await showUpdateDialog(
        context: context,
        info: latest,
        force: force,
        onUpdate: () => service.openApkUrl(latest.apkUrl),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    final unreadStream = me == null
        ? const Stream<int>.empty()
        : ref.read(notificationsRepositoryProvider).watchUnreadCount(me.uid);

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          const NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Inbox',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Friends',
          ),
          const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: StreamBuilder<int>(
              stream: unreadStream,
              builder: (_, snap) {
                final count = snap.data ?? 0;
                if (count <= 0) {
                  return const Icon(Icons.notifications_none_rounded);
                }
                return Badge(
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: const Icon(Icons.notifications_none_rounded),
                );
              },
            ),
            selectedIcon: StreamBuilder<int>(
              stream: unreadStream,
              builder: (_, snap) {
                final count = snap.data ?? 0;
                if (count <= 0) return const Icon(Icons.notifications_rounded);
                return Badge(
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: const Icon(Icons.notifications_rounded),
                );
              },
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
