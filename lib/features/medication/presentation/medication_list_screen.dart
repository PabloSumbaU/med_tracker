// lib/features/medication/presentation/medication_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'medication_controller.dart';
import '../domain/medication.dart';

class MedicationListScreen extends ConsumerWidget {
  const MedicationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicationState = ref.watch(medicationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Medicamentos'),
      ),
      body: medicationState.when(
        data: (medications) {
          if (medications.isEmpty) {
            return const Center(
              child: Text(
                'No tienes medicamentos registrados.\nPresiona + para añadir uno.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: medications.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final med = medications[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(_getIconForType(med.type)),
                  ),
                  title: Text(
                    med.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    med.description ?? 'Sin descripción de tratamiento',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      ref
                          .read(medicationControllerProvider.notifier)
                          .deleteMedication(med.id);
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error al cargar datos: $err'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-medication'),
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _getIconForType(MedicationType type) {
    switch (type) {
      case MedicationType.pastilla:
        return Icons.medication;
      case MedicationType.jarabe:
        return Icons.local_pharmacy;
      case MedicationType.inyeccion:
        return Icons.vaccines;
      default:
        return Icons.medical_services;
    }
  }
}