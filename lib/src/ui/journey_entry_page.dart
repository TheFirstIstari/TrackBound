import 'package:flutter/material.dart';
import '../db/daos/journey_dao.dart';
import '../db/daos/station_dao.dart';
import '../db/daos/journey_segment_dao.dart';
import '../db/database.dart';
import '../models/journey.dart';
import '../models/journey_segment.dart';

class JourneyEntryPage extends StatefulWidget {
  const JourneyEntryPage({super.key});

  @override
  State<JourneyEntryPage> createState() => _JourneyEntryPageState();
}

class _JourneyEntryPageState extends State<JourneyEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _dateCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _startLatCtrl = TextEditingController();
  final _startLngCtrl = TextEditingController();
  final _endLatCtrl = TextEditingController();
  final _endLngCtrl = TextEditingController();
  final _operatorCtrl = TextEditingController();
  final _trainNoCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int? _selectedRouteId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedRouteId != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final routeId = args['routeId'];
      if (routeId is int) {
        _selectedRouteId = routeId;
      }
    }
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _startLatCtrl.dispose();
    _startLngCtrl.dispose();
    _endLatCtrl.dispose();
    _endLngCtrl.dispose();
    _operatorCtrl.dispose();
    _trainNoCtrl.dispose();
    _classCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final journey = Journey(
        date: _dateCtrl.text,
        startStationId: null,
        endStationId: null,
        serviceId: null,
        trainNumber: _trainNoCtrl.text.isEmpty ? null : _trainNoCtrl.text,
        travelClass: _classCtrl.text.isEmpty ? null : _classCtrl.text,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        distanceM: null,
      );

      JourneyDao().insertJourney(journey).then((id) async {
        int? startId;
        int? endId;
        final stationDao = StationDao();
        try {
          final sLat = double.tryParse(_startLatCtrl.text);
          final sLng = double.tryParse(_startLngCtrl.text);
          if (sLat != null && sLng != null) {
            startId = await stationDao.insertStation(_startCtrl.text, latitude: sLat, longitude: sLng);
          } else if (_startCtrl.text.isNotEmpty) {
            startId = await stationDao.insertStation(_startCtrl.text);
          }

          final eLat = double.tryParse(_endLatCtrl.text);
          final eLng = double.tryParse(_endLngCtrl.text);
          if (eLat != null && eLng != null) {
            endId = await stationDao.insertStation(_endCtrl.text, latitude: eLat, longitude: eLng);
          } else if (_endCtrl.text.isNotEmpty) {
            endId = await stationDao.insertStation(_endCtrl.text);
          }

          // update journey with station ids
          final db = await AppDatabase.instance.database;
          await db.update('journeys', {'start_station_id': startId, 'end_station_id': endId}, where: 'id = ?', whereArgs: [id]);

          // create a simple LINESTRING geometry if coordinates available
          if (sLat != null && sLng != null && eLat != null && eLng != null) {
            final wkt = 'LINESTRING(${sLng.toString()} ${sLat.toString()}, ${eLng.toString()} ${eLat.toString()})';
            final seg = JourneySegment(journeyId: id, routeId: _selectedRouteId, geometryWkt: wkt);
            await JourneySegmentDao().insertSegment(seg);
          }
        } catch (e) {
          // ignore station/segment save errors
        }

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Journey saved')));
        Navigator.pop(context);
      }).catchError((e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Journey')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _dateCtrl,
                decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _startCtrl,
                decoration: const InputDecoration(labelText: 'Start Station'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              Row(children: [
                Expanded(child: TextFormField(controller: _startLatCtrl, decoration: const InputDecoration(labelText: 'Start Lat'))),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _startLngCtrl, decoration: const InputDecoration(labelText: 'Start Lng'))),
              ]),
              TextFormField(
                controller: _endCtrl,
                decoration: const InputDecoration(labelText: 'End Station'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              if (_selectedRouteId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('Selected Route ID: $_selectedRouteId', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              Row(children: [
                Expanded(child: TextFormField(controller: _endLatCtrl, decoration: const InputDecoration(labelText: 'End Lat'))),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _endLngCtrl, decoration: const InputDecoration(labelText: 'End Lng'))),
              ]),
              TextFormField(
                controller: _operatorCtrl,
                decoration: const InputDecoration(labelText: 'Operator'),
              ),
              TextFormField(
                controller: _trainNoCtrl,
                decoration: const InputDecoration(labelText: 'Train Number'),
              ),
              TextFormField(
                controller: _classCtrl,
                decoration: const InputDecoration(labelText: 'Class'),
              ),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _submit, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}
