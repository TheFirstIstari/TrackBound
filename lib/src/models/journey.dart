class Journey {
  final int? id;
  final String date; // ISO date
  final int? startStationId;
  final int? endStationId;
  final int? serviceId;
  final String? trainNumber;
  final String? travelClass;
  final String? notes;
  final double? distanceM;

  Journey({
    this.id,
    required this.date,
    this.startStationId,
    this.endStationId,
    this.serviceId,
    this.trainNumber,
    this.travelClass,
    this.notes,
    this.distanceM,
  });

  factory Journey.fromMap(Map<String, Object?> m) => Journey(
        id: m['id'] as int?,
        date: m['date'] as String,
        startStationId: m['start_station_id'] as int?,
        endStationId: m['end_station_id'] as int?,
        serviceId: m['service_id'] as int?,
        trainNumber: m['train_number'] as String?,
        travelClass: m['class'] as String?,
        notes: m['notes'] as String?,
        distanceM: (m['distance_m'] as num?)?.toDouble(),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'start_station_id': startStationId,
        'end_station_id': endStationId,
        'service_id': serviceId,
        'train_number': trainNumber,
        'class': travelClass,
        'notes': notes,
        'distance_m': distanceM,
      };
}
