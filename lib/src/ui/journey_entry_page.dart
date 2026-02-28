import 'package:flutter/material.dart';

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
  final _operatorCtrl = TextEditingController();
  final _trainNoCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _dateCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _operatorCtrl.dispose();
    _trainNoCtrl.dispose();
    _classCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      // TODO: hook into DB layer
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Journey saved (stub)')));
      Navigator.pop(context);
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
              TextFormField(
                controller: _endCtrl,
                decoration: const InputDecoration(labelText: 'End Station'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
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
