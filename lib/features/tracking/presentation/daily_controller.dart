// lib/features/tracking/presentation/daily_controller.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/tracking_repository.dart';
import '../domain/tracking_log.dart';
import '../../medication/data/medication_repository.dart';

// Modelo auxiliar para mostrar el nombre del medicamento junto con su log en la UI
class DailyTaskItem {
  final TrackingLog log;
  final String medicationName;
  final String dose;

  DailyTaskItem({required this.log, required this.medicationName, required this.dose});
}

final dailyControllerProvider = AsyncNotifierProvider<DailyController, List<DailyTaskItem>>(() {
  return DailyController();
});

class DailyController extends AsyncNotifier<List<DailyTaskItem>> {
  @override
  FutureOr<List<DailyTaskItem>> build() async {
    return _loadTodayTasks();
  }

  Future<List<DailyTaskItem>> _loadTodayTasks() async {
    final today = DateTime.now();
    final medRepo = ref.read(medicationRepositoryProvider);
    final trackingRepo = ref.read(trackingRepositoryProvider);

    final activeMeds = await medRepo.getActiveMedications();
    
    // Necesitamos también los esquemas de dosis para saber qué hora le toca a cada uno
    // (Asumiendo que puedes obtenerlos o guardarlos en un mapa rápido)
    // Para simplificar, generamos los logs de hoy:
    // ...
    
    final rawLogs = await trackingRepo.getLogsByDate(today);
    
    List<DailyTaskItem> items = [];
    for (var log in rawLogs) {
      // Buscamos el nombre del medicamento correspondiente
      final med = activeMeds.firstWhere((m) => m.id == log.medicationId, 
          orElse: () => Medication(id: '', name: 'Medicamento desconocido', type: MedicationType.pastilla));
      
      items.add(DailyTaskItem(
        log: log,
        medicationName: med.name,
        dose: 'Dosis programada',
      ));
    }
    return items;
  }

  Future<void> markAsTaken(String logId) async {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    // Actualizamos en base de datos
    // ...
    state = await AsyncValue.guard(() => _loadTodayTasks());
  }
}