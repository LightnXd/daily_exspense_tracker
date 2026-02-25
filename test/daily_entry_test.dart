import 'package:flutter_test/flutter_test.dart';
import 'package:daily_expense_tracker/models/daily_entry.dart';

void main() {
  test('sum computes correctly with nulls', () {
    final e = DailyEntry(date: DateTime(2026, 1, 1), breakfast: 1000, lunch: null, dinner: 2000, snack: null);
    expect(e.sum(), 3000);
  });

  test('toMap and fromMap roundtrip', () {
    final e = DailyEntry(date: DateTime(2026, 1, 2), breakfast: 100, lunch: 200, dinner: 300, snack: 400);
    final m = e.toMap();
    final e2 = DailyEntry.fromMap(m);
    expect(e2.sum(), e.sum());
    expect(e2.date.year, e.date.year);
  });
}
