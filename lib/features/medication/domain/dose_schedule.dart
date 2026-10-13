enum DoseFrequency {
  diaria,
  diasEspecificos,
  intervalo
}

class DoseSchedule{

  final String medicationId;
  final String dose;
  final DoseFrequency frequency;
  final List<String> scheduledTimes;


  DoseSchedule({
    required this.medicationId,
    required this.dose,
    required this.frequency,
    required this.scheduledTimes
  });

  DoseSchedule copyWith({
    String? medicationId,
    String? dose,
    DoseFrequency? frequency,
    List<String>? scheduledTimes
  }) {
    return DoseSchedule(
      medicationId: medicationId ?? this.medicationId,
      dose: dose ?? this.dose,
      frequency: frequency ?? this.frequency,
      scheduledTimes: scheduledTimes ?? this.scheduledTimes
    );
  }

}