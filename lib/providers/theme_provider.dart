import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // Clé pour stocker la préférence dans SharedPreferences
  static const String _themeKey = 'is_dark_mode';

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  // Charger le thème sauvegardé depuis SharedPreferences
  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }

  // Sauvegarder le thème dans SharedPreferences
  Future<void> _saveThemeToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
  }

  // Basculer entre mode clair et sombre
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveThemeToPrefs();
    notifyListeners();
  }

  // Définir explicitement un mode
  void setDarkMode(bool value) {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      _saveThemeToPrefs();
      notifyListeners();
    }
  }

  // Obtenir le ThemeMode actuel pour MaterialApp
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
}
