import 'package:flutter_test/flutter_test.dart';
import 'package:med_tracker/core/database/database_service.dart';
import 'package:med_tracker/core/notifications/notification_actions.dart';
import 'package:med_tracker/core/notifications/notification_service.dart';
import 'package:med_tracker/features/medication/data/medication_repository.dart';
import 'package:med_tracker/features/medication/domain/dose_schedule.dart';
import 'package:med_tracker/features/medication/domain/medication.dart';
import 'package:med_tracker/features/reminders/domain/reminder_planner.dart';
import 'package:med_tracker/features/tracking/data/tracking_repository.dart';
import 'package:med_tracker/features/tracking/domain/tracking_log.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late TrackingRepository tracking;

  const payload = ReminderPayload(
      medicationId: 'm1', dateKey: '2026-10-12', time: '14:00');

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: DatabaseService.createSchema,
        onConfigure: DatabaseService.configure,
      ),
    );
    tracking = TrackingRepository(Future.value(db));
    await MedicationRepository(Future.value(db)).insertMedicationWithSchedule(
      Medication(id: 'm1', name: 'Ibuprofeno', type: MedicationType.pastilla),
      DoseSchedule(
        medicationId: 'm1',
        dose: '1 pastilla',
        frequency: DoseFrequency.diaria,
        scheduledTimes: ['14:00'],
      ),
    );
  });

  tearDown(() => db.close());

  test('"Tomado" con la app cerrada crea la toma y guarda la hora real',
      () async {
    // La app no se abrió ese día: la toma aún no existe en la base
    expect(await tracking.getStatus(payload.logId), isNull);

    final result = await applyNotificationAction(db,
        payload: payload,
        actionId: kActionTake,
        now: DateTime(2026, 10, 12, 14, 3));

    expect(result, isA<TakenResult>());
    final log = (await tracking.getLogsByDate(DateTime(2026, 10, 12))).single;
    expect(log.status, LogStatus.realizada);
    expect(log.actualTakeTime, '14:03');
  });

  test('"Posponer" no cambia el estado y devuelve el texto del aviso',
      () async {
    final result = await applyNotificationAction(db,
        payload: payload,
        actionId: kActionSnooze,
        now: DateTime(2026, 10, 12, 14, 1));

    expect(result, isA<SnoozeResult>());
    expect((result as SnoozeResult).title, contains('Ibuprofeno'));
    expect(result.body, contains('1 pastilla'));
    expect(await tracking.getStatus(payload.logId), LogStatus.pendiente);
  });

  test('no pisa una toma ya registrada desde la app', () async {
    final logId = await tracking.ensureLog('m1', '2026-10-12', '14:00');
    await tracking.markAsTaken(logId, at: DateTime(2026, 10, 12, 13, 50));

    final result = await applyNotificationAction(db,
        payload: payload,
        actionId: kActionTake,
        now: DateTime(2026, 10, 12, 14, 30));

    expect(result, isA<IgnoredResult>());
    final log = (await tracking.getLogsByDate(DateTime(2026, 10, 12))).single;
    expect(log.actualTakeTime, '13:50');
  });

  test('ignora avisos de medicamentos eliminados', () async {
    await MedicationRepository(Future.value(db)).deleteMedication('m1');
    final result = await applyNotificationAction(db,
        payload: payload, actionId: kActionTake, now: DateTime(2026, 10, 12));
    expect(result, isA<IgnoredResult>());
  });
}
