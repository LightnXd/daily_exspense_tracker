# Daily Expense Tracker

A minimal Flutter app (Android) to track daily expenses: breakfast, lunch, dinner, snack.

Features
- Dashboard with date selector and inputs for 4 meal categories
- Daily budget (default 60,000) stored in SharedPreferences (editable)
- SQLite (sqflite) to persist daily entries
- Report page to view one month (day rows) with mean and totals
- Exspense tracker other types of exspense beside of daily food and drink are now supported and.
- Report page now included other purchases with total calculation for each category and total exspense in a month.
- Night mode

How to run
1. Install Flutter and Android SDK
2. Run `flutter pub get` inside the project
3. `flutter run -d <android-device>`

Future plans:
- Make type categorization customizeable
- Add customized repetitive exspense for quick report addition
