import 'package:flutter/material.dart';

class AppTheme {
  static const double radius = 16;

  static ThemeData get light {
    final scheme = const ColorScheme.light(
      primary: HamsColors.primary,
      secondary: HamsColors.secondary,
      surface: Colors.white,
      error: HamsColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F9FF),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFFF7F9FF),
        foregroundColor: Color(0xFF0F172A),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = const ColorScheme.dark(
      primary: HamsColors.primary,
      secondary: HamsColors.secondary,
      surface: HamsColors.darkSurface,
      error: HamsColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: HamsColors.darkBg,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: HamsColors.darkBg,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: HamsColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HamsColors.darkSurface,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class HamsColors {
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF8B5CF6);
  static const Color secondary = Color(0xFFEC4899);
  static const Color accent = Color(0xFF22D3EE);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  static const Color darkBg = Color(0xFF0B1020);
  static const Color darkSurface = Color(0xFF151B2F);
  static const Color darkCard = Color(0xFF1A2140);
}

class HamsGradients {
  static const LinearGradient brand = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackground = LinearGradient(
    colors: [Color(0xFF0B1020), Color(0xFF101735), Color(0xFF161022)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient lightBackground = LinearGradient(
    colors: [Color(0xFFF8FAFF), Color(0xFFEFF3FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class HamsDecor {
  static BoxDecoration screenDecoration(Brightness brightness) {
    return BoxDecoration(
      gradient: brightness == Brightness.dark
          ? HamsGradients.darkBackground
          : HamsGradients.lightBackground,
    );
  }
}
