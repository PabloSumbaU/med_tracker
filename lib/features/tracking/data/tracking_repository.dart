// lib/features/tracking/data/tracking_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../../core/utils/date_keys.dart';
import '../../medication/domain/dose_schedule.dart';
import '../../medication/domain/medication.dart';
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
    await db.insert(
      'tracking_logs',
      _toMap(log),
      // Si el logId ya existe, lo reemplaza
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Obtener todas las tomas programadas para un día específico,
  // ordenadas cronológicamente por hora programada (UI-01)
  Future<List<TrackingLog>> getLogsByDate(DateTime date) async {
    final db = await _dbFuture;

    final maps = await db.query(
      'tracking_logs',
      where: 'scheduledDate = ?',
      whereArgs: [toDateKey(date)],
      orderBy: 'scheduledTime ASC',
    );

    return maps.map(_fromMap).toList();
  }

  // Estados de todas las tomas entre dos fechas (inclusive), por logId.
  // Lo usa el planificador de recordatorios para no avisar de tomas ya hechas.
  Future<Map<String, LogStatus>> getStatusesBetween(
      DateTime from, DateTime to) async {
    final db = await _dbFuture;
    final rows = await db.query(
      'tracking_logs',
      columns: ['logId', 'status'],
      where: 'scheduledDate BETWEEN ? AND ?',
      whereArgs: [toDateKey(from), toDateKey(to)],
    );
    return {
      for (final r in rows)
        r['logId'] as String: LogStatus.values.byName(r['status'] as String),
    };
  }

  // Garantiza que exista el registro de una toma (pendiente si es nuevo).
  // Necesario cuando se responde a una notificación de un día cuyas tomas
  // aún no se habían generado (p. ej. la app no se abrió ese día).
  Future<String> ensureLog(
      String medicationId, String dateKey, String time) async {
    final db = await _dbFuture;
    final logId = buildLogId(medicationId, dateKey, time);
    await db.insert(
      'tracking_logs',
      {
        'logId': logId,
        'medicationId': medicationId,
        'scheduledDate': dateKey,
        'scheduledTime': time,
        'actualTakeDate': null,
        'actualTakeTime': null,
        'status': LogStatus.pendiente.name,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return logId;
  }

  // Estado actual de una toma, o null si no existe.
  Future<LogStatus?> getStatus(String logId) async {
    final db = await _dbFuture;
    final rows = await db.query('tracking_logs',
        columns: ['status'], where: 'logId = ?', whereArgs: [logId]);
    if (rows.isEmpty) return null;
    return LogStatus.values.byName(rows.first['status'] as String);
  }

  // Marcar una toma como Realizada guardando la fecha y hora REAL en la que
  // el usuario la confirmó en la app (BR-03), aunque sea retroactiva.
  Future<void> markAsTaken(String logId, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    await _updateStatus(
      logId,
      LogStatus.realizada,
      actualTakeDate: toDateKey(now),
      actualTakeTime: toTimeKey(now),
    );
  }

  // Marcar una toma como Omitida (no se registra hora real de toma)
  Future<void> markAsSkipped(String logId) =>
      _updateStatus(logId, LogStatus.omitida);

  // Volver una toma a Pendiente (para deshacer un toque equivocado)
  Future<void> resetToPending(String logId) =>
      _updateStatus(logId, LogStatus.pendiente);

  Future<void> _updateStatus(
    String logId,
    LogStatus status, {
    String? actualTakeDate,
    String? actualTakeTime,
  }) async {
    final db = await _dbFuture;
    await db.update(
      'tracking_logs',
      {
        'status': status.name,
        'actualTakeDate': actualTakeDate,
        'actualTakeTime': actualTakeTime,
      },
      where: 'logId = ?',
      whereArgs: [logId],
    );
  }

  // Crea las tomas "pendientes" de un día a partir de los horarios de cada
  // medicamento activo. Es idempotente: si la toma ya existe no se toca, así
  // que se puede llamar cada vez que se abre la pantalla de Hoy.
  //
  // Nota: por ahora solo la frecuencia "diaria" genera tomas; los días
  // específicos y los intervalos de horas se implementarán más adelante.
  Future<void> generateDailyLogsIfNeeded(
    DateTime date,
    List<Medication> activeMeds,
    Map<String, DoseSchedule> schedules,
  ) async {
    final db = await _dbFuture;
    final dateStr = toDateKey(date);

    final batch = db.batch();
    for (final med in activeMeds) {
      final schedule = schedules[med.id];
      if (schedule == null || schedule.frequency != DoseFrequency.diaria) {
        continue;
      }

      for (final time in schedule.scheduledTimes) {
        // El ID es determinista (medicamento + fecha + hora), así que con
        // ConflictAlgorithm.ignore nunca se duplican ni se pisan registros.
        batch.insert(
          'tracking_logs',
          {
            'logId': buildLogId(med.id, dateStr, time),
            'medicationId': med.id,
            'scheduledDate': dateStr,
            'scheduledTime': time,
            'actualTakeDate': null,
            'actualTakeTime': null,
            'status': LogStatus.pendiente.name,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  static String buildLogId(String medicationId, String dateKey, String time) =>
      '${medicationId}_${dateKey}_$time';

  Map<String, Object?> _toMap(TrackingLog log) => {
        'logId': log.logId,
        'medicationId': log.medicationId,
        'scheduledDate': toDateKey(log.scheduledDate),
        'scheduledTime': log.scheduledTime,
        'actualTakeDate':
            log.actualTakeDate == null ? null : toDateKey(log.actualTakeDate!),
        'actualTakeTime': log.actualTakeTime,
        'status': log.status.name,
      };

  TrackingLog _fromMap(Map<String, Object?> row) {
    return TrackingLog(
      logId: row['logId'] as String,
      medicationId: row['medicationId'] as String,
      scheduledDate: DateTime.parse(row['scheduledDate'] as String),
      scheduledTime: row['scheduledTime'] as String,
      actualTakeDate: row['actualTakeDate'] != null
          ? DateTime.parse(row['actualTakeDate'] as String)
          : null,
      actualTakeTime: row['actualTakeTime'] as String?,
      status: LogStatus.values.byName(row['status'] as String),
    );
  }
}
