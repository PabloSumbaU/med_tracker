import 'package:flutter_test/flutter_test.dart';
import 'package:med_tracker/features/medication/domain/dose_schedule.dart';
import 'package:med_tracker/features/medication/domain/medication.dart';
import 'package:med_tracker/features/reminders/domain/reminder_planner.dart';
import 'package:med_tracker/features/tracking/domain/tracking_log.dart';

void main() {
  final med = Medication(
      id: 'm1', name: 'Ibuprofeno', type: MedicationType.pastilla);
  final schedules = {
    'm1': DoseSchedule(
      medicationId: 'm1',
      dose: '1 pastilla',
      frequency: DoseFrequency.diaria,
      scheduledTimes: ['08:00', '14:00', '20:00'],
    ),
  };

  // Lunes 12/10/2026 a las 13:00
  final now = DateTime(2026, 10, 12, 13, 0);

  List<PlannedReminder> plan({
    Map<String, LogStatus> statuses = const {},
    int days = 2,
    int maxCount = 60,
    Map<String, DoseSchedule>? s,
  }) =>
      planReminders(
        now: now,
        activeMeds: [med],
        schedules: s ?? schedules,
        statusByLogId: statuses,
        days: days,
        maxCount: maxCount,
      );

  test('solo programa tomas futuras, en orden', () {
    final result = plan();
    expect(result.map((r) => r.at), [
      DateTime(2026, 10, 12, 14),
      DateTime(2026, 10, 12, 20),
      DateTime(2026, 10, 13, 8),
      DateTime(2026, 10, 13, 14),
      DateTime(2026, 10, 13, 20),
    ]);
  });

  test('no avisa de tomas ya realizadas u omitidas', () {
    final result = plan(statuses: {
      'm1_2026-10-12_14:00': LogStatus.realizada,
      'm1_2026-10-12_20:00': LogStatus.omitida,
      'm1_2026-10-13_08:00': LogStatus.pendiente,
    });
    expect(result.first.at, DateTime(2026, 10, 13, 8));
    expect(result, hasLength(3));
  });

  test('respeta el máximo de notificaciones (límite de iOS)', () {
    final result = plan(days: 30, maxCount: 60);
    expect(result, hasLength(60));
    expect(result.first.at, DateTime(2026, 10, 12, 14));
  });

  test('incluye nombre, dosis y hora en el texto', () {
    final r = plan().first;
    expect(r.title, contains('Ibuprofeno'));
    expect(r.body, 'Toma 1 pastilla · programada a las 14:00');
  });

  test('frecuencias aún no soportadas no generan avisos', () {
    final result = plan(s: {
      'm1': DoseSchedule(
        medicationId: 'm1',
        dose: '1',
        frequency: DoseFrequency.intervalo,
        scheduledTimes: ['14:00'],
      ),
    });
    expect(result, isEmpty);
  });

  test('cruza bien el cambio de mes', () {
    final result = planReminders(
      now: DateTime(2026, 10, 31, 21),
      activeMeds: [med],
      schedules: schedules,
      statusByLogId: const {},
      days: 2,
    );
    expect(result.first.at, DateTime(2026, 11, 1, 8));
    expect(result.first.payload.dateKey, '2026-11-01');
  });

  group('IDs y payload', () {
    test('el ID es estable, positivo y distinto para el pospuesto', () {
      const logId = 'm1_2026-10-12_14:00';
      expect(notificationIdForLog(logId), notificationIdForLog(logId));
      expect(notificationIdForLog(logId), greaterThanOrEqualTo(0));
      expect(notificationIdForLog(logId), lessThan(1 << 31));
      expect(snoozeNotificationIdForLog(logId),
          isNot(notificationIdForLog(logId)));
      expect(notificationIdForLog('m1_2026-10-12_20:00'),
          isNot(notificationIdForLog(logId)));
    });

    test('el payload se codifica y decodifica sin perder datos', () {
      const p = ReminderPayload(
          medicationId: 'm1', dateKey: '2026-10-12', time: '14:00');
      expect(ReminderPayload.tryDecode(p.encode()), p);
      expect(ReminderPayload.tryDecode(p.asSnooze().encode())!.isSnooze, isTrue);
      expect(p.logId, 'm1_2026-10-12_14:00');
      expect(ReminderPayload.tryDecode('basura'), isNull);
      expect(ReminderPayload.tryDecode(null), isNull);
    });
  });
}
