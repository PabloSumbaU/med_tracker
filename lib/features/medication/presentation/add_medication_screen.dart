// lib/features/medication/presentation/add_medication_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../domain/medication.dart';
import '../domain/dose_schedule.dart';
import 'medication_controller.dart';

class AddMedicationScreen extends ConsumerStatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  ConsumerState<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends ConsumerState<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _doseController = TextEditingController();

  MedicationType _selectedType = MedicationType.pastilla;
  final DoseFrequency _selectedFrequency = DoseFrequency.diaria;
  final List<TimeOfDay> _selectedTimes = [const TimeOfDay(hour: 8, minute: 0)];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _doseController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTimes[index],
    );
    if (picked != null) {
      setState(() {
        _selectedTimes[index] = picked;
      });
    }
  }

  void _addTimeSlot() {
    setState(() {
      _selectedTimes.add(const TimeOfDay(hour: 12, minute: 0));
    });
  }

  void _removeTimeSlot(int index) {
    if (_selectedTimes.length > 1) {
      setState(() {
        _selectedTimes.removeAt(index);
      });
    }
  }

  void _saveMedication() {
    if (_formKey.currentState!.validate()) {
      final medId = const Uuid().v4();

      // Convertimos los TimeOfDay a formato HH:MM (String)
      final formattedTimes = _selectedTimes.map((t) {
        final hour = t.hour.toString().padLeft(2, '0');
        final minute = t.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
      }).toList();

      final newMedication = Medication(
        id: medId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        type: _selectedType,
      );

      final newSchedule = DoseSchedule(
        medicationId: medId,
        dose: _doseController.text.trim(),
        frequency: _selectedFrequency,
        scheduledTimes: formattedTimes,
      );

      ref
          .read(medicationControllerProvider.notifier)
          .addMedication(newMedication, newSchedule);

      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir Medicamento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del medicamento *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Ingresa el nombre' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción del tratamiento (Opcional)',
                  hintText: 'Ej. Tomar con las comidas',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MedicationType>(
                decoration: const InputDecoration(
                  labelText: 'Presentación',
                  border: OutlineInputBorder(),
                ),
                items: MedicationType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _doseController,
                decoration: const InputDecoration(
                  labelText: 'Dosis *',
                  hintText: 'Ej. 1 pastilla, 5 ml',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Ingresa la dosis' : null,
              ),
              const SizedBox(height: 24),
              const Text(
                'Horarios de toma',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._selectedTimes.asMap().entries.map((entry) {
                final idx = entry.key;
                final time = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text('Hora: ${time.format(context)}'),
                          onPressed: () => _selectTime(idx),
                        ),
                      ),
                      if (_selectedTimes.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => _removeTimeSlot(idx),
                        ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                icon: const Icon(Icons.add_alarm),
                label: const Text('Añadir otra hora'),
                onPressed: _addTimeSlot,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveMedication,
                  child: const Text('Guardar Medicamento', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}