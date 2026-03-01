class JourneySegment {
  final int? id;
  final int journeyId;
  final int? routeId;
  final int? startPointIndex;
  final int? endPointIndex;
  final String? geometryWkt;
  final double? distanceM;

  JourneySegment({
    this.id,
    required this.journeyId,
    this.routeId,
    this.startPointIndex,
    this.endPointIndex,
    this.geometryWkt,
    this.distanceM,
  });

  factory JourneySegment.fromMap(Map<String, Object?> m) => JourneySegment(
        id: m['id'] as int?,
        journeyId: m['journey_id'] as int,
        routeId: m['route_id'] as int?,
        startPointIndex: m['start_point_index'] as int?,
        endPointIndex: m['end_point_index'] as int?,
        geometryWkt: m['geometry_wkt'] as String?,
        distanceM: (m['distance_m'] as num?)?.toDouble(),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'journey_id': journeyId,
        'route_id': routeId,
        'start_point_index': startPointIndex,
        'end_point_index': endPointIndex,
        'geometry_wkt': geometryWkt,
        'distance_m': distanceM,
      };
}
