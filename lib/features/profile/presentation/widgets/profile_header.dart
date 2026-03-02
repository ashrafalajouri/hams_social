import 'package:flutter/material.dart';

import '../../../store/domain/store_assets.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.username,
    required this.activeBannerId,
    required this.activeFrameId,
    required this.photoUrl,
  });

  final String username;
  final String? activeBannerId;
  final String? activeFrameId;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final bannerGradient = bannerGradientFor(activeBannerId);
    final frameColor = frameColorFor(activeFrameId);

    return Column(
      children: [
        Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: bannerGradient,
            color: bannerGradient == null ? Colors.grey.shade300 : null,
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '@$username',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(blurRadius: 8, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: Colors.grey.shade400,
              backgroundImage:
                  (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
              child: (photoUrl == null || photoUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            if (frameColor != null)
              IgnorePointer(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: frameColor,
                      width: 6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: frameColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
