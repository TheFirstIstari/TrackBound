import 'package:flutter/material.dart';
import '../db/daos/route_dao.dart';
import '../models/train_route.dart';
import '../utils/gpx_utils.dart';
import 'map_page.dart';

class RoutesPage extends StatefulWidget {
  const RoutesPage({super.key});

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  final RouteDao _dao = RouteDao();
  late Future<List<TrainRoute>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _routesFuture = _dao.getAllRoutes();
  }

  Future<void> _renameRoute(TrainRoute r) async {
    final c = TextEditingController(text: r.name);
    final name = await showDialog<String?>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Rename Route'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Route name')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save'))],
      );
    });
    c.dispose();
    if (name == null || name.isEmpty) return;
    final updated = TrainRoute(id: r.id, serviceId: r.serviceId, name: name, geometryWkt: r.geometryWkt);
    await _dao.updateRoute(updated);
    setState(_load);
  }

  Future<void> _deleteRoute(TrainRoute r) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Delete route "${r.name ?? 'unnamed'}"?'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
      );
    });
    if (ok == true) {
      await _dao.deleteRoute(r.id!);
      setState(_load);
    }
  }

  Future<void> _exportGpx(TrainRoute r) async {
    final gpx = routeToGpx(r);
    // show as share/copy dialog — for now display the GPX text in a dialog with copy option
    final copied = await showDialog<bool?>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Export GPX'),
        content: SizedBox(width: 400, height: 300, child: SingleChildScrollView(child: SelectableText(gpx))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Close')),
        ],
      );
    });
    (copied); // noop
  }

  void _selectForJourney(TrainRoute r) {
    // navigate to JourneyEntryPage with routeId argument
    Navigator.pushNamed(context, '/entry', arguments: {'routeId': r.id});
  }

  void _viewOnMap(TrainRoute r) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MapPage(routeId: r.id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Routes')),
      body: FutureBuilder<List<TrainRoute>>(
        future: _routesFuture,
        builder: (context, snap) {
          final routes = snap.data ?? [];
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (routes.isEmpty) return const Center(child: Text('No routes saved'));
          return ListView.builder(
            itemCount: routes.length,
            itemBuilder: (ctx, i) {
              final r = routes[i];
              return ListTile(
                title: Text(r.name ?? 'Unnamed route'),
                subtitle: Text('ID: ${r.id ?? '-'}'),
                onTap: () => _viewOnMap(r),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'rename') _renameRoute(r);
                    if (v == 'delete') _deleteRoute(r);
                    if (v == 'export') _exportGpx(r);
                    if (v == 'select') _selectForJourney(r);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    const PopupMenuItem(value: 'export', child: Text('Export GPX')),
                    const PopupMenuItem(value: 'select', child: Text('Select for Journey')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
