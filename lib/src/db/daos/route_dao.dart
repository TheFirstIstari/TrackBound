import 'package:sqflite/sqflite.dart';
import '../database.dart';
import '../../models/train_route.dart';

class RouteDao {
  final Future<Database> _db = AppDatabase.instance.database;

  Future<int> insertRoute(TrainRoute r) async {
    final db = await _db;
    return await db.insert('routes', r.toMap());
  }

  Future<List<TrainRoute>> getAllRoutes() async {
    final db = await _db;
    final rows = await db.query('routes', orderBy: 'id DESC');
    return rows.map((r) => TrainRoute.fromMap(r)).toList();
  }

  Future<TrainRoute?> getRouteById(int id) async {
    final db = await _db;
    final rows = await db.query('routes', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return TrainRoute.fromMap(rows.first);
  }
}
