import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/ui/home_page.dart';
import 'src/ui/map_page.dart';
import 'src/ui/journey_entry_page.dart';

void main() {
  runApp(const ProviderScope(child: TrackBoundApp()));
}

class TrackBoundApp extends StatelessWidget {
  const TrackBoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrackBound',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/map': (context) => const MapPage(),
        '/entry': (context) => const JourneyEntryPage(),
      },
    );
  }
}
