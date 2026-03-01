import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import '../db/daos/station_dao.dart';
import '../db/daos/journey_segment_dao.dart';
import '../db/daos/journey_dao.dart';
import '../db/daos/route_dao.dart';
import '../models/train_route.dart';

class _VisitedStation {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final int visitCount;

  const _VisitedStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.visitCount,
  });
}

class _MapData {
  final List<List<LatLng>> segmentLines;
  final List<List<LatLng>> routeLines;
  final List<_VisitedStation> visitedStations;
  final LatLng initialCenter;
  final double initialZoom;

  const _MapData({
    required this.segmentLines,
    required this.routeLines,
    required this.visitedStations,
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
  double _currentZoom = 6.0;
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
                segmentLines: <List<LatLng>>[],
                routeLines: <List<LatLng>>[],
                visitedStations: <_VisitedStation>[],
                initialCenter: LatLng(51.5074, -0.1278),
                initialZoom: 6.0,
              );

          if (_currentZoom == 6.0 && data.initialZoom != 6.0) {
            _currentZoom = data.initialZoom;
          }

          final segmentPolylines = _buildSegmentPolylines(data.segmentLines, _currentZoom);
          final routePolylines = _buildRoutePolylines(data.routeLines, _currentZoom);
          final stationMarkers = _buildStationMarkers(data.visitedStations, _currentZoom);

          final draftPolyline = _draftPoints.length > 1
              ? [Polyline(points: _draftPoints, color: Colors.orange, strokeWidth: 3.0)]
              : <Polyline>[];

          return FlutterMap(
            options: MapOptions(
              center: data.initialCenter,
              zoom: data.initialZoom,
              onPositionChanged: (position, hasGesture) {
                final nextZoom = position.zoom ?? _currentZoom;
                if ((nextZoom - _currentZoom).abs() >= 0.25) {
                  setState(() => _currentZoom = nextZoom);
                }
              },
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
              if (stationMarkers.isNotEmpty) MarkerLayer(markers: stationMarkers),
              if (segmentPolylines.isNotEmpty) PolylineLayer(polylineCulling: true, polylines: segmentPolylines),
              if (routePolylines.isNotEmpty) PolylineLayer(polylineCulling: true, polylines: routePolylines),
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
    final visitedStationsRows = await StationDao().getVisitedStations();

    final segmentLines = <List<LatLng>>[
      ...segments
        .map((s) {
          return _parseWktLineString(s.geometryWkt);
        })
        .where((points) => points.isNotEmpty)
        .toList(),
    ];

    for (final row in fallbackLines) {
      final sLat = (row['start_lat'] as num?)?.toDouble();
      final sLng = (row['start_lng'] as num?)?.toDouble();
      final eLat = (row['end_lat'] as num?)?.toDouble();
      final eLng = (row['end_lng'] as num?)?.toDouble();
      if (sLat == null || sLng == null || eLat == null || eLng == null) continue;
      segmentLines.add([LatLng(sLat, sLng), LatLng(eLat, eLng)]);
    }

    final routeLines = <List<LatLng>>[];
    List<LatLng> selectedPoints = const <LatLng>[];

    for (final rt in routes) {
      final pts = _parseWktLineString(rt.geometryWkt);
      if (pts.isEmpty) continue;
      final isSelected = widget.routeId != null && rt.id == widget.routeId;
      if (isSelected) {
        selectedPoints = pts;
      }
      routeLines.add(pts);
    }

    final visitedStations = visitedStationsRows.map((row) {
      return _VisitedStation(
        id: row['id'] as int,
        name: (row['name'] as String?) ?? 'Station',
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        visitCount: (row['visit_count'] as num?)?.toInt() ?? 1,
      );
    }).toList();

    if (visitedStations.isNotEmpty && selectedPoints.isEmpty) {
      final first = visitedStations.first;
      selectedPoints = [LatLng(first.latitude, first.longitude)];
    }

    LatLng initialCenter = LatLng(51.5074, -0.1278);
    double initialZoom = 6.0;

    if (selectedPoints.isNotEmpty) {
      initialCenter = _centroid(selectedPoints);
      initialZoom = 10.0;
    } else if (segmentLines.isNotEmpty && segmentLines.first.isNotEmpty) {
      initialCenter = segmentLines.first.first;
      initialZoom = 8.0;
    }

    return _MapData(
      segmentLines: segmentLines,
      routeLines: routeLines,
      visitedStations: visitedStations,
      initialCenter: initialCenter,
      initialZoom: initialZoom,
    );
  }

  List<Polyline> _buildSegmentPolylines(List<List<LatLng>> lines, double zoom) {
    return lines
        .map((line) => _simplifyLineForZoom(line, zoom))
        .where((line) => line.length >= 2)
        .map(
          (line) => Polyline(
            points: line,
            color: const Color.fromARGB(210, 33, 150, 243),
            strokeWidth: zoom <= 6 ? 2.5 : 4.0,
          ),
        )
        .toList();
  }

  List<Polyline> _buildRoutePolylines(List<List<LatLng>> lines, double zoom) {
    if (zoom < 7.0) {
      return const <Polyline>[];
    }
    return lines
        .map((line) => _simplifyLineForZoom(line, zoom))
        .where((line) => line.length >= 2)
        .map(
          (line) => Polyline(
            points: line,
            color: Colors.red,
            strokeWidth: zoom < 10 ? 2.0 : 3.0,
          ),
        )
        .toList();
  }

  List<Marker> _buildStationMarkers(List<_VisitedStation> stations, double zoom) {
    if (stations.isEmpty) return const <Marker>[];

    if (zoom < 7.0) {
      final cellSize = zoom < 5.0 ? 2.0 : 1.0;
      final clusters = <String, List<_VisitedStation>>{};

      for (final s in stations) {
        final keyLat = (s.latitude / cellSize).floor();
        final keyLng = (s.longitude / cellSize).floor();
        final key = '$keyLat:$keyLng';
        clusters.putIfAbsent(key, () => <_VisitedStation>[]).add(s);
      }

      return clusters.values.map((cluster) {
        final totalVisits = cluster.fold<int>(0, (sum, s) => sum + s.visitCount);
        final avgLat = cluster.map((s) => s.latitude).reduce((a, b) => a + b) / cluster.length;
        final avgLng = cluster.map((s) => s.longitude).reduce((a, b) => a + b) / cluster.length;
        return Marker(
          point: LatLng(avgLat, avgLng),
          width: 42,
          height: 42,
          builder: (_) => Container(
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$totalVisits',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        );
      }).toList();
    }

    return stations.map((s) {
      return Marker(
        point: LatLng(s.latitude, s.longitude),
        width: 24,
        height: 24,
        builder: (_) => Tooltip(
          message: '${s.name} (${s.visitCount})',
          child: const Icon(Icons.location_pin, color: Colors.indigo, size: 22),
        ),
      );
    }).toList();
  }

  List<LatLng> _simplifyLineForZoom(List<LatLng> points, double zoom) {
    if (points.length <= 2) return points;
    int stride;
    if (zoom <= 5.0) {
      stride = 8;
    } else if (zoom <= 7.0) {
      stride = 4;
    } else if (zoom <= 9.0) {
      stride = 2;
    } else {
      stride = 1;
    }

    if (stride == 1) return points;

    final simplified = <LatLng>[];
    for (var i = 0; i < points.length; i += stride) {
      simplified.add(points[i]);
    }
    if (simplified.last != points.last) {
      simplified.add(points.last);
    }
    return simplified;
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
