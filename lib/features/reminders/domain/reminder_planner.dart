// lib/features/reminders/domain/reminder_planner.dart
//
// Lógica pura (sin plugins) que decide QUÉ recordatorios deben estar
// programados en el sistema operativo.
//
// Estrategia de "ventana deslizante": en vez de alarmas repetitivas diarias,
// se programan notificaciones individuales para las próximas tomas
// pendientes (por defecto 7 días, máximo 60). Así:
//   * una toma ya marcada desde la app no vuelve a sonar,
//   * respetamos el límite de 64 notificaciones pendientes de iOS,
//   * cada vez que se abre la app la ventana se recalcula.

import 'dart:convert';

import '../../../core/utils/date_keys.dart';
import '../../medication/domain/dose_schedule.dart';
import '../../medication/domain/medication.dart';
import '../../tracking/data/tracking_repository.dart';
import '../../tracking/domain/tracking_log.dart';

/// Datos que viajan dentro de la notificación para saber a qué toma
/// corresponde cuando el usuario pulsa "Tomado" o "Posponer".
class ReminderPayload {
  final String medicationId;
  final String dateKey; // YYYY-MM-DD
  final String time; // HH:mm
  final bool isSnooze;

  const ReminderPayload({
    required this.medicationId,
    required this.dateKey,
    required this.time,
    this.isSnooze = false,
  });

  String get logId => TrackingRepository.buildLogId(medicationId, dateKey, time);

  ReminderPayload asSnooze() => ReminderPayload(
        medicationId: medicationId,
        dateKey: dateKey,
        time: time,
        isSnooze: true,
      );

  String encode() => jsonEncode({
        'm': medicationId,
        'd': dateKey,
        't': time,
        if (isSnooze) 's': 1,
      });

  static ReminderPayload? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ReminderPayload(
        medicationId: map['m'] as String,
        dateKey: map['d'] as String,
        time: map['t'] as String,
        isSnooze: map['s'] == 1,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderPayload &&
      other.medicationId == medicationId &&
      other.dateKey == dateKey &&
      other.time == time &&
      other.isSnooze == isSnooze;

  @override
  int get hashCode => Object.hash(medicationId, dateKey, time, isSnooze);
}

/// Un recordatorio que debe programarse.
class PlannedReminder {
  final int id;
  final DateTime at;
  final ReminderPayload payload;
  final String title;
  final String body;

  const PlannedReminder({
    required this.id,
    required this.at,
    required this.payload,
    required this.title,
    required this.body,
  });
}

/// ID numérico estable (31 bits) a partir de un texto, usando FNV-1a.
/// La misma toma siempre produce el mismo ID, así se puede cancelar.
int stableNotificationId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in utf8.encode(key)) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

int notificationIdForLog(String logId) => stableNotificationId(logId);
int snoozeNotificationIdForLog(String logId) =>
    stableNotificationId('$logId#snooze');

/// Calcula los recordatorios de las próximas tomas pendientes.
///
/// [statusByLogId] contiene el estado de las tomas que ya existen en la base
/// de datos; las que no aparecen se consideran pendientes.
List<PlannedReminder> planReminders({
  required DateTime now,
  required List<Medication> activeMeds,
  required Map<String, DoseSchedule> schedules,
  required Map<String, LogStatus> statusByLogId,
  int days = 7,
  int maxCount = 60,
}) {
  final result = <PlannedReminder>[];
  final today = DateTime(now.year, now.month, now.day);

  for (var offset = 0; offset < days; offset++) {
    final date = DateTime(today.year, today.month, today.day + offset);
    final dateKey = toDateKey(date);

    for (final med in activeMeds) {
      final schedule = schedules[med.id];
      // Por ahora solo la frecuencia diaria genera tomas (igual que en Hoy)
      if (schedule == null || schedule.frequency != DoseFrequency.diaria) {
        continue;
      }

      for (final time in schedule.scheduledTimes) {
        final at = combineDateAndTime(date, time);
        if (!at.isAfter(now)) continue;

        final payload = ReminderPayload(
          medicationId: med.id,
          dateKey: dateKey,
          time: time,
        );
        final status = statusByLogId[payload.logId];
        if (status != null && status != LogStatus.pendiente) continue;

        result.add(PlannedReminder(
          id: notificationIdForLog(payload.logId),
          at: at,
          payload: payload,
          title: reminderTitle(med),
          body: reminderBody(schedule.dose, time),
        ));
      }
    }
  }

  result.sort((a, b) => a.at.compareTo(b.at));
  return result.length > maxCount ? result.sublist(0, maxCount) : result;
}

String reminderTitle(Medication med) => '💊 Hora de tu ${med.name}';

String reminderBody(String dose, String time) =>
    dose.isEmpty ? 'Programada a las $time' : 'Toma $dose · programada a las $time';
