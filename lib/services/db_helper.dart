import 'dart:convert';
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
      version: 2,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE daily_entries (
            date TEXT PRIMARY KEY,
            breakfast INTEGER,
            lunch INTEGER,
            dinner INTEGER,
            snack INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE grand_purchase (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            color TEXT,
            price INTEGER NOT NULL,
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
              price INTEGER NOT NULL,
              date TEXT NOT NULL,
              desc TEXT
            )
          ''');
        }
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

  // ── export / import ──────────────────────────────────────────────────────

  /// Export all entries as a JSON file in the app documents directory.
  /// Returns the saved file path.
  Future<String> exportToJsonFile() async {
    final entries = await getAllEntries();
    final list = entries.map((e) => e.toMap()).toList();
    final jsonStr = jsonEncode(list);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/daily_expense_export_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json');
    await file.writeAsString(jsonStr);
    return file.path;
  }

  /// Import entries from a JSON string. The JSON should be a list of objects matching DailyEntry.toMap().
  Future<void> importFromJsonString(String jsonStr) async {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final entry = DailyEntry.fromMap(item);
        await upsertEntry(entry);
      }
    }
  }
}

