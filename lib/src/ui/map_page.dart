import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

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
      await store.manage.create();
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

    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: FlutterMap(
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
          // Placeholder polyline overlay (replace with route geometry from DB)
          PolylineLayer(
            polylineCulling: true,
            polylines: [
              Polyline(
                points: [LatLng(51.5074, -0.1278), LatLng(52.4862, -1.8904)],
                color: Colors.blue,
                strokeWidth: 4.0,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
