import 'package:flutter/material.dart';
import '../db/daos/journey_dao.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Map<String, Object?>>> _recentFuture;

  @override
  void initState() {
    super.initState();
    _recentFuture = JourneyDao().getRecentJourneyActivity();
  }

  Future<void> _openAndRefresh(String route) async {
    await Navigator.pushNamed(context, route);
    if (!mounted) return;
    setState(() {
      _recentFuture = JourneyDao().getRecentJourneyActivity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TrackBound')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Welcome to TrackBound', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Map'),
                subtitle: const Text('View logged journeys and routes'),
                trailing: const Icon(Icons.map),
                onTap: () => _openAndRefresh('/map'),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Add Journey'),
                subtitle: const Text('Log a new journey'),
                trailing: const Icon(Icons.add),
                onTap: () => _openAndRefresh('/entry'),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Routes'),
                subtitle: const Text('Manage saved routes'),
                trailing: const Icon(Icons.alt_route),
                onTap: () => _openAndRefresh('/routes'),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Recent activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: _recentFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final rows = snapshot.data ?? <Map<String, Object?>>[];
                  if (rows.isEmpty) {
                    return const Center(child: Text('No journeys yet — start by adding one.'));
                  }

                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      final date = (row['date'] as String?) ?? 'Unknown date';
                      final start = (row['start_name'] as String?) ?? 'Unknown start';
                      final end = (row['end_name'] as String?) ?? 'Unknown end';
                      final trainNo = (row['train_number'] as String?) ?? '';
                      final id = row['id'];
                      final subtitle = trainNo.isEmpty ? '$start → $end' : '$start → $end • Train $trainNo';
                      return ListTile(
                        dense: true,
                        title: Text('$date  #$id'),
                        subtitle: Text(subtitle),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
