import 'package:sqflite/sqflite.dart';
import '../database.dart';
import '../../models/train_route.dart';

class RouteDao {
  final Future<Database> _db = AppDatabase.instance.database;

  Future<int> insertRoute(TrainRoute r) async {
    final db = await _db;
    return await db.insert('routes', r.toMap());
  }

  Future<int> updateRoute(TrainRoute r) async {
    final db = await _db;
    if (r.id == null) throw ArgumentError('Route id required for update');
    return await db.update('routes', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  }

  Future<int> deleteRoute(int id) async {
    final db = await _db;
    return await db.delete('routes', where: 'id = ?', whereArgs: [id]);
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
