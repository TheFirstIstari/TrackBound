import 'dart:convert';
import 'dart:io';

String _coord(double value) => value.toStringAsFixed(6);

String _edgeKey(double aLat, double aLng, double bLat, double bLng) {
  final a = '${_coord(aLat)},${_coord(aLng)}';
  final b = '${_coord(bLat)},${_coord(bLng)}';
  return a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
}

Map<String, dynamic>? _edge(double aLat, double aLng, double bLat, double bLng) {
  if (aLat == bLat && aLng == bLng) return null;
  return {
    'edge_key': _edgeKey(aLat, aLng, bLat, bLng),
    'start_lat': aLat,
    'start_lng': aLng,
    'end_lat': bLat,
    'end_lng': bLng,
    'source_route_id': null,
    'travelled': 0,
  };
}

void _processLineCoordinates(List<dynamic> coords, Map<String, Map<String, dynamic>> out) {
  if (coords.length < 2) return;
  for (var i = 0; i < coords.length - 1; i++) {
    final a = coords[i];
    final b = coords[i + 1];
    if (a is! List || b is! List || a.length < 2 || b.length < 2) continue;

    final aLng = (a[0] as num).toDouble();
    final aLat = (a[1] as num).toDouble();
    final bLng = (b[0] as num).toDouble();
    final bLat = (b[1] as num).toDouble();

    final edge = _edge(aLat, aLng, bLat, bLng);
    if (edge == null) continue;
    out[edge['edge_key'] as String] = edge;
  }
}

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run tool/build_rail_seed.dart <input.geojson> <output.json>');
    exit(64);
  }

  final inputPath = args[0];
  final outputPath = args[1];

  final inputFile = File(inputPath);
  if (!await inputFile.exists()) {
    stderr.writeln('Input not found: $inputPath');
    exit(66);
  }

  final raw = await inputFile.readAsString();
  final parsed = jsonDecode(raw);

  if (parsed is! Map<String, dynamic>) {
    stderr.writeln('Invalid GeoJSON root object.');
    exit(65);
  }

  final features = parsed['features'];
  if (features is! List) {
    stderr.writeln('GeoJSON does not contain a features array.');
    exit(65);
  }

  final edgesByKey = <String, Map<String, dynamic>>{};

  for (final feature in features) {
    if (feature is! Map<String, dynamic>) continue;
    final geometry = feature['geometry'];
    if (geometry is! Map<String, dynamic>) continue;

    final type = geometry['type'];
    final coordinates = geometry['coordinates'];

    if (type == 'LineString' && coordinates is List) {
      _processLineCoordinates(coordinates, edgesByKey);
    } else if (type == 'MultiLineString' && coordinates is List) {
      for (final line in coordinates) {
        if (line is List) {
          _processLineCoordinates(line, edgesByKey);
        }
      }
    }
  }

  final edges = edgesByKey.values.toList()..sort((a, b) => (a['edge_key'] as String).compareTo(b['edge_key'] as String));

  final outFile = File(outputPath);
  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(const JsonEncoder.withIndent('  ').convert(edges));

  stdout.writeln('Wrote ${edges.length} unique rail edges to $outputPath');
}
