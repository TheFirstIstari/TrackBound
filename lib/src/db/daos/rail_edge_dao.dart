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

  Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rail_edges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        edge_key TEXT NOT NULL UNIQUE,
        start_lat REAL NOT NULL,
        start_lng REAL NOT NULL,
        end_lat REAL NOT NULL,
        end_lng REAL NOT NULL,
        source_route_id INTEGER REFERENCES routes(id) ON DELETE SET NULL,
        travelled INTEGER NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rail_edges_travelled ON rail_edges(travelled)');
  }

  Future<void> upsertEdgesFromLine(List<LatLng> points, {int? sourceRouteId}) async {
    if (points.length < 2) return;
    final db = await _db;
    await _ensureSchema(db);
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

  Future<int> getEdgeCount() async {
    final db = await _db;
    await _ensureSchema(db);
    final row = await db.rawQuery('SELECT COUNT(*) AS c FROM rail_edges');
    return (row.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<void> insertSeedEdges(List<RailEdge> edges) async {
    if (edges.isEmpty) return;
    final db = await _db;
    await _ensureSchema(db);
    final batch = db.batch();

    for (final edge in edges) {
      batch.rawInsert(
        '''
        INSERT OR IGNORE INTO rail_edges(
          edge_key, start_lat, start_lng, end_lat, end_lng, source_route_id, travelled
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          edge.edgeKey,
          edge.startLat,
          edge.startLng,
          edge.endLat,
          edge.endLng,
          edge.sourceRouteId,
          edge.travelled ? 1 : 0,
        ],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> replaceWithSeedEdges(List<RailEdge> edges, {bool preserveTravelled = true}) async {
    final db = await _db;
    await _ensureSchema(db);

    await db.transaction((txn) async {
      final travelledByKey = <String, int>{};
      if (preserveTravelled) {
        final current = await txn.query('rail_edges', columns: ['edge_key', 'travelled']);
        for (final row in current) {
          final edgeKey = (row['edge_key'] as String?)?.trim();
          if (edgeKey == null || edgeKey.isEmpty) continue;
          final travelled = ((row['travelled'] as num?)?.toInt() ?? 0) == 1 ? 1 : 0;
          if (travelled == 1) {
            travelledByKey[edgeKey] = 1;
          }
        }
      }

      await txn.delete('rail_edges');
      if (edges.isEmpty) return;

      final batch = txn.batch();
      for (final edge in edges) {
        final travelled = preserveTravelled
            ? (travelledByKey[edge.edgeKey] ?? (edge.travelled ? 1 : 0))
            : (edge.travelled ? 1 : 0);

        batch.rawInsert(
          '''
          INSERT INTO rail_edges(
            edge_key, start_lat, start_lng, end_lat, end_lng, source_route_id, travelled
          ) VALUES (?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            edge.edgeKey,
            edge.startLat,
            edge.startLng,
            edge.endLat,
            edge.endLng,
            edge.sourceRouteId,
            travelled,
          ],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<RailEdge>> getAllEdges() async {
    final db = await _db;
    await _ensureSchema(db);
    final rows = await db.query('rail_edges', orderBy: 'id ASC');
    return rows.map((r) => RailEdge.fromMap(r)).toList();
  }

  Future<int> toggleTravelled(int id) async {
    final db = await _db;
    await _ensureSchema(db);
    return await db.rawUpdate('''
      UPDATE rail_edges
      SET travelled = CASE travelled WHEN 1 THEN 0 ELSE 1 END
      WHERE id = ?
    ''', [id]);
  }

  Future<int> toggleTravelledBySourceRouteId(int sourceRouteId) async {
    final db = await _db;
    await _ensureSchema(db);
    final current = await db.rawQuery(
      'SELECT travelled FROM rail_edges WHERE source_route_id = ? LIMIT 1',
      [sourceRouteId],
    );
    if (current.isEmpty) return 0;
    final currentValue = ((current.first['travelled'] as num?)?.toInt() ?? 0) == 1;
    final nextValue = currentValue ? 0 : 1;
    return await db.rawUpdate(
      'UPDATE rail_edges SET travelled = ? WHERE source_route_id = ?',
      [nextValue, sourceRouteId],
    );
  }
}
