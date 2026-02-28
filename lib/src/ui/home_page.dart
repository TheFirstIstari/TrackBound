import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
                onTap: () => Navigator.pushNamed(context, '/map'),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Add Journey'),
                subtitle: const Text('Log a new journey'),
                trailing: const Icon(Icons.add),
                onTap: () => Navigator.pushNamed(context, '/entry'),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Recent activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Expanded(
              child: Center(child: Text('No journeys yet — start by adding one.')),
            ),
          ],
        ),
      ),
    );
  }
}
