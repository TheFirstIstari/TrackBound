import 'package:sqflite/sqflite.dart';
import '../database.dart';

class StationDao {
  final Future<Database> _db = AppDatabase.instance.database;

  Future<int> insertStation(String name, {String? code, double? latitude, double? longitude}) async {
    final db = await _db;
    final existing = await db.query('stations', where: 'name = ?', whereArgs: [name]);
    if (existing.isNotEmpty) return existing.first['id'] as int;
    return await db.insert('stations', {
      'name': name,
      'code': code,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Future<int?> getStationIdByName(String name) async {
    final db = await _db;
    final rows = await db.query('stations', where: 'name = ?', whereArgs: [name], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  Future<Map<String, Object?>?> getStationById(int id) async {
    final db = await _db;
    final rows = await db.query('stations', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }
}
