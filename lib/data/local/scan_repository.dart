import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:waste_classification/data/models/scan_result.dart';

class ScanRepository {
  Database? _database;
  final ValueNotifier<int> revision = ValueNotifier(0);

  Future<Database> get _db async {
    final current = _database;
    if (current != null) return current;

    final database = await openDatabase(
      p.join(await getDatabasesPath(), 'waste_classification.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scan_results (
            id TEXT PRIMARY KEY,
            image_path TEXT NOT NULL,
            scanned_at TEXT NOT NULL,
            category_id TEXT NOT NULL,
            model_label TEXT NOT NULL,
            confidence REAL NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_scan_results_scanned_at '
          'ON scan_results(scanned_at)',
        );
        await db.execute(
          'CREATE INDEX idx_scan_results_category_id '
          'ON scan_results(category_id)',
        );
      },
    );
    _database = database;
    return database;
  }

  Future<void> insert(ScanResult result) async {
    final db = await _db;
    await db.insert(
      'scan_results',
      result.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    revision.value++;
  }

  Future<List<ScanResult>> getAll() async {
    final db = await _db;
    final rows = await db.query('scan_results', orderBy: 'scanned_at DESC');
    return rows.map(ScanResult.fromMap).toList(growable: false);
  }
}

final scanRepository = ScanRepository();
