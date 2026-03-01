import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'dart:ui';
import '../db/daos/journey_segment_dao.dart';
import '../db/daos/journey_dao.dart';
import '../db/daos/route_dao.dart';
import '../models/train_route.dart';

class _MapData {
  final List<Polyline> segmentPolylines;
  final List<Polyline> routePolylines;
  final LatLng initialCenter;
  final double initialZoom;

  const _MapData({
    required this.segmentPolylines,
    required this.routePolylines,
    required this.initialCenter,
    required this.initialZoom,
  });
}

class MapPage extends StatefulWidget {
  final int? routeId;
  const MapPage({super.key, this.routeId});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  bool _initialized = false;
  bool _drawMode = false;
  final List<LatLng> _draftPoints = [];
  late Future<_MapData> _mapDataFuture;

  @override
  void initState() {
    super.initState();
    _initCaching();
    _mapDataFuture = _loadMapData();
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

    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: FutureBuilder<_MapData>(
        future: _mapDataFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load map data: ${snap.error}'));
          }

          final data = snap.data ??
              _MapData(
                segmentPolylines: <Polyline>[],
                routePolylines: <Polyline>[],
                initialCenter: LatLng(51.5074, -0.1278),
                initialZoom: 6.0,
              );

          final draftPolyline = _draftPoints.length > 1
              ? [Polyline(points: _draftPoints, color: Colors.orange, strokeWidth: 3.0)]
              : <Polyline>[];

          return FlutterMap(
            options: MapOptions(
              center: data.initialCenter,
              zoom: data.initialZoom,
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
              if (data.segmentPolylines.isNotEmpty) PolylineLayer(polylineCulling: true, polylines: data.segmentPolylines),
              if (data.routePolylines.isNotEmpty) PolylineLayer(polylineCulling: true, polylines: data.routePolylines),
              if (draftPolyline.isNotEmpty) PolylineLayer(polylineCulling: true, polylines: draftPolyline),
            ],
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
      _mapDataFuture = _loadMapData();
    });
  }

  Future<_MapData> _loadMapData() async {
    final segments = await JourneySegmentDao().getAllSegments();
    final fallbackLines = await JourneyDao().getFallbackJourneyLines();
    final routes = await RouteDao().getAllRoutes();

    final segmentPolylines = <Polyline>[
      ...segments
        .map((s) {
          final pts = _parseWktLineString(s.geometryWkt);
          return Polyline(points: pts, color: Colors.blue, strokeWidth: 4.0);
        })
        .where((p) => p.points.isNotEmpty)
        .toList(),
    ];

    for (final row in fallbackLines) {
      final sLat = (row['start_lat'] as num?)?.toDouble();
      final sLng = (row['start_lng'] as num?)?.toDouble();
      final eLat = (row['end_lat'] as num?)?.toDouble();
      final eLng = (row['end_lng'] as num?)?.toDouble();
      if (sLat == null || sLng == null || eLat == null || eLng == null) continue;
      segmentPolylines.add(
        Polyline(
          points: [LatLng(sLat, sLng), LatLng(eLat, eLng)],
          color: const Color.fromARGB(180, 33, 150, 243),
          strokeWidth: 4.0,
        ),
      );
    }

    final routePolylines = <Polyline>[];
    List<LatLng> selectedPoints = const <LatLng>[];

    for (final rt in routes) {
      final pts = _parseWktLineString(rt.geometryWkt);
      if (pts.isEmpty) continue;
      final isSelected = widget.routeId != null && rt.id == widget.routeId;
      if (isSelected) {
        selectedPoints = pts;
      }
      routePolylines.add(
        Polyline(
          points: pts,
          color: isSelected ? Colors.deepOrange : Colors.red,
          strokeWidth: isSelected ? 5.0 : 3.0,
        ),
      );
    }

    LatLng initialCenter = LatLng(51.5074, -0.1278);
    double initialZoom = 6.0;

    if (selectedPoints.isNotEmpty) {
      initialCenter = _centroid(selectedPoints);
      initialZoom = 10.0;
    } else if (segmentPolylines.isNotEmpty && segmentPolylines.first.points.isNotEmpty) {
      initialCenter = segmentPolylines.first.points.first;
      initialZoom = 8.0;
    }

    return _MapData(
      segmentPolylines: segmentPolylines,
      routePolylines: routePolylines,
      initialCenter: initialCenter,
      initialZoom: initialZoom,
    );
  }

  LatLng _centroid(List<LatLng> points) {
    double lat = 0;
    double lon = 0;
    for (final p in points) {
      lat += p.latitude;
      lon += p.longitude;
    }
    return LatLng(lat / points.length, lon / points.length);
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
