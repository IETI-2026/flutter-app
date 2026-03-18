import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const _key = 'theme_is_dark';
  final SharedPreferences _prefs;
  bool _isDark;

  ThemeService(SharedPreferences prefs)
      : _prefs = prefs,
        _isDark = prefs.getBool(_key) ?? false;

  bool get isDark => _isDark;
  ThemeMode get mode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> toggle() async {
    _isDark = !_isDark;
    await _prefs.setBool(_key, _isDark);
    notifyListeners();
  }
}
