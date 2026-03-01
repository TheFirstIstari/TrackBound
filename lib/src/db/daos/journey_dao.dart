import 'package:sqflite/sqflite.dart';
import '../database.dart';
import '../../models/journey.dart';

class JourneyDao {
  final Future<Database> _db = AppDatabase.instance.database;

  Future<int> insertJourney(Journey j) async {
    final db = await _db;
    return await db.insert('journeys', j.toMap());
  }

  Future<List<Journey>> getAllJourneys() async {
    final db = await _db;
    final rows = await db.query('journeys', orderBy: 'date DESC');
    return rows.map((r) => Journey.fromMap(r)).toList();
  }

  Future<List<Map<String, Object?>>> getRecentJourneyActivity({int limit = 10}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        j.id,
        j.date,
        j.train_number,
        j.class,
        ss.name AS start_name,
        es.name AS end_name
      FROM journeys j
      LEFT JOIN stations ss ON ss.id = j.start_station_id
      LEFT JOIN stations es ON es.id = j.end_station_id
      ORDER BY j.date DESC, j.id DESC
      LIMIT ?
    ''', [limit]);
    return rows;
  }

  Future<List<Map<String, Object?>>> getFallbackJourneyLines() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        j.id,
        ss.latitude AS start_lat,
        ss.longitude AS start_lng,
        es.latitude AS end_lat,
        es.longitude AS end_lng
      FROM journeys j
      LEFT JOIN stations ss ON ss.id = j.start_station_id
      LEFT JOIN stations es ON es.id = j.end_station_id
      WHERE ss.latitude IS NOT NULL
        AND ss.longitude IS NOT NULL
        AND es.latitude IS NOT NULL
        AND es.longitude IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM journey_segments js
          WHERE js.journey_id = j.id
            AND js.geometry_wkt IS NOT NULL
            AND LENGTH(TRIM(js.geometry_wkt)) > 0
        )
      ORDER BY j.date DESC, j.id DESC
    ''');
    return rows;
  }

  Future<void> deleteJourney(int id) async {
    final db = await _db;
    await db.delete('journeys', where: 'id = ?', whereArgs: [id]);
  }
}
