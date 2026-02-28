class TrainService {
  final int? id;
  final String name;
  final String? operator;
  final String? mode;
  final String? description;

  TrainService({this.id, required this.name, this.operator, this.mode, this.description});

  factory TrainService.fromMap(Map<String, Object?> m) => TrainService(
        id: m['id'] as int?,
        name: m['name'] as String,
        operator: m['operator'] as String?,
        mode: m['mode'] as String?,
        description: m['description'] as String?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'operator': operator,
        'mode': mode,
        'description': description,
      };
}
