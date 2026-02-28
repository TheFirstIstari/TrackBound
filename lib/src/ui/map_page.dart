import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import '../db/daos/journey_segment_dao.dart';
import '../models/journey_segment.dart';
import '../db/daos/route_dao.dart';
import '../models/train_route.dart';
import 'package:flutter_map/plugin_api.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  bool _initialized = false;
  bool _drawMode = false;
  final List<LatLng> _draftPoints = [];

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

    // Prepare headers required by OpenStreetMap tile usage policy.
    // Set your contact email here so requests include a From header.
    const contactEmail = 'your-email@example.com';
    const userAgent = 'TrackBound/0.1 (+https://github.com/your-username)';

    // Use NetworkTileProvider with headers to be compliant with OSM tile usage policy.
    final networkTileProvider = NetworkTileProvider(headers: {
      'User-Agent': userAgent,
      'From': contactEmail,
    });

    // load route/journey segment geometries from DB
    final segmentsFuture = JourneySegmentDao().getAllSegments();
    final routesFuture = RouteDao().getAllRoutes();

    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: FutureBuilder<List<JourneySegment>>(
        future: segmentsFuture,
        builder: (context, snap) {
          final segments = snap.data ?? [];
          return FutureBuilder<List<TrainRoute>>(
            future: routesFuture,
            builder: (context, rSnap) {
              final routes = rSnap.data ?? [];
              final polylines = segments.map((s) {
                final pts = _parseWktLineString(s.geometryWkt);
                return Polyline(points: pts, color: Colors.blue, strokeWidth: 4.0);
              }).where((p) => p.points.isNotEmpty).toList();

              final routePolylines = routes.map((rt) {
                final pts = _parseWktLineString(rt.geometryWkt);
                return Polyline(points: pts, color: Colors.red, strokeWidth: 3.0);
              }).where((p) => p.points.isNotEmpty).toList();

              final draftPolyline = _draftPoints.length > 1
                  ? [Polyline(points: _draftPoints, color: Colors.orange, strokeWidth: 3.0)]
                  : <Polyline>[];

              return FlutterMap(
                options: MapOptions(
                  center: LatLng(51.5074, -0.1278), // London as default
                  zoom: 6.0,
                  onTap: (pos, latlng) {
                    if (_drawMode) {
                      setState(() {
                        _draftPoints.add(latlng);
                      });
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    tileProvider: networkTileProvider,
                  ),
                  if (polylines.isNotEmpty) PolylineLayer(polylineCulling: true, polylines: polylines),
                  if (routePolylines.isNotEmpty) PolylineLayer(polylineCulling: true, polylines: routePolylines),
                  if (draftPolyline.isNotEmpty) PolylineLayer(polylineCulling: true, polylines: draftPolyline),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'draw',
            onPressed: () => setState(() => _drawMode = !_drawMode),
            child: Icon(_drawMode ? Icons.edit_off : Icons.draw),
            tooltip: _drawMode ? 'Exit draw mode' : 'Enter draw mode',
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'save',
            onPressed: _draftPoints.isNotEmpty ? _saveDraftAsRoute : null,
            child: const Icon(Icons.save),
            tooltip: 'Save drawn route',
          ),
        ],
      ),
    );
  }

  Future<void> _saveDraftAsRoute() async {
    if (_draftPoints.length < 2) return;
    final nameController = TextEditingController();
    final name = await showDialog<String?>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Save Route'),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Route name')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, nameController.text), child: const Text('Save'))],
      );
    });
    nameController.dispose();
    if (name == null || name.isEmpty) return;

    final coords = _draftPoints.map((p) => '${p.longitude} ${p.latitude}').join(', ');
    final wkt = 'LINESTRING($coords)';
    final rt = TrainRoute(serviceId: 0, name: name, geometryWkt: wkt);
    await RouteDao().insertRoute(rt);
    setState(() {
      _draftPoints.clear();
      _drawMode = false;
    });
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
