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
    
    final List<Map<String, dynamic>> maps = await db.query(
      'medications',
      where: 'status = ?',
      whereArgs: [MedicationStatus.activo.name],
    );

    return List.generate(maps.length, (i) {
      return Medication(
        id: maps[i]['id'] as String,
        name: maps[i]['name'] as String,
        description: maps[i]['description'] as String?,
        type: MedicationType.values.byName(maps[i]['type'] as String),
        status: MedicationStatus.values.byName(maps[i]['status'] as String),
      );
    });
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