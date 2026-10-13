// lib/features/medication/data/medication_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../domain/medication.dart';
import '../domain/dose_schedule.dart';

// Provider para inyectar el repositorio fácilmente en la UI
final medicationRepositoryProvider = Provider<MedicationRepository>((ref) {
  // Le pasamos el future de la base de datos al repositorio
  final dbFuture = ref.watch(databaseProvider.future);
  return MedicationRepository(dbFuture);
});

class MedicationRepository {
  final Future<Database> _dbFuture;

  MedicationRepository(this._dbFuture);

  // Guardar un medicamento y su esquema de dosis en una sola transacción
  Future<void> insertMedicationWithSchedule(Medication med, DoseSchedule schedule) async {
    final db = await _dbFuture;
    
    // Usamos un batch/transacción para asegurar que ambos se guarden o ninguno
    await db.transaction((txn) async {
      // 1. Guardar Medicamento
      await txn.insert(
        'medications',
        {
          'id': med.id,
          'name': med.name,
          'description': med.description,
          'type': med.type.name,
          'status': med.status.name,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Guardar Esquema
      await txn.insert(
        'dose_schedules',
        {
          'medicationId': schedule.medicationId,
          'dose': schedule.dose,
          'frequency': schedule.frequency.name,
          'scheduledTimes': schedule.scheduledTimes.join(','), // Convertimos la lista a String
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // Obtener todos los medicamentos activos
  Future<List<Medication>> getActiveMedications() async {
    final db = await _dbFuture;

    final maps = await db.query(
      'medications',
      where: 'status = ?',
      whereArgs: [MedicationStatus.activo.name],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return maps.map(_medicationFromMap).toList();
  }

  // Obtener todos los medicamentos (activos e inactivos), indexados por ID.
  // Útil para mostrar el nombre en el historial aunque el medicamento esté archivado.
  Future<Map<String, Medication>> getAllMedicationsById() async {
    final db = await _dbFuture;
    final maps = await db.query('medications');
    return {
      for (final m in maps.map(_medicationFromMap)) m.id: m,
    };
  }

  // Obtener todos los esquemas de dosis, indexados por ID de medicamento
  Future<Map<String, DoseSchedule>> getSchedulesByMedicationId() async {
    final db = await _dbFuture;
    final maps = await db.query('dose_schedules');

    return {
      for (final row in maps)
        row['medicationId'] as String: DoseSchedule(
          medicationId: row['medicationId'] as String,
          dose: row['dose'] as String,
          frequency: DoseFrequency.values.byName(row['frequency'] as String),
          scheduledTimes: (row['scheduledTimes'] as String)
              .split(',')
              .where((t) => t.isNotEmpty)
              .toList(),
        ),
    };
  }

  Medication _medicationFromMap(Map<String, Object?> row) {
    return Medication(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      type: MedicationType.values.byName(row['type'] as String),
      status: MedicationStatus.values.byName(row['status'] as String),
    );
  }

  // Eliminar un medicamento (gracias al ON DELETE CASCADE en SQLite, 
  // esto borrará también su dose_schedule y sus tracking_logs automáticamente)
  Future<void> deleteMedication(String id) async {
    final db = await _dbFuture;
    await db.delete(
      'medications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}