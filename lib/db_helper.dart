import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sql;

import 'transaction_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static sql.Database? _database;

  // Web fallback is in-memory only; data resets when the app/browser session is restarted.
  final List<TransactionItem> _webMemoryStorage = [];
  int _webIdCounter = 1;
  double _webMonthlyBudget = 15000;

  DatabaseHelper._init();

  Future<sql.Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initDB('expenses.db');
    return _database;
  }

  Future<sql.Database> _initDB(String filePath) async {
    final dbPath = await sql.getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return sql.openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            date TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE app_settings (
            setting_key TEXT PRIMARY KEY,
            setting_value REAL NOT NULL
          )
        ''');
        await db.insert('app_settings', {
          'setting_key': 'monthly_budget',
          'setting_value': 15000.0,
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Version 1 already contains the transactions table. Keep all existing rows.
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE app_settings (
              setting_key TEXT PRIMARY KEY,
              setting_value REAL NOT NULL
            )
          ''');
          await db.insert('app_settings', {
            'setting_key': 'monthly_budget',
            'setting_value': 15000.0,
          });
        }
      },
    );
  }

  Future<int> insert(TransactionItem item) async {
    if (kIsWeb) {
      final newItem = item.copyWith(id: _webIdCounter++);
      _webMemoryStorage.insert(0, newItem);
      return newItem.id!;
    }
    final db = await database;
    return db!.insert('transactions', item.toMap()..remove('id'));
  }

  Future<List<TransactionItem>> getAll() async {
    if (kIsWeb) return List.unmodifiable(_webMemoryStorage);
    final db = await database;
    final rows = await db!.query('transactions', orderBy: 'id DESC');
    return rows.map(TransactionItem.fromMap).toList();
  }

  Future<int> update(TransactionItem item) async {
    if (item.id == null) return 0;
    if (kIsWeb) {
      final index = _webMemoryStorage.indexWhere((entry) => entry.id == item.id);
      if (index == -1) return 0;
      _webMemoryStorage[index] = item;
      return 1;
    }
    final db = await database;
    return db!.update('transactions', item.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> delete(int id) async {
    if (kIsWeb) {
      final before = _webMemoryStorage.length;
      _webMemoryStorage.removeWhere((item) => item.id == id);
      return before - _webMemoryStorage.length;
    }
    final db = await database;
    return db!.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getMonthlyBudget() async {
    if (kIsWeb) return _webMonthlyBudget;
    final db = await database;
    final rows = await db!.query('app_settings',
        columns: ['setting_value'],
        where: 'setting_key = ?',
        whereArgs: ['monthly_budget'],
        limit: 1);
    if (rows.isEmpty) return 15000;
    return (rows.first['setting_value'] as num).toDouble();
  }

  Future<void> setMonthlyBudget(double amount) async {
    if (kIsWeb) {
      _webMonthlyBudget = amount;
      return;
    }
    final db = await database;
    await db!.insert(
      'app_settings',
      {'setting_key': 'monthly_budget', 'setting_value': amount},
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }
}
