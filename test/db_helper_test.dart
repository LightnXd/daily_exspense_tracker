import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:daily_expense_tracker/services/db_helper.dart';
import 'package:daily_expense_tracker/models/daily_entry.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('upsert and get entry', () async {
    final db = DBHelper();
    final e = DailyEntry(date: DateTime(2026, 1, 10), breakfast: 100, lunch: 200, dinner: 300, snack: 400);
    await db.upsertEntry(e);
    final got = await db.getEntry(DateTime(2026, 1, 10));
    expect(got, isNotNull);
    expect(got!.sum(), e.sum());
  });
}
