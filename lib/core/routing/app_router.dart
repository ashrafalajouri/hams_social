import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_dashboard_page.dart';
import '../../features/auth/data/user_bootstrap.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/banned_page.dart';
import '../../features/auth/presentation/onboarding_page.dart';
import '../../features/chat/presentation/pages/chat_list_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/feed/presentation/pages/discover_page.dart';
import '../../features/friends/presentation/pages/friends_page.dart';
import '../../features/gamification/presentation/pages/daily_missions_page.dart';
import '../../features/home/presentation/pages/home_shell_page.dart';
import '../../features/messages/presentation/pages/inbox_page.dart';
import '../../features/messages/presentation/pages/message_follow_up_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/create_profile_page.dart';
import '../../features/profile/presentation/controllers/profile_providers.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/public_profile_page.dart';
import 'package:hams_social/features/safety/presentation/pages/admin_moderation_page.dart';
import '../../features/safety/presentation/pages/blocked_users_page.dart';
import '../../features/store/presentation/pages/store_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/legal_page.dart';

class AppRoutes {
  static const appGate = '/';
  static const signIn = '/signin';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const profile = '/profile';
  static const createProfile = '/create-profile';
  static const publicProfile = '/u/:username';
  static const inbox = '/inbox';
  static const followUp = '/m/:token';
  static const dailyMissions = '/daily-missions';
  static const store = '/store';
  static const friends = '/friends';
  static const chat = '/chat/:chatId';
  static const chats = '/chats';
  static const blocked = '/blocked';
  static const notifications = '/notifications';
  static const discover = '/discover';
  static const adminReports = '/admin/reports';
  static const adminDashboard = '/admin/dashboard';
  static const banned = '/banned';
  static const settings = '/settings';
  static const legal = '/legal/:docType';
}

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.appGate,
      builder: (context, state) => const _AppGatePage(),
    ),
    GoRoute(
      path: AppRoutes.signIn,
      builder: (context, state) => const _SignInPage(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeShellPage(),
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: AppRoutes.createProfile,
      builder: (context, state) => const CreateProfilePage(),
    ),
    GoRoute(
      path: AppRoutes.inbox,
      builder: (context, state) => const InboxPage(),
    ),
    GoRoute(
      path: AppRoutes.dailyMissions,
      builder: (context, state) => const DailyMissionsPage(),
    ),
    GoRoute(
      path: AppRoutes.store,
      builder: (context, state) => const StorePage(),
    ),
    GoRoute(
      path: AppRoutes.friends,
      builder: (context, state) => const FriendsPage(),
    ),
    GoRoute(
      path: AppRoutes.chats,
      builder: (context, state) => const ChatListPage(),
    ),
    GoRoute(
      path: AppRoutes.chat,
      builder: (context, state) {
        final chatId = state.pathParameters['chatId'] ?? '';
        final otherUid = state.uri.queryParameters['otherUid'] ?? '';
        final otherUsername =
            state.uri.queryParameters['otherUsername'] ?? 'Chat';
        return ChatPage(
          chatId: chatId,
          otherUid: otherUid,
          otherUsername: otherUsername,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.blocked,
      builder: (context, state) => const BlockedUsersPage(),
    ),
    GoRoute(
      path: AppRoutes.notifications,
      builder: (context, state) => const NotificationsPage(),
    ),
    GoRoute(
      path: AppRoutes.discover,
      builder: (context, state) => const DiscoverPage(),
    ),
    GoRoute(
      path: AppRoutes.adminReports,
      builder: (context, state) => const AdminReportsPage(),
    ),
    GoRoute(
      path: AppRoutes.adminDashboard,
      builder: (context, state) => const AdminDashboardPage(),
    ),
    GoRoute(
      path: AppRoutes.banned,
      builder: (context, state) => const BannedPage(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: AppRoutes.legal,
      builder: (context, state) {
        final type = state.pathParameters['docType'] ?? '';
        return LegalPage(docType: type);
      },
    ),
    GoRoute(
      path: '/m/:token',
      builder: (context, state) {
        final token = state.pathParameters['token']!;
        return MessageFollowUpPage(token: token);
      },
    ),
    GoRoute(
      path: AppRoutes.publicProfile,
      builder: (context, state) {
        final username = state.pathParameters['username']!;
        return PublicProfilePage(username: username);
      },
    ),
  ],
);

class _AppGatePage extends ConsumerWidget {
  const _AppGatePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          Future.microtask(() async {
            await ensureUserDefaults();
            await ref
                .read(profileRepositoryProvider)
                .ensureUserDoc(uid: user.uid);
            final profile = await ref
                .read(profileRepositoryProvider)
                .getProfile(user.uid);
            final status = (profile?['accountStatus'] ?? 'active') as String;
            final onboardingDone = profile?['onboardingDone'] == true;
            if (!context.mounted) return;
            if (status == 'banned') {
              context.go(AppRoutes.banned);
            } else if (!onboardingDone) {
              context.go(AppRoutes.onboarding);
            } else {
              context.go(AppRoutes.home);
            }
          });
        } else {
          Future.microtask(() => context.go(AppRoutes.signIn));
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _SignInPage extends ConsumerWidget {
  const _SignInPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await FirebaseAuth.instance.signInAnonymously();
            if (context.mounted) {
              context.go(AppRoutes.appGate);
            }
          },
          child: const Text('Continue (Anonymous)'),
        ),
      ),
    );
  }
}
