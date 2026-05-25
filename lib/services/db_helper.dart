import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import '../models/daily_entry.dart';
import '../models/grand_purchase.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'daily_expense.db');

    _db = await openDatabase(
      path,
      version: 3,
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
        await db.execute('''
          CREATE TABLE grand_purchase (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            color TEXT,
            price REAL NOT NULL,
            date TEXT NOT NULL,
            desc TEXT
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
        // v3: price columns changed to REAL affinity.
        // SQLite stores the actual numeric type regardless of declared affinity,
        // so existing integer values continue to work without data migration.
      },
    );
    return _db!;
  }

  Future<DailyEntry?> getEntry(DateTime date) async {
    final db = await _open();
    final key = date.toIso8601String().split('T').first;
    final res = await db.query('daily_entries', where: 'date = ?', whereArgs: [key]);
    if (res.isEmpty) return null;
    return DailyEntry.fromMap(res.first);
  }

  Future<void> upsertEntry(DailyEntry e) async {
    final db = await _open();
    final map = e.toMap();
    map['date'] = e.date.toIso8601String().split('T').first;
    await db.insert('daily_entries', map, conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<int> insertGrandPurchase(GrandPurchase p) async {
    final db = await _open();
    return db.insert('grand_purchase', p.toMap());
  }

  Future<void> deleteGrandPurchase(int id) async {
    final db = await _open();
    await db.delete('grand_purchase', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<GrandPurchase>> getGrandPurchasesForMonth(int year, int month) async {
    final db = await _open();
    final start = DateTime(year, month, 1).toIso8601String().split('T').first;
    final end = DateTime(year, month + 1, 1).toIso8601String().split('T').first;
    final res = await db.rawQuery(
      'SELECT * FROM grand_purchase WHERE date >= ? AND date < ? ORDER BY date ASC',
      [start, end],
    );
    return res.map((m) => GrandPurchase.fromMap(m)).toList();
  }

  Future<List<GrandPurchase>> getAllGrandPurchases() async {
    final db = await _open();
    final res = await db.query('grand_purchase', orderBy: 'date ASC');
    return res.map((m) => GrandPurchase.fromMap(m)).toList();
  }
  Future<int> updateGrandPurchase(GrandPurchase p) async {
    final db = await _open();
    if (p.id == null) throw ArgumentError('GrandPurchase id is required for update');
    return db.update('grand_purchase', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
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

  /// Export entries and special purchases within [from]..[to] (inclusive) as CSV.
  /// Returns the CSV content as a string.
  Future<String> exportToCsvString(DateTime from, DateTime to) async {
    final fromStr = from.toIso8601String().split('T').first;
    final toStr = to.toIso8601String().split('T').first;
    final db = await _open();

    final entryRes = await db.rawQuery(
      'SELECT * FROM daily_entries WHERE date >= ? AND date <= ? ORDER BY date ASC',
      [fromStr, toStr],
    );
    final entries = entryRes.map((m) => DailyEntry.fromMap(m)).toList();

    final purchaseRes = await db.rawQuery(
      'SELECT * FROM grand_purchase WHERE date >= ? AND date <= ? ORDER BY date ASC',
      [fromStr, toStr],
    );
    final purchases = purchaseRes.map((m) => GrandPurchase.fromMap(m)).toList();

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

    return buf.toString();
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
          ));
        } catch (_) {}
      } else if (section == 'grand_purchase' && fields.length >= 5) {
        try {
          final p = GrandPurchase(
            type: fields[0],
            name: fields[1],
            color: fields[2].isEmpty ? null : fields[2],
            price: double.parse(fields[3]),
            date: DateTime.parse(fields[4]),
            desc: fields.length > 5 && fields[5].isNotEmpty ? fields[5] : null,
          );
          final dateStr = p.date.toIso8601String().split('T').first;
          final isDuplicate = existingPurchases.any((e) =>
              e.type == p.type &&
              e.name == p.name &&
              e.date.toIso8601String().split('T').first == dateStr);
          if (!isDuplicate) {
            await insertGrandPurchase(p);
            existingPurchases.add(p);
          }
        } catch (_) {}
      }
    }
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
      ));
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
  }
}

