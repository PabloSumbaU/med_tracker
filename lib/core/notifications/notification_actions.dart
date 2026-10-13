// lib/core/notifications/notification_actions.dart
//
// Qué pasa cuando el usuario pulsa "Tomado" o "Posponer" en la notificación
// (CU-02 / NOT-02). Funciona con la app cerrada: el plugin arranca un isolate
// en segundo plano y llama a [onBackgroundNotificationResponse].

import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/medication/data/medication_repository.dart';
import '../../features/reminders/domain/reminder_planner.dart';
import '../../features/tracking/data/tracking_repository.dart';
import '../../features/tracking/domain/tracking_log.dart';
import '../database/database_service.dart';
import 'notification_service.dart';

/// Punto de entrada en segundo plano. Debe ser una función de nivel superior
/// con @pragma('vm:entry-point') para que el compilador no la elimine.
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationResponse(
    NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  await handleNotificationResponse(response);
}

/// Maneja la respuesta tanto en primer plano como en segundo plano.
Future<void> handleNotificationResponse(NotificationResponse response) async {
  final payload = ReminderPayload.tryDecode(response.payload);
  if (payload == null) return;

  final action = response.actionId;
  // Tocar la notificación (sin acción) solo abre la app.
  if (action != kActionTake && action != kActionSnooze) return;

  try {
    // No cerramos la base: sqflite comparte la conexión con el resto de la app.
    final db = await DatabaseService.initDB();
    final result = await applyNotificationAction(
      db,
      payload: payload,
      actionId: action!,
      now: DateTime.now(),
    );

    final service = NotificationService.instance;
    await service.ensureInitialized();
    switch (result) {
      case TakenResult():
        // Quitamos un posible pospuesto pendiente de esta misma toma
        await service.cancelForLog(payload.logId);
      case SnoozeResult(:final title, :final body):
        await service.scheduleSnooze(payload, title: title, body: body);
      case IgnoredResult():
        break;
    }
  } catch (e, st) {
    debugPrint('Error al procesar la acción de notificación: $e\n$st');
  }
}

sealed class NotificationActionResult {
  const NotificationActionResult();
}

class TakenResult extends NotificationActionResult {
  const TakenResult();
}

class SnoozeResult extends NotificationActionResult {
  final String title;
  final String body;
  const SnoozeResult(this.title, this.body);
}

class IgnoredResult extends NotificationActionResult {
  const IgnoredResult();
}

/// Lógica de la acción, separada del plugin para poder probarla.
@visibleForTesting
Future<NotificationActionResult> applyNotificationAction(
  Database db, {
  required ReminderPayload payload,
  required String actionId,
  required DateTime now,
}) async {
  final medRepo = MedicationRepository(Future.value(db));
  final trackingRepo = TrackingRepository(Future.value(db));

  // El medicamento pudo eliminarse después de programar el aviso
  final med = (await medRepo.getAllMedicationsById())[payload.medicationId];
  if (med == null) return const IgnoredResult();

  final logId = await trackingRepo.ensureLog(
      payload.medicationId, payload.dateKey, payload.time);

  // Si ya se registró (desde la app o desde otra notificación), no la pisamos
  final status = await trackingRepo.getStatus(logId);
  if (status != LogStatus.pendiente) return const IgnoredResult();

  if (actionId == kActionTake) {
    // BR-03: se guarda la hora real en la que se confirmó
    await trackingRepo.markAsTaken(logId, at: now);
    return const TakenResult();
  }

  final dose =
      (await medRepo.getSchedulesByMedicationId())[med.id]?.dose ?? '';
  return SnoozeResult(
    '⏰ ${reminderTitle(med)}',
    reminderBody(dose, payload.time),
  );
}
