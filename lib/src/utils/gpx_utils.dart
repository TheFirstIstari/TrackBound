import '../models/train_route.dart';

String routeToGpx(TrainRoute route) {
  // Convert WKT LINESTRING (lon lat, lon lat, ...) to GPX trkseg
  final wkt = route.geometryWkt;
  final buffer = StringBuffer();
  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buffer.writeln('<gpx version="1.1" creator="TrackBound">');
  buffer.writeln('  <trk>');
  buffer.writeln('    <name>${route.name ?? 'route-${route.id}'}</name>');
  buffer.writeln('    <trkseg>');
  if (wkt != null && wkt.toUpperCase().startsWith('LINESTRING')) {
    final inner = wkt.substring(wkt.indexOf('(') + 1, wkt.lastIndexOf(')'));
    final parts = inner.split(',').map((s) => s.trim()).toList();
    for (final p in parts) {
      final comps = p.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      if (comps.length >= 2) {
        final lon = comps[0];
        final lat = comps[1];
        buffer.writeln('      <trkpt lat="$lat" lon="$lon"></trkpt>');
      }
    }
  }
  buffer.writeln('    </trkseg>');
  buffer.writeln('  </trk>');
  buffer.writeln('</gpx>');
  return buffer.toString();
}
