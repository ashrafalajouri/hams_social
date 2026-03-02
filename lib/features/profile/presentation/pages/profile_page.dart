import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/hams_ui.dart';
import '../../../../firebase/firestore_paths.dart';
import '../../../gamification/domain/badges.dart';
import '../../../gamification/domain/xp_rules.dart';
import '../../../messages/presentation/controllers/messages_providers.dart';
import '../../../safety/domain/trust_policy.dart';
import '../controllers/profile_providers.dart';
import '../widgets/profile_header.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Future.microtask(() => context.go(AppRoutes.signIn));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final repo = ref.watch(profileRepositoryProvider);

    return FutureBuilder<Map<String, dynamic>?>(
      future: repo.getProfile(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final data = snapshot.data;

        final username = (data?['username'] as String?)?.trim();
        final displayName = (data?['displayName'] as String?)?.trim();
        final bio = (data?['bio'] as String?)?.trim();
        final photoUrl = (data?['photoUrl'] as String?)?.trim();
        final viewsCount = (data?['viewsCount'] as int?) ?? 0;
        final xp = (data?['xp'] as int?) ?? 0;
        final level = XpRules.levelFromXp(xp);
        final totalLikes = (data?['totalLikes'] as int?) ?? 0;
        final publicReplies = (data?['publicReplies'] as int?) ?? 0;
        final messagesReceived = (data?['messagesReceived'] as int?) ?? 0;
        final reputationScore = ((data?['reputationScore'] ?? 100) as num)
            .toInt();
        final trustLevel = TrustPolicy.levelFromScore(reputationScore);
        final badges = ((data?['badges'] as List?) ?? [])
            .map((e) => e.toString())
            .toList();
        final store = (data?['store'] as Map?)?.cast<String, dynamic>() ?? {};
        final active = (store['active'] as Map?)?.cast<String, dynamic>() ?? {};
        final activeBanner = active['banner'] as String?;
        final activeFrame = active['frame'] as String?;
        final levelStartXp = (level - 1) * 200;
        final nextLevelXp = level * 200;
        final progress = nextLevelXp <= levelStartXp
            ? 0.0
            : ((xp - levelStartXp) / (nextLevelXp - levelStartXp))
                  .clamp(0.0, 1.0)
                  .toDouble();

        if (username == null || username.isEmpty) {
          Future.microtask(() => context.go(AppRoutes.createProfile));
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('الملف الشخصي'),
            actions: [
              IconButton(
                onPressed: () => context.push(AppRoutes.notifications),
                icon: const Icon(Icons.notifications_rounded),
              ),
              IconButton(
                onPressed: () => context.push(AppRoutes.settings),
                icon: const Icon(Icons.settings_rounded),
              ),
              IconButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) context.go(AppRoutes.signIn);
                },
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: HamsScreenBackground(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HamsGlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileHeader(
                          username: username,
                          activeBannerId: activeBanner,
                          activeFrameId: activeFrame,
                          photoUrl: photoUrl,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          displayName ?? 'No name',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '@$username',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(0.75),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoChip(
                              icon: Icons.shield_rounded,
                              label: 'Trust $trustLevel',
                              color: HamsColors.accent,
                            ),
                            _InfoChip(
                              icon: Icons.workspace_premium_rounded,
                              label: 'Rep $reputationScore',
                              color: HamsColors.warning,
                            ),
                            _InfoChip(
                              icon: Icons.favorite_rounded,
                              label: '$totalLikes Likes',
                              color: HamsColors.secondary,
                            ),
                          ],
                        ),
                        if (bio != null && bio.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            bio,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: 12),
                        HamsGradientButton(
                          label: 'Open Public Profile',
                          icon: Icons.open_in_new_rounded,
                          onPressed: () => context.push('/u/$username'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final link = 'https://hams.social/@$username';
                            await Clipboard.setData(ClipboardData(text: link));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profile link copied')),
                            );
                          },
                          icon: const Icon(Icons.link_rounded),
                          label: const Text('Copy profile link'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: HamsStatPill(
                          label: 'Views',
                          value: '$viewsCount',
                          icon: Icons.visibility_rounded,
                          color: HamsColors.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: HamsStatPill(
                          label: 'Msgs',
                          value: '$messagesReceived',
                          icon: Icons.mail_rounded,
                          color: HamsColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: HamsStatPill(
                          label: 'Replies',
                          value: '$publicReplies',
                          icon: Icons.reply_rounded,
                          color: HamsColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  HamsGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const HamsSectionTitle(title: 'التقدم والنقاط'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: HamsGradients.brand,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Level $level',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text('$xp / $nextLevelXp XP'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 9,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            color: HamsColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (badges.isNotEmpty)
                    HamsGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const HamsSectionTitle(title: 'الشارات'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: badges.map<Widget>((badgeId) {
                              final badge = Badges.badgeMap[badgeId];
                              return _InfoChip(
                                icon: Icons.auto_awesome_rounded,
                                label: badge?.title ?? badgeId,
                                color: HamsColors.primaryLight,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  HamsGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const HamsSectionTitle(title: 'التنقل السريع'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _RouteChip(
                              label: 'Inbox',
                              icon: Icons.inbox_rounded,
                              onTap: () => context.push(AppRoutes.inbox),
                            ),
                            _RouteChip(
                              label: 'Daily Missions',
                              icon: Icons.flag_circle_rounded,
                              onTap: () =>
                                  context.push(AppRoutes.dailyMissions),
                            ),
                            _RouteChip(
                              label: 'Store',
                              icon: Icons.storefront_rounded,
                              onTap: () => context.push(AppRoutes.store),
                            ),
                            _RouteChip(
                              label: 'Chats',
                              icon: Icons.chat_rounded,
                              onTap: () => context.push(AppRoutes.chats),
                            ),
                            _RouteChip(
                              label: 'Friends',
                              icon: Icons.people_alt_rounded,
                              onTap: () => context.push(AppRoutes.friends),
                            ),
                            _RouteChip(
                              label: 'Discover',
                              icon: Icons.explore_rounded,
                              onTap: () => context.push(AppRoutes.discover),
                            ),
                            _RouteChip(
                              label: 'Notifications',
                              icon: Icons.notifications_rounded,
                              onTap: () =>
                                  context.push(AppRoutes.notifications),
                            ),
                            _RouteChip(
                              label: 'Blocked',
                              icon: Icons.block_rounded,
                              onTap: () => context.push(AppRoutes.blocked),
                            ),
                            _RouteChip(
                              label: 'Settings',
                              icon: Icons.settings_rounded,
                              onTap: () => context.push(AppRoutes.settings),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<bool>(
                    future: FirebaseFirestore.instance
                        .collection(FirestorePaths.config)
                        .doc(FirestorePaths.admins)
                        .get()
                        .then((snap) {
                          final uids =
                              (snap.data()?['uids'] as Map?)
                                  ?.cast<String, dynamic>() ??
                              const <String, dynamic>{};
                          return uids[user.uid] == true;
                        }),
                    builder: (context, adminSnap) {
                      final isAdmin = adminSnap.data ?? false;
                      if (!isAdmin) return const SizedBox.shrink();
                      return HamsGlassCard(
                        borderColor: HamsColors.warning.withOpacity(0.4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const HamsSectionTitle(title: 'Admin'),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  context.push(AppRoutes.adminReports),
                              icon: const Icon(Icons.report_rounded),
                              label: const Text('Admin Reports'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  context.push(AppRoutes.adminDashboard),
                              icon: const Icon(Icons.dashboard_rounded),
                              label: const Text('Admin Dashboard'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  HamsGradientButton(
                    label: 'Open Token Test',
                    icon: Icons.bug_report_rounded,
                    onPressed: () {
                      final token = ref.read(lastMessageTokenProvider);
                      if (token == null || token.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No token yet')),
                        );
                        return;
                      }
                      context.push('/m/$token');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? HamsColors.darkSurface.withOpacity(0.8)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HamsColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: HamsColors.primary),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
