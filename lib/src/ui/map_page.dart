import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'dart:math';
import '../db/daos/station_dao.dart';
import '../db/daos/journey_segment_dao.dart';
import '../db/daos/journey_dao.dart';
import '../db/daos/route_dao.dart';
import '../db/daos/rail_edge_dao.dart';
import '../models/rail_edge.dart';
import '../utils/rail_network_seed.dart';

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
  final List<RailEdge>? railEdges;
  final List<_VisitedStation> visitedStations;
  final LatLng initialCenter;
  final double initialZoom;

  const _MapData({
    required this.segmentLines,
    required this.routeLines,
    required this.railEdges,
    required this.visitedStations,
    required this.initialCenter,
    required this.initialZoom,
  });
}

class _RailGraph {
  final Map<String, LatLng> nodeCoords;
  final Map<String, List<String>> adjacency;
  final Map<String, List<String>> grid;
  final double cellSizeDeg;

  const _RailGraph({
    required this.nodeCoords,
    required this.adjacency,
    required this.grid,
    required this.cellSizeDeg,
  });
}

class _QueueNode {
  final String key;
  final double priority;

  const _QueueNode(this.key, this.priority);
}

class MapPage extends StatefulWidget {
  final int? routeId;
  const MapPage({super.key, this.routeId});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _prefCenterLat = 'map.center.lat';
  static const _prefCenterLng = 'map.center.lng';
  static const _prefZoom = 'map.zoom';

  bool _initialized = false;
  bool _showRailNetwork = true;
  bool _markTravelMode = false;
  double _currentZoom = 6.0;
  LatLngBounds? _visibleBounds;
  LatLng? _lastCullCenter;
  LatLng? _persistedCenter;
  double? _persistedZoom;
  _MapData? _currentMapData;
  final Map<String, List<LatLng>> _pathCache = <String, List<LatLng>>{};
  late Future<_MapData> _mapDataFuture;

  @override
  void initState() {
    super.initState();
    _loadPersistedCamera();
    _initCaching();
    _mapDataFuture = _loadMapDataWithSeed();
  }

  Future<void> _loadPersistedCamera() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_prefCenterLat);
      final lng = prefs.getDouble(_prefCenterLng);
      final zoom = prefs.getDouble(_prefZoom);
      if (lat != null && lng != null) {
        _persistedCenter = LatLng(lat, lng);
      }
      if (zoom != null) {
        _persistedZoom = zoom;
      }
      if (mounted) {
        setState(() {
          _mapDataFuture = _loadMapDataWithSeed();
        });
      }
    } catch (_) {
      // ignore persistence issues
    }
  }

  Future<void> _persistCamera(LatLng center, double zoom) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefCenterLat, center.latitude);
      await prefs.setDouble(_prefCenterLng, center.longitude);
      await prefs.setDouble(_prefZoom, zoom);
    } catch (_) {
      // ignore persistence issues
    }
  }

  void _refreshMapData() {
    setState(() {
      _mapDataFuture = _loadMapDataWithSeed(forceReseed: true);
    });
  }

  Future<void> _resetAllTravelled() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Progress'),
        content: const Text('Set all rail segments to untravelled?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );

    if (confirmed != true) return;

    final changed = await RailEdgeDao().resetAllTravelled();
    if (!mounted) return;

    _refreshMapData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reset travelled status on $changed segment(s)')),
    );
  }

  Future<void> _hardResetRailData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hard Reset Rail Data'),
        content: const Text('Clear all rail edges and reload from bundled seed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hard Reset')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final dao = RailEdgeDao();
      await dao.replaceWithSeedEdges(const <RailEdge>[], preserveTravelled: false);
      await RailNetworkSeed.ensureLoaded(force: true);
      _refreshMapData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rail data hard reset complete')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hard reset failed')),
      );
    }
  }

  Future<_MapData> _loadMapDataWithSeed({bool forceReseed = false}) async {
    await RailNetworkSeed.ensureLoaded(force: forceReseed);
    return _loadMapData();
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
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showRailNetwork = !_showRailNetwork),
            icon: Icon(_showRailNetwork ? Icons.railway_alert : Icons.railway_alert_outlined),
            tooltip: _showRailNetwork ? 'Rail network overlay: on' : 'Rail network overlay: off',
          ),
          IconButton(
            onPressed: () => setState(() => _markTravelMode = !_markTravelMode),
            icon: Icon(_markTravelMode ? Icons.playlist_add_check_circle : Icons.playlist_add_check),
            tooltip: _markTravelMode ? 'Mark travelled mode: on' : 'Mark travelled mode: off',
          ),
          IconButton(
            onPressed: _resetAllTravelled,
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset travelled segments',
          ),
          IconButton(
            onPressed: _hardResetRailData,
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Hard reset rail data',
          ),
          IconButton(
            onPressed: _showControlsHelp,
            icon: const Icon(Icons.help_outline),
            tooltip: 'Map controls help',
          ),
          IconButton(onPressed: _refreshMapData, icon: const Icon(Icons.refresh), tooltip: 'Refresh map data'),
        ],
      ),
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
                railEdges: <RailEdge>[],
                visitedStations: <_VisitedStation>[],
                initialCenter: LatLng(51.5074, -0.1278),
                initialZoom: 6.0,
              );
          _currentMapData = data;

          if (_currentZoom == 6.0 && data.initialZoom != 6.0) {
            _currentZoom = data.initialZoom;
          }

          final segmentPolylines = _buildSegmentPolylines(data.segmentLines, _currentZoom);
          final routePolylines = _buildRoutePolylines(data.routeLines, _currentZoom);
          final railEdges = data.railEdges ?? const <RailEdge>[];
          final railPolylines = _showRailNetwork ? _buildRailEdgePolylines(railEdges, _currentZoom, _visibleBounds) : const <Polyline>[];
          final stationMarkers = _buildStationMarkers(data.visitedStations, _currentZoom);

          return FlutterMap(
            options: MapOptions(
              center: data.initialCenter,
              zoom: data.initialZoom,
              onPositionChanged: (position, hasGesture) {
                final nextZoom = position.zoom ?? _currentZoom;
                final center = position.center;
                final bounds = position.bounds;

                var shouldRebuild = false;
                var updatedZoom = _currentZoom;

                if ((nextZoom - _currentZoom).abs() >= 0.35) {
                  updatedZoom = nextZoom;
                  shouldRebuild = true;
                }

                if (center != null) {
                  if (_lastCullCenter == null || _distanceMeters(_lastCullCenter!, center) > 1200) {
                    _lastCullCenter = center;
                    shouldRebuild = true;
                  }
                }

                if (bounds != null && (_visibleBounds == null || shouldRebuild)) {
                  shouldRebuild = true;
                }

                if (shouldRebuild) {
                  setState(() {
                    _currentZoom = updatedZoom;
                    if (bounds != null) {
                      _visibleBounds = bounds;
                    }
                  });
                }

                if (center != null) {
                  _persistCamera(center, nextZoom);
                }
              },
              onTap: (pos, latlng) {
                if (_markTravelMode) {
                  _toggleNearestRailEdge(latlng, railEdges);
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
              if (railPolylines.isNotEmpty) PolylineLayer(polylineCulling: true, polylines: railPolylines),
              if (segmentPolylines.isNotEmpty) PolylineLayer(polylineCulling: true, polylines: segmentPolylines),
              if (routePolylines.isNotEmpty) PolylineLayer(polylineCulling: true, polylines: routePolylines),
            ],
          );
        },
      ),
    );
  }

  void _showControlsHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Map Controls'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('• Rail overlay toggle: shows rail network segments.'),
              SizedBox(height: 6),
              Text('• Untravelled rail edges render at high zoom for performance.'),
              SizedBox(height: 6),
              Text('• Mark travelled toggle: tap near a rail edge to mark/unmark travelled.'),
              SizedBox(height: 6),
              Text('• Reset (restart icon): sets all rail segments to untravelled.'),
              SizedBox(height: 6),
              Text('• Hard reset (broom icon): clears rail edges and reloads bundled seed.'),
              SizedBox(height: 6),
              Text('• Drawing on the map is deprecated in this version.'),
              SizedBox(height: 6),
              Text('• Refresh: rechecks bundled rail seed and reloads DB-backed map layers.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<_MapData> _loadMapData() async {
    final segments = await JourneySegmentDao().getAllSegments();
    final fallbackLines = await JourneyDao().getFallbackJourneyLines();
    final routes = await RouteDao().getAllRoutes();
    final visitedStationsRows = await StationDao().getVisitedStations();
    final railEdgeDao = RailEdgeDao();
    final routeById = <int, List<LatLng>>{};

    for (final rt in routes) {
      if (rt.id == null) continue;
      final pts = _parseWktLineString(rt.geometryWkt);
      if (pts.isNotEmpty) {
        routeById[rt.id!] = pts;
      }
    }

    final railEdges = await railEdgeDao.getAllEdges();
    final railGraph = _buildRailGraph(railEdges);
    _pathCache.clear();

    final segmentLines = <List<LatLng>>[];
    final renderedJourneyIds = <int>{};

    for (final s in segments) {
      // Deprecated: direct segment geometry rendering (historical drawn straight lines).
      // Keep only route-linked segments and snap them to the rail graph.
      if (s.routeId == null) {
        continue;
      }

      final routePoints = routeById[s.routeId!];
      if (routePoints == null || routePoints.length < 2) {
        continue;
      }

      final candidate = _sliceRoutePoints(routePoints, s.startPointIndex, s.endPointIndex);
      if (candidate.length < 2) {
        continue;
      }

      final snapped = _snapPolylineToRailGraph(candidate, railGraph);
      if (snapped.length < 2) {
        continue;
      }

      segmentLines.add(snapped);
      renderedJourneyIds.add(s.journeyId);
    }

    for (final row in fallbackLines) {
      final journeyId = (row['id'] as num?)?.toInt();
      if (journeyId != null && renderedJourneyIds.contains(journeyId)) {
        continue;
      }

      final sLat = (row['start_lat'] as num?)?.toDouble();
      final sLng = (row['start_lng'] as num?)?.toDouble();
      final eLat = (row['end_lat'] as num?)?.toDouble();
      final eLng = (row['end_lng'] as num?)?.toDouble();
      if (sLat == null || sLng == null || eLat == null || eLng == null) continue;
      final start = LatLng(sLat, sLng);
      final end = LatLng(eLat, eLng);
      final graphPath = _findPathOnRailGraph(start, end, railGraph);
      if (graphPath.length >= 2) {
        segmentLines.add(graphPath);
      }
    }

    final routeLines = <List<LatLng>>[];
    List<LatLng> selectedPoints = const <LatLng>[];

    for (final rt in routes) {
      final pts = rt.id != null ? (routeById[rt.id!] ?? <LatLng>[]) : _parseWktLineString(rt.geometryWkt);
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

    if (_persistedCenter != null && _persistedZoom != null && widget.routeId == null) {
      initialCenter = _persistedCenter!;
      initialZoom = _persistedZoom!;
    } else if (selectedPoints.isNotEmpty) {
      initialCenter = _centroid(selectedPoints);
      initialZoom = 10.0;
    } else if (segmentLines.isNotEmpty && segmentLines.first.isNotEmpty) {
      initialCenter = segmentLines.first.first;
      initialZoom = 8.0;
    }

    return _MapData(
      segmentLines: segmentLines,
      routeLines: routeLines,
      railEdges: railEdges,
      visitedStations: visitedStations,
      initialCenter: initialCenter,
      initialZoom: initialZoom,
    );
  }

  List<Polyline> _buildRailEdgePolylines(List<RailEdge> edges, double zoom, LatLngBounds? bounds) {
    if (edges.isEmpty) return const <Polyline>[];

    final showUntravelled = zoom >= 13.0;
    final maxTravelled = zoom < 8 ? 3000 : 12000;
    final maxUntravelled = zoom < 14 ? 2500 : 8000;

    final out = <Polyline>[];
    var travelledCount = 0;
    var untravelledCount = 0;

    for (final edge in edges) {
      if (!_edgeIntersectsBounds(edge, bounds)) continue;

      if (edge.travelled) {
        if (travelledCount >= maxTravelled) continue;
        travelledCount += 1;
      } else {
        if (!showUntravelled) continue;
        if (untravelledCount >= maxUntravelled) continue;
        untravelledCount += 1;
      }

      out.add(
        Polyline(
          points: [LatLng(edge.startLat, edge.startLng), LatLng(edge.endLat, edge.endLng)],
          color: edge.travelled ? const Color.fromARGB(220, 76, 175, 80) : const Color.fromARGB(120, 120, 120, 120),
          strokeWidth: edge.travelled ? 4.5 : 2.0,
        ),
      );
    }
    return out;
  }

  bool _edgeIntersectsBounds(RailEdge edge, LatLngBounds? bounds) {
    // When bounds are not yet available (initial map load), consider the
    // edge for rendering so the UI can show travelled/untravelled state
    // according to zoom and caps. Previously this returned only
    // `edge.travelled` which suppressed untravelled segments on first draw.
    if (bounds == null) {
      return true;
    }
    final a = LatLng(edge.startLat, edge.startLng);
    final b = LatLng(edge.endLat, edge.endLng);
    if (bounds.contains(a) || bounds.contains(b)) {
      return true;
    }
    final mid = LatLng((edge.startLat + edge.endLat) / 2, (edge.startLng + edge.endLng) / 2);
    return bounds.contains(mid);
  }

  Future<void> _toggleNearestRailEdge(LatLng tap, List<RailEdge> edges) async {
    final edge = _findNearestEdge(tap, edges, maxDistanceMeters: 700);
    if (edge == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No nearby rail segment found')));
      return;
    }

    if (edge.sourceRouteId != null) {
      await RailEdgeDao().toggleTravelledBySourceRouteId(edge.sourceRouteId!);
      _applyLocalRailToggle(sourceRouteId: edge.sourceRouteId);
    } else {
      await RailEdgeDao().toggleTravelled(edge.id!);
      _applyLocalRailToggle(edgeId: edge.id);
    }
    if (!mounted) return;
    setState(() {
      if (_currentMapData != null) {
        _mapDataFuture = Future<_MapData>.value(_currentMapData!);
      } else {
        _mapDataFuture = _loadMapDataWithSeed();
      }
    });
  }

  void _applyLocalRailToggle({int? edgeId, int? sourceRouteId}) {
    final current = _currentMapData;
    if (current == null) return;
    final railEdges = current.railEdges;
    if (railEdges == null || railEdges.isEmpty) return;

    bool? nextTravelled;
    for (final edge in railEdges) {
      final matchesGroup = sourceRouteId != null && edge.sourceRouteId == sourceRouteId;
      final matchesEdge = sourceRouteId == null && edgeId != null && edge.id == edgeId;
      if (matchesGroup || matchesEdge) {
        nextTravelled = !edge.travelled;
        break;
      }
    }
    if (nextTravelled == null) return;

    final updated = railEdges.map((edge) {
      final matchesGroup = sourceRouteId != null && edge.sourceRouteId == sourceRouteId;
      final matchesEdge = sourceRouteId == null && edgeId != null && edge.id == edgeId;
      if (!(matchesGroup || matchesEdge)) {
        return edge;
      }
      return RailEdge(
        id: edge.id,
        edgeKey: edge.edgeKey,
        startLat: edge.startLat,
        startLng: edge.startLng,
        endLat: edge.endLat,
        endLng: edge.endLng,
        sourceRouteId: edge.sourceRouteId,
        travelled: nextTravelled!,
      );
    }).toList(growable: false);

    _currentMapData = _MapData(
      segmentLines: current.segmentLines,
      routeLines: current.routeLines,
      railEdges: updated,
      visitedStations: current.visitedStations,
      initialCenter: current.initialCenter,
      initialZoom: current.initialZoom,
    );
  }

  RailEdge? _findNearestEdge(LatLng point, List<RailEdge> edges, {required double maxDistanceMeters}) {
    final latRadius = maxDistanceMeters / 111320.0;
    final lngRadius = maxDistanceMeters / (111320.0 * cos(_toRadians(point.latitude)).abs().clamp(0.1, 1.0));

    final candidates = edges.where((edge) {
      final minLat = min(edge.startLat, edge.endLat);
      final maxLat = max(edge.startLat, edge.endLat);
      final minLng = min(edge.startLng, edge.endLng);
      final maxLng = max(edge.startLng, edge.endLng);
      final nearLat = !(point.latitude + latRadius < minLat || point.latitude - latRadius > maxLat);
      final nearLng = !(point.longitude + lngRadius < minLng || point.longitude - lngRadius > maxLng);
      return nearLat && nearLng;
    });

    RailEdge? best;
    var bestDistance = double.infinity;

    for (final edge in candidates) {
      if (edge.id == null) continue;
      final a = LatLng(edge.startLat, edge.startLng);
      final b = LatLng(edge.endLat, edge.endLng);
      final nearest = _nearestPointOnSegment(point, a, b);
      final distance = _distanceMeters(point, nearest);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = edge;
      }
    }

    if (best == null || bestDistance > maxDistanceMeters) {
      return null;
    }
    return best;
  }

  _RailGraph _buildRailGraph(List<RailEdge> edges) {
    const cellSize = 0.02;
    final nodeCoords = <String, LatLng>{};
    final adjacency = <String, List<String>>{};
    final grid = <String, List<String>>{};

    void addNode(LatLng p) {
      final key = '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}';
      if (nodeCoords.containsKey(key)) return;
      nodeCoords[key] = p;
      final cellKey = _gridCell(p.latitude, p.longitude, cellSize);
      grid.putIfAbsent(cellKey, () => <String>[]).add(key);
    }

    void addEdge(String a, String b) {
      adjacency.putIfAbsent(a, () => <String>[]);
      if (!adjacency[a]!.contains(b)) {
        adjacency[a]!.add(b);
      }
    }

    for (final edge in edges) {
      final a = LatLng(edge.startLat, edge.startLng);
      final b = LatLng(edge.endLat, edge.endLng);
      addNode(a);
      addNode(b);
      final aKey = '${a.latitude.toStringAsFixed(6)},${a.longitude.toStringAsFixed(6)}';
      final bKey = '${b.latitude.toStringAsFixed(6)},${b.longitude.toStringAsFixed(6)}';
      addEdge(aKey, bKey);
      addEdge(bKey, aKey);
    }

    return _RailGraph(
      nodeCoords: nodeCoords,
      adjacency: adjacency,
      grid: grid,
      cellSizeDeg: cellSize,
    );
  }

  String _gridCell(double lat, double lng, double cellSize) {
    final latCell = (lat / cellSize).floor();
    final lngCell = (lng / cellSize).floor();
    return '$latCell:$lngCell';
  }

  String? _findNearestRailNode(LatLng point, _RailGraph graph, {double maxDistanceMeters = 3000}) {
    if (graph.nodeCoords.isEmpty) return null;

    final latCell = (point.latitude / graph.cellSizeDeg).floor();
    final lngCell = (point.longitude / graph.cellSizeDeg).floor();

    String? bestKey;
    var bestDistance = double.infinity;

    for (var radius = 0; radius <= 6; radius++) {
      var foundInRadius = false;
      for (var dLat = -radius; dLat <= radius; dLat++) {
        for (var dLng = -radius; dLng <= radius; dLng++) {
          final key = '${latCell + dLat}:${lngCell + dLng}';
          final nodes = graph.grid[key];
          if (nodes == null || nodes.isEmpty) continue;
          foundInRadius = true;

          for (final nodeKey in nodes) {
            final nodePoint = graph.nodeCoords[nodeKey];
            if (nodePoint == null) continue;
            final d = _distanceMeters(point, nodePoint);
            if (d < bestDistance) {
              bestDistance = d;
              bestKey = nodeKey;
            }
          }
        }
      }
      if (bestKey != null && foundInRadius) {
        break;
      }
    }

    if (bestKey == null || bestDistance > maxDistanceMeters) {
      return null;
    }
    return bestKey;
  }

  List<LatLng> _findPathOnRailGraph(LatLng start, LatLng end, _RailGraph graph) {
    final startKey = _findNearestRailNode(start, graph);
    final endKey = _findNearestRailNode(end, graph);
    if (startKey == null || endKey == null) return const <LatLng>[];
    if (startKey == endKey) {
      final p = graph.nodeCoords[startKey];
      return p == null ? const <LatLng>[] : <LatLng>[p];
    }

    final cacheKey = '$startKey>$endKey';
    final cached = _pathCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final open = PriorityQueue<_QueueNode>((a, b) => a.priority.compareTo(b.priority));
    final cameFrom = <String, String>{};
    final gScore = <String, double>{startKey: 0.0};
    final fScore = <String, double>{
      startKey: _distanceMeters(graph.nodeCoords[startKey]!, graph.nodeCoords[endKey]!),
    };
    final closed = <String>{};

    open.add(_QueueNode(startKey, fScore[startKey]!));

    while (open.isNotEmpty) {
      final current = open.removeFirst().key;
      if (current == endKey) {
        final path = _reconstructPath(cameFrom, current, graph);
        if (_pathCache.length > 10000) {
          _pathCache.clear();
        }
        _pathCache[cacheKey] = path;
        return path;
      }
      if (!closed.add(current)) {
        continue;
      }

      final neighbors = graph.adjacency[current] ?? const <String>[];
      for (final neighbor in neighbors) {
        if (closed.contains(neighbor)) continue;
        final currentPoint = graph.nodeCoords[current];
        final neighborPoint = graph.nodeCoords[neighbor];
        if (currentPoint == null || neighborPoint == null) continue;

        final tentative = (gScore[current] ?? double.infinity) + _distanceMeters(currentPoint, neighborPoint);
        if (tentative < (gScore[neighbor] ?? double.infinity)) {
          cameFrom[neighbor] = current;
          gScore[neighbor] = tentative;
          final heuristic = _distanceMeters(neighborPoint, graph.nodeCoords[endKey]!);
          final score = tentative + heuristic;
          fScore[neighbor] = score;
          open.add(_QueueNode(neighbor, score));
        }
      }
    }

    return const <LatLng>[];
  }

  List<LatLng> _snapPolylineToRailGraph(List<LatLng> points, _RailGraph graph) {
    if (points.length < 2) return const <LatLng>[];

    final snapped = <LatLng>[];
    for (var i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      final graphPath = _findPathOnRailGraph(start, end, graph);
      if (graphPath.length < 2) {
        return const <LatLng>[];
      }

      if (snapped.isEmpty) {
        snapped.addAll(graphPath);
      } else {
        snapped.addAll(graphPath.skip(1));
      }
    }

    return snapped;
  }

  List<LatLng> _reconstructPath(Map<String, String> cameFrom, String current, _RailGraph graph) {
    final path = <LatLng>[];
    var cursor = current;
    final currentPoint = graph.nodeCoords[cursor];
    if (currentPoint != null) {
      path.add(currentPoint);
    }

    while (cameFrom.containsKey(cursor)) {
      cursor = cameFrom[cursor]!;
      final p = graph.nodeCoords[cursor];
      if (p != null) {
        path.add(p);
      }
    }

    return path.reversed.toList(growable: false);
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

  List<LatLng> _sliceRoutePoints(List<LatLng> points, int? startIdx, int? endIdx) {
    if (points.length < 2) return points;
    if (startIdx == null || endIdx == null) return points;

    var a = startIdx;
    var b = endIdx;
    if (a > b) {
      final t = a;
      a = b;
      b = t;
    }

    final start = a.clamp(0, points.length - 1);
    final end = b.clamp(0, points.length - 1);
    if (end - start < 1) return points;
    return points.sublist(start, end + 1);
  }

  LatLng _nearestPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final ax = a.longitude;
    final ay = a.latitude;
    final bx = b.longitude;
    final by = b.latitude;
    final px = p.longitude;
    final py = p.latitude;

    final dx = bx - ax;
    final dy = by - ay;
    final len2 = (dx * dx) + (dy * dy);
    if (len2 == 0) return a;

    final t = (((px - ax) * dx) + ((py - ay) * dy)) / len2;
    final clampedT = t.clamp(0.0, 1.0);
    return LatLng(ay + (dy * clampedT), ax + (dx * clampedT));
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLon = _toRadians(b.longitude - a.longitude);
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);

    final h =
        (sin(dLat / 2) * sin(dLat / 2)) +
        (sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2));
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return r * c;
  }

  double _toRadians(double deg) => deg * 0.017453292519943295;

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
