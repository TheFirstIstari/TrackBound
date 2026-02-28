class Station {
  final int? id;
  final String name;
  final String? code;
  final double? latitude;
  final double? longitude;

  Station({this.id, required this.name, this.code, this.latitude, this.longitude});

  factory Station.fromMap(Map<String, Object?> m) => Station(
        id: m['id'] as int?,
        name: m['name'] as String,
        code: m['code'] as String?,
        latitude: m['latitude'] as double?,
        longitude: m['longitude'] as double?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'code': code,
        'latitude': latitude,
        'longitude': longitude,
      };
}
