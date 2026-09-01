import 'package:flutter_test/flutter_test.dart';
import 'package:daily_expense_tracker/models/grand_purchase.dart';
import 'package:daily_expense_tracker/models/purchase_type.dart';
import 'package:daily_expense_tracker/utils/purchase_display.dart';

void main() {
  test('purchaseDisplayName includes color when type uses color', () {
    final type = PurchaseType(name: 'sanitation', useColor: true);
    final p = GrandPurchase(
      typeId: 1,
      name: 'Soap',
      color: 'blue',
      price: 10,
      date: DateTime(2026, 1, 1),
    );
    expect(purchaseDisplayName(p, type), 'Soap - blue');
  });

  test('purchaseDisplayName omits color when type does not use color', () {
    final type = PurchaseType(name: 'food&drink');
    final p = GrandPurchase(
      typeId: 1,
      name: 'Coffee',
      color: 'red',
      price: 5,
      date: DateTime(2026, 1, 1),
    );
    expect(purchaseDisplayName(p, type), 'Coffee');
  });
}
