import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:trackbound/src/db/database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('AppDatabase', () {
    test('creates tables and allows basic insert/query', () async {
      // Ensure a fresh database path for the test
      final dbPath = await sqflite.getDatabasesPath();
      final dbFile = File('$dbPath/trackbound.db');
      if (await dbFile.exists()) await dbFile.delete();

      final db = await AppDatabase.instance.database;

      final id = await db.insert('train_services', {
        'name': 'Test Service',
        'operator': 'UnitTest'
      });

      expect(id, greaterThan(0));

      final rows = await db.query('train_services', where: 'id = ?', whereArgs: [id]);
      expect(rows, isNotEmpty);
      expect(rows.first['name'], 'Test Service');

      await AppDatabase.instance.close();

      // cleanup
      if (await dbFile.exists()) await dbFile.delete();
    });
  });
}
