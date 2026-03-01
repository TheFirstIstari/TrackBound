import 'package:sqflite/sqflite.dart';
import 'package:latlong2/latlong.dart';
import '../database.dart';
import '../../models/rail_edge.dart';

class RailEdgeDao {
  final Future<Database> _db = AppDatabase.instance.database;

  String _coord(double value) => value.toStringAsFixed(6);

  String _edgeKey(LatLng a, LatLng b) {
    final aKey = '${_coord(a.latitude)},${_coord(a.longitude)}';
    final bKey = '${_coord(b.latitude)},${_coord(b.longitude)}';
    return aKey.compareTo(bKey) <= 0 ? '$aKey|$bKey' : '$bKey|$aKey';
  }

  Future<void> upsertEdgesFromLine(List<LatLng> points, {int? sourceRouteId}) async {
    if (points.length < 2) return;
    final db = await _db;
    final batch = db.batch();

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (a.latitude == b.latitude && a.longitude == b.longitude) continue;
      final key = _edgeKey(a, b);
      batch.rawInsert(
        '''
        INSERT OR IGNORE INTO rail_edges(
          edge_key, start_lat, start_lng, end_lat, end_lng, source_route_id, travelled
        ) VALUES (?, ?, ?, ?, ?, ?, 0)
        ''',
        [key, a.latitude, a.longitude, b.latitude, b.longitude, sourceRouteId],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<RailEdge>> getAllEdges() async {
    final db = await _db;
    final rows = await db.query('rail_edges', orderBy: 'id ASC');
    return rows.map((r) => RailEdge.fromMap(r)).toList();
  }

  Future<int> toggleTravelled(int id) async {
    final db = await _db;
    return await db.rawUpdate('''
      UPDATE rail_edges
      SET travelled = CASE travelled WHEN 1 THEN 0 ELSE 1 END
      WHERE id = ?
    ''', [id]);
  }
}
