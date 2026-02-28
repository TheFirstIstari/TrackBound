import 'package:sqflite/sqflite.dart';
import '../database.dart';
import '../../models/journey_segment.dart';

class JourneySegmentDao {
  final Future<Database> _db = AppDatabase.instance.database;

  Future<int> insertSegment(JourneySegment s) async {
    final db = await _db;
    return await db.insert('journey_segments', s.toMap());
  }

  Future<List<JourneySegment>> getAllSegments() async {
    final db = await _db;
    final rows = await db.query('journey_segments');
    return rows.map((r) => JourneySegment.fromMap(r)).toList();
  }

  Future<List<JourneySegment>> getSegmentsForJourney(int journeyId) async {
    final db = await _db;
    final rows = await db.query('journey_segments', where: 'journey_id = ?', whereArgs: [journeyId]);
    return rows.map((r) => JourneySegment.fromMap(r)).toList();
  }
}
