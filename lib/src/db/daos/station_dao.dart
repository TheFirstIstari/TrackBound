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

  Future<List<Map<String, Object?>>> searchStationsByName(String query, {int limit = 8}) async {
    final db = await _db;
    final q = query.trim();
    if (q.isEmpty) return const <Map<String, Object?>>[];
    final rows = await db.query(
      'stations',
      where: 'name LIKE ?',
      whereArgs: ['%$q%'],
      orderBy: 'name ASC',
      limit: limit,
    );
    return rows;
  }

  Future<List<Map<String, Object?>>> getVisitedStations() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      WITH visited AS (
        SELECT start_station_id AS station_id, date AS visited_date
        FROM journeys
        WHERE start_station_id IS NOT NULL
        UNION ALL
        SELECT end_station_id AS station_id, date AS visited_date
        FROM journeys
        WHERE end_station_id IS NOT NULL
      )
      SELECT
        s.id,
        s.name,
        s.code,
        s.latitude,
        s.longitude,
        COUNT(v.station_id) AS visit_count,
        MAX(v.visited_date) AS last_visited_date
      FROM visited v
      JOIN stations s ON s.id = v.station_id
      WHERE s.latitude IS NOT NULL AND s.longitude IS NOT NULL
      GROUP BY s.id, s.name, s.code, s.latitude, s.longitude
      ORDER BY visit_count DESC, s.name ASC
    ''');
    return rows;
  }
}
