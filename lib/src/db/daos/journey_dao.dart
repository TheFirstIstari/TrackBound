import 'package:sqflite/sqflite.dart';
import '../db/database.dart';
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

  Future<void> deleteJourney(int id) async {
    final db = await _db;
    await db.delete('journeys', where: 'id = ?', whereArgs: [id]);
  }
}
