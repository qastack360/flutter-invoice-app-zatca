import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/invoice.dart';
import '../models/item_data.dart';
import '../models/company_details.dart';
import '../models/invoice_settings.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;
  DatabaseHelper._();

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    if (kIsWeb) {
      // For web platform, use SharedPreferences instead of SQLite
      throw UnsupportedError('SQLite not supported on web platform. Use SharedPreferences.');
    }
    final path = join(await getDatabasesPath(), 'invoice_app.db');
    return await openDatabase(path, version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future _onCreate(Database db, int v) async {
    await db.execute('''
      CREATE TABLE company_details(
        id INTEGER PRIMARY KEY,
        logoPath TEXT,
        ownerName1 TEXT,
        ownerName2 TEXT,
        otherName TEXT,
        phone TEXT,
        vatNo TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_settings(
        id INTEGER PRIMARY KEY,
        startInvoice INTEGER,
        vatPercent REAL
      )
    ''');

    // New table for sync tracking
    await db.execute('''
      CREATE TABLE sync_tracking(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id TEXT UNIQUE,
        invoice_number INTEGER,
        sync_status TEXT DEFAULT 'pending',
        zatca_uuid TEXT,
        zatca_qr_code TEXT,
        zatca_response TEXT,
        sync_timestamp TEXT,
        retry_count INTEGER DEFAULT 0,
        error_message TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Insert default settings
    await db.insert('invoice_settings', {
      'id': 1,
      'startInvoice': 1,
      'vatPercent': 15.0,
    });

    await db.insert('company_details', {
      'id': 1,
      'logoPath': '',
      'ownerName1': '',
      'ownerName2': '',
      'otherName': '',
      'phone': '',
      'vatNo': '',
    });
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add sync tracking table for version 2
      await db.execute('''
        CREATE TABLE sync_tracking(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_id TEXT UNIQUE,
          invoice_number INTEGER,
          sync_status TEXT DEFAULT 'pending',
          zatca_uuid TEXT,
          zatca_qr_code TEXT,
          zatca_response TEXT,
          sync_timestamp TEXT,
          retry_count INTEGER DEFAULT 0,
          error_message TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
    }
  }

  // Company Details CRUD
  Future<int> updateCompany(CompanyDetails c) async {
    final d = await db;
    return await d.update('company_details', c.toMap(), where: 'id=1');
  }

  Future<CompanyDetails> getCompany() async {
    final d = await db;
    final rows = await d.query('company_details', where: 'id=1');
    if (rows.isNotEmpty) {
      return CompanyDetails.fromMap(rows.first);
    }
    return CompanyDetails(
      id: 1,
      ownerName1: '',
      ownerName2: '',
      otherName: '',
      phone: '',
      vatNo: '',
    );
  }

  // Invoice Settings CRUD
  Future<int> updateSettings(InvoiceSettings s) async {
    final d = await db;
    return await d.update('invoice_settings', s.toMap(), where: 'id=1');
  }

  Future<InvoiceSettings> getSettings() async {
    final d = await db;
    final rows = await d.query('invoice_settings', where: 'id=1');
    return InvoiceSettings.fromMap(rows.first);
  }

  // Sync Tracking CRUD
  Future<int> insertSyncTracking(Map<String, dynamic> tracking) async {
    final d = await db;
    return await d.insert('sync_tracking', {
      ...tracking,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateSyncTracking(String invoiceId, Map<String, dynamic> updates) async {
    final d = await db;
    return await d.update('sync_tracking', {
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'invoice_id = ?', whereArgs: [invoiceId]);
  }

  Future<List<Map<String, dynamic>>> getPendingSyncInvoices() async {
    final d = await db;
    return await d.query(
      'sync_tracking',
      where: 'sync_status IN (?, ?)',
      whereArgs: ['pending', 'failed'],
      orderBy: 'created_at ASC',
    );
  }

  Future<Map<String, dynamic>?> getSyncTracking(String invoiceId) async {
    final d = await db;
    final rows = await d.query(
      'sync_tracking',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllSyncTracking() async {
    final d = await db;
    return await d.query('sync_tracking', orderBy: 'created_at DESC');
  }

  Future<int> deleteSyncTracking(String invoiceId) async {
    final d = await db;
    return await d.delete(
      'sync_tracking',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
  }

  // Get sync statistics
  Future<Map<String, int>> getSyncStats() async {
    final d = await db;
    final result = await d.rawQuery('''
      SELECT 
        sync_status,
        COUNT(*) as count
      FROM sync_tracking
      GROUP BY sync_status
    ''');

    Map<String, int> stats = {
      'pending': 0,
      'in_progress': 0,
      'completed': 0,
      'failed': 0,
    };

    for (var row in result) {
      stats[row['sync_status'] as String] = row['count'] as int;
    }

    return stats;
  }

  // Clear old sync records (cleanup)
  Future<int> clearOldSyncRecords(int daysOld) async {
    final d = await db;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld)).toIso8601String();
    
    return await d.delete(
      'sync_tracking',
      where: 'created_at < ? AND sync_status = ?',
      whereArgs: [cutoffDate, 'completed'],
    );
  }
}