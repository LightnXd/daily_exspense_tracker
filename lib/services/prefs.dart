import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static const _budgetKey = 'daily_budget';
  static const _themeKey = 'theme_mode';

  static final ValueNotifier<int> dailyBudget = ValueNotifier<int>(60000);
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.dark);

  static Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    final val = sp.getInt(_budgetKey) ?? 60000;
    dailyBudget.value = val;
    final t = sp.getString(_themeKey);
    if (t != null) {
      if (t == 'light') themeMode.value = ThemeMode.light;
      else if (t == 'dark') themeMode.value = ThemeMode.dark;
      else themeMode.value = ThemeMode.system;
    } else {
      // Default to dark mode if no user preference is stored
      themeMode.value = ThemeMode.dark;
    }
  }

  static Future<void> setDailyBudget(int value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_budgetKey, value);
    dailyBudget.value = value;
  }

  static Future<void> setThemeMode(ThemeMode m) async {
    final sp = await SharedPreferences.getInstance();
    final s = m == ThemeMode.light ? 'light' : m == ThemeMode.dark ? 'dark' : 'system';
    await sp.setString(_themeKey, s);
    themeMode.value = m;
  }

  static Future<int> getDailyBudget() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_budgetKey) ?? 60000;
  }
}
