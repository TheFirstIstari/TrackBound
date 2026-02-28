import 'package:sqflite/sqflite.dart';
import '../database.dart';

class ServiceDao {
  final Future<Database> _db = AppDatabase.instance.database;

  Future<int> insertService(String name, {String? operator, String? mode, String? description}) async {
    final db = await _db;
    final existing = await db.query('train_services', where: 'name = ?', whereArgs: [name]);
    if (existing.isNotEmpty) return existing.first['id'] as int;
    return await db.insert('train_services', {
      'name': name,
      'operator': operator,
      'mode': mode,
      'description': description,
    });
  }

  Future<Map<String, Object?>?> getServiceById(int id) async {
    final db = await _db;
    final rows = await db.query('train_services', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }
}
