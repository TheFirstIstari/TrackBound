import 'package:dio/dio.dart';

class StationLookupResult {
  final String name;
  final double latitude;
  final double longitude;
  final String source;

  const StationLookupResult({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.source,
  });
}

class StationLookup {
  final Dio _dio;

  StationLookup({Dio? dio}) : _dio = dio ?? Dio();

  Future<List<StationLookupResult>> search(String query, {int limit = 5}) async {
    final q = query.trim();
    if (q.isEmpty) return const <StationLookupResult>[];

    final response = await _dio.get(
      'https://nominatim.openstreetmap.org/search',
      queryParameters: {
        'q': '$q railway station',
        'format': 'jsonv2',
        'limit': limit,
        'countrycodes': 'gb',
      },
      options: Options(
        headers: {
          'User-Agent': 'TrackBound/0.1 (+https://github.com/your-username)',
          'From': 'your-email@example.com',
        },
      ),
    );

    final data = response.data;
    if (data is! List) return const <StationLookupResult>[];

    final out = <StationLookupResult>[];
    for (final raw in data) {
      if (raw is! Map) continue;
      final lat = double.tryParse('${raw['lat'] ?? ''}');
      final lon = double.tryParse('${raw['lon'] ?? ''}');
      final display = '${raw['display_name'] ?? ''}'.trim();
      if (lat == null || lon == null || display.isEmpty) continue;
      out.add(
        StationLookupResult(
          name: display.split(',').first.trim(),
          latitude: lat,
          longitude: lon,
          source: 'nominatim',
        ),
      );
    }

    return out;
  }
}
