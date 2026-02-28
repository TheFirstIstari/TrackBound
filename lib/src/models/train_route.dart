class TrainRoute {
  final int? id;
  final int serviceId;
  final String? name;
  final String? geometryWkt;

  TrainRoute({this.id, required this.serviceId, this.name, this.geometryWkt});

  factory TrainRoute.fromMap(Map<String, Object?> m) => TrainRoute(
        id: m['id'] as int?,
        serviceId: (m['service_id'] ?? 0) as int,
        name: m['name'] as String?,
        geometryWkt: m['geometry_wkt'] as String?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'service_id': serviceId,
        'name': name,
        'geometry_wkt': geometryWkt,
      };
}
