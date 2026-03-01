import 'package:sqflite/sqflite.dart';
import '../database.dart';

class StationDao {
  final Future<Database> _db = AppDatabase.instance.database;

  Future<int> insertStation(String name, {String? code, double? latitude, double? longitude}) async {
    final db = await _db;
    final existing = await db.query('stations', where: 'name = ?', whereArgs: [name]);
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      final existingCode = existing.first['code'] as String?;
      final existingLat = (existing.first['latitude'] as num?)?.toDouble();
      final existingLng = (existing.first['longitude'] as num?)?.toDouble();

      final updateMap = <String, Object?>{};
      if ((existingCode == null || existingCode.isEmpty) && code != null && code.isNotEmpty) {
        updateMap['code'] = code;
      }
      if (existingLat == null && latitude != null) {
        updateMap['latitude'] = latitude;
      }
      if (existingLng == null && longitude != null) {
        updateMap['longitude'] = longitude;
      }
      if (updateMap.isNotEmpty) {
        await db.update('stations', updateMap, where: 'id = ?', whereArgs: [id]);
      }

      return id;
    }
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
