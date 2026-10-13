// lib/features/tracking/presentation/daily_controller.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/utils/date_keys.dart';
import '../../medication/data/medication_repository.dart';
import '../../medication/domain/medication.dart';
import '../../medication/presentation/medication_controller.dart';
import '../../reminders/data/reminder_scheduler.dart';
import '../data/tracking_repository.dart';
import '../domain/tracking_log.dart';

/// Una toma del día lista para mostrarse en la UI: el log más los datos
/// del medicamento y su dosis.
class DailyTaskItem {
  final TrackingLog log;
  final String medicationName;
  final MedicationType medicationType;
  final String dose;
  final String? description;

  const DailyTaskItem({
    required this.log,
    required this.medicationName,
    required this.medicationType,
    required this.dose,
    this.description,
  });

  /// Fecha y hora programada completa de la toma.
  DateTime get scheduledAt =>
      combineDateAndTime(log.scheduledDate, log.scheduledTime);

  /// La toma sigue pendiente y ya pasó su hora programada.
  bool isOverdue(DateTime now) =>
      log.status == LogStatus.pendiente && scheduledAt.isBefore(now);
}

final dailyControllerProvider =
    AsyncNotifierProvider<DailyController, List<DailyTaskItem>>(
  DailyController.new,
);

class DailyController extends AsyncNotifier<List<DailyTaskItem>> {
  /// Día que se está mostrando (para detectar el cambio de día).
  DateTime _day = DateTime.now();
  DateTime get day => _day;

  @override
  Future<List<DailyTaskItem>> build() async {
    // Al depender del controlador de medicamentos, esta lista se recalcula
    // sola cuando el usuario añade o elimina un medicamento.
    await ref.watch(medicationControllerProvider.future);

    // Si el usuario respondió a una notificación con la app abierta, recargamos
    final sub = NotificationService.instance.changes.listen((_) => refresh());
    ref.onDispose(sub.cancel);

    _day = DateTime.now();
    final tasks = await _loadTasks(_day);
    _syncReminders();
    return tasks;
  }

  /// Recalcula los recordatorios programados en el sistema operativo.
  void _syncReminders() {
    unawaited(ref.read(reminderSchedulerProvider).reschedule());
  }

  Future<List<DailyTaskItem>> _loadTasks(DateTime day) async {
    final medRepo = ref.read(medicationRepositoryProvider);
    final trackingRepo = ref.read(trackingRepositoryProvider);

    final activeMeds = await medRepo.getActiveMedications();
    final schedules = await medRepo.getSchedulesByMedicationId();

    // Creamos las tomas pendientes de hoy si aún no existen
    await trackingRepo.generateDailyLogsIfNeeded(day, activeMeds, schedules);

    final logs = await trackingRepo.getLogsByDate(day);
    final medsById = await medRepo.getAllMedicationsById();

    final items = <DailyTaskItem>[];
    for (final log in logs) {
      final med = medsById[log.medicationId];
      if (med == null) continue; // Medicamento eliminado
      items.add(DailyTaskItem(
        log: log,
        medicationName: med.name,
        medicationType: med.type,
        description: med.description,
        dose: schedules[log.medicationId]?.dose ?? '',
      ));
    }
    // La consulta ya viene ordenada por hora; desempatamos por nombre
    items.sort((a, b) {
      final byTime = a.log.scheduledTime.compareTo(b.log.scheduledTime);
      return byTime != 0 ? byTime : a.medicationName.compareTo(b.medicationName);
    });
    return items;
  }

  /// Recarga la lista. Si cambió el día (la app quedó abierta pasada la
  /// medianoche), genera las tomas del nuevo día.
  Future<void> refresh() async {
    _day = DateTime.now();
    state = await AsyncValue.guard(() => _loadTasks(_day));
    _syncReminders();
  }

  /// Si el día mostrado ya no es hoy, recarga.
  Future<void> refreshIfDayChanged() async {
    if (toDateKey(_day) != toDateKey(DateTime.now())) {
      await refresh();
    }
  }

  Future<void> markAsTaken(String logId) => _apply((repo) async {
        await repo.markAsTaken(logId);
        // Quitamos la notificación si ya estaba en la bandeja
        await NotificationService.instance.cancelForLog(logId);
      });

  Future<void> markAsSkipped(String logId) => _apply((repo) async {
        await repo.markAsSkipped(logId);
        await NotificationService.instance.cancelForLog(logId);
      });

  Future<void> undo(String logId) => _apply(
        (repo) => repo.resetToPending(logId),
      );

  Future<void> _apply(Future<void> Function(TrackingRepository) action) async {
    // No ponemos el estado en "loading" para que la lista no parpadee
    final repo = ref.read(trackingRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await action(repo);
      return _loadTasks(_day);
    });
    _syncReminders();
  }
}
