// lib/features/tracking/data/tracking_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../domain/tracking_log.dart';

// Provider para inyectar este repositorio en la UI
final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  final dbFuture = ref.watch(databaseProvider.future);
  return TrackingRepository(dbFuture);
});

class TrackingRepository {
  final Future<Database> _dbFuture;

  TrackingRepository(this._dbFuture);

  // Guardar o actualizar un registro de toma
  Future<void> upsertTrackingLog(TrackingLog log) async {
    final db = await _dbFuture;
    
    // Extraemos solo la parte de la fecha (YYYY-MM-DD) para facilitar las búsquedas
    final scheduledDateStr = log.scheduledDate.toIso8601String().split('T').first;
    final actualTakeDateStr = log.actualTakeDate?.toIso8601String().split('T').first;

    await db.insert(
      'tracking_logs',
      {
        'logId': log.logId,
        'medicationId': log.medicationId,
        'scheduledDate': scheduledDateStr,
        'scheduledTime': log.scheduledTime,
        'actualTakeDate': actualTakeDateStr,
        'actualTakeTime': log.actualTakeTime,
        'status': log.status.name,
      },
      // Si el logId ya existe, lo reemplaza (útil para cuando el usuario presiona "Tomado")
      conflictAlgorithm: ConflictAlgorithm.replace, 
    );
  }

  // Obtener todas las tomas programadas para un día específico
  Future<List<TrackingLog>> getLogsByDate(DateTime date) async {
    final db = await _dbFuture;
    
    // Formateamos la fecha solicitada a YYYY-MM-DD
    final dateString = date.toIso8601String().split('T').first;

    final List<Map<String, dynamic>> maps = await db.query(
      'tracking_logs',
      where: 'scheduledDate = ?',
      whereArgs: [dateString],
      orderBy: 'scheduledTime ASC', // Ordenamos cronológicamente
    );

    return List.generate(maps.length, (i) {
      return TrackingLog(
        logId: maps[i]['logId'] as String,
        medicationId: maps[i]['medicationId'] as String,
        scheduledDate: DateTime.parse(maps[i]['scheduledDate'] as String),
        scheduledTime: maps[i]['scheduledTime'] as String,
        actualTakeDate: maps[i]['actualTakeDate'] != null 
            ? DateTime.parse(maps[i]['actualTakeDate'] as String) 
            : null,
        actualTakeTime: maps[i]['actualTakeTime'] as String?,
        status: LogStatus.values.byName(maps[i]['status'] as String),
      );
    });
  }

  // Verificar si ya existen logs para una fecha, si no, crearlos basados en los horarios
  Future<void> generateDailyLogsIfNeeded(DateTime date, List<Medication> activeMeds, Map<String, DoseSchedule> schedules) async {
    final db = await _dbFuture;
    final dateStr = date.toIso8601String().split('T').first;

    for (var med in activeMeds) {
      final schedule = schedules[med.id];
      if (schedule == null) continue;

      for (var time in schedule.scheduledTimes) {
        // Comprobamos si ya existe el log para este medicamento, fecha y hora
        final existing = await db.query(
          'tracking_logs',
          where: 'medicationId = ? AND scheduledDate = ? AND scheduledTime = ?',
          whereArgs: [med.id, dateStr, time],
        );

        if (existing.isEmpty) {
          await db.insert('tracking_logs', {
            'logId': '${med.id}_${dateStr}_$time',
            'medicationId': med.id,
            'scheduledDate': dateStr,
            'scheduledTime': time,
            'actualTakeDate': null,
            'actualTakeTime': null,
            'status': 'pendiente',
          });
        }
      }
    }
  }
}