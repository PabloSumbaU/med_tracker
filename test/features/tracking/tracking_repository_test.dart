import 'package:flutter_test/flutter_test.dart';
import 'package:med_tracker/core/database/database_service.dart';
import 'package:med_tracker/features/medication/data/medication_repository.dart';
import 'package:med_tracker/features/medication/domain/dose_schedule.dart';
import 'package:med_tracker/features/medication/domain/medication.dart';
import 'package:med_tracker/features/tracking/data/tracking_repository.dart';
import 'package:med_tracker/features/tracking/domain/tracking_log.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late MedicationRepository medRepo;
  late TrackingRepository trackingRepo;

  final day = DateTime(2026, 10, 12);

  final ibuprofeno = Medication(
    id: 'med-1',
    name: 'Ibuprofeno',
    type: MedicationType.pastilla,
  );
  final jarabe = Medication(
    id: 'med-2',
    name: 'Jarabe tos',
    type: MedicationType.jarabe,
  );

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: DatabaseService.createSchema,
        onConfigure: DatabaseService.configure,
      ),
    );
    medRepo = MedicationRepository(Future.value(db));
    trackingRepo = TrackingRepository(Future.value(db));

    await medRepo.insertMedicationWithSchedule(
      ibuprofeno,
      DoseSchedule(
        medicationId: 'med-1',
        dose: '1 pastilla',
        frequency: DoseFrequency.diaria,
        scheduledTimes: ['20:00', '08:00'],
      ),
    );
    await medRepo.insertMedicationWithSchedule(
      jarabe,
      DoseSchedule(
        medicationId: 'med-2',
        dose: '5 ml',
        frequency: DoseFrequency.diaria,
        scheduledTimes: ['14:00'],
      ),
    );
  });

  tearDown(() => db.close());

  Future<void> generate() async {
    await trackingRepo.generateDailyLogsIfNeeded(
      day,
      await medRepo.getActiveMedications(),
      await medRepo.getSchedulesByMedicationId(),
    );
  }

  test('lee los esquemas de dosis guardados', () async {
    final schedules = await medRepo.getSchedulesByMedicationId();
    expect(schedules['med-1']!.dose, '1 pastilla');
    expect(schedules['med-1']!.scheduledTimes, ['20:00', '08:00']);
    expect(schedules['med-2']!.frequency, DoseFrequency.diaria);
  });

  test('genera las tomas del día en orden cronológico y como pendientes',
      () async {
    await generate();
    final logs = await trackingRepo.getLogsByDate(day);

    expect(logs.map((l) => l.scheduledTime), ['08:00', '14:00', '20:00']);
    expect(logs.every((l) => l.status == LogStatus.pendiente), isTrue);
  });

  test('generar dos veces no duplica ni pisa tomas ya registradas', () async {
    await generate();
    final first = (await trackingRepo.getLogsByDate(day)).first;
    await trackingRepo.markAsTaken(first.logId, at: DateTime(2026, 10, 12, 8, 5));

    await generate();
    final logs = await trackingRepo.getLogsByDate(day);

    expect(logs, hasLength(3));
    expect(logs.first.status, LogStatus.realizada);
  });

  test('tomar guarda la fecha y hora real de confirmación (BR-03)', () async {
    await generate();
    final log = (await trackingRepo.getLogsByDate(day)).first;

    // Se confirma tarde, de forma retroactiva
    await trackingRepo.markAsTaken(log.logId,
        at: DateTime(2026, 10, 12, 10, 47));

    final updated = (await trackingRepo.getLogsByDate(day)).first;
    expect(updated.status, LogStatus.realizada);
    expect(updated.actualTakeDate, DateTime(2026, 10, 12));
    expect(updated.actualTakeTime, '10:47');
    // La hora programada no cambia
    expect(updated.scheduledTime, '08:00');
  });

  test('omitir y deshacer limpian la hora real', () async {
    await generate();
    final log = (await trackingRepo.getLogsByDate(day)).first;

    await trackingRepo.markAsTaken(log.logId, at: DateTime(2026, 10, 12, 8));
    await trackingRepo.markAsSkipped(log.logId);
    var updated = (await trackingRepo.getLogsByDate(day)).first;
    expect(updated.status, LogStatus.omitida);
    expect(updated.actualTakeTime, isNull);

    await trackingRepo.resetToPending(log.logId);
    updated = (await trackingRepo.getLogsByDate(day)).first;
    expect(updated.status, LogStatus.pendiente);
  });

  test('los medicamentos inactivos no generan tomas nuevas', () async {
    await db.update('medications', {'status': 'inactivo'},
        where: 'id = ?', whereArgs: ['med-2']);
    await generate();
    final logs = await trackingRepo.getLogsByDate(day);
    expect(logs.map((l) => l.medicationId), everyElement('med-1'));
  });

  test('las tomas de otro día no aparecen', () async {
    await generate();
    expect(await trackingRepo.getLogsByDate(DateTime(2026, 10, 13)), isEmpty);
  });
}
