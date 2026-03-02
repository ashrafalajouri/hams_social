import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appThemeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(
      ThemeModeController.new,
    );

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'app_theme_mode';
  bool _loaded = false;

  @override
  ThemeMode build() {
    if (!_loaded) {
      _loaded = true;
      _load();
    }
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    state = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_key, raw);
  }
}
