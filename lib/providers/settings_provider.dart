import 'package:flutter/material.dart';

import '../core/currency_helper.dart';
import '../core/theme/app_theme.dart';

enum ThemeModeOption { system, light, dark }

class SettingsProvider extends ChangeNotifier {
  ThemeModeOption _themeMode = ThemeModeOption.system;
  CurrencyCode _currency = CurrencyCode.usd;

  ThemeModeOption get themeMode => _themeMode;
  CurrencyCode get currency => _currency;

  ThemeData get themeData {
    switch (_themeMode) {
      case ThemeModeOption.light:
        return AppTheme.lightTheme;
      case ThemeModeOption.dark:
        return AppTheme.darkTheme;
      case ThemeModeOption.system:
        return AppTheme.lightTheme; // Will be overridden by builder
    }
  }

  Brightness get brightness {
    switch (_themeMode) {
      case ThemeModeOption.light:
        return Brightness.light;
      case ThemeModeOption.dark:
        return Brightness.dark;
      case ThemeModeOption.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  void setThemeMode(ThemeModeOption mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setCurrency(CurrencyCode code) {
    _currency = code;
    notifyListeners();
  }
}
