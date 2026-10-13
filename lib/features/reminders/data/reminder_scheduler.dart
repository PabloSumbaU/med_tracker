// lib/features/reminders/data/reminder_scheduler.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../medication/data/medication_repository.dart';
import '../../tracking/data/tracking_repository.dart';
import '../../tracking/domain/tracking_log.dart';
import '../domain/reminder_planner.dart';

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return ReminderScheduler(
    medicationRepository: ref.watch(medicationRepositoryProvider),
    trackingRepository: ref.watch(trackingRepositoryProvider),
    notifications: NotificationService.instance,
  );
});

/// Mantiene sincronizados los recordatorios del sistema operativo con los
/// medicamentos y las tomas guardadas.
class ReminderScheduler {
  ReminderScheduler({
    required this.medicationRepository,
    required this.trackingRepository,
    required this.notifications,
    this.windowDays = 7,
  });

  final MedicationRepository medicationRepository;
  final TrackingRepository trackingRepository;
  final NotificationService notifications;
  final int windowDays;

  // Encadena las ejecuciones para que dos reprogramaciones no se mezclen
  static Future<void> _queue = Future.value();

  Future<void> reschedule() {
    if (!NotificationService.isSupported) return Future.value();
    final run = _queue.then((_) => _reschedule()).catchError((Object e, st) {
      debugPrint('No se pudieron programar los recordatorios: $e\n$st');
    });
    _queue = run;
    return run;
  }

  Future<void> _reschedule() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(today.year, today.month, today.day + windowDays);

    final activeMeds = await medicationRepository.getActiveMedications();
    final schedules = await medicationRepository.getSchedulesByMedicationId();
    final statuses =
        await trackingRepository.getStatusesBetween(today, lastDay);

    final plan = planReminders(
      now: now,
      activeMeds: activeMeds,
      schedules: schedules,
      statusByLogId: statuses,
      days: windowDays,
    );

    // 1. Quitamos lo programado que ya no corresponde
    for (final p in await notifications.pending()) {
      final payload = ReminderPayload.tryDecode(p.payload);
      if (payload != null && payload.isSnooze) {
        // Un pospuesto se mantiene salvo que la toma ya no esté pendiente
        // o el medicamento haya dejado de estar activo
        final status = statuses[payload.logId];
        final stillActive = activeMeds.any((m) => m.id == payload.medicationId);
        if (stillActive && (status == null || status == LogStatus.pendiente)) {
          continue;
        }
      }
      await notifications.cancel(p.id);
    }

    // 2. Programamos la ventana actual
    for (final r in plan) {
      await notifications.schedule(
        id: r.id,
        at: r.at,
        title: r.title,
        body: r.body,
        payload: r.payload,
      );
    }
  }
}
