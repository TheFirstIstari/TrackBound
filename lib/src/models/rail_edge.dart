class RailEdge {
  final int? id;
  final String edgeKey;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final int? sourceRouteId;
  final bool travelled;

  RailEdge({
    this.id,
    required this.edgeKey,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    this.sourceRouteId,
    required this.travelled,
  });

  factory RailEdge.fromMap(Map<String, Object?> m) => RailEdge(
        id: m['id'] as int?,
        edgeKey: m['edge_key'] as String,
        startLat: (m['start_lat'] as num).toDouble(),
        startLng: (m['start_lng'] as num).toDouble(),
        endLat: (m['end_lat'] as num).toDouble(),
        endLng: (m['end_lng'] as num).toDouble(),
        sourceRouteId: m['source_route_id'] as int?,
        travelled: ((m['travelled'] as num?)?.toInt() ?? 0) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'edge_key': edgeKey,
        'start_lat': startLat,
        'start_lng': startLng,
        'end_lat': endLat,
        'end_lng': endLng,
        'source_route_id': sourceRouteId,
        'travelled': travelled ? 1 : 0,
      };
}
