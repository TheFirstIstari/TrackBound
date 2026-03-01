import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../db/daos/rail_edge_dao.dart';
import '../models/rail_edge.dart';

class RailNetworkSeed {
  static const _assetPath = 'assets/rail/rail_edges_seed.json';

  static Future<void> ensureLoaded() async {
    final dao = RailEdgeDao();
    final count = await dao.getEdgeCount();
    if (count > 0) return;

    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;

    final seedEdges = <RailEdge>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final startLat = (entry['start_lat'] as num?)?.toDouble();
      final startLng = (entry['start_lng'] as num?)?.toDouble();
      final endLat = (entry['end_lat'] as num?)?.toDouble();
      final endLng = (entry['end_lng'] as num?)?.toDouble();
      final edgeKey = (entry['edge_key'] as String?)?.trim();
      final sourceRouteId = (entry['source_route_id'] as num?)?.toInt();
      final travelled = ((entry['travelled'] as num?)?.toInt() ?? 0) == 1;

      if (startLat == null || startLng == null || endLat == null || endLng == null) continue;
      if (edgeKey == null || edgeKey.isEmpty) continue;

      seedEdges.add(
        RailEdge(
          edgeKey: edgeKey,
          startLat: startLat,
          startLng: startLng,
          endLat: endLat,
          endLng: endLng,
          sourceRouteId: sourceRouteId,
          travelled: travelled,
        ),
      );
    }

    await dao.insertSeedEdges(seedEdges);
  }
}
