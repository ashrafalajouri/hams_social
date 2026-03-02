import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/hams_ui.dart';
import '../../../../firebase/firestore_paths.dart';
import '../daily_missions_providers.dart';

class DailyMissionsPage extends ConsumerStatefulWidget {
  const DailyMissionsPage({super.key});

  @override
  ConsumerState<DailyMissionsPage> createState() => _DailyMissionsPageState();
}

class _DailyMissionsPageState extends ConsumerState<DailyMissionsPage> {
  bool _ensured = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    if (!_ensured) {
      _ensured = true;
      Future.microtask(
        () => ref.read(dailyMissionsRepositoryProvider).ensureToday(user.uid),
      );
    }

    final userDocStream = FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        title: const Text('المهام اليومية'),
      ),
      body: HamsScreenBackground(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userDocStream,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snap.data!.data() ?? {};
            final coins = (data['coins'] ?? 0) as int;
            final daily =
                (data['daily'] as Map?)?.cast<String, dynamic>() ?? {};
            final claimed =
                (daily['claimed'] as Map?)?.cast<String, dynamic>() ?? {};

            final recvMsg = (daily['recvMsg'] ?? 0) as int;
            final pubReply = (daily['pubReply'] ?? 0) as int;
            final likesGiven = (daily['likesGiven'] ?? 0) as int;

            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              children: [
                HamsGlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: HamsGradients.brand,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'رصيدك الحالي',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Coins: $coins',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _MissionTile(
                  title: 'Receive 1 message',
                  subtitle: 'Progress: $recvMsg / 1',
                  reward: '+10 coins',
                  done: recvMsg >= 1,
                  claimed: claimed['m1'] == true,
                  onClaim: () => ref
                      .read(dailyMissionsRepositoryProvider)
                      .claimMission(uid: user.uid, missionId: 'm1'),
                ),
                _MissionTile(
                  title: 'Post 1 public reply',
                  subtitle: 'Progress: $pubReply / 1',
                  reward: '+15 coins',
                  done: pubReply >= 1,
                  claimed: claimed['m2'] == true,
                  onClaim: () => ref
                      .read(dailyMissionsRepositoryProvider)
                      .claimMission(uid: user.uid, missionId: 'm2'),
                ),
                _MissionTile(
                  title: 'Like 3 posts',
                  subtitle: 'Progress: $likesGiven / 3',
                  reward: '+5 coins',
                  done: likesGiven >= 3,
                  claimed: claimed['m3'] == true,
                  onClaim: () => ref
                      .read(dailyMissionsRepositoryProvider)
                      .claimMission(uid: user.uid, missionId: 'm3'),
                ),
                const SizedBox(height: 8),
                HamsGlassCard(
                  child: Text(
                    'Tip: Missions reset daily based on your device date.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.85),
                    ),
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

class _MissionTile extends StatelessWidget {
  const _MissionTile({
    required this.title,
    required this.subtitle,
    required this.reward,
    required this.done,
    required this.claimed,
    required this.onClaim,
  });

  final String title;
  final String subtitle;
  final String reward;
  final bool done;
  final bool claimed;
  final Future<void> Function() onClaim;

  @override
  Widget build(BuildContext context) {
    final canClaim = done && !claimed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HamsGlassCard(
        borderColor: claimed ? HamsColors.success.withOpacity(0.45) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  reward,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: HamsColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (claimed)
                  const _StateChip(label: 'Claimed', color: HamsColors.success)
                else if (done)
                  const _StateChip(label: 'Done', color: HamsColors.accent)
                else
                  const _StateChip(
                    label: 'In progress',
                    color: HamsColors.primary,
                  ),
                const Spacer(),
                HamsGradientButton(
                  label: 'Claim',
                  icon: Icons.card_giftcard_rounded,
                  onPressed: canClaim
                      ? () async {
                          await onClaim();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Claimed ✅')),
                            );
                          }
                        }
                      : null,
                  height: 40,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
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
