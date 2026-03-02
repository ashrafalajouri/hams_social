import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/hams_ui.dart';
import '../../../../firebase/firestore_paths.dart';
import '../../domain/store_catalog.dart';
import '../store_providers.dart';

class StorePage extends ConsumerWidget {
  const StorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final userStream = FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        title: const Text('المتجر'),
      ),
      body: HamsScreenBackground(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userStream,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snap.data!.data() ?? {};
            final coins = (data['coins'] ?? 0) as int;

            final store =
                (data['store'] as Map?)?.cast<String, dynamic>() ?? {};
            final owned =
                (store['owned'] as Map?)?.cast<String, dynamic>() ?? {};
            final active =
                (store['active'] as Map?)?.cast<String, dynamic>() ?? {};

            final ownedFrames =
                (owned['frames'] as List?)?.cast<String>() ?? [];
            final ownedBanners =
                (owned['banners'] as List?)?.cast<String>() ?? [];
            final ownedThemes =
                (owned['themes'] as List?)?.cast<String>() ?? [];

            final activeFrame = active['frame'] as String?;
            final activeBanner = active['banner'] as String?;
            final activeTheme = active['theme'] as String?;

            bool isOwned(StoreItem item) {
              if (item.type == 'frame') return ownedFrames.contains(item.id);
              if (item.type == 'banner') return ownedBanners.contains(item.id);
              return ownedThemes.contains(item.id);
            }

            bool isActive(StoreItem item) {
              if (item.type == 'frame') return activeFrame == item.id;
              if (item.type == 'banner') return activeBanner == item.id;
              return activeTheme == item.id;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              children: [
                HamsGlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: HamsGradients.brand,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.monetization_on_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Coins: $coins',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...StoreCatalog.items.map((item) {
                  final ownedNow = isOwned(item);
                  final activeNow = isActive(item);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: HamsGlassCard(
                      borderColor: activeNow
                          ? HamsColors.success.withOpacity(0.45)
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                '${item.price}c',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: HamsColors.warning,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.description,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color?.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: HamsColors.accent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.type.toUpperCase(),
                                  style: const TextStyle(
                                    color: HamsColors.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (!ownedNow)
                                HamsGradientButton(
                                  label: 'Buy',
                                  icon: Icons.shopping_bag_outlined,
                                  height: 40,
                                  onPressed: () async {
                                    try {
                                      await ref
                                          .read(storeRepositoryProvider)
                                          .buyItem(
                                            uid: user.uid,
                                            type: item.type,
                                            itemId: item.id,
                                            price: item.price,
                                          );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Purchased ✅'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('$e')),
                                        );
                                      }
                                    }
                                  },
                                )
                              else
                                FilledButton.tonalIcon(
                                  onPressed: activeNow
                                      ? null
                                      : () async {
                                          try {
                                            await ref
                                                .read(storeRepositoryProvider)
                                                .activateItem(
                                                  uid: user.uid,
                                                  type: item.type,
                                                  itemId: item.id,
                                                );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Activated ✅'),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(content: Text('$e')),
                                              );
                                            }
                                          }
                                        },
                                  icon: Icon(
                                    activeNow
                                        ? Icons.check_circle_rounded
                                        : Icons.bolt_rounded,
                                  ),
                                  label: Text(
                                    activeNow ? 'Active' : 'Activate',
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
