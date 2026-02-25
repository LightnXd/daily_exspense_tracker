# Daily Expense Tracker

A minimal Flutter app (Android) to track daily expenses: breakfast, lunch, dinner, snack.

Features
- Dashboard with date selector and inputs for 4 meal categories
- Daily budget (default 60,000) stored in SharedPreferences (editable)
- SQLite (sqflite) to persist daily entries
- Report page to view one month (day rows) with mean and totals
- Night mode

How to run
1. Install Flutter and Android SDK
2. Run `flutter pub get` inside the project
3. `flutter run -d <android-device>`

Notes
- The daily budget is stored in SharedPreferences (so not in DB), default is 60000.
- Numbers are formatted with commas and negative left-balance is supported.

App name and icons
- App name set to **Food Expense**.
- To use your icon: add `assets/logo.png` and run `flutter pub run flutter_launcher_icons:main` to generate platform icons.
