import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_expense_tracker/services/prefs.dart';

void main() {
  test('prefs init reads daily budget', () async {
    SharedPreferences.setMockInitialValues({'daily_budget': 12345});
    await PrefsService.init();
    expect(PrefsService.dailyBudget.value, 12345);
  });

  test('setThemeMode persists and updates notifier', () async {
    SharedPreferences.setMockInitialValues({});
    await PrefsService.init();
    await PrefsService.setThemeMode(ThemeMode.dark);
    expect(PrefsService.themeMode.value, ThemeMode.dark);
  });
}
