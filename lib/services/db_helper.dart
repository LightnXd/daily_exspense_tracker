import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import '../models/daily_entry.dart';
import '../models/grand_purchase.dart';
import '../models/purchase_type.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  Database? _db;

  static const _purchaseSelect = '''
    SELECT gp.*, pt.name AS type_name
    FROM grand_purchase gp
    INNER JOIN purchase_type pt ON gp.type_id = pt.id
  ''';

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'daily_expense.db');

    await _restoreFromExternalBackupIfNeeded(path);

    _db = await openDatabase(
      path,
      version: 5,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE daily_entries (
            date TEXT PRIMARY KEY,
            breakfast REAL,
            lunch REAL,
            dinner REAL,
            snack REAL
          )
        ''');
        await _createPurchaseTypeTable(db);
        await _seedPurchaseTypes(db);
        await db.execute('''
          CREATE TABLE grand_purchase (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            color TEXT,
            price REAL NOT NULL,
            date TEXT NOT NULL,
            desc TEXT,
            FOREIGN KEY (type_id) REFERENCES purchase_type(id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS grand_purchase (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type TEXT NOT NULL,
              name TEXT NOT NULL,
              color TEXT,
              price REAL NOT NULL,
              date TEXT NOT NULL,
              desc TEXT
            )
          ''');
        }
        if (oldVersion < 4) {
          await _createPurchaseTypeTable(db);
          await _seedPurchaseTypes(db);
        }
        if (oldVersion < 5) {
          await _migrateGrandPurchaseToTypeId(db);
        }
      },
    );
    await _backupToExternal(path);
    return _db!;
  }

  /// Opens the DB (restores from Downloads backup on fresh install) and keeps
  /// an external copy in sync. Safe to call at app startup.
  Future<void> warmUp() async {
    await _open();
  }

  /// Copies the internal DB to Downloads/FoodExpense (survives uninstall).
  Future<void> backupToDownloads() async {
    final databasesPath = await getDatabasesPath();
    await _backupToExternal(join(databasesPath, 'daily_expense.db'));
  }

  /// Copies the DB to Downloads/FoodExpense so data can survive app uninstall.
  Future<void> _backupToExternal(String dbPath) async {
    if (!Platform.isAndroid) return;
    try {
      if (_db != null) {
        try {
          await _db!.rawQuery('PRAGMA wal_checkpoint(FULL)');
        } catch (_) {}
      }

      final backup = await _externalBackupFile();
      if (backup == null) return;
      final internal = File(dbPath);
      if (!await internal.exists()) return;
      await internal.copy(backup.path);
    } catch (_) {}
  }

  Future<void> _restoreFromExternalBackupIfNeeded(String dbPath) async {
    if (!Platform.isAndroid) return;
    try {
      final internal = File(dbPath);
      if (await internal.exists()) return;

      final backup = await _externalBackupFile();
      if (backup == null || !await backup.exists()) return;

      await Directory(dirname(dbPath)).create(recursive: true);
      await backup.copy(dbPath);
    } catch (_) {}
  }

  Future<File?> _externalBackupFile() async {
    if (!Platform.isAndroid) return null;
    try {
      Directory dir;

      final downloads = await getDownloadsDirectory();
      if (downloads != null && !downloads.path.contains('/Android/data/')) {
        dir = Directory(join(downloads.path, 'FoodExpense'));
      } else {
        // Public Downloads folder — not removed on uninstall.
        dir = Directory('/storage/emulated/0/Download/FoodExpense');
      }

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return File(join(dir.path, 'daily_expense.db'));
    } catch (_) {
      return null;
    }
  }

  Future<void> _afterWrite() async {
    await backupToDownloads();
  }

  Future<DailyEntry?> getEntry(DateTime date) async {
    final db = await _open();
    final key = date.toIso8601String().split('T').first;
    final res = await db.query('daily_entries', where: 'date = ?', whereArgs: [key]);
    if (res.isEmpty) return null;
    return DailyEntry.fromMap(res.first);
  }

  Future<void> upsertEntry(DailyEntry e, {bool backup = true}) async {
    final db = await _open();
    final map = e.toMap();
    map['date'] = e.date.toIso8601String().split('T').first;
    await db.insert('daily_entries', map, conflictAlgorithm: ConflictAlgorithm.replace);
    if (backup) await _afterWrite();
  }

  Future<List<DailyEntry>> getEntriesForMonth(int year, int month) async {
    final db = await _open();
    final start = DateTime(year, month, 1).toIso8601String().split('T').first;
    final end = DateTime(year, month + 1, 1).toIso8601String().split('T').first;
    final res = await db.rawQuery(
      'SELECT * FROM daily_entries WHERE date >= ? AND date < ? ORDER BY date ASC',
      [start, end],
    );
    return res.map((m) => DailyEntry.fromMap(m)).toList();
  }

  Future<List<DailyEntry>> getAllEntries() async {
    final db = await _open();
    final res = await db.query('daily_entries', orderBy: 'date ASC');
    return res.map((m) => DailyEntry.fromMap(m)).toList();
  }

  // ── grand_purchase ────────────────────────────────────────────────────────

  Future<int> insertGrandPurchase(GrandPurchase p, {bool backup = true}) async {
    final db = await _open();
    final id = await db.insert('grand_purchase', p.toMap());
    if (backup) await _afterWrite();
    return id;
  }

  Future<void> deleteGrandPurchase(int id) async {
    final db = await _open();
    await db.delete('grand_purchase', where: 'id = ?', whereArgs: [id]);
    await _afterWrite();
  }

  Future<List<GrandPurchase>> getGrandPurchasesForMonth(int year, int month) async {
    final db = await _open();
    final start = DateTime(year, month, 1).toIso8601String().split('T').first;
    final end = DateTime(year, month + 1, 1).toIso8601String().split('T').first;
    final res = await db.rawQuery(
      '$_purchaseSelect WHERE gp.date >= ? AND gp.date < ? ORDER BY gp.date ASC',
      [start, end],
    );
    return res.map((m) => GrandPurchase.fromMap(m)).toList();
  }

  Future<List<GrandPurchase>> getAllGrandPurchases() async {
    final db = await _open();
    final res = await db.rawQuery('$_purchaseSelect ORDER BY gp.date ASC');
    return res.map((m) => GrandPurchase.fromMap(m)).toList();
  }
  Future<int> updateGrandPurchase(GrandPurchase p) async {
    final db = await _open();
    if (p.id == null) throw ArgumentError('GrandPurchase id is required for update');
    final rows = await db.update('grand_purchase', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
    await _afterWrite();
    return rows;
  }

  // ── purchase_type ─────────────────────────────────────────────────────────

  static Future<void> _createPurchaseTypeTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_type (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        use_color INTEGER NOT NULL DEFAULT 0,
        deduct_from_budget INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  static Future<void> _migrateGrandPurchaseToTypeId(Database db) async {
    await _createPurchaseTypeTable(db);
    await _seedPurchaseTypes(db);

    final columns = await db.rawQuery('PRAGMA table_info(grand_purchase)');
    final hasTypeText = columns.any((c) => c['name'] == 'type');
    final hasTypeId = columns.any((c) => c['name'] == 'type_id');

    if (!hasTypeText && hasTypeId) return;

    if (hasTypeText) {
      final orphans = await db.rawQuery('''
        SELECT DISTINCT type FROM grand_purchase
        WHERE type NOT IN (SELECT name FROM purchase_type)
      ''');
      for (final row in orphans) {
        await db.insert('purchase_type', {
          'name': row['type'],
          'use_color': 0,
          'deduct_from_budget': 0,
          'sort_order': 999,
        });
      }

      if (!hasTypeId) {
        await db.execute('ALTER TABLE grand_purchase ADD COLUMN type_id INTEGER');
      }

      await db.execute('''
        UPDATE grand_purchase SET type_id = (
          SELECT id FROM purchase_type WHERE purchase_type.name = grand_purchase.type
        )
      ''');
    }

    await db.execute('''
      CREATE TABLE grand_purchase_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        color TEXT,
        price REAL NOT NULL,
        date TEXT NOT NULL,
        desc TEXT,
        FOREIGN KEY (type_id) REFERENCES purchase_type(id)
      )
    ''');

    await db.execute('''
      INSERT INTO grand_purchase_new (id, type_id, name, color, price, date, desc)
      SELECT id, type_id, name, color, price, date, desc FROM grand_purchase
      WHERE type_id IS NOT NULL
    ''');

    await db.execute('DROP TABLE grand_purchase');
    await db.execute('ALTER TABLE grand_purchase_new RENAME TO grand_purchase');
  }

  static Future<void> _seedPurchaseTypes(Database db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM purchase_type'),
    );
    if (count != null && count > 0) return;

    final defaults = [
      {'name': 'food&drink', 'use_color': 0, 'deduct_from_budget': 1, 'sort_order': 0},
    ];
    for (final row in defaults) {
      await db.insert('purchase_type', row);
    }
  }

  Future<List<PurchaseType>> getAllPurchaseTypes() async {
    final db = await _open();
    final res = await db.query(
      'purchase_type',
      orderBy: 'sort_order ASC, name ASC',
    );
    return res.map((m) => PurchaseType.fromMap(m)).toList();
  }

  Future<PurchaseType?> getPurchaseTypeByName(String name) async {
    final db = await _open();
    final res = await db.query(
      'purchase_type',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return PurchaseType.fromMap(res.first);
  }

  Future<int> insertPurchaseType(PurchaseType t) async {
    final db = await _open();
    final id = await db.insert('purchase_type', t.toMap());
    await _afterWrite();
    return id;
  }

  Future<PurchaseType?> getPurchaseTypeById(int id) async {
    final db = await _open();
    final res = await db.query(
      'purchase_type',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return PurchaseType.fromMap(res.first);
  }

  Future<int> resolveTypeId(String typeName) async {
    final existing = await getPurchaseTypeByName(typeName);
    if (existing?.id != null) return existing!.id!;
    return insertPurchaseType(PurchaseType(name: typeName, sortOrder: 999));
  }

  Future<void> updatePurchaseType(PurchaseType t) async {
    final db = await _open();
    if (t.id == null) throw ArgumentError('PurchaseType id is required for update');

    await db.update(
      'purchase_type',
      t.toMap(),
      where: 'id = ?',
      whereArgs: [t.id],
    );
    await _afterWrite();
  }

  Future<void> _importPurchaseTypes(dynamic types) async {
    if (types is! List) return;
    for (final item in types) {
      if (item is! Map) continue;
      final type = PurchaseType.fromJson(
        Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
      );
      final existing = await getPurchaseTypeByName(type.name);
      if (existing != null) {
        await updatePurchaseType(
          PurchaseType(
            id: existing.id,
            name: type.name,
            useColor: type.useColor,
            deductFromBudget: type.deductFromBudget,
            sortOrder: type.sortOrder,
          ),
        );
      } else {
        await insertPurchaseType(type);
      }
    }
  }

  // ── export / import ──────────────────────────────────────────────────────

  static String _escapeCsvField(String? value) {
    if (value == null) return '';
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _numToCsv(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    int i = 0;
    while (i < line.length) {
      if (line[i] == '"') {
        i++;
        final sb = StringBuffer();
        while (i < line.length) {
          if (line[i] == '"' && i + 1 < line.length && line[i + 1] == '"') {
            sb.write('"');
            i += 2;
          } else if (line[i] == '"') {
            i++;
            break;
          } else {
            sb.write(line[i]);
            i++;
          }
        }
        result.add(sb.toString());
        if (i < line.length && line[i] == ',') i++;
      } else {
        final start = i;
        while (i < line.length && line[i] != ',') i++;
        result.add(line.substring(start, i));
        if (i < line.length) i++;
      }
    }
    return result;
  }

  Future<List<DailyEntry>> _entriesForRange(DateTime from, DateTime to) async {
    final fromStr = from.toIso8601String().split('T').first;
    final toStr = to.toIso8601String().split('T').first;
    final db = await _open();

    final entryRes = await db.rawQuery(
      'SELECT * FROM daily_entries WHERE date >= ? AND date <= ? ORDER BY date ASC',
      [fromStr, toStr],
    );
    return entryRes.map((m) => DailyEntry.fromMap(m)).toList();
  }

  Future<List<GrandPurchase>> _purchasesForRange(DateTime from, DateTime to) async {
    final fromStr = from.toIso8601String().split('T').first;
    final toStr = to.toIso8601String().split('T').first;
    final db = await _open();

    final purchaseRes = await db.rawQuery(
      '$_purchaseSelect WHERE gp.date >= ? AND gp.date <= ? ORDER BY gp.date ASC',
      [fromStr, toStr],
    );
    return purchaseRes.map((m) => GrandPurchase.fromMap(m)).toList();
  }

  /// Export entries, special purchases, and categories within [from]..[to] as JSON.
  /// Categories are always exported in full (not date-filtered).
  Future<String> exportToJsonString(DateTime from, DateTime to) async {
    final entries = await _entriesForRange(from, to);
    final purchases = await _purchasesForRange(from, to);
    final purchaseTypes = await getAllPurchaseTypes();

    final payload = {
      'entries': entries.map((e) => e.toJson()).toList(),
      'purchases': purchases.map((p) => p.toJson()).toList(),
      'purchase_types': purchaseTypes.map((t) => t.toJson()).toList(),
    };

    return jsonEncode(payload);
  }

  /// Export entries and special purchases within [from]..[to] (inclusive) as CSV.
  /// Returns the CSV content as a string.
  Future<String> exportToCsvString(DateTime from, DateTime to) async {
    final entries = await _entriesForRange(from, to);
    final purchases = await _purchasesForRange(from, to);
    final purchaseTypes = await getAllPurchaseTypes();

    final buf = StringBuffer();

    buf.writeln('DAILY_ENTRIES');
    buf.writeln('date,breakfast,lunch,dinner,snack');
    for (final e in entries) {
      buf.writeln([
        e.date.toIso8601String().split('T').first,
        e.breakfast == null ? '' : _numToCsv(e.breakfast!),
        e.lunch == null ? '' : _numToCsv(e.lunch!),
        e.dinner == null ? '' : _numToCsv(e.dinner!),
        e.snack == null ? '' : _numToCsv(e.snack!),
      ].join(','));
    }

    buf.writeln();

    buf.writeln('GRAND_PURCHASE');
    buf.writeln('type,name,color,price,date,desc');
    for (final p in purchases) {
      buf.writeln([
        _escapeCsvField(p.type),
        _escapeCsvField(p.name),
        _escapeCsvField(p.color),
        _numToCsv(p.price),
        p.date.toIso8601String().split('T').first,
        _escapeCsvField(p.desc),
      ].join(','));
    }

    buf.writeln();

    buf.writeln('PURCHASE_TYPE');
    buf.writeln('name,use_color,deduct_from_budget,sort_order');
    for (final t in purchaseTypes) {
      buf.writeln([
        _escapeCsvField(t.name),
        t.useColor ? '1' : '0',
        t.deductFromBudget ? '1' : '0',
        t.sortOrder.toString(),
      ].join(','));
    }

    return buf.toString();
  }

  /// Import entries and special purchases from a JSON string.
  Future<void> importFromJsonString(String jsonContent) async {
    final decoded = jsonDecode(jsonContent);
    if (decoded is! Map) {
      throw FormatException('JSON payload must be an object with entries and purchases');
    }

    final payload = Map<String, dynamic>.from(decoded as Map<dynamic, dynamic>);
    await _importPurchaseTypes(payload['purchase_types']);

    final entries = payload['entries'];
    final purchases = payload['purchases'];

    if (entries is List) {
      for (final item in entries) {
        if (item is Map) {
          final entry = DailyEntry.fromJson(Map<String, dynamic>.from(item as Map<dynamic, dynamic>));
          await upsertEntry(entry, backup: false);
        }
      }
    }

    final existingPurchases = await getAllGrandPurchases();
    if (purchases is List) {
      for (final item in purchases) {
        if (item is Map) {
          final raw = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
          final purchase = GrandPurchase.fromJson(raw);
          final typeId = purchase.typeId != 0
              ? purchase.typeId
              : await resolveTypeId(purchase.type);
          final resolved = GrandPurchase(
            id: purchase.id,
            typeId: typeId,
            typeName: purchase.typeName,
            name: purchase.name,
            color: purchase.color,
            price: purchase.price,
            date: purchase.date,
            desc: purchase.desc,
          );
          final dateStr = resolved.date.toIso8601String().split('T').first;
          final isDuplicate = existingPurchases.any((e) =>
              e.typeId == resolved.typeId &&
              e.name == resolved.name &&
              e.date.toIso8601String().split('T').first == dateStr);
          if (!isDuplicate) {
            await insertGrandPurchase(resolved, backup: false);
            existingPurchases.add(resolved);
          }
        }
      }
    }
    await _afterWrite();
  }

  /// Import entries and special purchases from a CSV string.
  /// For grand_purchase: skips rows where type+name+date already exist.
  Future<void> importFromCsvString(String csvContent) async {
    final lines = csvContent.split('\n').map((l) => l.trimRight()).toList();
    String? section;
    bool headerSkipped = false;
    final existingPurchases = await getAllGrandPurchases();

    for (final line in lines) {
      if (line.isEmpty) {
        headerSkipped = false;
        continue;
      }
      if (line == 'DAILY_ENTRIES') {
        section = 'daily_entries';
        headerSkipped = false;
        continue;
      }
      if (line == 'GRAND_PURCHASE') {
        section = 'grand_purchase';
        headerSkipped = false;
        continue;
      }
      if (line == 'PURCHASE_TYPE') {
        section = 'purchase_type';
        headerSkipped = false;
        continue;
      }
      if (!headerSkipped) {
        headerSkipped = true;
        continue;
      }

      final fields = _parseCsvLine(line);

      if (section == 'daily_entries' && fields.length >= 5) {
        try {
          await upsertEntry(DailyEntry(
            date: DateTime.parse(fields[0]),
            breakfast: fields[1].isEmpty ? null : double.parse(fields[1]),
            lunch: fields[2].isEmpty ? null : double.parse(fields[2]),
            dinner: fields[3].isEmpty ? null : double.parse(fields[3]),
            snack: fields[4].isEmpty ? null : double.parse(fields[4]),
          ), backup: false);
        } catch (_) {}
      } else if (section == 'grand_purchase' && fields.length >= 5) {
        try {
          final typeId = await resolveTypeId(fields[0]);
          final p = GrandPurchase(
            typeId: typeId,
            name: fields[1],
            color: fields[2].isEmpty ? null : fields[2],
            price: double.parse(fields[3]),
            date: DateTime.parse(fields[4]),
            desc: fields.length > 5 && fields[5].isNotEmpty ? fields[5] : null,
          );
          final dateStr = p.date.toIso8601String().split('T').first;
          final isDuplicate = existingPurchases.any((e) =>
              e.typeId == p.typeId &&
              e.name == p.name &&
              e.date.toIso8601String().split('T').first == dateStr);
          if (!isDuplicate) {
            await insertGrandPurchase(p, backup: false);
            existingPurchases.add(p);
          }
        } catch (_) {}
      } else if (section == 'purchase_type' && fields.length >= 4) {
        try {
          await _importPurchaseTypes([
            {
              'name': fields[0],
              'use_color': fields[1] == '1' ? 1 : 0,
              'deduct_from_budget': fields[2] == '1' ? 1 : 0,
              'sort_order': int.parse(fields[3]),
            },
          ]);
        } catch (_) {}
      }
    }
    await _afterWrite();
  }

  // ── bulk change ───────────────────────────────────────────────────────────

  double _applyOp(double value, String operation, double operand) {
    double result;
    switch (operation) {
      case 'add':
        result = value + operand;
        break;
      case 'subtract':
        result = value - operand;
        break;
      case 'multiply':
        result = value * operand;
        break;
      case 'divide':
        result = operand != 0 ? value / operand : value;
        break;
      default:
        result = value;
    }
    return (result * 100).roundToDouble() / 100;
  }

  Future<void> applyBulkChange(String operation, double operand) async {
    final db = await _open();
    final entries = await getAllEntries();
    for (final e in entries) {
      await upsertEntry(DailyEntry(
        date: e.date,
        breakfast: e.breakfast != null ? _applyOp(e.breakfast!, operation, operand) : null,
        lunch: e.lunch != null ? _applyOp(e.lunch!, operation, operand) : null,
        dinner: e.dinner != null ? _applyOp(e.dinner!, operation, operand) : null,
        snack: e.snack != null ? _applyOp(e.snack!, operation, operand) : null,
      ), backup: false);
    }
    final purchases = await getAllGrandPurchases();
    for (final p in purchases) {
      await db.update(
        'grand_purchase',
        {'price': _applyOp(p.price, operation, operand)},
        where: 'id = ?',
        whereArgs: [p.id],
      );
    }
    await _afterWrite();
  }
}

