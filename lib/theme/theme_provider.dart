import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { knp, light, dark }

class ThemeNotifier extends ChangeNotifier {
  static const String _key = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.knp;

  AppThemeMode get mode => _mode;

  ThemeNotifier() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key) ?? 'knp';
    _mode = _fromString(value);
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _toString(mode));
  }

  AppThemeMode _fromString(String value) {
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      default:
        return AppThemeMode.knp;
    }
  }

  String _toString(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.knp:
        return 'knp';
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
    }
  }
}
