import 'package:flutter/material.dart';

Gradient? bannerGradientFor(String? bannerId) {
  switch (bannerId) {
    case 'banner_sky':
      return const LinearGradient(
        colors: [Color(0xFF66B3FF), Color(0xFFB3E5FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    case 'banner_dark':
      return const LinearGradient(
        colors: [Color(0xFF222222), Color(0xFF555555)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    default:
      return null;
  }
}

Color? frameColorFor(String? frameId) {
  switch (frameId) {
    case 'frame_gold':
      return const Color(0xFFFFD54F);
    case 'frame_neon':
      return const Color(0xFF00E5FF);
    default:
      return null;
  }
}
