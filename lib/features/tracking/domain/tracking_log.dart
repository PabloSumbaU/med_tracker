enum LogStatus {
  pendiente,
  realizada,
  omitida,
}

class TrackingLog {
  final String logId;
  final String medicationId;
  final DateTime scheduledDate;
  final String scheduledTime;
  final DateTime? actualTakeDate;
  final String? actualTakeTime;
  final LogStatus status;

  TrackingLog({
    required this.logId,
    required this.medicationId,
    required this.scheduledDate,
    required this.scheduledTime,
    this.actualTakeDate,
    this.actualTakeTime,
    this.status = LogStatus.pendiente
  });

  TrackingLog copyWith({
    String? logId,
    String? medicationId,
    DateTime? scheduledDate,
    String? scheduledTime,
    DateTime? actualTakeDate,
    String? actualTakeTime,
    LogStatus? status
  }) {
    return TrackingLog(
      logId: logId ?? this.logId,
      medicationId: medicationId ?? this.medicationId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      actualTakeDate: actualTakeDate ?? this.actualTakeDate,
      actualTakeTime: actualTakeTime ?? this.actualTakeTime,
      status: status ?? this.status
    );
  }
}