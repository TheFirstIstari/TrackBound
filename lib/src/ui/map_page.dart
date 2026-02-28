import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import '../db/daos/journey_segment_dao.dart';
import '../models/journey_segment.dart';
import 'package:flutter_map/plugin_api.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initCaching();
  }

  Future<void> _initCaching() async {
    try {
      await FlutterMapTileCaching.initialise();
      final store = FMTC.instance('trackbound');
      // create the store (synchronous on some versions) — do not await a void
      store.manage.create();
    } catch (_) {
      // ignore caching errors — map will still load from network
    }
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tileProvider = FMTC.instance('trackbound').getTileProvider();

    // load route/journey segment geometries from DB
    final segmentsFuture = JourneySegmentDao().getAllSegments();

    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: FutureBuilder<List<JourneySegment>>(
        future: segmentsFuture,
        builder: (context, snap) {
          final segments = snap.data ?? [];
          final polylines = segments.map((s) {
            final pts = _parseWktLineString(s.geometryWkt);
            return Polyline(points: pts, color: Colors.blue, strokeWidth: 4.0);
          }).where((p) => p.points.isNotEmpty).toList();

          return FlutterMap(
            options: MapOptions(
              center: LatLng(51.5074, -0.1278), // London as default
              zoom: 6.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.trackbound',
                tileProvider: tileProvider,
              ),
              if (polylines.isNotEmpty) PolylineLayer(polylineCulling: true, polylines: polylines),
            ],
          );
        },
      ),
    );
  }

  List<LatLng> _parseWktLineString(String? wkt) {
    if (wkt == null || !wkt.toUpperCase().startsWith('LINESTRING')) return [];
    final inner = wkt.substring(wkt.indexOf('(') + 1, wkt.lastIndexOf(')'));
    final parts = inner.split(',').map((s) => s.trim()).toList();
    final pts = <LatLng>[];
    for (final p in parts) {
      final comps = p.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      if (comps.length >= 2) {
        // assume WKT stored as 'lon lat'
        final lon = double.tryParse(comps[0]);
        final lat = double.tryParse(comps[1]);
        if (lat != null && lon != null) pts.add(LatLng(lat, lon));
      }
    }
    return pts;
  }
}
