import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppThemes {
  static ThemeData themeFor(String? themeId) {
    switch (themeId) {
      case 'theme_midnight':
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          primaryColor: HamsColors.primary,
          scaffoldBackgroundColor: HamsColors.darkBg,
          colorScheme: const ColorScheme.dark(
            primary: HamsColors.primary,
            secondary: HamsColors.secondary,
            surface: HamsColors.darkSurface,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: HamsColors.darkBg,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          cardTheme: CardThemeData(
            color: HamsColors.darkCard,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: HamsColors.darkSurface,
            side: BorderSide(color: Colors.white.withOpacity(0.12)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: HamsColors.darkSurface,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: HamsColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );

      case 'theme_classic':
      default:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          primaryColor: const Color(0xFF1D4ED8),
          scaffoldBackgroundColor: const Color(0xFFF8FAFF),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1D4ED8),
            secondary: Color(0xFFEA580C),
            surface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF8FAFF),
            foregroundColor: Color(0xFF0F172A),
            elevation: 0,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.black.withOpacity(0.06)),
            ),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: const Color(0xFFF1F5F9),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
    }
  }
}
