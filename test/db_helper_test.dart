import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:daily_expense_tracker/services/db_helper.dart';
import 'package:daily_expense_tracker/models/daily_entry.dart';
import 'package:daily_expense_tracker/models/grand_purchase.dart';
import 'package:daily_expense_tracker/models/purchase_type.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('upsert and get entry', () async {
    final db = DBHelper();
    final e = DailyEntry(
        date: DateTime(2026, 1, 10),
        breakfast: 100,
        lunch: 200,
        dinner: 300,
        snack: 400);
    await db.upsertEntry(e);
    final got = await db.getEntry(DateTime(2026, 1, 10));
    expect(got, isNotNull);
    expect(got!.sum(), e.sum());
  });

  test('v4 migration seeds default purchase type', () async {
    final db = DBHelper();
    final types = await db.getAllPurchaseTypes();
    expect(types.length, greaterThanOrEqualTo(1));

    final food = types.firstWhere((t) => t.name == 'food&drink');
    expect(food.deductFromBudget, isTrue);
    expect(food.useColor, isFalse);
  });

  test('insert and update purchase type', () async {
    final db = DBHelper();
    final id = await db.insertPurchaseType(
      PurchaseType(name: 'custom', useColor: true, sortOrder: 99),
    );
    expect(id, greaterThan(0));

    final created = await db.getPurchaseTypeByName('custom');
    expect(created, isNotNull);
    expect(created!.useColor, isTrue);

    await db.updatePurchaseType(
      PurchaseType(
        id: created.id,
        name: 'custom_renamed',
        useColor: false,
        deductFromBudget: true,
        sortOrder: 99,
      ),
    );

    final updated = await db.getPurchaseTypeByName('custom_renamed');
    expect(updated, isNotNull);
    expect(updated!.deductFromBudget, isTrue);
    expect(await db.getPurchaseTypeByName('custom'), isNull);
  });

  test('rename purchase type updates joined purchase name via fk', () async {
    final db = DBHelper();

    final transportId = await db.insertPurchaseType(
      PurchaseType(name: 'transport', sortOrder: 1),
    );

    await db.insertGrandPurchase(GrandPurchase(
      typeId: transportId,
      name: 'Bus ticket',
      price: 5000,
      date: DateTime(2026, 2, 1),
    ));

    final transportType = await db.getPurchaseTypeById(transportId);
    expect(transportType, isNotNull);

    await db.updatePurchaseType(
      PurchaseType(
        id: transportType!.id,
        name: 'transportation',
        useColor: transportType.useColor,
        deductFromBudget: transportType.deductFromBudget,
        sortOrder: transportType.sortOrder,
      ),
    );

    final purchases = await db.getGrandPurchasesForMonth(2026, 2);
    expect(purchases.length, 1);
    expect(purchases.first.typeId, transportId);
    expect(purchases.first.type, 'transportation');
  });
}
