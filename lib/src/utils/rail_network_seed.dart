import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../db/daos/rail_edge_dao.dart';
import '../models/rail_edge.dart';

class RailNetworkSeed {
  static const _assetPath = 'assets/rail/rail_edges_seed.json';
  static const _prefSeedFingerprint = 'rail.seed.fingerprint.v1';
  static const _prefSeedCount = 'rail.seed.count.v1';
  static const _prefSeedSchemaVersion = 'rail.seed.schema.version.v1';
  static const _seedSchemaVersion = 2;

  static Future<void> ensureLoaded({bool force = false}) async {
    final dao = RailEdgeDao();
    final raw = await rootBundle.loadString(_assetPath);
    final seedEdges = _parseSeedEdges(raw);
    if (seedEdges.isEmpty) return;
    final fingerprint = _fnv1a32Hex(raw);

    final prefs = await SharedPreferences.getInstance();
    final previousFingerprint = prefs.getString(_prefSeedFingerprint);
    final previousSeedCount = prefs.getInt(_prefSeedCount);
    final previousSchemaVersion = prefs.getInt(_prefSeedSchemaVersion) ?? 0;
    final dbCount = await dao.getEdgeCount();

    final needsReseed =
        force ||
        dbCount == 0 ||
        dbCount != seedEdges.length ||
        previousSeedCount != seedEdges.length ||
        previousSchemaVersion != _seedSchemaVersion ||
        previousFingerprint != fingerprint;

    if (!needsReseed) return;

    await dao.replaceWithSeedEdges(seedEdges, preserveTravelled: true);
    await prefs.setString(_prefSeedFingerprint, fingerprint);
    await prefs.setInt(_prefSeedCount, seedEdges.length);
    await prefs.setInt(_prefSeedSchemaVersion, _seedSchemaVersion);
  }

  static List<RailEdge> _parseSeedEdges(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <RailEdge>[];

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

    return seedEdges;
  }

  static String _fnv1a32Hex(String input) {
    var hash = 0x811c9dc5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
