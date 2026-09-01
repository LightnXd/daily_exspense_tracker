import 'package:flutter_test/flutter_test.dart';
import 'package:daily_expense_tracker/models/daily_entry.dart';
import 'package:daily_expense_tracker/models/grand_purchase.dart';

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

  test('toJson and fromJson roundtrip', () {
    final e = DailyEntry(date: DateTime(2026, 1, 3), breakfast: 100, lunch: null, dinner: 300, snack: 400);
    final json = e.toJson();
    final e2 = DailyEntry.fromJson(json);
    expect(e2.sum(), e.sum());
    expect(e2.date.toIso8601String().split('T').first, '2026-01-03');
  });

  test('grand purchase json roundtrip preserves important fields', () async {
    final p = GrandPurchase(
      id: 7,
      typeId: 3,
      typeName: 'sanitation',
      name: 'Cleaning',
      color: 'blue',
      price: 42.5,
      date: DateTime(2026, 1, 4),
      desc: 'weekly',
    );

    final payload = p.toJson();
    final decoded = GrandPurchase.fromJson(payload);

    expect(decoded.typeId, p.typeId);
    expect(decoded.type, p.type);
    expect(decoded.name, p.name);
    expect(decoded.color, p.color);
    expect(decoded.price, p.price);
    expect(decoded.date.toIso8601String().split('T').first, '2026-01-04');
    expect(decoded.desc, p.desc);
  });
}
