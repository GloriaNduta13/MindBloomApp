import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeData _themeData;
  bool _isDarkMode;
  String _currentScheme = 'Lavender';

  ThemeProvider({bool isDarkMode = false})
      : _isDarkMode = isDarkMode,
        _themeData = isDarkMode
            ? FlexThemeData.dark(scheme: FlexScheme.mandyRed) 
            : FlexThemeData.light(scheme: FlexScheme.mandyRed);

  ThemeData get theme => _themeData;
  bool get isDarkMode => _isDarkMode;
  String get currentScheme => _currentScheme;

  void toggleDarkMode(bool value) {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    _themeData = _isDarkMode
        ? FlexThemeData.dark(scheme: _getScheme(_currentScheme))
        : FlexThemeData.light(scheme: _getScheme(_currentScheme));
    notifyListeners();
  }

  void setTheme(String schemeName, bool darkMode) {
    if (_currentScheme == schemeName && _isDarkMode == darkMode) return;
    _currentScheme = schemeName;
    _isDarkMode = darkMode;
    _themeData = _isDarkMode
        ? FlexThemeData.dark(scheme: _getScheme(schemeName))
        : FlexThemeData.light(scheme: _getScheme(schemeName));
    notifyListeners();
  }

  FlexScheme _getScheme(String name) {
    switch (name) {
      case 'Lavender':
        return FlexScheme.mandyRed;
      case 'Earthy':
        return FlexScheme.greenM3;
      case 'Charcoal':
        return FlexScheme.outerSpace;
      case 'Sunset':
        return FlexScheme.sakura;
      default:
        return FlexScheme.material;
    }
  }
}