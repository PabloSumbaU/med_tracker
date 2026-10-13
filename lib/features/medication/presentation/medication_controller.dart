// lib/features/medication/presentation/medication_controller.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/medication_repository.dart';
import '../domain/medication.dart';
import '../domain/dose_schedule.dart';

final medicationControllerProvider =
    AsyncNotifierProvider<MedicationController, List<Medication>>(() {
  return MedicationController();
});

class MedicationController extends AsyncNotifier<List<Medication>> {
  @override
  FutureOr<List<Medication>> build() {
    // Carga inicial de medicamentos activos al instanciar la pantalla
    return ref.watch(medicationRepositoryProvider).getActiveMedications();
  }

  // Guardar nuevo medicamento
  Future<void> addMedication(Medication med, DoseSchedule schedule) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(medicationRepositoryProvider);
      await repo.insertMedicationWithSchedule(med, schedule);
      return repo.getActiveMedications();
    });
  }

  // Eliminar medicamento
  Future<void> deleteMedication(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(medicationRepositoryProvider);
      await repo.deleteMedication(id);
      return repo.getActiveMedications();
    });
  }
}